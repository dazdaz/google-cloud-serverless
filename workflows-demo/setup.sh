#!/bin/bash

# Workflows Demo - Setup Script
# This script deploys mock API endpoints and creates the workflow

set -e

# Track created resources for cleanup
CREATED_FUNCTION=""
CREATED_WORKFLOW=""

# Cleanup function
cleanup_on_error() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo ""
    echo "=================================="
    echo "Setup interrupted or failed!"
    echo "Cleaning up partially created resources..."
    echo "=================================="
    
    # Remove workflow if created
    if [ ! -z "$CREATED_WORKFLOW" ]; then
      echo "Removing workflow: $CREATED_WORKFLOW"
      gcloud workflows delete $CREATED_WORKFLOW \
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
echo "Workflows Demo - Setup"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
WORKFLOW_NAME="order-processing-workflow"
FUNCTION_NAME="workflow-mock-api"

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Enable required APIs
echo "1. Enabling required APIs..."
gcloud services enable \
  workflows.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  --quiet

echo "✓ APIs enabled"
echo ""

# Deploy mock API function
echo "2. Deploying mock API endpoints..."
echo "   (This may take a few minutes...)"
gcloud functions deploy ${FUNCTION_NAME} \
  --gen2 \
  --runtime=nodejs20 \
  --region=${REGION} \
  --source=./mock-api \
  --entry-point=workflowMockApi \
  --trigger-http \
  --allow-unauthenticated \
  --timeout=60s \
  --quiet

CREATED_FUNCTION="${FUNCTION_NAME}"
echo "✓ Mock API deployed"
echo ""

# Get the function URL
FUNCTION_URL=$(gcloud functions describe ${FUNCTION_NAME} \
  --gen2 \
  --region=${REGION} \
  --format='value(serviceConfig.uri)')

echo "Mock API URL: $FUNCTION_URL"
echo ""

# Store API endpoints in environment file
cat > api-endpoints.env << EOF
export VALIDATE_URL="${FUNCTION_URL}/validate"
export INVENTORY_URL="${FUNCTION_URL}/inventory"
export SHIPPING_URL="${FUNCTION_URL}/shipping"
export TAX_URL="${FUNCTION_URL}/tax"
export PAYMENT_URL="${FUNCTION_URL}/payment"
export NOTIFICATION_URL="${FUNCTION_URL}/notification"
EOF

echo "API Endpoints configured:"
echo "  - Validate: ${FUNCTION_URL}/validate"
echo "  - Inventory: ${FUNCTION_URL}/inventory"
echo "  - Shipping: ${FUNCTION_URL}/shipping"
echo "  - Tax: ${FUNCTION_URL}/tax"
echo "  - Payment: ${FUNCTION_URL}/payment"
echo "  - Notification: ${FUNCTION_URL}/notification"
echo ""

# Deploy the workflow
echo "3. Deploying workflow..."
gcloud workflows deploy ${WORKFLOW_NAME} \
  --source=workflow.yaml \
  --location=${REGION} \
  --quiet

CREATED_WORKFLOW="${WORKFLOW_NAME}"
echo "✓ Workflow deployed"
echo ""

# Store configuration for other scripts
cat > config.env << EOF
export PROJECT_ID="${PROJECT_ID}"
export REGION="${REGION}"
export WORKFLOW_NAME="${WORKFLOW_NAME}"
export FUNCTION_NAME="${FUNCTION_NAME}"
export FUNCTION_URL="${FUNCTION_URL}"
EOF

# Disable trap on successful completion
trap - EXIT INT TERM

echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Resources created:"
echo "- Mock API Function: ${FUNCTION_NAME}"
echo "- Workflow: ${WORKFLOW_NAME}"
echo ""
echo "Workflow details:"
gcloud workflows describe ${WORKFLOW_NAME} --location=${REGION}
echo ""
echo "Next steps:"
echo "1. Run './trigger.sh' to execute the workflow"
echo "2. View executions: gcloud workflows executions list ${WORKFLOW_NAME} --location=${REGION}"
echo "3. View logs: gcloud functions logs read ${FUNCTION_NAME} --region=${REGION} --limit=50"
echo ""
