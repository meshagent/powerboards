FROM ghcr.io/cirruslabs/flutter:3.38.4 AS flutter
RUN apt update && apt install -y git unzip curl

ARG DART_DEFINE_CONFIG=
ARG RELEASE_TYPE=
ARG FLUTTER_SOURCE_MAPS_FLAG=

COPY ./powerboards /powerboards


RUN mkdir -p meshagent-sdk
COPY ./pubspec.yaml /
# Remove the studio from the workspace file
RUN sed -i '/- meshagent-studio/d' pubspec.yaml
COPY ./meshagent-sdk/meshagent-dart /meshagent-sdk/meshagent-dart
COPY ./meshagent-sdk/meshagent-flutter /meshagent-sdk/meshagent-flutter
COPY ./meshagent-sdk/meshagent-flutter-widgets /meshagent-sdk/meshagent-flutter-widgets 
COPY ./meshagent-sdk/meshagent-flutter-auth /meshagent-sdk/meshagent-flutter-auth 
COPY ./meshagent-sdk/meshagent-flutter-shadcn /meshagent-sdk/meshagent-flutter-shadcn
COPY ./meshagent-sdk/meshagent-super-editor /meshagent-sdk/meshagent-super-editor
COPY ./meshagent-sdk/meshagent-flutter-dev /meshagent-sdk/meshagent-flutter-dev
COPY ./meshagent-sdk/meshagent-luau /meshagent-sdk/meshagent-luau
COPY ./meshagent-sdk/meshagent-dart-service /meshagent-sdk/meshagent-dart-service
COPY ./meshagent-sdk/meshagent-git-credentials /meshagent-sdk/meshagent-git-credentials
COPY ./meshagent-sdk/meshagent-accounts /meshagent-sdk/meshagent-accounts

WORKDIR powerboards
RUN flutter build web \
  --no-tree-shake-icons \
  --pwa-strategy none \
  --dart-define-from-file=$DART_DEFINE_CONFIG \
  --base-href="/" $FLUTTER_SOURCE_MAPS_FLAG $RELEASE_TYPE


# FROM golang:1.23.1-alpine AS builder
# WORKDIR /workspace
# COPY ./powerboards/server server
# WORKDIR /workspace/server
# RUN go mod download
# RUN go build -o server

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
COPY --from=flutter /powerboards/ios/$AASA_FILE public/.well-known/apple-app-site-association
COPY --from=flutter /powerboards/android/assetlinks.json public/.well-known/assetlinks.json

EXPOSE 80
ENTRYPOINT ["./server"]

