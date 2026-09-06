# Quick runner for every compose stack in this repo.
# Usage: make up-redis | make logs-pgsql | make down-kafka | make config-mysql
# Version/secret overrides live in .env (auto-created from .env.example).

SERVICES := bitnami-postgres cassandra elastic-search julia kafka kafka-gui \
	mongodb mysql nginx pgsql rabbitmq redis redis-master-replica \
	tigerbeetle zookeeper-kafka

# Single-line helper (must stay on one line: each recipe line is its own shell).
# Resolves "<name>.yml" or "<name>.yaml", ensures .env exists, then runs
# "docker compose -f <file>" with whatever command follows $(RUN).
# Prefix with GUI=1 to include the opt-in 'gui' profile (web UIs).
RUN = [ -f .env ] || { cp .env.example .env; echo "Created .env from .env.example - edit it to switch versions/passwords."; }; f="$*.yml"; [ -f "$$f" ] || f="$*.yaml"; [ -f "$$f" ] || { echo "Unknown service '$*'. Try: make list"; exit 1; }; docker compose $${GUI:+--profile gui} -f "$$f"
# Same, but always covering the gui profile: stop/clean/inspect act on the
# whole stack so GUI containers are never left orphaned.
RUN_ALL = [ -f .env ] || { cp .env.example .env; echo "Created .env from .env.example - edit it to switch versions/passwords."; }; f="$*.yml"; [ -f "$$f" ] || f="$*.yaml"; [ -f "$$f" ] || { echo "Unknown service '$*'. Try: make list"; exit 1; }; docker compose --profile gui -f "$$f"

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
	@echo ""
	@echo "Web UIs (opt-in gui profile): GUI=1 make up-redis  (see README)"

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

down-%: ## Stop a service (keep volumes, incl. GUI): make down-redis
	@$(RUN_ALL) down

clean-%: ## Stop a service AND delete its volumes: make clean-redis
	@$(RUN_ALL) down -v

restart-%: ## Restart a service (incl. GUI): make restart-pgsql
	@$(RUN_ALL) restart

pull-%: ## Pull image(s) for a service (incl. GUI): make pull-kafka
	@$(RUN_ALL) pull

logs-%: ## Follow logs (incl. GUI): make logs-mysql (Ctrl-C to exit)
	@$(RUN_ALL) logs -f --tail=100

ps-%: ## Show containers for a service (incl. GUI): make ps-redis
	@$(RUN_ALL) ps

config-%: ## Validate + print resolved config: make config-pgsql
	@$(RUN) config
