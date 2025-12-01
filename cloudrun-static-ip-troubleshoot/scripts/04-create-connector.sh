#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Create VPC Connector
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

echo "Creating VPC Access Connector: $CONNECTOR_NAME"

# Create VPC Access Connector using the dedicated subnet
run gcloud compute networks vpc-access connectors create $CONNECTOR_NAME \
  --region=$REGION \
  --subnet=$CONNECTOR_SUBNET_NAME \
  --subnet-project=$PROJECT_ID \
  --min-instances=$CONNECTOR_MIN_INSTANCES \
  --max-instances=$CONNECTOR_MAX_INSTANCES

echo ""
echo "Waiting for connector to be ready..."
sleep 10

# Verify connector
echo ""
echo "=== VPC Connector Details ==="
run gcloud compute networks vpc-access connectors describe $CONNECTOR_NAME \
  --region=$REGION

echo ""
echo "VPC Connector created successfully."
echo ""
echo "IMPORTANT: Note the connector subnet for Cloud NAT configuration."