#!/bin/bash

# Cloud Scheduler Demo - Setup Script
# This script creates a Cloud Function and schedules it to run every 5 minutes

set -e

# Track created resources for cleanup
CREATED_SERVICE_ACCOUNT=""
CREATED_FUNCTION=""
CREATED_JOB=""

# Cleanup function
cleanup_on_error() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo ""
    echo "=================================="
    echo "Setup interrupted or failed!"
    echo "Cleaning up partially created resources..."
    echo "=================================="
    
    # Remove scheduler job if created
    if [ ! -z "$CREATED_JOB" ]; then
      echo "Removing Cloud Scheduler job: $CREATED_JOB"
      gcloud scheduler jobs delete $CREATED_JOB \
        --location=$REGION \
        --quiet 2>/dev/null || true
    fi
    
    # Remove Cloud Function if created
    if [ ! -z "$CREATED_FUNCTION" ]; then
      echo "Removing Cloud Function: $CREATED_FUNCTION"
      gcloud functions delete $CREATED_FUNCTION \
        --gen2 \
        --region=$REGION \
        --quiet 2>/dev/null || true
    fi
    
    # Remove service account if created
    if [ ! -z "$CREATED_SERVICE_ACCOUNT" ]; then
      echo "Removing service account: $CREATED_SERVICE_ACCOUNT"
      gcloud iam service-accounts delete $CREATED_SERVICE_ACCOUNT \
        --quiet 2>/dev/null || true
    fi
    
    echo ""
    echo "Cleanup complete. You can re-run setup.sh to try again."
  fi
}

# Set up trap to catch errors and interrupts
trap cleanup_on_error EXIT INT TERM

echo "=================================="
echo "Cloud Scheduler Demo - Setup"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
FUNCTION_NAME="scheduler-demo-function"
JOB_NAME="scheduler-demo-job"
SERVICE_ACCOUNT_NAME="scheduler-invoker"

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Enable required APIs
echo "1. Enabling required APIs..."
gcloud services enable \
  cloudscheduler.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  --quiet

echo "✓ APIs enabled"
echo ""

# Create service account for Cloud Scheduler
echo "2. Creating service account for Cloud Scheduler..."
if gcloud iam service-accounts describe ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --quiet 2>/dev/null; then
  echo "Service account already exists, skipping creation"
else
  gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
    --display-name="Cloud Scheduler Invoker" \
    --quiet
  CREATED_SERVICE_ACCOUNT="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  echo "✓ Service account created"
fi
echo ""

# Deploy Cloud Function
echo "3. Deploying Cloud Function..."
gcloud functions deploy ${FUNCTION_NAME} \
  --gen2 \
  --runtime=nodejs20 \
  --region=${REGION} \
  --source=./function \
  --entry-point=schedulerHandler \
  --trigger-http \
  --allow-unauthenticated \
  --quiet

CREATED_FUNCTION="${FUNCTION_NAME}"
echo "✓ Cloud Function deployed"
echo ""

# Get the function URL
FUNCTION_URL=$(gcloud functions describe ${FUNCTION_NAME} \
  --gen2 \
  --region=${REGION} \
  --format='value(serviceConfig.uri)')

echo "Function URL: $FUNCTION_URL"
echo ""

# Grant the service account permission to invoke the function
echo "4. Setting up IAM permissions..."
gcloud functions add-invoker-policy-binding ${FUNCTION_NAME} \
  --gen2 \
  --region=${REGION} \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --quiet

echo "✓ IAM permissions configured"
echo ""

# Create Cloud Scheduler job
echo "5. Creating Cloud Scheduler job..."
if gcloud scheduler jobs describe ${JOB_NAME} --location=${REGION} --quiet 2>/dev/null; then
  echo "Scheduler job already exists, deleting and recreating..."
  gcloud scheduler jobs delete ${JOB_NAME} --location=${REGION} --quiet
fi

gcloud scheduler jobs create http ${JOB_NAME} \
  --location=${REGION} \
  --schedule="*/5 * * * *" \
  --uri="${FUNCTION_URL}" \
  --http-method=POST \
  --oidc-service-account-email="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --oidc-token-audience="${FUNCTION_URL}" \
  --max-retry-attempts=3 \
  --max-backoff=3600s \
  --min-backoff=5s \
  --quiet

CREATED_JOB="${JOB_NAME}"
echo "✓ Cloud Scheduler job created"
echo ""

# Disable trap on successful completion
trap - EXIT INT TERM

echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "The scheduler job will run every 5 minutes."
echo ""
echo "Next steps:"
echo "1. Wait 5 minutes for the first execution, or"
echo "2. Run './trigger.sh' to manually trigger the job"
echo "3. View logs: gcloud functions logs read ${FUNCTION_NAME} --region=${REGION} --limit=10"
echo ""
echo "Job details:"
gcloud scheduler jobs describe ${JOB_NAME} --location=${REGION}
