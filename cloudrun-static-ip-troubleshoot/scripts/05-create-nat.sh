#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Create Cloud Router and NAT with Static IP
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

echo "Reserving static IP address: $STATIC_IP_NAME"

# Reserve a static external IP address
run gcloud compute addresses create $STATIC_IP_NAME \
  --region=$REGION \
  --description="Static IP for Cloud Run NAT"

# Get the IP address
STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
  --region=$REGION \
  --format="value(address)")

echo "Reserved static IP: $STATIC_IP"

echo ""
echo "Creating Cloud Router: $ROUTER_NAME"

# Create Cloud Router
run gcloud compute routers create $ROUTER_NAME \
  --network=$NETWORK_NAME \
  --region=$REGION \
  --description="Router for Cloud Run static IP NAT"

echo ""
echo "Creating Cloud NAT: $NAT_NAME"

# Create Cloud NAT with static IP
# IMPORTANT: Use --nat-all-subnet-ip-ranges to include the VPC connector subnet
run gcloud compute routers nats create $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION \
  --nat-external-ip-pool=$STATIC_IP_NAME \
  --nat-all-subnet-ip-ranges \
  --enable-logging \
  --log-filter=ALL

echo ""
echo "=== Cloud Router Details ==="
run gcloud compute routers describe $ROUTER_NAME --region=$REGION

echo ""
echo "=== Cloud NAT Details ==="
run gcloud compute routers nats describe $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION

echo ""
echo "=============================================="
echo "=============================================="
echo ""
echo "  *** IMPORTANT: STATIC IP FOR WHITELISTING ***"
echo ""
echo "  Static IP Address: $STATIC_IP"
echo ""
echo "  This is the IP address your client needs to"
echo "  whitelist to allow access from your Cloud Run"
echo "  services (e.g., Jira, SFTP, external APIs)"
echo ""
echo "=============================================="
echo "=============================================="
echo ""
echo "Cloud NAT and Router created successfully."