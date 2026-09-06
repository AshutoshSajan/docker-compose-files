# Quick runner for every compose stack in this repo.
# Usage: make up-redis | make logs-pgsql | make down-kafka | make config-mysql
# Version/secret overrides live in .env (auto-created from .env.example).

SERVICES := bitnami-postgres cassandra elastic-search julia kafka kafka-gui \
	mongodb mysql nginx pgsql rabbitmq redis redis-master-replica \
	tigerbeetle zookeeper-kafka

# Single-line helper (must stay on one line: each recipe line is its own shell).
# Resolves "<name>.yml" or "<name>.yaml", ensures .env exists, then runs
# "docker compose -f <file>" with whatever command follows $(RUN).
RUN = [ -f .env ] || { cp .env.example .env; echo "Created .env from .env.example - edit it to switch versions/passwords."; }; f="$*.yml"; [ -f "$$f" ] || f="$*.yaml"; [ -f "$$f" ] || { echo "Unknown service '$*'. Try: make list"; exit 1; }; docker compose -f "$$f"

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "Usage: make <action>-<service>   (e.g. make up-redis)"
	@echo ""
	@echo "Actions:"
	@grep -E '^(up|down|clean|restart|pull|logs|ps|config)-%:.*?##' $(MAKEFILE_LIST) | sed -e 's/-%:/ <svc>:/' -e 's/## //' -e 's/^/  /'
	@echo ""
	@echo "Other:"
	@grep -E '^(list|ps-all|help):.*?##' $(MAKEFILE_LIST) | sed -e 's/:.*?##/: /' -e 's/: ## /: /' -e 's/## //' -e 's/^/  /'
	@echo ""
	@echo "Services: $(SERVICES)"

.PHONY: list
list: ## List available services
	@echo "$(SERVICES)" | tr ' ' '\n'

.PHONY: ps-all
ps-all: ## Show running containers for all stacks
	@for s in $(SERVICES); do \
	  f="$$s.yml"; [ -f "$$f" ] || f="$$s.yaml"; \
	  echo "=== $$s ==="; docker compose -f "$$f" ps; \
	done

up-%: ## Start a service detached: make up-redis
	@$(RUN) up -d

down-%: ## Stop a service (keep volumes): make down-redis
	@$(RUN) down

clean-%: ## Stop a service AND delete its volumes: make clean-redis
	@$(RUN) down -v

restart-%: ## Restart a service: make restart-pgsql
	@$(RUN) restart

pull-%: ## Pull image(s) for a service: make pull-kafka
	@$(RUN) pull

logs-%: ## Follow logs: make logs-mysql (Ctrl-C to exit)
	@$(RUN) logs -f --tail=100

ps-%: ## Show containers for a service: make ps-redis
	@$(RUN) ps

config-%: ## Validate + print resolved config: make config-pgsql
	@$(RUN) config
