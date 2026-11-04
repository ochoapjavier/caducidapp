# backend/schemas/notification.py
from pydantic import BaseModel, ConfigDict


class DeviceRegisterRequest(BaseModel):
    fcm_token: str
    platform: str  # 'android', 'web', 'ios'


class PreferenceUpdateRequest(BaseModel):
    notifications_enabled: bool
    notification_time: str  # "HH:MM:SS"
    timezone_offset: int  # Minutes


class PreferenceResponse(BaseModel):
    user_id: str
    notifications_enabled: bool
    notification_time: str
    timezone_offset: int

    model_config = ConfigDict(from_attributes=True)
