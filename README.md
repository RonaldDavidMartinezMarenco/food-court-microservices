# Food Court

[![Postgres](https://github.com/RonaldDavidMartinezMarenco/food-court-microservices/actions/workflows/postgres.yml/badge.svg)](https://github.com/RonaldDavidMartinezMarenco/food-court-microservices/actions/workflows/postgres.yml)
[![Java](https://img.shields.io/badge/Java-21-007396?logo=openjdk&logoColor=white)](https://openjdk.org/projects/jdk/21/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4.1.1-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)

Backend for a food court. A customer orders dishes from one restaurant. An administrator creates restaurants and owner accounts. An owner manages that restaurant's menu and employees. An employee prepares the order and delivers it with a security PIN.

This repository is the master checkout. It holds the docs, Compose files, and the script that clones the services. Each service is a separate Git repository. Cloning this repo does not download them.

## Contents

- [Repositories](#repositories)
- [Order flow](#order-flow)
- [Quick start](#quick-start)
- [Run the services](#run-the-services)
- [Layout](#layout)

## Repositories

| Service | Repository | Port | Database |
| --- | --- | --- | --- |
| Accounts, roles, and login | [user-service](https://github.com/RonaldDavidMartinezMarenco/user-service) | 8081 | `user_db` |
| Restaurants, dishes, and orders | [plaza-service](https://github.com/RonaldDavidMartinezMarenco/plaza-service) | 8082 | `plaza_db` |
| Status history and efficiency | [traceability-service](https://github.com/RonaldDavidMartinezMarenco/traceability-service) | 8083 | `traceability_db` |
| Ready-order SMS through Twilio | [messaging-service](https://github.com/RonaldDavidMartinezMarenco/messaging-service) | 8084 | none |

`scripts/clone-services.sh` clones those four repositories into this directory. The master `.gitignore` excludes the folders, so their history stays in their own remotes.

## Order flow

1. The customer places an order. It starts as `PENDING`.
2. An employee of that restaurant assigns it and moves it to `IN_PREPARATION`.
3. The customer can cancel only while the order is `PENDING`.
4. The employee marks it `READY`. The customer receives a PIN by SMS.
5. The employee enters that PIN and the order becomes `DELIVERED`.

A customer can have only one order in `PENDING`, `IN_PREPARATION`, or `READY`. Payment is out of scope. The requirements summary is in [docs/requirements/project-overview.md](docs/requirements/project-overview.md).

## Quick start

```bash
git clone https://github.com/RonaldDavidMartinezMarenco/food-court-microservices.git
cd food-court-microservices
bash scripts/clone-services.sh
cp .env.example .env
docker compose --env-file .env -f compose.postgres.yml up -d --wait
```

Postgres listens on host port `5433`. The container creates `user_db`. `postgres/init-databases.sql` creates `plaza_db` and `traceability_db` the first time the volume is empty.

If a service directory is already a Git checkout, the script leaves it in place.

## Run the services

Postgres only, then each service from its own directory:

```bash
docker compose --env-file .env -f compose.postgres.yml up -d --wait
cd user-service && ./mvnw spring-boot:run
```

Repeat `./mvnw spring-boot:run` in `plaza-service`, `traceability-service`, and `messaging-service`. From the host, the JDBC URL uses `localhost:5433`.

The full stack, including the four images:

```bash
docker compose --env-file .env up --build
```

Inside Compose the database host is `postgres` and the port is `5432`. `docker compose down` keeps the volume. `docker compose down -v` deletes the data.

Fill `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM_NUMBER` in `.env` before sending the ready-order SMS. `.env` is not committed.

## Layout

```text
food-court-microservices/          this repository
  user-service/                    separate Git repository
  plaza-service/
  traceability-service/
  messaging-service/
  compose.yml                      all four services and Postgres
  compose.postgres.yml             Postgres only
  postgres/init-databases.sql
  scripts/clone-services.sh
  docs/
```

Each service is a Java 21 and Spring Boot 4.1.1 application with hexagonal packages: domain inside, HTTP and JPA outside. One user story lives on its own branch and has unit tests. Each service publishes an OpenAPI description.
