#!/bin/bash

# Cloud Run Binary Authorization Demo - Test Unsigned Deployment
# This script attempts to deploy an unsigned image to demonstrate that Binary Authorization blocks it

set -e

echo "=================================="
echo "Test: Deploy Unsigned Image"
echo "=================================="
echo ""

# Load configuration
if [ ! -f config.env ]; then
  echo "Error: config.env not found. Please run ./setup.sh first."
  exit 1
fi

source config.env

SERVICE_NAME="binauthz-app-unsigned"
UNSIGNED_IMAGE_URL="${IMAGE_URL}:unsigned"

echo "This test demonstrates Binary Authorization's security by attempting"
echo "to deploy an unsigned container image to Cloud Run."
echo ""
echo "Expected result: Deployment should be BLOCKED"
echo ""

# Authenticate to Artifact Registry
echo "1. Authenticating to Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
echo "✓ Authenticated"
echo ""

# Build and push container image WITHOUT signing
echo "2. Building unsigned container image..."
echo "   This may take a few minutes..."
gcloud builds submit ./app \
  --tag=${UNSIGNED_IMAGE_URL} \
  --quiet

echo "✓ Unsigned image built and pushed"
echo ""

# Get the image digest
echo "3. Getting image digest..."
IMAGE_DIGEST=$(gcloud artifacts docker images describe ${UNSIGNED_IMAGE_URL} \
  --format='value(image_summary.digest)')

UNSIGNED_IMAGE_WITH_DIGEST="${IMAGE_URL}@${IMAGE_DIGEST}"

echo "Image: ${UNSIGNED_IMAGE_WITH_DIGEST}"
echo ""

# Attempt to deploy WITHOUT creating attestation
echo "4. Attempting to deploy unsigned image to Cloud Run..."
echo "   Binary Authorization should BLOCK this deployment..."
echo ""

set +e  # Don't exit on error for this command

gcloud run deploy ${SERVICE_NAME} \
  --image="${UNSIGNED_IMAGE_WITH_DIGEST}" \
  --platform=managed \
  --region=${REGION} \
  --allow-unauthenticated \
  --binary-authorization=default \
  --quiet

DEPLOY_EXIT_CODE=$?

set -e

echo ""
echo "=================================="
if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
  echo "❌ UNEXPECTED: Deployment succeeded!"
  echo "=================================="
  echo ""
  echo "The unsigned image was deployed, which should not have happened."
  echo "Binary Authorization may not be configured correctly."
  echo ""
  # Clean up the service
  gcloud run services delete ${SERVICE_NAME} \
    --region=${REGION} \
    --quiet 2>/dev/null || true
  exit 1
else
  echo "✅ SUCCESS: Deployment was BLOCKED!"
  echo "=================================="
  echo ""
  echo "Binary Authorization successfully prevented the deployment of an unsigned image."
  echo ""
  echo "This demonstrates that:"
  echo "  • Only images with valid attestations can be deployed"
  echo "  • Unsigned or untrusted images are automatically blocked"
  echo "  • Your Cloud Run services are protected from unauthorized deployments"
  echo ""
  echo "To deploy this image, you would need to:"
  echo "  1. Create an attestation using sign-and-deploy.sh"
  echo "  2. Or add it to the policy's allowlist"
  echo ""
fi
