# 2. Three services with a Redis queue and Postgres
Status: Accepted

**Context:** A realistic multi-service workload without app complexity distracting from delivery.
**Decision:** `api` (FastAPI) serves and redirects; clicks flow through a Redis list to `worker`, which updates Postgres; `frontend` is static nginx proxying to `api`.
**Alternatives:** single service (too little to demonstrate); Kafka/RabbitMQ (heavier, no extra learning here).
**Consequences:** Redirect latency is independent of DB writes. Events can be lost if Redis dies before consumption (acceptable for click counts).
