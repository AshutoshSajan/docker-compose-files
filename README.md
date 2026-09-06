# docker-compose-files

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

## Index

| File | Service(s) | Default ports | Notes |
|---|---|---|---|
| `pgsql.yml` | Postgres 16 (official) | 5432 | `POSTGRES_*` in `.env`, seeds from `./sql_scripts`, healthcheck `pg_isready` |
| `bitnami-postgres.yml` | Postgres 16 (official image; ex-Bitnami file) | 5433 | Alternative to `pgsql.yml`; pick one (port 5433 avoids clash) |
| `mysql.yml` | MySQL 8.4 LTS | 3306 | Non-root `MYSQL_USER`, `mysqladmin ping` healthcheck |
| `mongodb.yml` | MongoDB 7.0 | 27017 | Persistent `db-data` + root auth + `mongosh ping` |
| `redis.yml` | Redis 7.4 (official) | 6379 | Password required by default, `FLUSHDB/FLUSHALL` disabled |
| `redis-master-replica.yml` | Redis master + replica | 6379, 6380 | Named volumes (no placeholder paths), replica waits for healthy master |
| `rabbitmq.yml` | RabbitMQ 3.13 (official, mgmt) | 5672, 15672 | `RABBITMQ_*` in `.env`, `rabbitmq-diagnostics ping` |
| `kafka.yml` | Kafka 3.8 KRaft (no ZK) | 9094 host | Replaces unmaintained `wurstmeister/*`; no `docker.sock` mount |
| `zookeeper-kafka.yml` | Kafka 7.6 + Zookeeper | 9092 | Minimal Confluent example with `cub` healthchecks + volumes |
| `kafka-gui.yml` | 2x Kafka + ZK + Schema Registry + Connect + kafka-ui | 8080, 9092-9093, 8083, 8085 | All Confluent images pinned to 7.6.1; seeds from `./kafka-seeds/message.json`; fixed duplicate broker id |
| `elastic-search.yml` | ES 8.14 3-node | 9200 | Security disabled for local dev only; optional Kibana commented in-file |
| `cassandra.yml` | Cassandra 4.1 | 9042 | Minimal working file; `cqlsh`/`nodetool` via `--profile tools`, Reaper/Prom/Grafana via `--profile observability` |
| `tigerbeetle.yaml` | TigerBeetle 3-node (host net, Linux) | 3001-3003 | Run `--profile format` once before `up` |
| `nginx.yml` | Nginx 1.27-alpine | 80, 443 | Example `./nginx/{html,conf.d}` mounts commented in-file |
| `julia.yml` | Julia 1.10 REPL | 7777 | Workdir `/work` mounted from `./julia-work` |
| `Dockerfile` | Jenkins LTS JDK17 + docker-cli | — | Blue Ocean removed (deprecated); cleaned apt layers |

Renamed: `rabitmq.yml` → `rabbitmq.yml`.

## Conventions applied to every file

* No obsolete `version:` key (Compose Spec).
* Images bumped off EOL tags; restart policies set. Bitnami community tags were
  removed from Docker Hub, so ex-Bitmami files now use official images.
* No hardcoded secrets — `${VAR:-default}` with `.env.example`; copy to `.env` (git-ignored).
* `healthcheck:` + `depends_on: condition: service_healthy` where ordering matters.
* Named volumes for all stateful services; no `/path/to/...` placeholders.
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
