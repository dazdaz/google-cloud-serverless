#!/bin/bash
set -e

# Configuration
SERVICE_NAME="env-demo-yaml"
REGION="${GCP_REGION:-us-central1}"

echo "Deploying service using YAML file (--env-vars-file)..."
echo "This method is cleaner and easier to manage for many variables."
echo ""

# We need to be in the app directory for source deployment, 
# but reference the yaml file in the parent directory
cd app

gcloud run deploy "$SERVICE_NAME" \
    --source . \
    --region "$REGION" \
    --allow-unauthenticated \
    --env-vars-file ../env-vars.yaml \
    --quiet

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format 'value(status.url)')

echo ""
echo "Service deployed at: $SERVICE_URL"
echo "Check the environment variables:"
echo "curl $SERVICE_URL"