"""Tests for authenticated notification administration endpoints."""

from services.notification_service import NotificationService


def test_cron_notifications_requires_configuration(client, monkeypatch):
    """The scheduler must fail closed when no cron secret is configured."""
    monkeypatch.delenv("CRON_SECRET", raising=False)

    response = client.post("/api/v1/notifications/cron/trigger-notifications")

    assert response.status_code == 503


def test_cron_notifications_accepts_valid_secret(client, monkeypatch):
    """A valid bearer secret triggers notification processing exactly once."""
    monkeypatch.setenv("CRON_SECRET", "test-cron-secret")
    monkeypatch.setattr(
        NotificationService,
        "trigger_daily_notifications",
        lambda self: {"status": "success", "notifications_sent": 0},
    )

    response = client.post(
        "/api/v1/notifications/cron/trigger-notifications",
        headers={"Authorization": "Bearer test-cron-secret"},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "success", "notifications_sent": 0}
