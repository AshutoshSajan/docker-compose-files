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

Every stack runs as its own compose project (`-p <service>`), so stacks get
separate networks and volume prefixes and never see each other's containers.
If you ran these files before this change, stop the old shared project once
(`docker compose -f <file>.yml down`) and drop its orphaned volumes
(`docker volume ls | grep docker-compose-files`).

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
make backup-valkey              # → dump/valkey-<timestamp>.rdb (BGSAVE)
make backup-pgsql ENV=acme      # same, with project env
```

Restore is deliberately manual (destructive — check twice). CI verifies the
Postgres roundtrip (backup → wipe → restore → marker row) on every push:

```bash
# Postgres:  docker compose -f pgsql.yml exec -T postgresql-db psql -U admin -d postgres < dump/pgsql-<ts>.sql
# MySQL:     docker compose -f mysql.yml exec -T db mysql -u root -p < dump/mysql-<ts>.sql
# MongoDB:   docker compose -f mongodb.yml exec -T mongo mongorestore -u root -p changeme --authenticationDatabase admin --gzip --archive=/tmp/x.archive.gz
# Redis:     stop, replace /data/dump.rdb in the redis_data volume, start
```

## Disk cleanup

Images pile up fast with this repo. Safe first, destructive last:

```bash
docker system df               # what's eating disk
make clean-<svc>               # stop a stack AND delete its volumes (scoped, safe)
docker image prune             # dangling images only (safe)
docker image prune -a          # all unused images (re-pulled on demand; running stacks kept)
docker container prune         # stopped containers
docker network prune           # unused networks
docker builder prune           # build cache
docker system prune            # all of the above at once (never touches volumes)
```

DANGER — deletes data, no undo:

```bash
docker volume ls                             # inspect first
docker volume prune                          # ALL unattached volumes
docker compose -f <file>.yml down -v         # same as make clean-<svc>
```

Rules of thumb: `make down-<svc>` keeps volumes (data survives restarts);
back up first (`make backup-<svc>`) before anything with `-v` or prune.

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
| `pgsql.yml` / `postgres-alt.yml` | pgAdmin 4 | :5050 | `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` |
| `mysql.yml` | phpMyAdmin | :8081 | MySQL user from `.env` |
| `mongodb.yml` | mongo-express | :8082 | `MONGO_EXPRESS_USER` / `MONGO_EXPRESS_PASSWORD` |
| `redis.yml` / `redis-master-replica.yml` / `valkey.yml` | redis-commander | :8084 / :8084 / :8086 | no login (local dev) |
| `rabbitmq.yml` | Management UI (built in) | :15672 | `RABBITMQ_USER` / `RABBITMQ_PASSWORD` |
| `kafka.yml` / `zookeeper-kafka.yml` | kafka-ui | :8080 | no login |
| `kafka-gui.yml` | kafka-ui (always on) | :8080 | no login |
| `elastic-search.yml` | Kibana | :5601 | no login (security disabled, dev only) |
| `cassandra.yml` | Reaper + Grafana + Prometheus | :8080 / :3000 / :9090 | `GRAFANA_USER` / `GRAFANA_PASSWORD` |
| `observability.yml` | Grafana (pre-wired to Prometheus) | :3000 | `GRAFANA_USER` / `GRAFANA_PASSWORD` |
| `clickhouse.yml` | Playground (built in) | :8123 | `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` |
| `minio.yml` | Console (built in) | :9001 | `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` |
| `mailpit.yml` | Web UI (built in) | :8025 | no login |
| `meilisearch.yml` | Dashboard (built in) | :7700 | `MEILI_MASTER_KEY` |
| `nats.yml` | Monitoring endpoint (JSON, no full UI) | :8222 | no login |
| Jenkins (`Dockerfile`) | Jenkins itself | :8080 | set on first boot |

No GUI: `nginx` (is itself a web server), `julia` (REPL), `tigerbeetle`
(no official web UI). GUI image versions/ports are `.env` vars
(`PGADMIN_VERSION`, `PHPMYADMIN_PORT`, …).

## GUI directory — install permanently

✅ = one-command setup already wired in this repo (`GUI=1 make up-<svc>`).
Everything else you can install yourself via the links.

### PostgreSQL

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| pgAdmin 4 ✅ | web | [pgadmin-org/pgadmin4](https://github.com/pgadmin-org/pgadmin4) | [pgadmin.org](https://www.pgadmin.org) | official, most complete |
| DBeaver | desktop | [dbeaver/dbeaver](https://github.com/dbeaver/dbeaver) | [dbeaver.io](https://dbeaver.io) | universal client (also MySQL/Mongo/Cassandra/…) |
| DataGrip | desktop | — | [jetbrains.com/datagrip](https://www.jetbrains.com/datagrip) | paid JetBrains IDE |
| TablePlus | desktop | — | [tableplus.com](https://tableplus.com) | paid, fast native client |
| Beekeeper Studio | desktop | [beekeeper-studio/beekeeper-studio](https://github.com/beekeeper-studio/beekeeper-studio) | [beekeeperstudio.io](https://www.beekeeperstudio.io) | OSS, clean UI |
| DbGate | web/desktop | [dbgate/dbgate](https://github.com/dbgate/dbgate) | [dbgate.org](https://dbgate.org) | OSS, runs in browser too |
| Postico | desktop | — | [eggerapps.at/postico](https://eggerapps.at/postico/) | Mac-only, PG-focused |

### MySQL

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| phpMyAdmin ✅ | web | [phpmyadmin/phpmyadmin](https://github.com/phpmyadmin/phpmyadmin) | [phpmyadmin.net](https://www.phpmyadmin.net) | classic, PHP |
| Adminer | web | [vrana/adminer](https://github.com/vrana/adminer) | [adminer.org](https://www.adminer.org) | single PHP file |
| MySQL Workbench | desktop | — | [dev.mysql.com/workbench](https://dev.mysql.com/workbench/) | official Oracle tool |
| HeidiSQL | desktop | [HeidiSQL/HeidiSQL](https://github.com/HeidiSQL/HeidiSQL) | [heidisql.com](https://www.heidisql.com) | Windows-first, free |
| DBeaver / TablePlus / Beekeeper | desktop | see PostgreSQL | see PostgreSQL | same apps, MySQL included |

### MongoDB

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| mongo-express ✅ | web | [mongo-express/mongo-express](https://github.com/mongo-express/mongo-express) | — | lightweight, matches this repo |
| Compass | desktop | [mongodb-js/compass](https://github.com/mongodb-js/compass) | [mongodb.com/try/download/compass](https://www.mongodb.com/try/download/compass) | official, free |
| Studio 3T | desktop | — | [studio3t.com](https://studio3t.com) | paid, power-user features |
| NoSQLBooster | desktop | — | [nosqlbooster.com](https://nosqlbooster.com) | paid, SQL-to-MQL helper |

### Redis

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| redis-commander ✅ | web | [joeferner/redis-commander](https://github.com/joeferner/redis-commander) | — | lightweight, matches this repo |
| RedisInsight | desktop/docker | [redis/RedisInsight](https://github.com/redis/RedisInsight) | [redis.io/insight](https://redis.io/insight/) | official, free (`redis/redisinsight` image) |
| Another Redis Desktop Manager | desktop | [qishibo/AnotherRedisDesktopManager](https://github.com/qishibo/AnotherRedisDesktopManager) | — | OSS, fast |
| RESP.app | desktop | — | [resp.app](https://resp.app) | paid (ex Redis Desktop Manager) |

Any Redis GUI above also works against Valkey (`valkey.yml`) — same protocol.

### RabbitMQ

Built-in management UI ✅ (this repo's image ships it on `:15672`) —
[docs](https://www.rabbitmq.com/docs/management). No third-party GUI needed.

### Kafka

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| kafka-ui ✅ | web | [kafbat/kafka-ui](https://github.com/kafbat/kafka-ui) | [kafbat.io](https://kafbat.io) | see migration note below |
| AKHQ | web | [tchiotludo/akhq](https://github.com/tchiotludo/akhq) | [akhq.io](https://akhq.io) | Kafka + Schema Registry + Connect |
| Kafdrop | web | [obsidiandynamics/kafdrop](https://github.com/obsidiandynamics/kafdrop) | — | minimal topic/message browser |
| Redpanda Console | web | [redpanda-data/console](https://github.com/redpanda-data/console) | [redpanda.com](https://www.redpanda.com) | ex-Kowl, works with any Kafka |
| Conduktor | desktop/platform | — | [conduktor.io](https://www.conduktor.io) | free desktop + paid platform |

> Provectus paused `provectuslabs/kafka-ui` in 2023; the active
> community fork is **Kafbat UI** (`ghcr.io/kafbat/kafka-ui`, same config
> keys) — prefer it for permanent installs.

### Elasticsearch

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| Kibana ✅ | web | [elastic/kibana](https://github.com/elastic/kibana) | [elastic.co/kibana](https://www.elastic.co/kibana) | official, full power |
| Elasticvue | desktop/ext/docker | [cars10/elasticvue](https://github.com/cars10/elasticvue) | [elasticvue.com](https://elasticvue.com) | lightweight document browser |
| Cerebro | web | [lmenezes/cerebro](https://github.com/lmenezes/cerebro) | — | cluster admin, aging (2021 release) |

### Cassandra

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| Reaper ✅ | web | [thelastpickle/cassandra-reaper](https://github.com/thelastpickle/cassandra-reaper) | [cassandra-reaper.io](https://cassandra-reaper.io) | repairs (this repo's pick) |
| Grafana ✅ | web | [grafana/grafana](https://github.com/grafana/grafana) | [grafana.com](https://grafana.com) | metrics dashboards |
| DBeaver | desktop | see PostgreSQL | see PostgreSQL | CQL via JDBC driver |

### ClickHouse

Playground is built in (`clickhouse.yml` `:8123`). For permanent installs:

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| Tabix | web | [tabixio/tabix](https://github.com/tabixio/tabix) | [tabix.io](https://tabix.io) | lightweight, free |
| DBeaver / DataGrip / TablePlus | desktop | see PostgreSQL | see PostgreSQL | all speak ClickHouse |

### NATS

No full GUI — the built-in monitoring endpoint (`nats.yml` `:8222`,
`/connz` `/varz` `/jsz`) plus the official CLI
([nats-io/natscli](https://github.com/nats-io/natscli)) cover daily use.

### MinIO / Mailpit / Meilisearch

All three ship their UI in the box (`minio.yml` `:9001`,
`mailpit.yml` `:8025`, `meilisearch.yml` `:7700`) — nothing to install.

### Nginx

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| Nginx Proxy Manager | web | [NginxProxyManager/nginx-proxy-manager](https://github.com/NginxProxyManager/nginx-proxy-manager) | [nginxproxymanager.com](https://nginxproxymanager.com) | reverse-proxy + Let's Encrypt UI |
| nginxconfig.io | generator | [digitalocean/nginxconfig.io](https://github.com/digitalocean/nginxconfig.io) | [nginxconfig.io](https://www.nginxconfig.io) | generates tuned configs |

### TigerBeetle

No widely-adopted GUI — operate via CLI +
[docs](https://tigerbeetle.com).

### Julia

| GUI | Type | GitHub | Website | Notes |
|---|---|---|---|---|
| Pluto.jl | notebook | [fonsp/Pluto.jl](https://github.com/fonsp/Pluto.jl) | [plutojl.org](https://plutojl.org) | reactive notebooks, `] add Pluto` |
| Jupyter + IJulia | notebook | [JuliaInterop/IJulia.jl](https://github.com/JuliaInterop/IJulia.jl) | [jupyter.org](https://jupyter.org) | classic notebooks |

### Jenkins / Prometheus

Jenkins *is* its own GUI (Blue Ocean is deprecated — this repo
intentionally doesn't install it). For Prometheus the GUI is Grafana ✅.

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

## Keeping versions fresh

Version lines in `.env.example` tagged `# renovate: …` are auto-updated by
[Renovate](https://docs.renovatebot.com) (`renovate.json`, one grouped PR).
Enable it via the Renovate GitHub App (or self-hosted) — the `validate`
workflow smoke-tests every bump. The Jenkins image in `Dockerfile`
(`ARG JENKINS_VERSION`) is covered by Renovate's built-in dockerfile manager.

## Index

### Relational databases

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `pgsql.yml` | Postgres `${POSTGRES_VERSION:-18}` | 5432 | `POSTGRES_*` in `.env`, seeds from `./sql_scripts`, healthcheck `pg_isready` |
| `postgres-alt.yml` | Postgres `${POSTGRES_VERSION:-18}` | 5433 | Second instance; pick one of the two pg files |
| `mysql.yml` | MySQL `${MYSQL_VERSION:-9}` LTS | 3306 | Non-root `MYSQL_USER`, `mysqladmin ping` healthcheck |

### NoSQL / cache

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `mongodb.yml` | MongoDB `${MONGO_VERSION:-8}` | 27017 | Persistent `mongo-data` + root auth + `mongosh ping` |
| `redis.yml` | Redis `${REDIS_VERSION:-8}` | 6379 | Password required by default, `FLUSHDB/FLUSHALL` disabled |
| `redis-master-replica.yml` | Redis master + replica | 6379, 6380 | Named volumes (no placeholder paths), replica waits for healthy master |
| `valkey.yml` | Valkey `${VALKEY_VERSION:-8}` (Redis fork) | 6381 | Same password/commander setup as `redis.yml` |
| `cassandra.yml` | Cassandra `${CASSANDRA_VERSION:-5.0}` | 9042 | `cqlsh`/`nodetool` via `--profile tools`, Reaper/Prom/Grafana via `--profile observability` |
| `tigerbeetle.yaml` | TigerBeetle 3-node (host net, Linux) | 3001-3003 | Run `--profile format` once before `up` |

### Analytics

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `clickhouse.yml` | ClickHouse `${CLICKHOUSE_VERSION:-26.3}` | 8123, 9000 | `CLICKHOUSE_*` in `.env`, playground UI built in, `clickhouse-client` healthcheck |

### Messaging & streaming

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `rabbitmq.yml` | RabbitMQ `${RABBITMQ_VERSION:-4.3-management}` (mgmt) | 5672, 15672 | `RABBITMQ_*` in `.env`, `rabbitmq-diagnostics ping` |
| `kafka.yml` | Kafka `${KAFKA_VERSION:-4.3.1}` KRaft (no ZK) | 9094 host | Single broker, no `docker.sock` mount |
| `zookeeper-kafka.yml` | Kafka + Zookeeper (Confluent `${CONFLUENT_VERSION:-7.9.9}`) | 9092 | Minimal Confluent example with `cub` healthchecks + volumes |
| `kafka-gui.yml` | 2x Kafka + ZK + Schema Registry + Connect + kafka-ui | 8080, 9092-9093, 8083, 8085 | Confluent images share `${CONFLUENT_VERSION:-7.9.9}`; seeds from `./kafka-seeds/message.json` |
| `nats.yml` | NATS `${NATS_VERSION:-2}` + JetStream | 4222, 8222 | No healthcheck (scratch image); monitoring endpoint built in |

### Search

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `elastic-search.yml` | ES `${ES_VERSION:-9.5.3}` 3-node | 9200 | Security disabled for local dev only; Kibana via `gui` profile |
| `meilisearch.yml` | Meilisearch `${MEILI_VERSION:-v1}` | 7700 | `MEILI_MASTER_KEY` in `.env`, dashboard built in |

### Storage

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `minio.yml` | MinIO `${MINIO_VERSION:-RELEASE.2025-09-07T16-13-09Z}` (S3 API) | 9000, 9001 | `MINIO_ROOT_*` in `.env`, console built in |

### Observability

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `observability.yml` | Prometheus + Grafana | 9090, 3000 | Grafana pre-wired to Prometheus; add targets in `./observability/prometheus.yml` |

### Dev tools

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `mailpit.yml` | Mailpit `${MAILPIT_VERSION:-v1.31}` (email testing) | 1025, 8025 | In-memory by default; persistence commented in-file |
| `julia.yml` | Julia `${JULIA_VERSION:-1.12}` REPL | 7777 | Workdir `/work` mounted from `./julia-work` |

### Web & CI

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `nginx.yml` | Nginx `${NGINX_VERSION:-1.30-alpine}` (stable) | 80, 443 | Example `./nginx/{html,conf.d}` mounts commented in-file |
| `Dockerfile` | Jenkins `${JENKINS_VERSION:-2.555.3-lts-jdk21}` + docker-cli | — | No deprecated Blue Ocean; cleaned apt layers |

## Host ports

Every published port and the `.env` var that moves it (`—` = fixed):

| Host port | Stack | Env var |
|---|---|---|
| 5432 | `pgsql.yml` Postgres | `POSTGRES_PORT` |
| 5433 | `postgres-alt.yml` Postgres | `ALT_POSTGRES_PORT` |
| 5050 | pgAdmin (both pg files) | `PGADMIN_PORT` |
| 3306 | `mysql.yml` | `MYSQL_PORT` |
| 8081 | phpMyAdmin | `PHPMYADMIN_PORT` |
| 27017 | `mongodb.yml` | `MONGO_PORT` |
| 8082 | mongo-express | `MONGO_EXPRESS_PORT` |
| 6379 | `redis.yml` / `redis-master-replica.yml` master | `REDIS_PORT` / `REDIS_MASTER_PORT` |
| 6380 | replica | `REDIS_REPLICA_PORT` |
| 6381 | `valkey.yml` | `VALKEY_PORT` |
| 8084 | redis-commander (both redis files) | `REDIS_COMMANDER_PORT` |
| 8086 | redis-commander (valkey) | `VALKEY_COMMANDER_PORT` |
| 5672, 15672 | `rabbitmq.yml` | `RABBITMQ_AMQP_PORT`, `RABBITMQ_MGMT_PORT` |
| 9094 | `kafka.yml` | `KAFKA_PORT` |
| 9092 | `zookeeper-kafka.yml` | `KAFKA_PORT` |
| 8080 | kafka-ui (`kafka.yml`, `zookeeper-kafka.yml`, `kafka-gui.yml`) + Reaper | `KAFKA_UI_PORT`, `REAPER_PORT` |
| 9092, 9093, 9997, 9998 | `kafka-gui.yml` brokers/JMX | — |
| 8085, 18085, 8083, 2181 | `kafka-gui.yml` registries/connect/zk | — |
| 9200 | `elastic-search.yml` | `ES_PORT` |
| 5601 | Kibana | `KIBANA_PORT` |
| 9042 | `cassandra.yml` | `CASSANDRA_PORT` |
| 8123, 9000 | `clickhouse.yml` (HTTP, native) | `CLICKHOUSE_HTTP_PORT`, `CLICKHOUSE_NATIVE_PORT` |
| 4222, 8222 | `nats.yml` (client, monitoring) | `NATS_PORT`, `NATS_HTTP_PORT` |
| 9000, 9001 | `minio.yml` (API, console) | `MINIO_API_PORT`, `MINIO_CONSOLE_PORT` |
| 1025, 8025 | `mailpit.yml` (SMTP, UI) | `MAILPIT_SMTP_PORT`, `MAILPIT_HTTP_PORT` |
| 7700 | `meilisearch.yml` | `MEILI_PORT` |
| 9090, 3000 | `observability.yml` (Prometheus, Grafana) | `PROM_PORT`, `GRAFANA_PORT` |
| 8081, 9090, 3000 | Reaper-internal, Prometheus, Grafana | — (`REAPER_PORT` for the UI) |
| 3001–3003 | `tigerbeetle.yaml` (host net) | — |
| 80, 443 | `nginx.yml` | `NGINX_HTTP_PORT`, `NGINX_HTTPS_PORT` |
| 7777 | `julia.yml` | `JULIA_PORT` |

Known overlaps when running several stacks at once: pgAdmin `:5050`
(both pg files), kafka-ui `:8080` (all three Kafka files + Reaper),
redis-commander `:8084` (both redis files), Prometheus `:9090` / Grafana
`:3000` (`cassandra.yml` vs `observability.yml`) — override per stack via
`ENV=<name>` or one-off `VAR=port make …`.

## Conventions applied to every file

* No obsolete `version:` key (Compose Spec).
* Official, maintained images; restart policies set.
* No hardcoded secrets — `${VAR:-default}` with `.env.example`; copy to `.env` (git-ignored).
* `healthcheck:` + `depends_on: condition: service_healthy` where ordering matters.
* Generous `deploy.resources.limits.memory` caps on JVMs and databases
  (ES/Cassandra/Kafka/MySQL/…) so one stack can't eat your laptop; small
  UIs and CLIs are uncapped.
* No log rotation per file — set it once per machine in
  `/etc/docker/daemon.json` (then `systemctl restart docker`):
  `{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}`.
* Named volumes for all stateful services; no `/path/to/...` placeholders.
  Volume names are prefixed per stack (`pgsql-data`, `mongo-data`, …) so
  stacks never share a data dir. Postgres mounts `/var/lib/postgresql`
  (parent dir) as required by the 18+ image — works for older majors too.
* No read-write `/var/run/docker.sock` mounts.
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

## Troubleshooting

* Kafka brokers refuse to start with `Invalid cluster.id in meta.properties`:
  ZK and broker volumes diverged (one was reset without the other — these
  must always be reset together). Wipe and start fresh:
  `make clean-kafka-gui` (or `clean-zookeeper-kafka`), then `up` again.
  Your topics are test data; re-seeding runs automatically.
* Image pull fails with snapshot/overlayfs errors: usually disk pressure —
  see Disk cleanup above, then retry the pull.

## License

MIT — see [LICENSE](LICENSE).
