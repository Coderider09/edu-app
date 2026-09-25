"""Offline mode: downloadable content packs and upload of work done without internet."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.api.v1.serializers import profile_out
from app.core.deps import get_onboarded_user
from app.db.database import get_db
from app.models import Subject, User, UserRole
from app.schemas.offline import ManifestOut, SyncIn, SyncOut
from app.services import packs
from app.services.sync import sync

router = APIRouter()


@router.get("/packs", response_model=ManifestOut)
def get_packs(
    cluster_id: Optional[int] = Query(default=None),
    grade: Optional[int] = Query(default=None, ge=1, le=11),
    user: User = Depends(get_onboarded_user),
    db: Session = Depends(get_db),
):
    """Cluster structures (subtests, durations) and the packs to download.

    Without parameters — the packs of the user's cluster (abiturient) or grade (schoolboy).
    Compare `version` with the downloaded one to know whether an update is available.
    """
    if cluster_id is None and grade is None:
        if user.active_role == UserRole.ABITURIENT and user.abiturient_profile:
            cluster_id = user.abiturient_profile.cluster_id
        elif user.active_role == UserRole.SCHOOLBOY and user.school_profile:
            grade = user.school_profile.grade
    return packs.manifest(db, cluster_id=cluster_id, grade=grade)


@router.get("/packs/{subject_id}/download", response_class=FileResponse)
def download_pack(subject_id: int, _: User = Depends(get_onboarded_user), db: Session = Depends(get_db)):
    """ZIP: `content.json` (topics, lessons, questions with answer keys and explanations) + `images/`."""
    subject = db.get(Subject, subject_id)
    if subject is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")
    path = packs.build_zip(db, subject)
    version = path.stem.rsplit("-", 1)[-1]
    return FileResponse(
        path,
        media_type="application/zip",
        filename=f"{subject.code or subject.id}-{version}.zip",
        headers={"X-Pack-Version": version},
    )


@router.post("/sync", response_model=SyncOut)
def sync_offline(data: SyncIn, user: User = Depends(get_onboarded_user), db: Session = Depends(get_db)):
    """Upload offline attempts, read lessons and marks. Safe to retry: attempts are deduplicated by
    `client_id`. Answers are re-graded on the server; the response has the official result of each attempt."""
    result = sync(db, user, data)
    db.refresh(user)
    return {**result, "profile": profile_out(db, user)}
