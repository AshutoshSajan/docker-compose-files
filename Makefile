# Quick runner for every compose stack in this repo.
# Usage: make up-redis | make logs-pgsql | make down-kafka | make config-mysql
# Version/secret overrides live in .env (auto-created from .env.example).

SERVICES := cassandra clickhouse elastic-search julia kafka kafka-gui \
	mailpit meilisearch minio mongodb mysql nats nginx observability pgsql postgres-alt \
	rabbitmq redis redis-master-replica tigerbeetle valkey \
	zookeeper-kafka

# Single-line helper (must stay on one line: each recipe line is its own shell).
# Resolves "<name>.yml" or "<name>.yaml" and the env file (.env by default,
# .env.<name> with ENV=<name>), then runs "docker compose ..." with whatever
# command follows $(RUN).
# Prefix with GUI=1 to include the opt-in 'gui' profile (web UIs).
ENV_SETUP = e=".env"; [ -n "$(ENV)" ] && e=".env.$(ENV)"; if [ ! -f "$$e" ]; then if [ -n "$(ENV)" ]; then echo "Missing env file $$e - create it with: make env-$(ENV)"; exit 1; fi; cp .env.example .env; echo "Created .env from .env.example - edit it to switch versions/passwords."; fi; f="$*.yml"; [ -f "$$f" ] || f="$*.yaml"; [ -f "$$f" ] || { echo "Unknown service '$*'. Try: make list"; exit 1; }
RUN = $(ENV_SETUP); docker compose --env-file "$$e" -p "$*" $${GUI:+--profile gui} -f "$$f"
# Same, but always covering the gui profile: stop/clean/inspect act on the
# whole stack so GUI containers are never left orphaned.
RUN_ALL = $(ENV_SETUP); docker compose --env-file "$$e" -p "$*" --profile gui -f "$$f"

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "Usage: make <action>-<service>   (e.g. make up-redis)"
	@echo ""
	@echo "Actions:"
	@grep -E '^(up|down|clean|restart|pull|logs|ps|config)-%:.*?##' $(MAKEFILE_LIST) | sed -e 's/-%:/ <svc>:/' -e 's/## //' -e 's/^/  /'
	@echo ""
	@echo "Other:"
	@grep -E '^(env|backup)-%:.*?##' $(MAKEFILE_LIST) | sed -e 's/-%:/ <name>:/' -e 's/## //' -e 's/^/  /'
	@grep -E '^(list|ps-all|help):.*?##' $(MAKEFILE_LIST) | sed -e 's/: ## /: /' -e 's/## //' -e 's/^/  /'
	@echo ""
	@echo "Services: $(SERVICES)"
	@echo ""
	@echo "Options: GUI=1 (include web UIs)   ENV=<name> (use .env.<name>)"
	@echo "Web UIs (opt-in gui profile): GUI=1 make up-redis  (see README)"

.PHONY: list
list: ## List available services
	@echo "$(SERVICES)" | tr ' ' '\n'

.PHONY: ps-all
ps-all: ## Show running containers for all stacks
	@e=".env"; [ -n "$(ENV)" ] && e=".env.$(ENV)"; [ -f "$$e" ] || e=".env.example"; for s in $(SERVICES); do \
	  f="$$s.yml"; [ -f "$$f" ] || f="$$s.yaml"; \
	  echo "=== $$s ==="; docker compose --env-file "$$e" -p "$$s" -f "$$f" ps; \
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

env-%: ## Create .env.<name> from template: make env-acme
	@if [ -f ".env.$*" ]; then echo ".env.$* already exists"; else cp .env.example ".env.$*"; echo "Created .env.$* - edit versions/passwords, then use ENV=$*."; fi

backup-%: ## Dump data into ./dump (pg/mysql/mongo/redis/valkey): make backup-pgsql
	@mkdir -p dump; e=".env"; [ -n "$(ENV)" ] && e=".env.$(ENV)"; \
	[ -f "$$e" ] || { echo "Missing env file $$e"; exit 1; }; \
	f="$*.yml"; [ -f "$$f" ] || f="$*.yaml"; \
	[ -f "$$f" ] || { echo "Unknown service '$*'. Try: make list"; exit 1; }; \
	set -a; . "./$$e"; set +a; ts=$$(date +%Y%m%d-%H%M%S); \
	case "$*" in \
	  pgsql) docker compose --env-file "$e" -p "$*" -f "$f" exec -T postgresql-db pg_dump -U "$${POSTGRES_USER:-admin}" -d "$${POSTGRES_DB:-postgres}" > "dump/pgsql-$$ts.sql" ;; \
	  postgres-alt) docker compose --env-file "$e" -p "$*" -f "$f" exec -T postgresql pg_dump -U "$${POSTGRES_USER:-admin}" -d "$${POSTGRES_DB:-postgres}" > "dump/postgres-alt-$$ts.sql" ;; \
	  mysql) docker compose --env-file "$e" -p "$*" -f "$f" exec -T db mysqldump -h localhost -u root --password="$${MYSQL_ROOT_PASSWORD:-changeme-root}" --all-databases > "dump/mysql-$$ts.sql" ;; \
	  mongodb) cid=$$(docker compose --env-file "$e" -p "$*" -f "$f" ps -q mongo); \
	    docker compose --env-file "$e" -p "$*" -f "$f" exec -T mongo mongodump -u "$${MONGO_ROOT_USER:-root}" -p "$${MONGO_ROOT_PASSWORD:-changeme}" --authenticationDatabase admin --archive=/tmp/mdump.archive --gzip && \
	    docker cp "$$cid:/tmp/mdump.archive" "dump/mongodb-$$ts.archive.gz" && \
	    docker compose --env-file "$e" -p "$*" -f "$f" exec -T mongo rm /tmp/mdump.archive ;; \
  redis) docker compose --env-file "$e" -p "$*" -f "$f" exec -T redis redis-cli -a "$${REDIS_PASSWORD:-changeme}" BGSAVE; sleep 3; \
    cid=$$(docker compose --env-file "$e" -p "$*" -f "$f" ps -q redis); \
    docker cp "$$cid:/data/dump.rdb" "dump/redis-$$ts.rdb" ;; \
  valkey) docker compose --env-file "$e" -p "$*" -f "$f" exec -T valkey valkey-cli -a "$${VALKEY_PASSWORD:-changeme}" BGSAVE; sleep 3; \
    cid=$$(docker compose --env-file "$e" -p "$*" -f "$f" ps -q valkey); \
    docker cp "$$cid:/data/dump.rdb" "dump/valkey-$$ts.rdb" ;; \
	  redis-master-replica) docker compose --env-file "$e" -p "$*" -f "$f" exec -T redis-master redis-cli -a "$${REDIS_MASTER_PASSWORD:-changeme-master}" BGSAVE; sleep 3; \
	    cid=$$(docker compose --env-file "$e" -p "$*" -f "$f" ps -q redis-master); \
	    docker cp "$$cid:/data/dump.rdb" "dump/redis-master-$$ts.rdb" ;; \
	  *) echo "No backup defined for '$*'. Supported: pgsql postgres-alt mysql mongodb redis redis-master-replica valkey"; exit 1 ;; \
	esac; ls -la dump/ | tail -n +2
