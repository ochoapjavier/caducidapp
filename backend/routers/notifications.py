# backend/routers/notifications.py
import hmac
import os

from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.orm import Session

from auth.firebase_auth import get_current_user_id
from database import get_db
from schemas.notification import DeviceRegisterRequest, PreferenceUpdateRequest, PreferenceResponse
from services.notification_service import NotificationService

router = APIRouter()

@router.post("/device", status_code=status.HTTP_201_CREATED)
def register_device(
    request: DeviceRegisterRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """Register a user device for push notifications."""
    service = NotificationService(db)
    service.register_device(
        user_id, request.fcm_token, request.platform, request.installation_id
    )
    return {"status": "registered"}

@router.post("/preferences")
def update_preferences(
    request: PreferenceUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """Update user notification preferences."""
    service = NotificationService(db)
    service.update_preferences(
        user_id, 
        request.notifications_enabled, 
        request.notification_time, 
        request.timezone_offset,
        request.timezone,
    )
    return {"status": "updated"}

@router.get("/preferences", response_model=PreferenceResponse)
def get_preferences(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """Get user notification preferences."""
    service = NotificationService(db)
    return service.get_preferences(user_id)

# Cron endpoint - Protected by Secret
@router.post("/cron/trigger-notifications")
def trigger_notifications(
    authorization: str = Header(None),
    db: Session = Depends(get_db)
):
    """
    Trigger daily notifications. 
    Protected by CRON_SECRET env var.
    Intended to be called by GitHub Actions or external scheduler.
    """
    cron_secret = os.getenv("CRON_SECRET")
    if not cron_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Cron notifications are not configured",
        )

    expected_header = f"Bearer {cron_secret}"
    if not authorization or not hmac.compare_digest(authorization, expected_header):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Cron Secret",
        )
    
    service = NotificationService(db)
    result = service.trigger_daily_notifications()
    return result
