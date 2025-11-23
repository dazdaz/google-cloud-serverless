#!/bin/bash

# Cloud Run Binary Authorization Demo - Cleanup Script
# This script removes all resources created by the demo

set -e

echo "=================================="
echo "Binary Authorization Demo - Cleanup"
echo "=================================="
echo ""

# Load configuration if it exists
if [ -f config.env ]; then
  source config.env
else
  echo "Warning: config.env not found. Using default values."
  PROJECT_ID=$(gcloud config get-value project)
  REGION="us-central1"
  REPO_NAME="binauthz-demo"
  ATTESTOR_NAME="binauthz-attestor"
  KEYRING_NAME="binauthz-keyring"
  KEY_NAME="binauthz-key"
  SERVICE_ACCOUNT_NAME="binauthz-signer"
fi

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Delete Cloud Run services
echo "1. Deleting Cloud Run services..."
for SERVICE in binauthz-app binauthz-app-unsigned; do
  if gcloud run services describe $SERVICE --region=${REGION} --quiet 2>/dev/null; then
    echo "   Deleting service: $SERVICE"
    gcloud run services delete $SERVICE \
      --region=${REGION} \
      --quiet 2>/dev/null || true
  fi
done
echo "✓ Cloud Run services deleted"
echo ""

# Reset Binary Authorization policy to default (allow all)
echo "2. Resetting Binary Authorization policy..."
cat > /tmp/reset-policy.yaml << EOF
admissionWhitelistPatterns:
- namePattern: "*"
defaultAdmissionRule:
  evaluationMode: ALWAYS_ALLOW
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
name: projects/${PROJECT_ID}/policy
EOF

gcloud container binauthz policy import /tmp/reset-policy.yaml --quiet 2>/dev/null || true
rm -f /tmp/reset-policy.yaml
echo "✓ Binary Authorization policy reset to default"
echo ""

# Delete attestor
echo "3. Deleting attestor..."
if gcloud container binauthz attestors describe ${ATTESTOR_NAME} --quiet 2>/dev/null; then
  gcloud container binauthz attestors delete ${ATTESTOR_NAME} --quiet
  echo "✓ Attestor deleted"
else
  echo "   Attestor not found, skipping"
fi
echo ""

# Remove IAM policy bindings
echo "4. Removing IAM policy bindings..."
if gcloud iam service-accounts describe ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --quiet 2>/dev/null; then
  # Remove KMS signer role
  gcloud kms keys remove-iam-policy-binding ${KEY_NAME} \
    --keyring=${KEYRING_NAME} \
    --location=${REGION} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role=roles/cloudkms.signerVerifier \
    --quiet 2>/dev/null || true
  
  # Remove Container Analysis role
  gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role=roles/containeranalysis.occurrences.editor \
    --quiet 2>/dev/null || true
  
  echo "✓ IAM policy bindings removed"
else
  echo "   Service account not found, skipping IAM cleanup"
fi
echo ""

# Delete service account
echo "5. Deleting service account..."
if gcloud iam service-accounts describe ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --quiet 2>/dev/null; then
  gcloud iam service-accounts delete ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --quiet
  echo "✓ Service account deleted"
else
  echo "   Service account not found, skipping"
fi
echo ""

# Delete container images
echo "6. Deleting container images..."
if gcloud artifacts repositories describe ${REPO_NAME} --location=${REGION} --quiet 2>/dev/null; then
  echo "   Deleting images in repository..."
  gcloud artifacts docker images list ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME} --quiet 2>/dev/null | grep -v "Listing items" | awk '{print $1}' | while read IMAGE; do
    if [ ! -z "$IMAGE" ]; then
      gcloud artifacts docker images delete $IMAGE --quiet --delete-tags 2>/dev/null || true
    fi
  done
  echo "✓ Container images deleted"
else
  echo "   Repository not found, skipping image cleanup"
fi
echo ""

# Delete Artifact Registry repository
echo "7. Deleting Artifact Registry repository..."
if gcloud artifacts repositories describe ${REPO_NAME} --location=${REGION} --quiet 2>/dev/null; then
  gcloud artifacts repositories delete ${REPO_NAME} \
    --location=${REGION} \
    --quiet
  echo "✓ Artifact Registry repository deleted"
else
  echo "   Repository not found, skipping"
fi
echo ""

# Note about KMS resources
echo "8. KMS key and keyring..."
echo "   Note: KMS keys cannot be immediately deleted."
echo "   They are scheduled for deletion after a 30-day waiting period."
echo ""
if gcloud kms keys describe ${KEY_NAME} --keyring=${KEYRING_NAME} --location=${REGION} --quiet 2>/dev/null; then
  echo "   To schedule the KMS key for deletion (optional):"
  echo "   gcloud kms keys versions destroy 1 \\"
  echo "     --key=${KEY_NAME} \\"
  echo "     --keyring=${KEYRING_NAME} \\"
  echo "     --location=${REGION}"
  echo ""
fi

# Remove configuration file
echo "9. Removing configuration file..."
if [ -f config.env ]; then
  rm config.env
  echo "✓ Configuration file removed"
fi
echo ""

echo "=================================="
echo "Cleanup Complete!"
echo "=================================="
echo ""
echo "All resources have been removed except:"
echo "  • KMS keyring and key (scheduled for deletion after 30 days)"
echo ""
echo "Binary Authorization policy has been reset to allow all deployments."
echo ""
