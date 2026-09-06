# docker-compose-files

![validate](https://github.com/AshutoshSajan/docker-compose-files/actions/workflows/validate.yml/badge.svg)

Standalone Docker Compose snippets for local dev infrastructure.
Each file is self-contained — pick one and run it with Docker Compose v2.

## Quick start

```bash
cp .env.example .env   # then edit passwords/ports
docker compose -f pgsql.yml up -d
docker compose -f pgsql.yml ps
docker compose -f pgsql.yml down
```

Validate without starting:

```bash
docker compose -f <file>.yml config
```

## Quick runner (Makefile)

Any stack with one command — `<service>` is the file name without extension:

```bash
make help            # list actions + services
make list            # list services only
make up-redis        # docker compose -f redis.yml up -d
make logs-pgsql      # follow logs (Ctrl-C to exit)
make ps-kafka        # status for one stack
make ps-all          # status for all stacks
make down-mysql      # stop, keep volumes
make clean-mongo     # stop AND delete volumes
make restart-rabbit  # ❌ no — name must match: make restart-rabbitmq
make pull-kafka      # pre-pull images
make config-nginx    # validate + print resolved config
```

`.env` is auto-created from `.env.example` on first run.
Per-invocation overrides work too: `REDIS_VERSION=7.4 make up-redis`.

## Per-project environments

One checkout, many projects — keep a separate env file per project:

```bash
make env-acme          # creates .env.acme from the template; edit it
make up-redis ENV=acme # uses .env.acme (versions, passwords, ports)
make backup-pgsql ENV=acme
```

`ENV=<name>` works with every target (`up/down/logs/ps/config/backup`,
`GUI=1` can be combined: `GUI=1 make up-redis ENV=acme`). `.env.*` files
are git-ignored; only `.env.example` is tracked.

## Backups

Dumps land in `./dump/` (git-ignored). The service must be running:

```bash
make backup-pgsql               # → dump/pgsql-<timestamp>.sql (pg_dump)
make backup-mysql               # → dump/mysql-<timestamp>.sql (all DBs)
make backup-mongodb             # → dump/mongodb-<timestamp>.archive.gz
make backup-redis               # → dump/redis-<timestamp>.rdb (BGSAVE)
make backup-redis-master-replica
make backup-pgsql ENV=acme      # same, with project env
```

Restore is deliberately manual (destructive — check twice):

```bash
# Postgres:  docker compose -f pgsql.yml exec -T postgresql-db psql -U admin -d postgres < dump/pgsql-<ts>.sql
# MySQL:     docker compose -f mysql.yml exec -T db mysql -u root -p < dump/mysql-<ts>.sql
# MongoDB:   docker compose -f mongodb.yml exec -T mongo mongorestore -u root -p changeme --authenticationDatabase admin --gzip --archive=/tmp/x.archive.gz
# Redis:     stop, replace /data/dump.rdb in the redis_data volume, start
```

## Web GUIs for every tool

GUI sidecars are opt-in behind the `gui` profile — plain `make up-<svc>`
stays minimal. Prefix with `GUI=1` to include the web UI:

```bash
GUI=1 make up-redis        # Redis + redis-commander  → http://localhost:8084
GUI=1 make up-pgsql        # Postgres + pgAdmin       → http://localhost:5050
GUI=1 make up-kafka        # Kafka + kafka-ui         → http://localhost:8080
```

Raw compose equivalent: `docker compose -f redis.yml --profile gui up -d`.

| Stack | GUI | Default URL | Login |
|---|---|---|---|
| `pgsql.yml` / `bitnami-postgres.yml` | pgAdmin 4 | :5050 | `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` |
| `mysql.yml` | phpMyAdmin | :8081 | MySQL user from `.env` |
| `mongodb.yml` | mongo-express | :8082 | `MONGO_EXPRESS_USER` / `MONGO_EXPRESS_PASSWORD` |
| `redis.yml` / `redis-master-replica.yml` | redis-commander | :8084 | no login (local dev) |
| `rabbitmq.yml` | Management UI (built in) | :15672 | `RABBITMQ_USER` / `RABBITMQ_PASSWORD` |
| `kafka.yml` / `zookeeper-kafka.yml` | kafka-ui | :8080 | no login |
| `kafka-gui.yml` | kafka-ui (always on) | :8080 | no login |
| `elastic-search.yml` | Kibana | :5601 | no login (security disabled, dev only) |
| `cassandra.yml` | Reaper + Grafana + Prometheus | :8080 / :3000 / :9090 | `GRAFANA_USER` / `GRAFANA_PASSWORD` |
| Jenkins (`Dockerfile`) | Jenkins itself | :8080 | set on first boot |

No GUI: `nginx` (is itself a web server), `julia` (REPL), `tigerbeetle`
(no official web UI). GUI image versions/ports are `.env` vars
(`PGADMIN_VERSION`, `PHPMYADMIN_PORT`, …).

## Switching versions

Every image tag is a variable with a latest-stable default — no file editing needed:

```bash
cp .env.example .env   # then set versions per project
```

```dotenv
POSTGRES_VERSION=17
MONGO_VERSION=7.0
REDIS_VERSION=7.4
RABBITMQ_VERSION=4.2-management
MYSQL_VERSION=8.4
ES_VERSION=8.19.21
CONFLUENT_VERSION=7.8.10
KAFKA_VERSION=4.2.1
CASSANDRA_VERSION=4.1
NGINX_VERSION=1.28-alpine
JULIA_VERSION=1.10
```

Full list: `POSTGRES_VERSION`, `MYSQL_VERSION`, `MONGO_VERSION`,
`REDIS_VERSION`, `RABBITMQ_VERSION`, `KAFKA_VERSION`, `CONFLUENT_VERSION`,
`KAFKA_UI_VERSION`, `ES_VERSION`, `CASSANDRA_VERSION`, `REAPER_VERSION`,
`PROM_VERSION`, `GRAFANA_VERSION`, `TIGERBEETLE_VERSION`, `NGINX_VERSION`,
`JULIA_VERSION` (see `.env.example`). One-off override without `.env`:

```bash
POSTGRES_VERSION=17 docker compose -f pgsql.yml up -d
```

Jenkins (`Dockerfile`) uses a build arg instead:

```bash
docker build --build-arg JENKINS_VERSION=2.555.3-lts-jdk21 .
```

> Major-version downgrades (e.g. Postgres 18 → 17) need a fresh volume:
> `docker compose -f pgsql.yml down -v` before switching.

## Index

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `pgsql.yml` | Postgres `${POSTGRES_VERSION:-18}` (official) | 5432 | `POSTGRES_*` in `.env`, seeds from `./sql_scripts`, healthcheck `pg_isready` |
| `bitnami-postgres.yml` | Postgres `${POSTGRES_VERSION:-18}` (official image; ex-Bitnami file) | 5433 | Alternative to `pgsql.yml`; pick one (port 5433 avoids clash) |
| `mysql.yml` | MySQL `${MYSQL_VERSION:-9}` LTS | 3306 | Non-root `MYSQL_USER`, `mysqladmin ping` healthcheck |
| `mongodb.yml` | MongoDB `${MONGO_VERSION:-8}` | 27017 | Persistent `db-data` + root auth + `mongosh ping` |
| `redis.yml` | Redis `${REDIS_VERSION:-8}` (official) | 6379 | Password required by default, `FLUSHDB/FLUSHALL` disabled |
| `redis-master-replica.yml` | Redis master + replica | 6379, 6380 | Named volumes (no placeholder paths), replica waits for healthy master |
| `rabbitmq.yml` | RabbitMQ `${RABBITMQ_VERSION:-4.3-management}` (official, mgmt) | 5672, 15672 | `RABBITMQ_*` in `.env`, `rabbitmq-diagnostics ping` |
| `kafka.yml` | Kafka `${KAFKA_VERSION:-4.3.1}` KRaft (no ZK) | 9094 host | Replaces unmaintained `wurstmeister/*`; no `docker.sock` mount |
| `zookeeper-kafka.yml` | Kafka + Zookeeper (Confluent `${CONFLUENT_VERSION:-7.9.9}`) | 9092 | Minimal Confluent example with `cub` healthchecks + volumes |
| `kafka-gui.yml` | 2x Kafka + ZK + Schema Registry + Connect + kafka-ui | 8080, 9092-9093, 8083, 8085 | All Confluent images pinned to `${CONFLUENT_VERSION:-7.9.9}`; seeds from `./kafka-seeds/message.json`; fixed duplicate broker id |
| `elastic-search.yml` | ES `${ES_VERSION:-9.5.3}` 3-node | 9200 | Security disabled for local dev only; optional Kibana commented in-file |
| `cassandra.yml` | Cassandra `${CASSANDRA_VERSION:-5.0}` | 9042 | Minimal working file; `cqlsh`/`nodetool` via `--profile tools`, Reaper/Prom/Grafana via `--profile observability` |
| `tigerbeetle.yaml` | TigerBeetle 3-node (host net, Linux) | 3001-3003 | Run `--profile format` once before `up` |
| `nginx.yml` | Nginx `${NGINX_VERSION:-1.30-alpine}` (stable) | 80, 443 | Example `./nginx/{html,conf.d}` mounts commented in-file |
| `julia.yml` | Julia `${JULIA_VERSION:-1.12}` REPL | 7777 | Workdir `/work` mounted from `./julia-work` |
| `Dockerfile` | Jenkins `${JENKINS_VERSION:-2.555.3-lts-jdk21}` + docker-cli | — | Blue Ocean removed (deprecated); cleaned apt layers |

Renamed: `rabitmq.yml` → `rabbitmq.yml`.

## Conventions applied to every file

* No obsolete `version:` key (Compose Spec).
* Images bumped off EOL tags; restart policies set. Bitnami community tags were
  removed from Docker Hub, so ex-Bitmami files now use official images.
* No hardcoded secrets — `${VAR:-default}` with `.env.example`; copy to `.env` (git-ignored).
* `healthcheck:` + `depends_on: condition: service_healthy` where ordering matters.
* Named volumes for all stateful services; no `/path/to/...` placeholders.
  Volume names are prefixed per stack (`pgsql-data`, `mongo-data`, …) so
  stacks never share a data dir. Postgres mounts `/var/lib/postgresql`
  (parent dir) as required by the 18+ image — works for older majors too.
* No read-write `/var/run/docker.sock` mounts (removed from Kafka; documented in Cassandra).
* `tigerbeetle.yaml` keeps `network_mode: host` with Linux-only warning + explicit `format` step.

## Profiles / special commands

```bash
# Cassandra helpers
docker compose -f cassandra.yml --profile tools run --rm cqlsh
docker compose -f cassandra.yml --profile observability up -d

# TigerBeetle first-time format, then start
docker compose -f tigerbeetle.yaml --profile format up
docker compose -f tigerbeetle.yaml up -d

# Kafka GUI full stack
docker compose -f kafka-gui.yml up -d
```

## Security notes

* Defaults in `.env.example` are for local dev only — change them.
* ES `xpack.security.enabled=false` and Redis/Mongo/ES open ports are dev-only.
* For shared/staging use Docker secrets (`*_FILE`) and enable TLS/auth.
