#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Cleanup All Resources
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

echo ""
echo "This will delete ALL demo resources. Are you sure? (y/yes to confirm)"
read -r CONFIRM

# Accept y, Y, yes, YES, Yes
if [[ ! "$CONFIRM" =~ ^[yY]([eE][sS])?$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo "Proceeding with cleanup..."

echo ""
echo "Deleting Cloud Run services..."
run gcloud run services delete $SERVICE_NAME --region=$REGION --quiet 2>/dev/null || true
run gcloud run services delete ip-checker --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting Cloud NAT..."
run gcloud compute routers nats delete $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting Cloud Router..."
run gcloud compute routers delete $ROUTER_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting VPC Connector (this can take 5-10 minutes)..."
run gcloud compute networks vpc-access connectors delete $CONNECTOR_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Releasing static IP..."
run gcloud compute addresses delete $STATIC_IP_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting subnets (waiting for VPC connector resources to release)..."
run gcloud compute networks subnets delete $CONNECTOR_SUBNET_NAME \
  --region=$REGION --quiet 2>/dev/null || true
run gcloud compute networks subnets delete $SUBNET_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting VPC network..."
run gcloud compute networks delete $NETWORK_NAME --quiet 2>/dev/null || true

echo ""
echo "Cleanup complete."