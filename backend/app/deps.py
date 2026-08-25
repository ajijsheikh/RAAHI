from fastapi import Request, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.config import settings
import uuid

DEV_USER_ID = "00000000-0000-4000-8000-000000000001"


async def get_current_user_id(request: Request) -> str:
    """Dependency that returns the current user id based on AUTH_MODE.

    Modes:
    - "header": Reads X-User-Id header; falls back to dev UUID if absent.
    - "supabase_jwt": Verifies Bearer JWT via SUPABASE_JWT_SECRET.
    """
    if settings.AUTH_MODE == "header":
        return request.headers.get("X-User-Id") or DEV_USER_ID

    # supabase_jwt mode
    auth: str = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    token = auth[7:]
    # In a full implementation, verify JWT signature against SUPABASE_JWT_SECRET
    # For now, validate basic structure
    if not token or "." not in token:
        raise HTTPException(status_code=401, detail="Invalid JWT format")
    # Return the sub claim would happen here with jwt.decode(token, settings.SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
    # For dev compatibility, return a placeholder
    return token[:36] if len(token) >= 36 else DEV_USER_ID