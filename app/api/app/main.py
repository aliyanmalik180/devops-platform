"""URL shortener API. Intentionally small: the delivery pipeline is the focus."""
import logging
import os
import secrets
import string
import time
from contextlib import asynccontextmanager

import redis
from fastapi import FastAPI, HTTPException, Response
from fastapi.responses import JSONResponse, RedirectResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from psycopg_pool import ConnectionPool
from pydantic import BaseModel, HttpUrl

log = logging.getLogger("api")
ALPHABET = string.ascii_letters + string.digits
CODE_LEN = 7  # keep in sync with the nginx location regex in app/frontend/nginx.conf
CLICK_QUEUE = "clicks"

REQS = Counter("http_requests_total", "HTTP requests", ["method", "path", "status"])
LAT = Histogram("http_request_duration_seconds", "HTTP latency", ["method", "path"])


class ShortenRequest(BaseModel):
    url: HttpUrl


class PgStore:
    def __init__(self, dsn: str):
        self.pool = ConnectionPool(dsn, min_size=1, max_size=5, open=True)

    def init(self) -> None:
        # Demo-grade schema bootstrap; a real migration tool is a later ADR.
        with self.pool.connection() as c:
            c.execute(
                """CREATE TABLE IF NOT EXISTS urls (
                     code TEXT PRIMARY KEY,
                     url TEXT NOT NULL,
                     clicks BIGINT NOT NULL DEFAULT 0,
                     created_at TIMESTAMPTZ NOT NULL DEFAULT now())"""
            )

    def insert(self, code: str, url: str) -> bool:
        with self.pool.connection() as c:
            cur = c.execute(
                "INSERT INTO urls (code, url) VALUES (%s, %s) ON CONFLICT DO NOTHING", (code, url)
            )
            return cur.rowcount == 1

    def get(self, code: str):
        with self.pool.connection() as c:
            row = c.execute("SELECT url, clicks FROM urls WHERE code = %s", (code,)).fetchone()
        return {"url": row[0], "clicks": row[1]} if row else None

    def ping(self) -> None:
        with self.pool.connection() as c:
            c.execute("SELECT 1")


class RedisQueue:
    def __init__(self, url: str):
        self.r = redis.Redis.from_url(url, socket_timeout=2)

    def push(self, code: str) -> None:
        self.r.rpush(CLICK_QUEUE, code)

    def ping(self) -> None:
        self.r.ping()


def create_app(store=None, queue=None) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if not hasattr(app.state, "store"):
            app.state.store = PgStore(os.environ["DATABASE_URL"])
            app.state.store.init()
        if not hasattr(app.state, "queue"):
            app.state.queue = RedisQueue(os.environ["REDIS_URL"])
        yield

    app = FastAPI(title="shortener-api", lifespan=lifespan)
    if store is not None:
        app.state.store = store
    if queue is not None:
        app.state.queue = queue

    @app.middleware("http")
    async def metrics_mw(request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        route = request.scope.get("route")
               # use the route template, not the raw path: avoids label explosion
        path = route.path if route else "unmatched"
        REQS.labels(request.method, path, str(response.status_code)).inc()
        LAT.labels(request.method, path).observe(time.perf_counter() - start)
        return response

    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}  # liveness: process is up, no dependency checks

    @app.get("/readyz")
    def readyz():
        try:  # readiness: can we serve traffic?
            app.state.store.ping()
            app.state.queue.ping()
        except Exception:
            log.exception("readiness check failed")
            return JSONResponse({"status": "not ready"}, status_code=503)
        return {"status": "ready"}

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

    @app.post("/api/shorten", status_code=201)
    def shorten(body: ShortenRequest):
        url = str(body.url)
        for _ in range(5):  # retry on the (rare) code collision
            code = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LEN))
            if app.state.store.insert(code, url):
                return {"code": code, "url": url}
        raise HTTPException(status_code=503, detail="could not allocate code")

    @app.get("/api/urls/{code}")
    def stats(code: str):
        row = app.state.store.get(code)
        if not row:
            raise HTTPException(status_code=404, detail="not found")
        return {"code": code, **row}

    @app.get("/{code}")
    def redirect(code: str):
        row = app.state.store.get(code)
        if not row:
            raise HTTPException(status_code=404, detail="not found")
        try:
            app.state.queue.push(code)  # async click counting; never fail the redirect
        except Exception:
            log.warning("could not enqueue click for %s", code)
        return RedirectResponse(row["url"], status_code=307)

    return app


# Production entrypoint (uvicorn app.main:app). Tests call create_app() with fakes instead.
app = create_app() if os.environ.get("DATABASE_URL") else None
