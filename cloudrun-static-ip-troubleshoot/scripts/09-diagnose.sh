#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Comprehensive Diagnostic Script
# =============================================================================

# Don't exit on error - we want to collect all diagnostics
set +e

# Function to show and run commands
run() {
  echo "+ $*"
  "$@"
}

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/01-setup-environment.sh"

# Initialize issue tracking
ISSUES=()
FIXES=()

echo "=========================================="
echo "Cloud Run Static IP Diagnostic Report"
echo "Generated: $(date)"
echo "=========================================="

echo ""
echo "=== 1. Project and Region ==="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"

echo ""
echo "=== 2. Cloud Run Service Configuration ==="
echo "Service Name: $SERVICE_NAME"
SERVICE_EXISTS=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(metadata.name)" 2>/dev/null)
if [ -z "$SERVICE_EXISTS" ]; then
  echo "❌ Service not found"
  ISSUES+=("Cloud Run service '$SERVICE_NAME' does not exist")
  FIXES+=("Deploy the service: ./06-deploy-service.sh")
else
  gcloud run services describe $SERVICE_NAME --region=$REGION \
    --format="yaml(spec.template.spec.vpcAccess)" 2>/dev/null
fi

echo ""
echo "=== 3. VPC Egress Setting (CRITICAL) ==="
EGRESS=$(gcloud run services describe $SERVICE_NAME --region=$REGION \
  --format="value(spec.template.spec.vpcAccess.egress)" 2>/dev/null)
if [ "$EGRESS" == "all-traffic" ]; then
  echo "✅ VPC Egress: $EGRESS (Correct)"
elif [ -z "$EGRESS" ]; then
  echo "❌ VPC Egress: NOT SET"
  ISSUES+=("VPC egress is not configured - traffic won't use the VPC connector")
  FIXES+=("gcloud run services update $SERVICE_NAME --vpc-egress=all-traffic --region=$REGION")
else
  echo "❌ VPC Egress: $EGRESS (Should be 'all-traffic')"
  ISSUES+=("VPC egress is '$EGRESS' - public traffic bypasses the VPC connector and NAT")
  FIXES+=("gcloud run services update $SERVICE_NAME --vpc-egress=all-traffic --region=$REGION")
fi

echo ""
echo "=== 4. VPC Connector ==="
CONNECTOR_EXISTS=$(gcloud compute networks vpc-access connectors describe $CONNECTOR_NAME \
  --region=$REGION --format="value(name)" 2>/dev/null)
if [ -z "$CONNECTOR_EXISTS" ]; then
  echo "❌ VPC Connector not found"
  ISSUES+=("VPC Connector '$CONNECTOR_NAME' does not exist")
  FIXES+=("Create connector: ./04-create-connector.sh")
else
  echo "✅ VPC Connector exists: $CONNECTOR_NAME"
  gcloud compute networks vpc-access connectors describe $CONNECTOR_NAME \
    --region=$REGION --format="yaml(state,network,ipCidrRange)" 2>/dev/null
fi

echo ""
echo "=== 5. Cloud NAT Configuration ==="
NAT_EXISTS=$(gcloud compute routers nats describe $NAT_NAME \
  --router=$ROUTER_NAME --region=$REGION --format="value(name)" 2>/dev/null)
if [ -z "$NAT_EXISTS" ]; then
  echo "❌ Cloud NAT not found - THIS IS LIKELY YOUR MAIN ISSUE!"
  ISSUES+=("Cloud NAT '$NAT_NAME' does not exist - outbound traffic cannot reach the internet")
  FIXES+=("gcloud compute routers nats create $NAT_NAME --router=$ROUTER_NAME --region=$REGION --nat-external-ip-pool=$STATIC_IP_NAME --nat-all-subnet-ip-ranges --enable-logging --log-filter=ALL")
else
  echo "✅ Cloud NAT exists: $NAT_NAME"
  gcloud compute routers nats describe $NAT_NAME \
    --router=$ROUTER_NAME --region=$REGION 2>/dev/null
fi

echo ""
echo "=== 6. NAT Subnet Coverage ==="
if [ -n "$NAT_EXISTS" ]; then
  NAT_SUBNETS=$(gcloud compute routers nats describe $NAT_NAME \
    --router=$ROUTER_NAME \
    --region=$REGION \
    --format="value(sourceSubnetworkIpRangesToNat)" 2>/dev/null)
  if [ "$NAT_SUBNETS" == "ALL_SUBNETWORKS_ALL_IP_RANGES" ]; then
    echo "✅ NAT covers all subnets including VPC connector"
  elif [ -z "$NAT_SUBNETS" ]; then
    echo "❌ NAT subnet coverage not configured"
    ISSUES+=("NAT not configured to cover any subnets")
    FIXES+=("gcloud compute routers nats update $NAT_NAME --router=$ROUTER_NAME --region=$REGION --nat-all-subnet-ip-ranges")
  else
    echo "⚠️  NAT subnet coverage: $NAT_SUBNETS"
    echo "   May not include VPC connector subnet"
    ISSUES+=("NAT may not cover the VPC connector subnet")
    FIXES+=("gcloud compute routers nats update $NAT_NAME --router=$ROUTER_NAME --region=$REGION --nat-all-subnet-ip-ranges")
  fi
else
  echo "⚠️  Skipped - NAT does not exist"
fi

echo ""
echo "=== 7. Static IP Address ==="
STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
  --region=$REGION \
  --format="value(address)" 2>/dev/null)
if [ -n "$STATIC_IP" ]; then
  echo "✅ Static IP: $STATIC_IP"
else
  echo "❌ No static IP found"
  ISSUES+=("Static IP '$STATIC_IP_NAME' does not exist")
  FIXES+=("gcloud compute addresses create $STATIC_IP_NAME --region=$REGION")
fi

echo ""
echo "=== 8. NAT IP Configuration ==="
if [ -n "$NAT_EXISTS" ]; then
  NAT_IPS=$(gcloud compute routers nats describe $NAT_NAME \
    --router=$ROUTER_NAME \
    --region=$REGION \
    --format="value(natIps)" 2>/dev/null)
  if [ -n "$NAT_IPS" ]; then
    echo "✅ NAT using static IPs: $NAT_IPS"
  else
    echo "❌ NAT not using static IPs (using auto-allocated)"
    ISSUES+=("NAT is using auto-allocated IPs instead of static IP")
    FIXES+=("gcloud compute routers nats update $NAT_NAME --router=$ROUTER_NAME --region=$REGION --nat-external-ip-pool=$STATIC_IP_NAME")
  fi
else
  echo "⚠️  Skipped - NAT does not exist"
fi

echo ""
echo "=== 9. Cloud Router ==="
ROUTER_EXISTS=$(gcloud compute routers describe $ROUTER_NAME \
  --region=$REGION --format="value(name)" 2>/dev/null)
if [ -z "$ROUTER_EXISTS" ]; then
  echo "❌ Cloud Router not found"
  ISSUES+=("Cloud Router '$ROUTER_NAME' does not exist")
  FIXES+=("gcloud compute routers create $ROUTER_NAME --network=$NETWORK_NAME --region=$REGION")
else
  echo "✅ Cloud Router exists: $ROUTER_NAME"
fi

echo ""
echo "=== 10. Firewall Rules (Egress) ==="
DENY_RULES=$(gcloud compute firewall-rules list \
  --filter="direction=EGRESS AND network=$NETWORK_NAME AND action=DENY" \
  --format="value(name)" 2>/dev/null)
if [ -n "$DENY_RULES" ]; then
  echo "⚠️  Found DENY egress rules:"
  gcloud compute firewall-rules list \
    --filter="direction=EGRESS AND network=$NETWORK_NAME AND action=DENY" \
    --format="table(name,priority,action,destinationRanges)" 2>/dev/null
  ISSUES+=("Egress DENY firewall rules may be blocking traffic: $DENY_RULES")
  FIXES+=("Review and remove blocking rules or add higher priority ALLOW rule")
else
  echo "✅ No blocking egress firewall rules found"
fi

echo ""
echo "=== 11. Network Routes ==="
DEFAULT_ROUTE=$(gcloud compute routes list \
  --filter="network=$NETWORK_NAME AND destRange=0.0.0.0/0" \
  --format="value(name)" 2>/dev/null)
if [ -z "$DEFAULT_ROUTE" ]; then
  echo "❌ No default internet route found"
  ISSUES+=("Missing default route to internet gateway")
  FIXES+=("gcloud compute routes create default-internet --network=$NETWORK_NAME --destination-range=0.0.0.0/0 --next-hop-gateway=default-internet-gateway")
else
  echo "✅ Default internet route exists"
  gcloud compute routes list \
    --filter="network=$NETWORK_NAME AND destRange=0.0.0.0/0" \
    --format="table(name,destRange,nextHopGateway,priority)" 2>/dev/null
fi

echo ""
echo "=== 12. NAT Logging Status ==="
if [ -n "$NAT_EXISTS" ]; then
  NAT_LOGGING=$(gcloud compute routers nats describe $NAT_NAME \
    --router=$ROUTER_NAME \
    --region=$REGION \
    --format="value(logConfig.enable)" 2>/dev/null)
  if [ "$NAT_LOGGING" == "True" ]; then
    echo "✅ NAT logging is enabled"
  else
    echo "⚠️  NAT logging is disabled"
    ISSUES+=("NAT logging disabled - enable for troubleshooting")
    FIXES+=("gcloud compute routers nats update $NAT_NAME --router=$ROUTER_NAME --region=$REGION --enable-logging --log-filter=ALL")
  fi
else
  echo "⚠️  Skipped - NAT does not exist"
fi

# ============================================================================
# SUMMARY AND RECOMMENDATIONS
# ============================================================================

echo ""
echo ""
echo "=============================================="
echo "=============================================="
echo "         DIAGNOSTIC SUMMARY"
echo "=============================================="
echo "=============================================="

if [ ${#ISSUES[@]} -eq 0 ]; then
  echo ""
  echo "✅ ALL CHECKS PASSED!"
  echo ""
  echo "Your configuration appears correct."
  echo "If you're still having issues, try:"
  echo "  1. Run ./08-test-connectivity.sh to test outbound"
  echo "  2. Check NAT logs in Cloud Console"
  echo "  3. Verify the target service allows your static IP: $STATIC_IP"
  echo ""
else
  echo ""
  echo "❌ FOUND ${#ISSUES[@]} ISSUE(S) TO FIX:"
  echo ""
  
  for i in "${!ISSUES[@]}"; do
    echo "─────────────────────────────────────────────"
    echo "Issue $((i+1)): ${ISSUES[$i]}"
    echo ""
    echo "Fix:"
    echo "  ${FIXES[$i]}"
    echo ""
  done
  
  echo "=============================================="
  echo ""
  echo "RECOMMENDED ACTION:"
  echo ""
  echo "Run the fixes above in order, then test with:"
  echo "  ./08-test-connectivity.sh"
  echo ""
fi

echo "=============================================="
echo "Static IP to whitelist: $STATIC_IP"
echo "=============================================="
echo ""