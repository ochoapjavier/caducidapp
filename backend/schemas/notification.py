# backend/schemas/notification.py
from pydantic import BaseModel, ConfigDict


class DeviceRegisterRequest(BaseModel):
    fcm_token: str
    platform: str  # 'android', 'web', 'ios'
    installation_id: str | None = None


class PreferenceUpdateRequest(BaseModel):
    notifications_enabled: bool
    notification_time: str  # "HH:MM:SS"
    timezone_offset: int  # Legacy client offset in minutes
    timezone: str = 'Europe/Madrid'


class PreferenceResponse(BaseModel):
    user_id: str
    notifications_enabled: bool
    notification_time: str
    timezone_offset: int
    timezone: str

    model_config = ConfigDict(from_attributes=True)
