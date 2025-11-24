#!/bin/bash
set -e

# Configuration
SERVICE_NAME="env-demo-cli"
REGION="${GCP_REGION:-us-central1}"

echo "Deploying service using CLI flags (--set-env-vars)..."
echo "This method requires listing every variable in the command line."
echo ""

cd app

gcloud run deploy "$SERVICE_NAME" \
    --source . \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-env-vars "APP_ENV=development" \
    --set-env-vars "DB_HOST=localhost" \
    --set-env-vars "DB_PORT=5432" \
    --set-env-vars "API_KEY=secret-key-from-cli" \
    --set-env-vars "FEATURE_FLAG_X=false" \
    --set-env-vars "MAINTENANCE_MODE=false" \
    --set-env-vars "DEPLOYMENT_METHOD=cli-flags" \
    --quiet

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format 'value(status.url)')

echo ""
echo "Service deployed at: $SERVICE_URL"
echo "Check the environment variables:"
echo "curl $SERVICE_URL"