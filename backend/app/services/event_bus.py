"""In-memory pub/sub event bus with per-trip history replay.

Demo-scoped (single-process) by design — matches PRD MVP scope.
The SSE endpoint replays full history on connect, which is what makes
client auto-reconnect safe without persistence.
"""

import asyncio
import json
import uuid
from collections import defaultdict, deque
from datetime import datetime, timezone
from typing import Any, Dict, List


class EventBus:
    def __init__(self, history_maxlen: int = 500) -> None:
        self._subscribers: Dict[str, List[asyncio.Queue]] = defaultdict(list)
        self._history: Dict[str, deque] = defaultdict(
            lambda: deque(maxlen=history_maxlen)
        )

    async def publish(
        self, trip_id: str, event_type: str, payload: Dict[str, Any] | None = None
    ) -> Dict[str, Any]:
        event = {
            "event_id": str(uuid.uuid4()),
            "type": event_type,
            "payload": payload or {},
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        self._history[trip_id].append(event)
        for q in list(self._subscribers.get(trip_id, [])):
            await q.put(event)
        return event

    def subscribe(self, trip_id: str) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue()
        # Replay history so late/reconnecting clients catch up instantly.
        for event in self._history[trip_id]:
            q.put_nowait(event)
        self._subscribers[trip_id].append(q)
        return q

    def unsubscribe(self, trip_id: str, q: asyncio.Queue) -> None:
        try:
            self._subscribers[trip_id].remove(q)
        except ValueError:
            pass

    @staticmethod
    def format_sse(event: Dict[str, Any]) -> str:
        return f"event: {event['type']}\ndata: {json.dumps(event)}\n\n"


bus = EventBus()
