"""Consumes click events from Redis and increments counters in Postgres."""
import logging
import os
import signal
import time

import psycopg
import redis
from prometheus_client import Counter, start_http_server

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("worker")

QUEUE = "clicks"
PROCESSED = Counter("worker_events_processed_total", "Click events processed")
FAILED = Counter("worker_events_failed_total", "Click events that failed")
_running = True


def parse_event(raw: bytes | str) -> str | None:
    code = raw.decode() if isinstance(raw, bytes) else raw
    code = code.strip()
    return code if len(code) == 7 and code.isalnum() else None


def _stop(*_):
    global _running
    _running = False  # finish current event, then exit cleanly (graceful SIGTERM in k8s)


def main() -> None:
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    start_http_server(int(os.environ.get("METRICS_PORT", "9100")))
    r = redis.Redis.from_url(os.environ["REDIS_URL"])
    log.info("worker started")
    while _running:
        try:
            item = r.blpop(QUEUE, timeout=5)
            if item is None:
                continue
            code = parse_event(item[1])
            if code is None:
                FAILED.inc()
                continue
            with psycopg.connect(os.environ["DATABASE_URL"], autocommit=True) as conn:
                conn.execute("UPDATE urls SET clicks = clicks + 1 WHERE code = %s", (code,))
            PROCESSED.inc()
        except Exception:
            FAILED.inc()
            log.exception("event failed; backing off")
            time.sleep(2)
    log.info("worker stopped")


if __name__ == "__main__":
    main()
