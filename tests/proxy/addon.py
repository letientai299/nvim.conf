"""
mitmproxy addon: cache all HTTPS responses on disk, replay with recorded
latency so race-condition behavior is preserved across runs.
"""

import hashlib
import json
import os
import time
from pathlib import Path

from mitmproxy import ctx, http

CACHE_DIR = Path("/cache")
# PROXY_SPEED > 1 replays cached responses faster (e.g., 4 = 4x speed).
SPEED = max(1.0, float(os.environ.get("PROXY_SPEED", "1")))
# Git pack responses break at high speed — cap to 2x regardless of global speed.
GIT_PACK_MAX_SPEED = 2.0


def _cache_key(flow: http.HTTPFlow) -> str:
    req = flow.request
    parts = f"{req.method}:{req.pretty_url}"
    if req.method == "POST" and req.content:
        body_hash = hashlib.sha256(req.content).hexdigest()
        parts = f"{parts}:{body_hash}"
    return hashlib.sha256(parts.encode()).hexdigest()


def _cache_paths(host: str, key: str) -> tuple[Path, Path]:
    base = CACHE_DIR / host / key[:2]
    return base / f"{key}.meta", base / f"{key}.data"


class HttpCache:
    def __init__(self):
        self._pending: dict[str, float] = {}  # flow.id -> request start time

    def request(self, flow: http.HTTPFlow):
        key = _cache_key(flow)
        meta_path, data_path = _cache_paths(flow.request.pretty_host, key)

        if meta_path.exists() and data_path.exists():
            meta = json.loads(meta_path.read_text())
            body = data_path.read_bytes()

            is_git_pack = (
                "/git-upload-pack" in flow.request.pretty_url
                or meta.get("headers", {}).get("content-type", "")
                == "application/x-git-upload-pack-result"
            )
            speed = min(SPEED, GIT_PACK_MAX_SPEED) if is_git_pack else SPEED
            duration = meta.get("duration", 0) / speed
            if duration > 0:
                # Block synchronously — mitmproxy runs request hooks in a
                # thread so time.sleep won't stall the event loop.
                time.sleep(duration)

            flow.response = http.Response.make(
                meta["status_code"],
                body,
                dict(meta.get("headers", {})),
            )
            ctx.log.info(f"[cache hit]  {flow.request.method} {flow.request.pretty_url}")
            return

        self._pending[flow.id] = time.monotonic()
        ctx.log.info(f"[cache miss] {flow.request.method} {flow.request.pretty_url}")

    def response(self, flow: http.HTTPFlow):
        start = self._pending.pop(flow.id, None)
        if start is None:
            return  # was a cache hit — nothing to store

        duration = time.monotonic() - start
        key = _cache_key(flow)
        meta_path, data_path = _cache_paths(flow.request.pretty_host, key)

        meta_path.parent.mkdir(parents=True, exist_ok=True)

        # Filter hop-by-hop and encoding headers — mitmproxy already decodes
        skip = frozenset({"transfer-encoding", "content-encoding", "content-length"})
        headers = {
            k: v
            for k, v in flow.response.headers.items(multi=True)
            if k.lower() not in skip
        }

        meta = {
            "status_code": flow.response.status_code,
            "headers": headers,
            "duration": round(duration, 4),
            "url": flow.request.pretty_url,
            "method": flow.request.method,
        }
        meta_path.write_text(json.dumps(meta, indent=2))
        data_path.write_bytes(flow.response.content or b"")


addons = [HttpCache()]
