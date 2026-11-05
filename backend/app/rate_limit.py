import time
from threading import Lock

MAX_FAILURES = 5
LOCK_SECONDS = 15 * 60

_failures: dict[str, list[float]] = {}
_lock = Lock()


def seconds_locked(key: str) -> int:
    """Seconds left until this key may try again (0 if not locked)."""
    now = time.monotonic()
    with _lock:
        recent = [t for t in _failures.get(key, []) if now - t < LOCK_SECONDS]
        if recent:
            _failures[key] = recent
        else:
            _failures.pop(key, None)
        if len(recent) >= MAX_FAILURES:
            return max(1, int(LOCK_SECONDS - (now - recent[-1])))
        return 0


def record_failure(key: str) -> None:
    with _lock:
        _failures.setdefault(key, []).append(time.monotonic())


def reset(key: str) -> None:
    with _lock:
        _failures.pop(key, None)