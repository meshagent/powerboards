## Powerboards

Built on Meshagent

## Getting Started
How to build powerboards and deploy to cloud run.

### Setup
- Clone the powerboards repository at https://github.com/meshagent/powerboards
- Setup an OAUTH ID in meshagent.
  - Login to https://studio.meshagent.com
  - Create a project or go to an existing project.
  - Select the OAuth Clients tab.
  - Create a new OAuth Client for your instance of powerboards.
    When creating the oauth client for the powerboards web app, set the redirect url to `https://[my-domain]/mauth/callback`.

    When creating the oauth client for the powerboards mobile app, set the redirect url to `powerboards:/mauth/callback`
    
    You will need to use the OAuth client ids when building powerboards. The Client ids will be passed as `--dart-define` options to the `flutter build` command

   - Ensure you have a GCP project, the [gcloud tools](https://docs.cloud.google.com/sdk/docs/install-sdk) installed and you are authenticated.


### Building and Deploying to a GCS Bucket

- Create a storage bucket in GCS to copy the powerboards web site into.

```  
# Create the bucket
gcloud storage buckets create gs://www.my-powerboards.com --location=US --uniform-bucket-level-access

# Make the bucket public readable
gcloud storage buckets add-iam-policy-binding gs://www.my-powerboards.com --member="allUsers" --role="roles/storage.objectViewer"

# Set the website default pages
gcloud storage buckets update gs://www.my-powerboards.com --web-main-page-suffix=index.html --web-error-page=index.html
```

- [Build the powerboards web app](#building-the-web-app-locally).

- Copy the website to the storage bucket
```
gcloud storage cp -r ./build/web/* gs://www.my-powerboards.com
```

- Create a google load balancer and use the storage bucket for the backend configuration
- Update your DNS with the ip address of the load balancer.

### Building and Deploying to Cloud Run

You can use the [Sample Dockerfile](#sample-dockerfile) to build a docker image that will run powerboards.


```
# Replace these values with your configuration
POWERBOARDS_DOMAIN=www.my-powerboards.com
CLOUD_REGION=us-central1
PROJECT_LOCATION=us-central1-docker.pkg.dev
CLOUD_PROJECT_NAME=my-gcp-project-name
ARTIFACT_REPO_NAME=powerboards
IMAGE_TAG=$PROJECT_LOCATION/$CLOUD_PROJECT_NAME/$ARTIFACT_REPO_NAME/powerboards-ui:v1
CLOUD_RUN_SERVICE_NAME=powerboards-ui

# Authenticate Docker
gcloud auth configure-docker $PROJECT_LOCATION

# Build
docker build --file sample.dockerfile -t $IMAGE_TAG .

# Push to the artifact registry

docker push $IMAGE_TAG

# Deploying to Cloud Run

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

### Setup a domain mapping.
By setting up a domain mapping, you can redirect all traffic to the cloud run service.
You will need to create the mapping and then setup DNS records.
A domain mapping only needs to be created once.

```
gcloud beta run domain-mappings create --service CLOUD_RUN_SERVICE_NAME --domain$ $POWERBOARDS_DOMAIN --region $CLOUD_REGION

# Get the DNS resource records
gcloud beta run domain-mappings describe --domain $POWERBOARDS_DOMAIN --region $CLOUD_REGION --project $CLOUD_PROJECT_NAME
```

### Update DNS
In the output of the `gcloud beta run domain-mappings describe` command above, look for the section `resourceRecords`. Take these values and use them for the DNS records.

## Building the web app locally
Before building, replace the --dart-define values for APP_URL, OAUTH_CALLBACK_URL, OAUTH_CLIENT_ID and OAUTH_MOBILE_CLIENT_ID
 
```
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
## Sample dockerfile

Before building, replace the --dart-define values for APP_URL, OAUTH_CALLBACK_URL, OAUTH_CLIENT_ID and OAUTH_MOBILE_CLIENT_ID

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
