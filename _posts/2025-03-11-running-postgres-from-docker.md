---
title:  "Running PostgreSQL on Docker"
date:   2025-03-11 07:41:10 -0300
categories:
  - Blog
tags:
  - postgres
  - docker
---

No need to install PostgreSQL on your system.

<!--more-->

# Introduction

Often times we need to run local PostgreSQL tests and installing it on your system can be painful sometimes.
Either by messing with your current PostgreSQL setup or just by leaving an extra process running because you
forgot to remove it after your testing.

This post describes a simple example on how to get PostgreSQL running by using Docker only.

# Running docker compose

Docker is an amazing tool and we can use it to run PostgreSQL:

```yaml
# docker-compose.yaml
services:
  db:
    image: postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

Save this file as `docker-compose.yaml` and spin a PostgreSQL service with it!

## Running psql

Now that we have our Docker container running PostgreSQL, we can start using psql to run our tests:

```bash
# Find our container
$ docker ps
CONTAINER ID   IMAGE      COMMAND                  CREATED         STATUS         PORTS      NAMES
9251e0046114   postgres   "docker-entrypoint.s…"   4 minutes ago   Up 4 minutes   5432/tcp   ...

# Run psql
$ docker exec -it 9251e0046114 psql -U postgres
psql (17.4 (Debian 17.4-1.pgdg120+2))
Type "help" for help.

postgres=#
```

# Conclusion

Docker is very helpful, after we stop using it, you can easily remove volumes and the PostgreSQL image.

Happy SQLing!
