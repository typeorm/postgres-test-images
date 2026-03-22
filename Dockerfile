# Default versions - can be overridden at build time using --build-arg
ARG PG_VERSION=17.9
ARG POSTGIS_VERSION=3.6.2
ARG PGVECTOR_VERSION=0.8.2

FROM postgres:${PG_VERSION}

# Re-declare ARGs after FROM to make them available in this build stage
ARG POSTGIS_VERSION
ARG PGVECTOR_VERSION

LABEL maintainer="TypeORM"
LABEL description="PostgreSQL with PostGIS and pgvector extensions for TypeORM"
LABEL org.opencontainers.image.source="https://github.com/typeorm/docker"

# Install PostGIS, build pgvector from source, then clean up in a single layer
# Note: PG_MAJOR is provided by the official postgres base image
RUN set -eux \
    && apt-get update \
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
        "postgresql-server-dev-${PG_MAJOR}" \
    && POSTGIS_MAJOR=$(echo "${POSTGIS_VERSION}" | cut -d. -f1) \
    && apt-get install -y --no-install-recommends \
        "postgis=${POSTGIS_VERSION}+dfsg*" \
        "postgresql-${PG_MAJOR}-postgis-${POSTGIS_MAJOR}=${POSTGIS_VERSION}+dfsg*" \
        "postgresql-${PG_MAJOR}-postgis-${POSTGIS_MAJOR}-scripts=${POSTGIS_VERSION}+dfsg*" \
    && git clone --branch "v${PGVECTOR_VERSION}" --depth 1 https://github.com/pgvector/pgvector.git /usr/src/pgvector \
    && cd /usr/src/pgvector \
    && make \
    && make install \
    && apt-get purge -y --auto-remove \
        build-essential \
        git \
        make \
        gcc \
        "postgresql-server-dev-${PG_MAJOR}" \
        wget \
        lsb-release \
        gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /usr/src/pgvector \
        /etc/apt/sources.list.d/pgdg.list \
        /usr/share/keyrings/postgresql-archive-keyring.gpg

# Copy initialization scripts
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD pg_isready -U postgres

EXPOSE 5432
