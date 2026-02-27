## Powerboards

Powerboards is a Flutter web app built on Meshagent.

This guide covers:
- Meshagent OAuth setup
- Building the app locally
- Deploying static hosting on Google Cloud Storage + Load Balancer
- Deploying with Cloud Run

## Prerequisites

- Flutter installed and working
- A Meshagent account with access to [https://studio.meshagent.com](https://studio.meshagent.com)
- A Google Cloud project
- `gcloud` CLI installed and authenticated ([install docs](https://docs.cloud.google.com/sdk/docs/install-sdk))
- Docker installed (for Cloud Run image builds)

## 1) Configure Meshagent OAuth

1. Log in to [https://studio.meshagent.com](https://studio.meshagent.com).
2. Open (or create) your project.
3. Go to **OAuth Clients**.
4. Create web and mobile OAuth clients:
   - **Web redirect URL:** `https://<your-domain>/mauth/callback`
   - **Mobile redirect URL:** `powerboards:/mauth/callback`

Save both client IDs. You will pass them to `flutter build` through `--dart-define`.

## 2) Build the web app locally

`powerboards/pubspec.yaml` is currently configured for a pub workspace (`resolution: workspace`).

Choose one of the following:
- Put `powerboards` inside your pub workspace.
- Remove `resolution: workspace` from `pubspec.yaml`.
- Create `pubspec_overrides.yaml` with:

```yaml
resolution:
```

Then build:

```bash
flutter build web \
  --no-tree-shake-icons \
  --pwa-strategy none \
  --base-href="/" \
  --dart-define=SERVER_URL=https://api.meshagent.com \
  --dart-define=APP_URL=https://$POWERBOARDS_DOMAIN \
  --dart-define=BILLING_URL=https://accounts.meshagent.com \
  --dart-define=OAUTH_CALLBACK_URL=https://$POWERBOARDS_DOMAIN/mauth/callback \
  --dart-define=OAUTH_CLIENT_ID=$WEB_OAUTH_CLIENT_ID_FROM_MESHAGENT \
  --dart-define=OAUTH_MOBILE_CALLBACK_URL=powerboards:/mauth/callback \
  --dart-define=OAUTH_MOBILE_CLIENT_ID=$MOBILE_OAUTH_CLIENT_ID_FROM_MESHAGENT \
  --dart-define=SENTRY_ENABLED=false \
  --dart-define=MESHAGENT_DOMAIN=meshagent.com \
  --dart-define=DOMAINS=meshagent.app \
  --dart-define=MESHAGENT_MAIL_DOMAIN=mail.meshagent.com \
  --dart-define=IMAGE_TAG_PREFIX=us-central1-docker.pkg.dev/meshagent-public/images/
```

## 3) Deploy static files to GCS + HTTPS Load Balancer

### 3.1 Create and configure the bucket

```bash
gcloud storage buckets create gs://www.my-powerboards.com --location=US --uniform-bucket-level-access

gcloud storage buckets add-iam-policy-binding gs://www.my-powerboards.com \
  --member="allUsers" \
  --role="roles/storage.objectViewer"

gcloud storage buckets update gs://www.my-powerboards.com \
  --web-main-page-suffix=index.html \
  --web-error-page=index.html
```

### 3.2 Upload the built site

```bash
gcloud storage cp -r ./build/web/* gs://www.my-powerboards.com
```

### 3.3 Create global HTTPS load balancer

```bash

# Replace these values with your configuration
PROJECT_ID="my-powerboards"
DOMAIN="www.my-powerboards.com"
LB_NAME="mypowerboards-lb"
BUCKET="www.my-powerboards.com"

# Create an ipaddress for DNS and the load balancer.
gcloud compute addresses create "${LB_NAME}-ip" --global
IP_ADDR="$(gcloud compute addresses describe "${LB_NAME}-ip" --global --format='get(address)')"
echo "Load balancer IP: ${IP_ADDR}"

# Important. Manually configure your DNS A record for ${DOMAIN} to ${IP_ADDR}

# Create the load balancer backend for the bucket
gcloud compute backend-buckets create "${LB_NAME}-backend" --gcs-bucket-name="${BUCKET}"
gcloud compute url-maps create "${LB_NAME}-https-map" --default-backend-bucket="${LB_NAME}-backend"

# Create the load balancer ssl certificate for the domain
gcloud compute ssl-certificates create "${LB_NAME}-cert" --domains="${DOMAIN}" --global

# Create the load balancer front end and http -> https redirect.
gcloud compute target-https-proxies create "${LB_NAME}-https-proxy" \
  --ssl-certificates="${LB_NAME}-cert" \
  --url-map="${LB_NAME}-https-map"

gcloud compute forwarding-rules create "${LB_NAME}-https-fr" \
  --global \
  --address="${LB_NAME}-ip" \
  --target-https-proxy="${LB_NAME}-https-proxy" \
  --ports=443

cat <<EOF > temp-http-redirect-map.yaml
name: ${LB_NAME}-http-redirect-map
defaultUrlRedirect:
  httpsRedirect: true
  redirectResponseCode: MOVED_PERMANENTLY_DEFAULT
  stripQuery: false
EOF

gcloud compute url-maps import "${LB_NAME}-http-redirect-map" \
  --global \
  --source temp-http-redirect-map.yaml

gcloud compute target-http-proxies create "${LB_NAME}-http-proxy" \
  --url-map="${LB_NAME}-http-redirect-map"

gcloud compute forwarding-rules create "${LB_NAME}-http-fr" \
  --global \
  --address="${LB_NAME}-ip" \
  --target-http-proxy="${LB_NAME}-http-proxy" \
  --ports=80
```

## 4) Deploy using Cloud Run

You can use the [Sample Dockerfile](#sample-dockerfile) to build a docker image that will run powerboards.
Copy and save the contents to sample.dockerfile

```bash

# Replace these values with your configuration
POWERBOARDS_DOMAIN=www.my-powerboards.com
CLOUD_REGION=us-central1
PROJECT_LOCATION=us-central1-docker.pkg.dev
CLOUD_PROJECT_NAME=my-gcp-project-name
ARTIFACT_REPO_NAME=powerboards
IMAGE_TAG=$PROJECT_LOCATION/$CLOUD_PROJECT_NAME/$ARTIFACT_REPO_NAME/powerboards-ui:v1
CLOUD_RUN_SERVICE_NAME=powerboards-ui

# Authenticate docker, build and push
gcloud auth configure-docker $PROJECT_LOCATION
docker build --file sample.dockerfile -t $IMAGE_TAG .
docker push $IMAGE_TAG

# Deploy to cloud run
gcloud run deploy $CLOUD_RUN_SERVICE_NAME \
  --image $IMAGE_TAG \
  --platform managed \
  --port 80 \
  --cpu 1 \
  --memory 2Gi \
  --project=$CLOUD_PROJECT_NAME \
  --region=$CLOUD_REGION \
  --allow-unauthenticated \
  --concurrency=1000 \
  --timeout=300s
```

### Optional: map a custom domain to Cloud Run

```bash
gcloud beta run domain-mappings create \
  --service $CLOUD_RUN_SERVICE_NAME \
  --domain $POWERBOARDS_DOMAIN \
  --region $CLOUD_REGION

gcloud beta run domain-mappings describe \
  --domain $POWERBOARDS_DOMAIN \
  --region $CLOUD_REGION \
  --project $CLOUD_PROJECT_NAME
```

Important. Use `resourceRecords` from the `describe` output to create DNS records.

## Sample Dockerfile

Before building, replace the `--dart-define` values for:
- `APP_URL`
- `OAUTH_CALLBACK_URL`
- `OAUTH_CLIENT_ID`
- `OAUTH_MOBILE_CLIENT_ID`

```dockerfile
FROM ghcr.io/cirruslabs/flutter:3.38.4 AS flutter
RUN apt update && apt install -y git

COPY . /powerboards
WORKDIR /powerboards

RUN sed -i '/^resolution: workspace$/d' pubspec.yaml

RUN flutter build web \
  --no-tree-shake-icons \
  --pwa-strategy none \
  --base-href="/" \
  --dart-define=SERVER_URL=https://api.meshagent.com \
  --dart-define=APP_URL=https://[my-domain] \
  --dart-define=BILLING_URL=https://accounts.meshagent.com \
  --dart-define=OAUTH_CALLBACK_URL=https://[my-domain]/mauth/callback \
  --dart-define=OAUTH_CLIENT_ID=[my-oauth-id-from-meshagent] \
  --dart-define=OAUTH_MOBILE_CALLBACK_URL=powerboards:/mauth/callback \
  --dart-define=OAUTH_MOBILE_CLIENT_ID=[my-mobile-oauth-id-from-meshagent] \
  --dart-define=SENTRY_ENABLED=false \
  --dart-define=MESHAGENT_DOMAIN=meshagent.com \
  --dart-define=DOMAINS=meshagent.app \
  --dart-define=MESHAGENT_MAIL_DOMAIN=mail.meshagent.com \
  --dart-define=IMAGE_TAG_PREFIX=us-central1-docker.pkg.dev/meshagent-public/images/

FROM dart:stable AS builder
WORKDIR /workspace
COPY ./server server
WORKDIR /workspace/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o server

FROM debian:bookworm-slim AS final
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /workspace/server/server server
COPY --from=flutter /powerboards/build/web public
RUN mkdir -p public/.well-known/

EXPOSE 80
ENTRYPOINT ["./server"]
```
