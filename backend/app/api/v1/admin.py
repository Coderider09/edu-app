"""Admin REST API: content CRUD (content manager) and users/statistics (superadmin)."""
from typing import Type

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.deps import require_content_manager, require_superadmin
from app.db.database import Base, get_db
from app.models import Cluster, ClusterSubject, ExamTest, Lesson, Question, Subject, Topic, User
from app.schemas.admin import ClusterIn, ClusterSubjectIn, ExamTestIn, LessonIn, QuestionIn, SubjectIn, TopicIn
from app.services.stats import collect_stats

router = APIRouter()


def _to_dict(obj: Base) -> dict:
    return {c.name: getattr(obj, c.name) for c in obj.__table__.columns}


def _save(db: Session, obj: Base) -> dict:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Integrity error: {exc.orig}") from exc
    db.refresh(obj)
    return _to_dict(obj)


def _check_refs(db: Session, data: BaseModel) -> None:
    refs = {
        "cluster_id": Cluster, "subject_id": Subject, "topic_id": Topic, "parent_topic_id": Topic,
        "lesson_id": Lesson, "exam_test_id": ExamTest,
    }
    for field, model in refs.items():
        value = getattr(data, field, None)
        if value is not None and db.get(model, value) is None:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=f"{field}={value} not found")


def _register_crud(path: str, model: Type[Base], schema: Type[BaseModel]) -> None:
    @router.post(f"/{path}", status_code=status.HTTP_201_CREATED, name=f"create_{path}")
    def create(data: schema, db: Session = Depends(get_db), _: User = Depends(require_content_manager)):  # type: ignore[valid-type]
        _check_refs(db, data)
        obj = model(**data.model_dump())
        db.add(obj)
        return _save(db, obj)

    @router.put(f"/{path}/{{obj_id}}", name=f"update_{path}")
    def update(obj_id: int, data: schema, db: Session = Depends(get_db), _: User = Depends(require_content_manager)):  # type: ignore[valid-type]
        obj = db.get(model, obj_id)
        if obj is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
        _check_refs(db, data)
        for key, value in data.model_dump().items():
            setattr(obj, key, value)
        return _save(db, obj)

    @router.delete(f"/{path}/{{obj_id}}", status_code=status.HTTP_204_NO_CONTENT, name=f"delete_{path}")
    def delete(obj_id: int, db: Session = Depends(get_db), _: User = Depends(require_content_manager)):
        obj = db.get(model, obj_id)
        if obj is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
        db.delete(obj)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Object is still referenced") from None


_register_crud("clusters", Cluster, ClusterIn)
_register_crud("subjects", Subject, SubjectIn)
_register_crud("cluster-subjects", ClusterSubject, ClusterSubjectIn)
_register_crud("topics", Topic, TopicIn)
_register_crud("lessons", Lesson, LessonIn)
_register_crud("questions", Question, QuestionIn)
_register_crud("exam-tests", ExamTest, ExamTestIn)


@router.get("/stats")
def stats(db: Session = Depends(get_db), _: User = Depends(require_superadmin)) -> dict:
    """DAU, tests taken, average result by cluster."""
    return collect_stats(db)


def _set_active(db: Session, user_id: int, active: bool, admin: User) -> dict:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if user.id == admin.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot block yourself")
    user.is_active = active
    db.commit()
    return {"id": user.id, "is_active": user.is_active}


@router.post("/users/{user_id}/ban")
def ban_user(user_id: int, db: Session = Depends(get_db), admin: User = Depends(require_superadmin)) -> dict:
    return _set_active(db, user_id, False, admin)


@router.post("/users/{user_id}/unban")
def unban_user(user_id: int, db: Session = Depends(get_db), admin: User = Depends(require_superadmin)) -> dict:
    return _set_active(db, user_id, True, admin)
