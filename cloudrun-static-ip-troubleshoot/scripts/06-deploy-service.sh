#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Deploy Cloud Run Service
# =============================================================================

set -e  # Exit on error

# Function to show and run commands
run() {
  echo "+ $*"
  "$@"
}

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/01-setup-environment.sh"

echo "Deploying Cloud Run service: $SERVICE_NAME"

# Get the full connector path
CONNECTOR_PATH="projects/$PROJECT_ID/locations/$REGION/connectors/$CONNECTOR_NAME"

# Deploy Cloud Run service with VPC connector and all-traffic egress
# CRITICAL: The --vpc-egress=all-traffic flag is essential!
run gcloud run deploy $SERVICE_NAME \
  --image=$CONTAINER_IMAGE \
  --region=$REGION \
  --platform=managed \
  --vpc-connector=$CONNECTOR_PATH \
  --vpc-egress=all-traffic \
  --allow-unauthenticated \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION"

echo ""
echo "=== Cloud Run Service Details ==="
run gcloud run services describe $SERVICE_NAME --region=$REGION

echo ""
echo "=== VPC Configuration ==="
run gcloud run services describe $SERVICE_NAME --region=$REGION \
  --format="yaml(spec.template.spec.vpcAccess)"

echo ""
echo "Cloud Run service deployed successfully."

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION \
  --format="value(status.url)")

echo ""
echo "Service URL: $SERVICE_URL"

# Try to grant public access (may fail due to org policies)
echo ""
echo "Attempting to grant public access..."
if gcloud run services add-iam-policy-binding $SERVICE_NAME \
  --region=$REGION \
  --member="allUsers" \
  --role="roles/run.invoker" 2>/dev/null; then
  echo "Public access granted."
  echo ""
  echo "=============================================="
  echo "Test the service (public access):"
  echo "  curl $SERVICE_URL"
  echo "=============================================="
else
  echo ""
  echo "=============================================="
  echo "NOTE: Public access not available"
  echo "(Your organization may restrict this)"
  echo "=============================================="
  echo ""
  echo "Use AUTHENTICATED access instead:"
  echo ""
  echo "  curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" \\"
  echo "    $SERVICE_URL"
  echo ""
  echo "Or in a single command:"
  echo ""
  echo "  curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" $SERVICE_URL"
  echo ""
  echo "=============================================="
fi