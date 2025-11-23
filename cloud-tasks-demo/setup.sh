#!/bin/bash

# Cloud Tasks Demo - Setup Script
# This script creates a Cloud Function worker and a Cloud Tasks queue

set -e

# Track created resources for cleanup
CREATED_FUNCTION=""
CREATED_QUEUE=""

# Cleanup function
cleanup_on_error() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo ""
    echo "=================================="
    echo "Setup interrupted or failed!"
    echo "Cleaning up partially created resources..."
    echo "=================================="
    
    # Remove task queue if created
    if [ ! -z "$CREATED_QUEUE" ]; then
      echo "Removing Cloud Tasks queue: $CREATED_QUEUE"
      gcloud tasks queues delete $CREATED_QUEUE \
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
    
    echo ""
    echo "Cleanup complete. You can re-run setup.sh to try again."
  fi
}

# Set up trap to catch errors and interrupts
trap cleanup_on_error EXIT INT TERM

echo "=================================="
echo "Cloud Tasks Demo - Setup"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
FUNCTION_NAME="tasks-demo-worker"
QUEUE_NAME="tasks-demo-queue"

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Enable required APIs
echo "1. Enabling required APIs..."
gcloud services enable \
  cloudtasks.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  --quiet

echo "✓ APIs enabled"
echo ""

# Deploy Cloud Function worker
echo "2. Deploying Cloud Function worker..."
gcloud functions deploy ${FUNCTION_NAME} \
  --gen2 \
  --runtime=nodejs20 \
  --region=${REGION} \
  --source=./worker \
  --entry-point=taskHandler \
  --trigger-http \
  --allow-unauthenticated \
  --timeout=60s \
  --quiet

CREATED_FUNCTION="${FUNCTION_NAME}"
echo "✓ Worker function deployed"
echo ""

# Get the function URL
FUNCTION_URL=$(gcloud functions describe ${FUNCTION_NAME} \
  --gen2 \
  --region=${REGION} \
  --format='value(serviceConfig.uri)')

echo "Worker URL: $FUNCTION_URL"
echo ""

# Create Cloud Tasks queue with rate limiting and retry configuration
echo "3. Creating Cloud Tasks queue..."
if gcloud tasks queues describe ${QUEUE_NAME} --location=${REGION} --quiet 2>/dev/null; then
  echo "Queue already exists, deleting and recreating..."
  gcloud tasks queues delete ${QUEUE_NAME} --location=${REGION} --quiet
fi

gcloud tasks queues create ${QUEUE_NAME} \
  --location=${REGION} \
  --max-dispatches-per-second=5 \
  --max-concurrent-dispatches=10 \
  --max-attempts=5 \
  --min-backoff=5s \
  --max-backoff=3600s \
  --max-retry-duration=86400s \
  --quiet

CREATED_QUEUE="${QUEUE_NAME}"
echo "✓ Cloud Tasks queue created"
echo ""

# Store configuration for other scripts
cat > config.env << EOF
export PROJECT_ID="${PROJECT_ID}"
export REGION="${REGION}"
export FUNCTION_URL="${FUNCTION_URL}"
export QUEUE_NAME="${QUEUE_NAME}"
EOF

# Disable trap on successful completion
trap - EXIT INT TERM

echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Resources created:"
echo "- Worker Function: ${FUNCTION_NAME}"
echo "- Task Queue: ${QUEUE_NAME}"
echo ""
echo "Queue Configuration:"
gcloud tasks queues describe ${QUEUE_NAME} --location=${REGION}
echo ""
echo "Next steps:"
echo "1. Run './trigger.sh' to create a sample task"
echo "2. Run './create-tasks.sh 10' to create 10 tasks"
echo "3. View logs: gcloud functions logs read ${FUNCTION_NAME} --region=${REGION} --limit=20"
echo ""
