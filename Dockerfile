# Default versions - can be overridden at build time using --build-arg
ARG PG_VERSION=17.9
ARG POSTGIS_VERSION=3
ARG PGVECTOR_VERSION=0.8.2

FROM postgres:${PG_VERSION}

# Re-declare ARGs after FROM to make them available in this build stage
ARG POSTGIS_VERSION
ARG PGVECTOR_VERSION

LABEL maintainer="TypeORM"
LABEL description="PostgreSQL with PostGIS and pgvector extensions for TypeORM"
LABEL org.opencontainers.image.source="https://github.com/typeorm/postgres-test-images"

# Install base dependencies, setup PGDG repository, and install build tools
# Note: PG_MAJOR is provided by the official postgres base image
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    lsb-release \
    gnupg \
    ca-certificates \
    wget \
    && wget --quiet -O /usr/share/keyrings/postgresql-archive-keyring.gpg https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && sh -c 'echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    make \
    gcc \
    "postgresql-server-dev-${PG_MAJOR}"

# Install PostGIS
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    postgis \
    "postgresql-${PG_MAJOR}-postgis-${POSTGIS_VERSION}" \
    "postgresql-${PG_MAJOR}-postgis-${POSTGIS_VERSION}-scripts"

# Build and install pgvector
RUN apt-get update \
    && apt-get install -y --no-install-recommends git make gcc "postgresql-server-dev-${PG_MAJOR}" \
    && mkdir -p /usr/src/pgvector \
    && git clone --branch "v${PGVECTOR_VERSION}" https://github.com/pgvector/pgvector.git /usr/src/pgvector \
    && cd /usr/src/pgvector \
    && make \
    && make install

# Cleanup build dependencies
RUN apt-get purge -y --auto-remove \
    build-essential \
    git \
    make \
    gcc \
    "postgresql-server-dev-${PG_MAJOR}" \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/pgvector

# Copy initialization scripts
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/

EXPOSE 5432
