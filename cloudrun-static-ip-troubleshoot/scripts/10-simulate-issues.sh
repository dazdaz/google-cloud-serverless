#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Simulate Common Issues
# =============================================================================
# This script helps simulate common misconfigurations for testing/demo purposes
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

echo "=========================================="
echo "Cloud Run Static IP - Issue Simulator"
echo "=========================================="
echo ""
echo "Select an issue to simulate:"
echo ""
echo "1) Set VPC egress to 'private-ranges-only' (most common issue)"
echo "2) Configure NAT for specific subnet only (excludes connector)"
echo "3) Create blocking firewall rule"
echo "4) Reset to working configuration"
echo "5) Exit"
echo ""
read -p "Enter choice (1-5): " CHOICE

case $CHOICE in
  1)
    echo ""
    echo "Simulating: VPC egress set to private-ranges-only"
    echo "This will cause public requests to bypass the VPC connector and NAT"
    echo ""
    
    run gcloud run services update $SERVICE_NAME \
      --vpc-egress=private-ranges-only \
      --region=$REGION
    
    # Also update ip-checker if it exists
    run gcloud run services update ip-checker \
      --vpc-egress=private-ranges-only \
      --region=$REGION 2>/dev/null || true
    
    echo ""
    echo "✅ Issue simulated. Now test connectivity - it should fail or show wrong IP."
    echo ""
    echo "To fix: gcloud run services update $SERVICE_NAME --vpc-egress=all-traffic --region=$REGION"
    ;;
    
  2)
    echo ""
    echo "Simulating: NAT configured for main subnet only (excludes connector subnet)"
    echo "This will cause traffic from the connector to not be NAT'd"
    echo ""
    
    run gcloud compute routers nats update $NAT_NAME \
      --router=$ROUTER_NAME \
      --region=$REGION \
      --nat-custom-subnet-ip-ranges=$SUBNET_NAME
    
    echo ""
    echo "✅ Issue simulated. Now test connectivity - it should timeout or fail."
    echo ""
    echo "To fix: gcloud compute routers nats update $NAT_NAME --router=$ROUTER_NAME --region=$REGION --nat-all-subnet-ip-ranges"
    ;;
    
  3)
    echo ""
    echo "Simulating: Firewall rule blocking all egress"
    echo "This will block all outbound traffic from the VPC"
    echo ""
    
    run gcloud compute firewall-rules create block-egress-test \
      --direction=EGRESS \
      --priority=100 \
      --network=$NETWORK_NAME \
      --action=DENY \
      --rules=all \
      --destination-ranges=0.0.0.0/0 \
      --description="Test rule - blocks all egress"
    
    echo ""
    echo "✅ Issue simulated. Now test connectivity - it should fail immediately."
    echo ""
    echo "To fix: gcloud compute firewall-rules delete block-egress-test --quiet"
    ;;
    
  4)
    echo ""
    echo "Resetting to working configuration..."
    echo ""
    
    # Fix VPC egress
    echo "Setting VPC egress to all-traffic..."
    run gcloud run services update $SERVICE_NAME \
      --vpc-egress=all-traffic \
      --region=$REGION
    
    run gcloud run services update ip-checker \
      --vpc-egress=all-traffic \
      --region=$REGION 2>/dev/null || true
    
    # Fix NAT subnet coverage
    echo "Setting NAT to cover all subnets..."
    run gcloud compute routers nats update $NAT_NAME \
      --router=$ROUTER_NAME \
      --region=$REGION \
      --nat-all-subnet-ip-ranges
    
    # Remove blocking firewall rule if exists
    echo "Removing blocking firewall rule if exists..."
    run gcloud compute firewall-rules delete block-egress-test --quiet 2>/dev/null || true
    
    echo ""
    echo "✅ Configuration reset to working state."
    ;;
    
  5)
    echo "Exiting."
    exit 0
    ;;
    
  *)
    echo "Invalid choice. Please run again and select 1-5."
    exit 1
    ;;
esac

echo ""
echo "Run ./08-test-connectivity.sh to verify the current state."