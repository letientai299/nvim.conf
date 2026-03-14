"""Async data processing pipeline with dataclasses, generics, and decorators."""

from __future__ import annotations

import asyncio
import functools
import logging
import time
from abc import ABC, abstractmethod
from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Any, Generic, TypeVar

logger = logging.getLogger(__name__)

T = TypeVar("T")
U = TypeVar("U")


# --- Decorators ---


def retry(max_attempts: int = 3, delay: float = 0.5):
    """Retry decorator with exponential backoff."""

    def decorator(func: Callable[..., Any]) -> Callable[..., Any]:
        @functools.wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            last_exc: Exception | None = None
            for attempt in range(1, max_attempts + 1):
                try:
                    return await func(*args, **kwargs)
                except Exception as exc:
                    last_exc = exc
                    if attempt < max_attempts:
                        wait = delay * (2 ** (attempt - 1))
                        logger.warning(
                            "Attempt %d/%d failed: %s, retrying in %.1fs",
                            attempt,
                            max_attempts,
                            exc,
                            wait,
                        )
                        await asyncio.sleep(wait)
            raise last_exc  # type: ignore[misc]

        return wrapper

    return decorator


def timed(func: Callable[..., Any]) -> Callable[..., Any]:
    """Log execution time of an async function."""

    @functools.wraps(func)
    async def wrapper(*args: Any, **kwargs: Any) -> Any:
        start = time.perf_counter()
        result = await func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        logger.info("%s took %.3fs", func.__name__, elapsed)
        return result

    return wrapper


# --- Domain models ---


class Status(Enum):
    PENDING = auto()
    RUNNING = auto()
    COMPLETED = auto()
    FAILED = auto()


@dataclass(frozen=True)
class Record(Generic[T]):
    id: str
    payload: T
    metadata: dict[str, Any] = field(default_factory=dict)
    created_at: float = field(default_factory=time.time)


@dataclass
class StageResult(Generic[T]):
    stage: str
    status: Status
    output: T | None = None
    error: str | None = None
    duration_ms: float = 0.0


@dataclass
class PipelineStats:
    total: int = 0
    succeeded: int = 0
    failed: int = 0
    total_ms: float = 0.0

    @property
    def success_rate(self) -> float:
        return self.succeeded / self.total if self.total > 0 else 0.0


# --- Pipeline stages ---


class Stage(ABC, Generic[T, U]):
    """Abstract pipeline stage: transforms T -> U."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    async def process(self, item: T) -> U: ...

    async def run(self, item: T) -> StageResult[U]:
        start = time.perf_counter()
        try:
            output = await self.process(item)
            elapsed = (time.perf_counter() - start) * 1000
            return StageResult(self.name, Status.COMPLETED, output, duration_ms=elapsed)
        except Exception as exc:
            elapsed = (time.perf_counter() - start) * 1000
            return StageResult(self.name, Status.FAILED, error=str(exc), duration_ms=elapsed)


class Pipeline(Generic[T]):
    """Multi-stage async pipeline with bounded concurrency."""

    def __init__(self, concurrency: int = 5) -> None:
        self._stages: list[Stage[Any, Any]] = []
        self._semaphore = asyncio.Semaphore(concurrency)
        self.stats = PipelineStats()

    def add_stage(self, stage: Stage[Any, Any]) -> Pipeline[T]:
        self._stages.append(stage)
        return self

    @timed
    async def execute(self, items: AsyncIterator[Record[T]]) -> list[StageResult[Any]]:
        results: list[StageResult[Any]] = []

        async def process_one(record: Record[T]) -> None:
            async with self._semaphore:
                self.stats.total += 1
                current: Any = record.payload
                for stage in self._stages:
                    result = await stage.run(current)
                    results.append(result)
                    if result.status == Status.FAILED:
                        self.stats.failed += 1
                        return
                    current = result.output
                self.stats.succeeded += 1

        tasks: list[asyncio.Task[None]] = []
        async for item in items:
            tasks.append(asyncio.create_task(process_one(item)))

        await asyncio.gather(*tasks)
        self.stats.total_ms = sum(r.duration_ms for r in results)
        return results
