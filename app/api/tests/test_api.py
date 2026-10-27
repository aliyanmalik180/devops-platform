from fastapi.testclient import TestClient

from app.main import create_app


class FakeStore:
    def __init__(self):
        self.d = {}

    def init(self):
        pass

    def insert(self, code, url):
        if code in self.d:
            return False
        self.d[code] = {"url": url, "clicks": 0}
        return True

    def get(self, code):
        return self.d.get(code)

    def ping(self):
        pass


class FakeQueue:
    def __init__(self):
        self.items = []

    def push(self, code):
        self.items.append(code)

    def ping(self):
        pass


def make():
    q = FakeQueue()
    return TestClient(create_app(store=FakeStore(), queue=q)), q


def test_health_and_ready():
    c, _ = make()
    assert c.get("/healthz").json() == {"status": "ok"}
    assert c.get("/readyz").status_code == 200


def test_shorten_and_redirect_enqueues_click():
    c, q = make()
    r = c.post("/api/shorten", json={"url": "https://example.com/a"})
    assert r.status_code == 201
    code = r.json()["code"]
    assert len(code) == 7
    r = c.get(f"/{code}", follow_redirects=False)
    assert r.status_code == 307
    assert r.headers["location"] == "https://example.com/a"
    assert q.items == [code]


def test_invalid_url_rejected():
    c, _ = make()
    assert c.post("/api/shorten", json={"url": "not-a-url"}).status_code == 422


def test_unknown_code_404():
    c, _ = make()
    assert c.get("/abcdefg", follow_redirects=False).status_code == 404


def test_metrics_exposed():
    c, _ = make()
    c.get("/healthz")
    assert "http_requests_total" in c.get("/metrics").text
