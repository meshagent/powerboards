### Powerboards

Built on Meshagent

### Sample dockerfile

```
FROM ghcr.io/cirruslabs/flutter:3.38.4 AS flutter
RUN apt update && apt install -y git unzip curl

COPY . /powerboards

WORKDIR /powerboards

RUN sed -i '/^resolution: workspace$/d' pubspec.yaml

RUN flutter build web \
  --no-tree-shake-icons \
  --pwa-strategy none \
  --base-href="/" \
  --dart-define=SERVER_URL=https://api.meshagent.com \
  --dart-define=APP_URL=https://app.powerboards.com \
  --dart-define=BILLING_URL=https://accounts.meshagent.com \
  --dart-define=OAUTH_CALLBACK_URL=https://app.powerboards.com/mauth/callback \
  --dart-define=OAUTH_CLIENT_ID=RJQBqvFp7dEUrRs15Xx_pUl5K3Smtu24 \
  --dart-define=OAUTH_MOBILE_CALLBACK_URL=powerboards:/mauth/callback \
  --dart-define=OAUTH_MOBILE_CLIENT_ID=tQ_59LpzrKP7JswrcCCYwnEgvNydSqRI \
  --dart-define=SENTRY_ENABLED=false \
  --dart-define=MESHAGENT_DOMAIN=meshagent.com \
  --dart-define=DOMAINS=meshagent.app \
  --dart-define=MESHAGENT_MAIL_DOMAIN=mail.meshagent.com \
  --dart-define=IMAGE_TAG_PREFIX=us-central1-docker.pkg.dev/meshagent-public/images/


# --- Build Server ---
FROM dart:stable AS builder
WORKDIR /workspace
COPY ./powerboards/server server
WORKDIR /workspace/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o server

# --- Final Stage ---
FROM debian:bookworm-slim AS final
ARG AASA_FILE=
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /workspace/server/server server
COPY --from=flutter /powerboards/build/web public

EXPOSE 80
ENTRYPOINT ["./server"]
```
