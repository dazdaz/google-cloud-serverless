#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Test Connectivity
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

echo "Testing Cloud Run Static IP Configuration"
echo ""

# Get expected static IP
STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
  --region=$REGION \
  --format="value(address)" 2>/dev/null)

echo "Expected outbound IP: $STATIC_IP"
echo ""

# Get IP checker service URL
IP_CHECKER_URL=$(gcloud run services describe ip-checker --region=$REGION \
  --format="value(status.url)" 2>/dev/null)

if [ -n "$IP_CHECKER_URL" ]; then
  echo "Testing via IP Checker service..."
  echo "URL: $IP_CHECKER_URL"
  echo ""
  
  # Try public access first, fall back to authenticated
  echo "Fetching response..."
  RESPONSE=$(curl -s "$IP_CHECKER_URL" 2>/dev/null)
  
  if echo "$RESPONSE" | grep -q "Forbidden\|forbidden\|403"; then
    echo "Public access denied. Using authenticated access..."
    echo ""
    RESPONSE=$(curl -s -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$IP_CHECKER_URL")
  fi
  
  echo ""
  echo "=== Response ==="
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
  echo ""
  
  # Analyze the response for common issues
  if echo "$RESPONSE" | grep -q "timed out\|timeout\|Network is unreachable\|Connection refused"; then
    echo ""
    echo "=============================================="
    echo "❌ OUTBOUND REQUESTS FAILING"
    echo "=============================================="
    echo ""
    echo "The IP Checker service is running, but OUTBOUND"
    echo "requests to external services are timing out."
    echo ""
    echo "This is the EXACT ISSUE we're troubleshooting!"
    echo ""
    echo "LIKELY CAUSES:"
    echo "  1. Cloud NAT not created or misconfigured"
    echo "  2. VPC egress set to 'private-ranges-only'"
    echo "  3. Firewall rules blocking egress"
    echo ""
    echo "DIAGNOSTIC STEPS:"
    echo ""
    echo "  1. Check if Cloud NAT exists:"
    echo "     gcloud compute routers nats describe $NAT_NAME \\"
    echo "       --router=$ROUTER_NAME --region=$REGION"
    echo ""
    echo "  2. If NAT doesn't exist, create it:"
    echo "     gcloud compute routers nats create $NAT_NAME \\"
    echo "       --router=$ROUTER_NAME --region=$REGION \\"
    echo "       --nat-external-ip-pool=$STATIC_IP_NAME \\"
    echo "       --nat-all-subnet-ip-ranges --enable-logging"
    echo ""
    echo "  3. Check VPC egress setting:"
    echo "     gcloud run services describe ip-checker --region=$REGION \\"
    echo "       --format='value(spec.template.spec.vpcAccess.egress)'"
    echo ""
    echo "  4. Run full diagnostics:"
    echo "     ./09-diagnose.sh"
    echo ""
    echo "=============================================="
  elif echo "$RESPONSE" | grep -q '"status": "success"\|"status":"success"'; then
    echo ""
    echo "=============================================="
    echo "✅ OUTBOUND REQUESTS WORKING"
    echo "=============================================="
    echo ""
    echo "Static IP configuration is working correctly!"
    echo ""
    # Extract the IP from the response
    DETECTED_IP=$(echo "$RESPONSE" | grep -o '"origin": "[^"]*"' | head -1 | sed 's/"origin": "//;s/"//')
    if [ -n "$DETECTED_IP" ]; then
      echo "Detected outbound IP: $DETECTED_IP"
      echo "Expected static IP:   $STATIC_IP"
      echo ""
      if [ "$DETECTED_IP" == "$STATIC_IP" ]; then
        echo "✅ IP addresses MATCH - Configuration is correct!"
      else
        echo "⚠️  IP addresses DON'T MATCH"
        echo "   Traffic may not be going through Cloud NAT"
      fi
    fi
    echo ""
    echo "=============================================="
  fi
else
  echo "IP Checker service not deployed. Deploy with script 07."
  echo ""
  echo "Attempting to get service URL for: $SERVICE_NAME"
  SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION \
    --format="value(status.url)" 2>/dev/null)
  
  if [ -n "$SERVICE_URL" ]; then
    echo "Service URL: $SERVICE_URL"
    echo ""
    echo "To test with authenticated access:"
    echo "  curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" $SERVICE_URL"
  fi
fi

echo ""
echo "=========================================="
echo "Verification Steps:"
echo "1. Check that the IP addresses in the response match: $STATIC_IP"
echo "2. If IPs don't match, run the diagnostic script (./09-diagnose.sh)"
echo "3. Verify with your client that they've whitelisted: $STATIC_IP"
echo "=========================================="