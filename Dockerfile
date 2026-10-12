# syntax=docker/dockerfile:1
#
# CI image for Dean's Ruby projects.
# mise picks Ruby and Node from each project's .mise.toml, as in development,
# and the common versions are preinstalled.
#
# Local build: docker build -t ruby-mise:test .
# Published to GHCR by .github/workflows/publish.yml.

FROM debian:trixie-slim

ENV MISE_DATA_DIR=/mise \
    MISE_CONFIG_DIR=/mise/config \
    MISE_INSTALL_PATH=/usr/local/bin/mise \
    PATH="/mise/shims:/usr/local/bin:${PATH}" \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git build-essential ca-certificates gnupg \
      libssl-dev libyaml-dev zlib1g-dev libreadline-dev \
      libsqlite3-dev libvips ffmpeg pkg-config \
    && rm -rf /var/lib/apt/lists/*

# MySQL 8.4 LTS from MySQL's apt repo. Not MariaDB, which lacks
# utf8mb4_0900_ai_ci, MySQL 8's default collation.
#
# The repo is added by hand rather than with the mysql-apt-config package,
# whose bundled signing key expires. Oracle republishes the key with a new
# expiry as RPM-GPG-KEY-mysql-<year>.
#
# The package sets up the system tables at build time. Jobs that need a
# database run start-mysql: CI runners replace the entrypoint, so it can't
# start automatically.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL http://repo.mysql.com/RPM-GPG-KEY-mysql-2025 \
      | gpg --dearmor -o /etc/apt/keyrings/mysql.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian/ $(. /etc/os-release && echo "$VERSION_CODENAME") mysql-8.4-lts" \
      > /etc/apt/sources.list.d/mysql.list \
    && echo "deb [signed-by=/etc/apt/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian/ $(. /etc/os-release && echo "$VERSION_CODENAME") mysql-tools" \
      >> /etc/apt/sources.list.d/mysql.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends mysql-server mysql-client libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*
COPY start-mysql /usr/local/bin/start-mysql
RUN chmod +x /usr/local/bin/start-mysql

# Redis from Debian. Jobs that need it run start-redis.
RUN apt-get update && apt-get install -y --no-install-recommends redis-server \
    && rm -rf /var/lib/apt/lists/*
COPY start-redis /usr/local/bin/start-redis
RUN chmod +x /usr/local/bin/start-redis

RUN curl https://mise.run | sh

# Every Ruby the projects use. Check the .mise.toml files and billy's CI
# matrix before removing one. `mise use -g` replaces the global version, so
# install them all and then make the newest the default.
RUN mise install ruby@3.3 ruby@3.4 ruby@4.0 && \
    mise use -g ruby@4.0

# Node 24 and pnpm, for syncagent's build. corepack adds pnpm without mise
# knowing, so reshim to put it on PATH.
RUN mise use -g node@24 && \
    mise exec -- corepack enable pnpm && \
    mise reshim

WORKDIR /workspace
