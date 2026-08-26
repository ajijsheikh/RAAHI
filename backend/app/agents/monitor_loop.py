"""Monitor loop — the trip watcher agent (one agent, one file per AGENTS.md §4).

Watches in-memory runtime state for each active trip and publishes derived
events onto the EventBus:

  * delay >= DELAY_THRESHOLD_MIN  ->  `reroute` event (worse-but-viable path)
  * zone entry                    ->  `safety_alert` event (+ Twilio SOS hook)

Simulate endpoints inject into TripRuntime; this loop does the reacting.
That separation is the demo claim: "the agent noticed and acted" — triggers
only set state, events arrive through the same bus as real events would.
"""

import asyncio
import logging
import os
from typing import Dict

from app.services.event_bus import bus
from app.services import twilio_client

logger = logging.getLogger("raahi.monitor")

DELAY_THRESHOLD_MIN = int(os.getenv("DELAY_THRESHOLD_MIN", "15"))
POLL_INTERVAL_S = float(os.getenv("MONITOR_POLL_INTERVAL_S", "5"))


class TripRuntime:
    """Live mutable state injected by demo simulate endpoints."""

    def __init__(self) -> None:
        self.current_leg: int = 0
        self.delay_min: int = 0
        self.delay_handled: bool = False
        self.zone_name: str | None = None
        self.zone_handled: bool = False


class MonitorLoop:
    def __init__(self) -> None:
        self._runtimes: Dict[str, TripRuntime] = {}
        self._tasks: Dict[str, asyncio.Task] = {}

    def runtime(self, trip_id: str) -> TripRuntime:
        return self._runtimes.setdefault(trip_id, TripRuntime())

    def start(self, trip_id: str) -> None:
        task = self._tasks.get(trip_id)
        if task and not task.done():
            return
        self.runtime(trip_id)
        self._tasks[trip_id] = asyncio.create_task(self._run(trip_id))

    def stop(self, trip_id: str) -> None:
        task = self._tasks.pop(trip_id, None)
        if task:
            task.cancel()

    async def stop_all(self) -> None:
        for trip_id in list(self._tasks):
            self.stop(trip_id)

    async def _run(self, trip_id: str) -> None:
        rt = self.runtime(trip_id)
        await bus.publish(
            trip_id,
            "leg_started",
            {"leg_index": rt.current_leg, "message": f"Leg {rt.current_leg + 1} started"},
        )

        while True:
            await asyncio.sleep(POLL_INTERVAL_S)

            # ---- Delay / budget watcher ----
            if rt.delay_min >= DELAY_THRESHOLD_MIN and not rt.delay_handled:
                rt.delay_handled = True
                cost_delta = max(10, rt.delay_min)
                eta_saved = max(0, rt.delay_min - 8)
                await bus.publish(
                    trip_id,
                    "reroute",
                    {
                        "reason": f"Leg delayed by {rt.delay_min} min",
                        "cost_delta_inr": cost_delta,
                        "eta_delta_min": -eta_saved,
                        "message": (
                            f"Route updated — delay {rt.delay_min} min detected, "
                            f"switched to faster option. +₹{cost_delta}, "
                            f"ETA improved ~{eta_saved} min."
                        ),
                    },
                )

            # ---- Safety watcher ----
            if rt.zone_name and not rt.zone_handled:
                rt.zone_handled = True
                notified = await self._notify_contact(rt)
                await bus.publish(
                    trip_id,
                    "safety_alert",
                    {
                        "zone_name": rt.zone_name,
                        "contact_notified": notified,
                        "lat": 22.5768,
                        "lng": 88.4302,
                        "message": f"You've entered a flagged area — {rt.zone_name}",
                    },
                )
                logger.info("safety_alert published trip=%s notified=%s", trip_id, notified)

    @staticmethod
    async def _notify_contact(rt: TripRuntime) -> bool:
        """Send SOS SMS via Twilio when enabled/credentialed.

        A failed SMS must NEVER suppress the in-app alert (AGENTS.md §3),
        so any failure just returns False for contact_notified.
        """
        sid = await twilio_client.send_sos(
            to_phone=os.getenv("TWILIO_TO_NUMBER_OVERRIDE") or "+919000000000",
            traveler_name="Raahi user",
            lat=22.5768,
            lng=88.4302,
            zone_name=rt.zone_name or "flagged area",
        )
        return sid is not None


monitor = MonitorLoop()
