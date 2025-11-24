#!/bin/bash
set -e

REGION="${GCP_REGION:-us-central1}"

echo "Cleaning up Cloud Run services..."

for SERVICE in env-demo-cli env-demo-yaml; do
    echo "Deleting $SERVICE..."
    gcloud run services delete "$SERVICE" --region "$REGION" --quiet || echo "$SERVICE not found or already deleted"
done

echo "Cleanup complete."