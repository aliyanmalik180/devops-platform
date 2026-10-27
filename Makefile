.DEFAULT_GOAL := help
SERVICES := api worker frontend
SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-10s %s\n",$$1,$$2}'

up: ## Start the whole stack locally
	@test -f .env || cp .env.example .env
	docker compose up --build -d
	@echo "UI: http://localhost:8080  API docs: http://localhost:8000/docs"

down: ## Stop the stack and delete volumes
	docker compose down -v

logs: ## Tail logs
	docker compose logs -f

lint: ## ruff + hadolint
	ruff check app && ruff format --check app
	@for s in $(SERVICES); do hadolint app/$$s/Dockerfile; done

test: ## Unit tests (api, worker)
	cd app/api && python -m pytest -q
	cd app/worker && python -m pytest -q

build: ## Build images tagged with the git SHA (never latest)
	@for s in $(SERVICES); do docker build -t shortener-$$s:$(SHA) app/$$s; done

scan: build ## Trivy scan, fail on CRITICAL
	@for s in $(SERVICES); do trivy image --severity CRITICAL --exit-code 1 --ignore-unfixed shortener-$$s:$(SHA); done

smoke: ## End-to-end check against the running stack
	@code=$$(curl -fsS -X POST localhost:8080/api/shorten -H 'content-type: application/json' -d '{"url":"https://example.com"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['code'])"); \
	curl -fsSI localhost:8080/$$code | head -1; sleep 2; curl -fsS localhost:8080/api/urls/$$code; echo
