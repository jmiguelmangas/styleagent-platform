SHELL := /bin/bash
COMPOSE_PROJECT := styleagent-platform

.PHONY: help bootstrap up down restart ps logs backend-logs frontend-logs runner-logs smoke smoke-ollama host-e2e runner-host-local build wait-down

help:
	@echo "StyleAgent platform commands"
	@echo ""
	@echo "  make bootstrap         Init/update submodules"
	@echo "  make up                Start mongodb + backend + frontend + runner with Docker"
	@echo "  make down              Stop Docker services"
	@echo "  make restart           Restart Docker services"
	@echo "  make build             Rebuild Docker services"
	@echo "  make ps                Show Docker service status"
	@echo "  make logs              Tail all Docker logs"
	@echo "  make backend-logs      Tail backend logs"
	@echo "  make frontend-logs     Tail frontend logs"
	@echo "  make runner-logs       Tail runner logs"
	@echo "  make smoke             Run deterministic full-stack smoke test"
	@echo "  make smoke-ollama      Run full-stack smoke test against local Ollama"
	@echo "  make host-e2e          Run local Capture One host E2E"
	@echo "  make runner-host-local Run runner host integration pytest wrapper"

bootstrap:
	./scripts/bootstrap.sh

up:
	$(MAKE) wait-down
	docker compose up -d --build mongodb backend frontend runner

down:
	docker compose down --remove-orphans
	$(MAKE) wait-down

restart: down up

build:
	docker compose build mongodb backend frontend runner

ps:
	docker compose ps

logs:
	docker compose logs -f

backend-logs:
	docker compose logs -f backend

frontend-logs:
	docker compose logs -f frontend

runner-logs:
	docker compose logs -f runner

smoke:
	./scripts/integration_smoke.sh

smoke-ollama:
	./scripts/integration_smoke_ollama.sh

host-e2e:
	./scripts/integration_captureone_host.sh

runner-host-local:
	./scripts/integration_runner_host_local.sh

wait-down:
	@for i in {1..60}; do \
		if [ -z "$$(docker ps -a --filter label=com.docker.compose.project=$(COMPOSE_PROJECT) -q)" ]; then \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Timed out waiting for Compose resources to be removed"; \
	exit 1
