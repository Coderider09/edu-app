import logging
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)


def verify(token: str) -> Optional[dict]:
    """Verify a Google ID token and return its claims, or None if invalid."""
    if not settings.GOOGLE_CLIENT_IDS:
        logger.warning("GOOGLE_CLIENT_IDS is not configured; Google sign-in is disabled")
        return None
    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token

        info = id_token.verify_oauth2_token(token, google_requests.Request())
    except Exception:  # invalid signature, expired, network error...
        return None
    if info.get("aud") not in settings.GOOGLE_CLIENT_IDS:
        return None
    return info
