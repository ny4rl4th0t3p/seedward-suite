# Docs site for the Seedward Suite (MkDocs Material).
# Prereqs: Python 3.x.
# All Python work happens inside a local .venv (gitignored) — nothing touches the system Python.

VENV := .venv
BIN  := $(VENV)/bin

.PHONY: help serve build deploy clean dev-up dev-down dev-pull dev-seed dev-accounts

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-10s %s\n", $$1, $$2}'

# Create the venv + install deps; re-runs only when requirements.txt changes.
$(VENV): requirements.txt
	python3 -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -r requirements.txt
	@touch $(VENV)

serve: $(VENV) ## Live-reload preview at http://127.0.0.1:8000 (creates .venv on first run)
	$(BIN)/mkdocs serve

build: $(VENV) ## Build the static site into ./site (fails on warnings)
	$(BIN)/mkdocs build --strict

deploy: $(VENV) ## Build + push to the gh-pages branch (GitHub Pages)
	$(BIN)/mkdocs gh-deploy --force

clean: ## Remove the built site and the venv
	rm -rf site $(VENV)

# --- Full-stack dev/demo (Docker) — coordd + web UI from published GHCR images -------
COMPOSE := docker compose -f docker/docker-compose.yml

dev-up: ## Run coordd + the web UI → http://localhost:3000 (needs .env)
	$(COMPOSE) up

dev-down: ## Stop the full stack and remove its data volume
	$(COMPOSE) down --volumes

dev-pull: ## Pull the latest pinned images
	$(COMPOSE) pull

dev-seed: ## Seed the running stack with the demo fixture (needs .env: DEMO_MNEMONIC + admin address)
	$(COMPOSE) --profile seed run --build --rm seeder

dev-accounts: ## Print the demo account table (idx | address | privkey) — no running stack needed
	$(COMPOSE) --profile seed run --build --rm --no-deps -e SEED_MODE=accounts seeder