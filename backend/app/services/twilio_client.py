"""Twilio SOS SMS client - the demo differentiator. This path is never mocked.

Contract (see 03_PERSON_C_DATA_INFRA.md P2.3):
    async def send_sos(to_phone, traveler_name, lat, lng, zone_name) -> str | None

Returns the Twilio message SID on success, or None when ALERTS_ENABLED is
false / credentials are missing / the send fails. A None return must NEVER
suppress the in-app safety alert - callers emit `contact_notified: false`.

Secrets policy (SECURITY.md): never log the auth token; log SID only.
"""

import asyncio
import logging
import os
from datetime import datetime

logger = logging.getLogger("raahi.twilio")

MAX_SMS_CHARS = 160  # one SMS segment


async def send_sos(
    to_phone: str,
    traveler_name: str,
    lat: float,
    lng: float,
    zone_name: str,
) -> str | None:
    """Send the SOS SMS. Returns message SID, or None if disabled/failed."""
    if os.getenv("ALERTS_ENABLED", "true").lower() != "true":
        logger.warning(
            "ALERTS_ENABLED=false - SOS SMS SUPPRESSED (would have gone to %s). "
            "In-app safety_alert still fires.",
            to_phone,
        )
        return None

    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    from_number = os.getenv("TWILIO_FROM_NUMBER")
    override = os.getenv("TWILIO_TO_NUMBER_OVERRIDE")

    dest = to_phone
    if override:
        logger.info(
            "TWILIO_TO_NUMBER_OVERRIDE active: requested=%s actual=%s",
            to_phone,
            override,
        )
        dest = override

    if not (account_sid and auth_token and from_number):
        logger.warning(
            "Twilio credentials incomplete (SID/token/from) - "
            "SOS suppressed for %s. In-app alert still fires.",
            dest,
        )
        return None

    body = _build_body(traveler_name, lat, lng, zone_name)

    def _send() -> str:
        from twilio.rest import Client

        client = Client(account_sid, auth_token)
        message = client.messages.create(to=dest, from_=from_number, body=body)
        return message.sid

    try:
        sid = await asyncio.to_thread(_send)
        logger.info("SOS delivered to %s sid=%s", dest, sid)
        return sid
    except Exception as e:  # noqa: BLE001 - a failed SMS must never raise into the watcher
        code = getattr(e, "code", None)  # TwilioRestException carries .code
        logger.error("Twilio send failed (code=%s): %s", code, type(e).__name__)
        return None


def _build_body(traveler_name: str, lat: float, lng: float, zone_name: str) -> str:
    """Lead with the actionable part; keep <=160 chars so it stays one segment."""
    hhmm = datetime.now().strftime("%H:%M")
    url = f"https://maps.google.com/?q={lat:.5f},{lng:.5f}"
    body = f"RAAHI SOS: {traveler_name} entered {zone_name} at {hhmm}. Live: {url}"
    if len(body) > MAX_SMS_CHARS:
        overhead = len(body) - len(zone_name)
        allowed = max(0, MAX_SMS_CHARS - overhead - 1)  # -1 for '~' truncation mark
        body = (
            f"RAAHI SOS: {traveler_name} entered {zone_name[:allowed]}~ "
            f"at {hhmm}. Live: {url}"
        )
    return body[:MAX_SMS_CHARS]