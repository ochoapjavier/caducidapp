# backend/services/notification_service.py
from sqlalchemy.orm import Session
from models import (
    HogarMiembro,
    InventoryStock,
    NotificationDelivery,
    Product,
    UserDevice,
    UserPreference,
)
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from firebase_admin import messaging
import logging

logger = logging.getLogger(__name__)

class NotificationService:
    def __init__(self, db: Session):
        self.db = db

    def register_device(
        self,
        user_id: str,
        token: str,
        platform: str,
        installation_id: str | None = None,
    ):
        """Upsert one FCM token for a user installation."""
        query = self.db.query(UserDevice).filter(UserDevice.user_id == user_id)
        device = None
        if installation_id:
            device = query.filter(
                UserDevice.installation_id == installation_id
            ).first()
        if not device:
            device = query.filter(UserDevice.fcm_token == token).first()

        if not device:
            device = UserDevice(
                user_id=user_id,
                fcm_token=token,
                platform=platform,
                installation_id=installation_id,
            )
            self.db.add(device)
        else:
            device.fcm_token = token
            device.platform = platform
            device.last_active = datetime.utcnow()
            device.last_error_code = None
            device.last_error_at = None

        self.db.commit()
        self.db.refresh(device)
        return device

    def update_preferences(
        self,
        user_id: str,
        enabled: bool,
        time_str: str,
        offset: int,
        timezone: str = "Europe/Madrid",
    ):
        """Update notification preferences, including the IANA timezone."""
        self._validate_timezone(timezone)
        self._parse_notification_time(time_str)
        pref = self.db.query(UserPreference).filter_by(user_id=user_id).first()
        if pref:
            pref.notifications_enabled = enabled
            pref.notification_time = time_str
            pref.timezone_offset = offset
            pref.timezone = timezone
        else:
            pref = UserPreference(
                user_id=user_id,
                notifications_enabled=enabled,
                notification_time=time_str,
                timezone_offset=offset,
                timezone=timezone,
            )
            self.db.add(pref)
        self.db.commit()
        self.db.refresh(pref)
        return pref

    def get_preferences(self, user_id: str):
        """Get user preferences, creating default if not exists."""
        pref = self.db.query(UserPreference).filter_by(user_id=user_id).first()
        if not pref:
            pref = UserPreference(user_id=user_id)
            self.db.add(pref)
            self.db.commit()
        return pref

    def trigger_daily_notifications(self):
        """Send scheduled expiry notifications with retry-safe diagnostics."""
        now_utc = datetime.utcnow().replace(tzinfo=ZoneInfo("UTC"))
        users_prefs = self.db.query(UserPreference).filter_by(
            notifications_enabled=True
        ).all()
        result = {
            "status": "success",
            "users_checked": len(users_prefs),
            "users_due": 0,
            "users_without_households": 0,
            "users_without_devices": 0,
            "users_without_expiring_items": 0,
            "notifications_sent": 0,
            "already_notified": 0,
            "invalid_tokens_removed": 0,
            "processing_errors": 0,
        }

        for pref in users_prefs:
            try:
                timezone = self._get_timezone(pref)
                now_local = now_utc.astimezone(timezone)
                scheduled = now_local.replace(
                    hour=self._parse_notification_time(pref.notification_time)[0],
                    minute=self._parse_notification_time(pref.notification_time)[1],
                    second=0,
                    microsecond=0,
                )
                elapsed_minutes = (now_local - scheduled).total_seconds() / 60
                if elapsed_minutes < 0 or elapsed_minutes >= 120:
                    continue

                result["users_due"] += 1
                hogar_ids = [
                    member.fk_hogar
                    for member in self.db.query(HogarMiembro).filter_by(
                        user_id=pref.user_id
                    ).all()
                ]
                if not hogar_ids:
                    result["users_without_households"] += 1
                    continue

                local_date = now_local.date()
                expiring_items = self.db.query(InventoryStock).join(Product).filter(
                    InventoryStock.hogar_id.in_(hogar_ids),
                    InventoryStock.fecha_caducidad >= local_date,
                    InventoryStock.fecha_caducidad <= local_date + timedelta(days=3),
                    InventoryStock.cantidad_actual > 0,
                    InventoryStock.estado_producto != "congelado",
                ).all()
                if not expiring_items:
                    result["users_without_expiring_items"] += 1
                    continue

                devices = self.db.query(UserDevice).filter_by(
                    user_id=pref.user_id
                ).all()
                if not devices:
                    result["users_without_devices"] += 1
                    continue

                delivery = self.db.query(NotificationDelivery).filter_by(
                    user_id=pref.user_id,
                    notification_type="expiry_digest",
                    reference_date=local_date,
                ).first()
                if delivery and delivery.status == "sent":
                    result["already_notified"] += 1
                    continue
                if not delivery:
                    delivery = NotificationDelivery(
                        user_id=pref.user_id,
                        notification_type="expiry_digest",
                        reference_date=local_date,
                        status="pending",
                    )
                    self.db.add(delivery)
                    self.db.flush()

                count = len(expiring_items)
                product_names = ", ".join(
                    item.producto_maestro.nombre for item in expiring_items[:2]
                )
                if count > 2:
                    body = f"{product_names} y {count - 2} mas caducan pronto."
                elif count == 1:
                    body = f"{product_names} caduca pronto."
                else:
                    body = f"{product_names} caducan pronto."

                delivery.attempted_at = datetime.utcnow()
                sent_for_user = 0
                for device in devices:
                    try:
                        message = messaging.Message(
                            notification=messaging.Notification(
                                title="Caducidad proxima",
                                body=body,
                            ),
                            token=device.fcm_token,
                            data={
                                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                                "type": "expiry_alert",
                            },
                        )
                        messaging.send(message)
                        sent_for_user += 1
                        result["notifications_sent"] += 1
                    except Exception as error:
                        error_name = type(error).__name__
                        if error_name in {"UnregisteredError", "InvalidArgumentError"}:
                            self.db.delete(device)
                            result["invalid_tokens_removed"] += 1
                        logger.error(
                            "Error sending FCM notification for user %s: %s",
                            device.user_id,
                            error,
                        )
                        result["processing_errors"] += 1

                if sent_for_user:
                    delivery.status = "sent"
                    delivery.sent_at = datetime.utcnow()
                    delivery.error_code = None
                    delivery.error_message = None
                else:
                    delivery.status = "failed"
                    delivery.error_code = "FCM_SEND_FAILED"
                delivery.updated_at = datetime.utcnow()
                self.db.commit()
            except (TypeError, ValueError, AttributeError) as error:
                self.db.rollback()
                logger.error(
                    "Invalid notification preference for user %s: %s",
                    pref.user_id,
                    error,
                )
                result["processing_errors"] += 1
            except Exception as error:
                self.db.rollback()
                logger.error(
                    "Error processing notifications for user %s: %s",
                    pref.user_id,
                    error,
                )
                result["processing_errors"] += 1

        return result

    @staticmethod
    def _parse_notification_time(value: str) -> tuple[int, int]:
        parts = value.split(":")
        if len(parts) != 3:
            raise ValueError("notification_time must use HH:MM:SS")
        hour, minute, second = (int(part) for part in parts)
        if not (0 <= hour <= 23 and 0 <= minute <= 59 and 0 <= second <= 59):
            raise ValueError("notification_time is outside valid range")
        return hour, minute

    @staticmethod
    def _validate_timezone(value: str) -> None:
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, TypeError):
            raise ValueError("Invalid IANA timezone")

    @classmethod
    def _get_timezone(cls, preference: UserPreference) -> ZoneInfo:
        value = getattr(preference, "timezone", None) or "Europe/Madrid"
        cls._validate_timezone(value)
        return ZoneInfo(value)
