#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Create VPC Network
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

echo "Creating VPC network: $NETWORK_NAME"

# Create VPC network (custom mode to have control over subnets)
run gcloud compute networks create $NETWORK_NAME \
  --subnet-mode=custom \
  --description="Demo VPC for Cloud Run static IP"

echo ""
echo "Creating subnet: $SUBNET_NAME"

# Create main subnet
run gcloud compute networks subnets create $SUBNET_NAME \
  --network=$NETWORK_NAME \
  --region=$REGION \
  --range=$SUBNET_RANGE \
  --enable-private-ip-google-access

echo ""
echo "Creating connector subnet: $CONNECTOR_SUBNET_NAME"

# Create subnet for VPC connector
# Note: VPC connector requires a /28 subnet at minimum
run gcloud compute networks subnets create $CONNECTOR_SUBNET_NAME \
  --network=$NETWORK_NAME \
  --region=$REGION \
  --range=$CONNECTOR_SUBNET_RANGE \
  --enable-private-ip-google-access

echo ""
echo "Network and subnets created successfully."

# Verify
echo ""
echo "=== Network Details ==="
run gcloud compute networks describe $NETWORK_NAME

echo ""
echo "=== Subnets ==="
run gcloud compute networks subnets list --network=$NETWORK_NAME