FROM debian:stable AS build
ARG PG_VERSION=18beta1

RUN set -ex; \
    apt-get update; \
    apt-get install -y curl tar git build-essential pkg-config flex bison libreadline-dev zlib1g-dev libicu-dev

WORKDIR /build

RUN git clone --depth 1 https://github.com/docker-library/postgres.git scripts

RUN set -ex; \
    curl -LO "https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2{,.sha256}"; \
    tar xf postgresql-${PG_VERSION}.tar.bz2; \
    sha256sum -c postgresql-${PG_VERSION}.tar.bz2.sha256

WORKDIR /build/postgresql-${PG_VERSION}

ENV PG_MAJOR=18
RUN set -ex; \
    ./configure --prefix=/usr/lib/postgresql/$PG_MAJOR; \
    make -j $(( $( (echo 2;grep -c ^processor /proc/cpuinfo||:;)|sort -n|tail -1) - 1 )); \
    make install DESTDIR=/build/postgres

FROM debian:stable-slim AS final

ENV PG_MAJOR=18
COPY --from=build /build/postgres /
ENV PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin

# Install lib dependencies
RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends libreadline8 zlib1g libicu72; \
    rm -rf /var/lib/apt/lists/*

# Most of the below is ripped from https://github.com/docker-library/postgres/blob/master/Dockerfile-debian.template

# explicitly set user/group IDs
RUN set -eux; \
    groupadd -r postgres --gid=999; \
    useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    install --verbose --directory --owner postgres --group postgres --mode 1777 /var/lib/postgresql

# (if "less" is available, it gets used as the default pager for psql, and it only adds ~1.5MiB to our image size)
RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends less; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    apt-get update; \
    apt-get install -y gosu; \
    rm -rf /var/lib/apt/lists/*; \
    gosu nobody true

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN set -eux; \
    if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
# if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
        grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
        sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
        ! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
    fi; \
    apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen; \
    locale-gen; \
    locale -a | grep 'en_US.utf8'
ENV LANG=en_US.utf8

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libnss-wrapper \
        xz-utils \
        zstd \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /docker-entrypoint-initdb.d

ENV PGDATA=/var/lib/postgresql/data
# this 1777 will be replaced by 0700 at runtime (allows semi-arbitrary "--user" values)
RUN install --verbose --directory --owner postgres --group postgres --mode 1777 "$PGDATA"
VOLUME /var/lib/postgresql/data

RUN sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /usr/lib/postgresql/$PG_MAJOR/share/postgresql.conf.sample

COPY --from=build /build/scripts/docker-entrypoint.sh /build/scripts/docker-ensure-initdb.sh /usr/local/bin/
RUN ln -sT docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh
ENTRYPOINT ["docker-entrypoint.sh"]

STOPSIGNAL SIGINT
EXPOSE 5432
CMD ["postgres"]