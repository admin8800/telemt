FROM ghcr.io/telemt/telemt:latest AS telemt

FROM debian:12-slim

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl jq; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=telemt /app/telemt /app/telemt
COPY config.toml.template /etc/telemt/config.toml.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /app/telemt /entrypoint.sh

EXPOSE 443 9091

ENTRYPOINT ["/entrypoint.sh"]