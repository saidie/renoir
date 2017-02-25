FROM debian:jessie

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates gcc libc6-dev make ruby && \
    mkdir /redis && \
    curl -L https://github.com/antirez/redis/archive/unstable.tar.gz | tar xfz - -C /redis && \
    mv /redis/*/* /redis/ && \
    grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' /redis/src/server.h && \
    sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' /redis/src/server.h && \
    grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' /redis/src/server.h && \
    make -C /redis && \
    gem install redis && \
    apt-get purge -y --auto-remove curl gcc libc6-dev make

COPY docker-entrypoint.sh /redis/docker-entrypoint.sh

ENTRYPOINT /redis/docker-entrypoint.sh
