# backend/services/notification_service.py
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from models import UserDevice, UserPreference, InventoryStock, Product, Location, HogarMiembro
from datetime import datetime, timedelta
from firebase_admin import messaging
import logging

logger = logging.getLogger(__name__)

class NotificationService:
    def __init__(self, db: Session):
        self.db = db

    def register_device(self, user_id: str, token: str, platform: str):
        """Register or update a user device for push notifications."""
        device = self.db.query(UserDevice).filter_by(user_id=user_id, fcm_token=token).first()
        if device:
            device.last_active = datetime.utcnow()
            device.platform = platform
        else:
            device = UserDevice(user_id=user_id, fcm_token=token, platform=platform)
            self.db.add(device)
        self.db.commit()
        return device

    def update_preferences(self, user_id: str, enabled: bool, time_str: str, offset: int):
        """Update user notification preferences."""
        pref = self.db.query(UserPreference).filter_by(user_id=user_id).first()
        if pref:
            pref.notifications_enabled = enabled
            pref.notification_time = time_str
            pref.timezone_offset = offset
        else:
            pref = UserPreference(
                user_id=user_id, 
                notifications_enabled=enabled, 
                notification_time=time_str, 
                timezone_offset=offset
            )
            self.db.add(pref)
        self.db.commit()
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
        """
        Check for expiring products and send notifications to users who scheduled them for this hour.
        This method is intended to be called hourly by a cron job.
        """
        current_utc = datetime.utcnow()
        current_hour = current_utc.hour
        current_minute = current_utc.minute
        
        # 1. Find users who want notifications at this UTC hour
        # Logic: User Time (minutes) - Offset = UTC Time (minutes)
        # We check if current UTC time matches User Preference Time +/- 30 mins window
        
        # Simplified approach: Check users whose (LocalTime - Offset) matches CurrentUTC +/- margin
        # But storing time as string 'HH:MM:SS' makes SQL math hard.
        # We will iterate all enabled users and check in Python for simplicity (assuming low user count for now)
        # For scale, this should be optimized with SQL math.
        
        users_prefs = self.db.query(UserPreference).filter_by(notifications_enabled=True).all()
        
        sent_count = 0
        
        for pref in users_prefs:
            try:
                # Parse user preferred time
                h, m, s = map(int, pref.notification_time.split(':'))
                user_minutes = h * 60 + m
                
                # Calculate target UTC minutes for this user
                # Offset is in minutes. If offset is -60 (UTC+1), then 09:00 Local (540m) -> 540 - (-60) = 600m ?? No.
                # Timezone Offset usually means Local = UTC - Offset (or similar, depends on JS convention).
                # JS: new Date().getTimezoneOffset() returns positive if behind UTC (e.g. UTC-5 is 300).
                # Let's assume standard JS offset: UTC = Local + Offset (minutes).
                # Example: UTC+1 (Spain). 09:00 Local. JS offset is -60.
                # UTC = 09:00 + (-60min) = 08:00. Correct.
                
                target_utc_minutes = user_minutes + pref.timezone_offset
                
                # Normalize to 0-1440
                target_utc_minutes = target_utc_minutes % 1440
                
                current_utc_minutes = current_hour * 60 + current_minute
                
                # Check if we are within the hour window (e.g. cron runs at :00, we match if target is within this hour)
                # Actually, cron runs hourly. We should match if target hour == current hour.
                target_utc_hour = target_utc_minutes // 60
                
                if target_utc_hour != current_hour:
                    continue
                
                # 2. Check for expiring products for this user
                # We need to find all households this user belongs to
                hogar_ids = [m.fk_hogar for m in self.db.query(HogarMiembro).filter_by(user_id=pref.user_id).all()]
                
                if not hogar_ids:
                    continue
                
                # Find products expiring in 3 days (or less, but not expired yet)
                target_date = current_utc.date() + timedelta(days=3)
                today = current_utc.date()
                
                expiring_items = self.db.query(InventoryStock).join(Product).filter(
                    InventoryStock.hogar_id.in_(hogar_ids),
                    InventoryStock.fecha_caducidad <= target_date,
                    InventoryStock.fecha_caducidad >= today,
                    InventoryStock.cantidad_actual > 0
                ).all()
                
                if not expiring_items:
                    continue
                
                # 3. Construct message
                count = len(expiring_items)
                product_names = ", ".join([item.producto_maestro.nombre for item in expiring_items[:2]])
                if count > 2:
                    body = f"{product_names} y {count - 2} más caducan pronto."
                elif count == 1:
                    body = f"{product_names} caduca pronto."
                else:
                    body = f"{product_names} caducan pronto."
                
                # 4. Send to all user devices
                devices = self.db.query(UserDevice).filter_by(user_id=pref.user_id).all()
                if not devices:
                    continue
                
                for device in devices:
                    try:
                        message = messaging.Message(
                            notification=messaging.Notification(
                                title="⚠️ Caducidad Próxima",
                                body=body,
                            ),
                            token=device.fcm_token,
                            data={
                                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                                "type": "expiry_alert"
                            }
                        )
                        messaging.send(message)
                        sent_count += 1
                    except Exception as e:
                        logger.error(f"Error sending FCM to {device.user_id}: {e}")
                        # Optionally remove invalid token
                        
            except Exception as e:
                logger.error(f"Error processing user {pref.user_id}: {e}")
                continue
                
        return {"status": "success", "notifications_sent": sent_count}
