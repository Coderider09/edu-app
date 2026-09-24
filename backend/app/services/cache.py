"""Redis-backed cache and rate limiter with an in-process fallback.

The API keeps working when Redis is unavailable (local dev, tests): values are then
kept in process memory, which is fine for a single instance.
"""
import json
import logging
import threading
import time
from typing import Any, Optional

import redis

from app.core.config import settings

logger = logging.getLogger(__name__)


class _MemoryStore:
    def __init__(self) -> None:
        self._data: dict[str, tuple[float, Any]] = {}
        self._lock = threading.Lock()

    def _alive(self, key: str) -> Optional[Any]:
        item = self._data.get(key)
        if item is None:
            return None
        expires, value = item
        if expires and expires < time.time():
            self._data.pop(key, None)
            return None
        return value

    def get(self, key: str) -> Optional[str]:
        with self._lock:
            return self._alive(key)

    def setex(self, key: str, ttl: int, value: str) -> None:
        with self._lock:
            self._data[key] = (time.time() + ttl, value)

    def incr_window(self, key: str, ttl: int) -> int:
        with self._lock:
            current = self._alive(key)
            if current is None:
                self._data[key] = (time.time() + ttl, 1)
                return 1
            expires, _ = self._data[key]
            self._data[key] = (expires, current + 1)
            return current + 1

    def delete_prefix(self, prefix: str) -> None:
        with self._lock:
            for key in [k for k in self._data if k.startswith(prefix)]:
                self._data.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()


class Cache:
    def __init__(self, url: str) -> None:
        self._memory = _MemoryStore()
        self._redis: Optional[redis.Redis] = None
        self._url = url
        self._retry_at = 0.0

    def _client(self) -> Optional[redis.Redis]:
        if self._redis is not None:
            return self._redis
        if time.time() < self._retry_at or not self._url:
            return None
        try:
            client = redis.Redis.from_url(self._url, socket_connect_timeout=0.3, socket_timeout=0.3)
            client.ping()
            self._redis = client
        except redis.RedisError:
            logger.warning("Redis unavailable, using in-memory cache")
            self._retry_at = time.time() + 30
        return self._redis

    def _fail(self) -> None:
        self._redis = None
        self._retry_at = time.time() + 30

    def get_json(self, key: str) -> Optional[Any]:
        client = self._client()
        if client is not None:
            try:
                raw = client.get(key)
                return json.loads(raw) if raw else None
            except redis.RedisError:
                self._fail()
        raw = self._memory.get(key)
        return json.loads(raw) if raw else None

    def set_json(self, key: str, value: Any, ttl: int) -> None:
        raw = json.dumps(value, default=str)
        client = self._client()
        if client is not None:
            try:
                client.setex(key, ttl, raw)
                return
            except redis.RedisError:
                self._fail()
        self._memory.setex(key, ttl, raw)

    def invalidate_prefix(self, prefix: str) -> None:
        client = self._client()
        if client is not None:
            try:
                for key in client.scan_iter(f"{prefix}*"):
                    client.delete(key)
            except redis.RedisError:
                self._fail()
        self._memory.delete_prefix(prefix)

    def hit(self, key: str, window_seconds: int) -> int:
        """Count one hit in a fixed window and return the number of hits so far."""
        client = self._client()
        if client is not None:
            try:
                pipe = client.pipeline()
                pipe.incr(key)
                pipe.expire(key, window_seconds, nx=True)
                count, _ = pipe.execute()
                return int(count)
            except redis.RedisError:
                self._fail()
        return self._memory.incr_window(key, window_seconds)

    def reset_memory(self) -> None:
        self._memory.clear()


cache = Cache(settings.REDIS_URL)
