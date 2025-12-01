# Cloud Run Static IP Demo Scripts

This document contains all the scripts needed to set up a complete Cloud Run static IP demo environment. These scripts are designed to be educational and help troubleshoot different scenarios.

## Overview

The demo creates:
1. A VPC network with a custom subnet
2. A VPC Access Connector
3. A Cloud Router and Cloud NAT with a static IP
4. A sample Cloud Run service configured to use the static IP
5. Diagnostic and testing utilities

## Script 1: Environment Setup

**Filename:** `scripts/01-setup-environment.sh`

This script sets up all the required environment variables.

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Environment Setup
# =============================================================================
# This script sets up environment variables for the demo.
# Modify these values according to your GCP project.
# =============================================================================

set -e

# Project Configuration
export PROJECT_ID="${PROJECT_ID:-your-project-id}"
export REGION="${REGION:-europe-west1}"
export ZONE="${ZONE:-europe-west1-b}"

# Network Configuration
export NETWORK_NAME="${NETWORK_NAME:-demo-vpc}"
export SUBNET_NAME="${SUBNET_NAME:-demo-subnet}"
export SUBNET_RANGE="${SUBNET_RANGE:-10.0.0.0/24}"
export CONNECTOR_SUBNET_NAME="${CONNECTOR_SUBNET_NAME:-connector-subnet}"
export CONNECTOR_SUBNET_RANGE="${CONNECTOR_SUBNET_RANGE:-10.8.0.0/28}"

# VPC Connector Configuration
export CONNECTOR_NAME="${CONNECTOR_NAME:-demo-connector}"
export CONNECTOR_MIN_INSTANCES="${CONNECTOR_MIN_INSTANCES:-2}"
export CONNECTOR_MAX_INSTANCES="${CONNECTOR_MAX_INSTANCES:-3}"

# Cloud Router and NAT Configuration
export ROUTER_NAME="${ROUTER_NAME:-demo-router}"
export NAT_NAME="${NAT_NAME:-demo-nat}"
export STATIC_IP_NAME="${STATIC_IP_NAME:-demo-static-ip}"

# Cloud Run Configuration
export SERVICE_NAME="${SERVICE_NAME:-demo-static-ip-service}"
export CONTAINER_IMAGE="${CONTAINER_IMAGE:-gcr.io/cloudrun/hello}"

# Display configuration
echo "=== Cloud Run Static IP Demo Configuration ==="
echo "PROJECT_ID:              $PROJECT_ID"
echo "REGION:                  $REGION"
echo "NETWORK_NAME:            $NETWORK_NAME"
echo "SUBNET_NAME:             $SUBNET_NAME"
echo "CONNECTOR_NAME:          $CONNECTOR_NAME"
echo "ROUTER_NAME:             $ROUTER_NAME"
echo "NAT_NAME:                $NAT_NAME"
echo "STATIC_IP_NAME:          $STATIC_IP_NAME"
echo "SERVICE_NAME:            $SERVICE_NAME"
echo "=============================================="

# Set project
gcloud config set project $PROJECT_ID

echo "Environment setup complete. Source this file before running other scripts:"
echo "  source ./01-setup-environment.sh"
```

---

## Script 2: Enable Required APIs

**Filename:** `scripts/02-enable-apis.sh`

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Enable Required APIs
# =============================================================================

set -e
source "$(dirname "$0")/01-setup-environment.sh"

echo "Enabling required APIs..."

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable vpcaccess.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

echo "APIs enabled successfully."
echo ""
echo "Enabled APIs:"
gcloud services list --enabled --filter="NAME:(compute OR run OR vpcaccess)" \
  --format="table(NAME,TITLE)"
```

---

## Script 3: Create VPC Network

**Filename:** `scripts/03-create-network.sh`

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Create VPC Network
# =============================================================================

set -e
source "$(dirname "$0")/01-setup-environment.sh"

echo "Creating VPC network: $NETWORK_NAME"

# Create VPC network (custom mode to have control over subnets)
gcloud compute networks create $NETWORK_NAME \
  --subnet-mode=custom \
  --description="Demo VPC for Cloud Run static IP"

echo ""
echo "Creating subnet: $SUBNET_NAME"

# Create main subnet
gcloud compute networks subnets create $SUBNET_NAME \
  --network=$NETWORK_NAME \
  --region=$REGION \
  --range=$SUBNET_RANGE \
  --enable-private-ip-google-access

echo ""
echo "Creating connector subnet: $CONNECTOR_SUBNET_NAME"

# Create subnet for VPC connector
# Note: VPC connector requires a /28 subnet at minimum
gcloud compute networks subnets create $CONNECTOR_SUBNET_NAME \
  --network=$NETWORK_NAME \
  --region=$REGION \
  --range=$CONNECTOR_SUBNET_RANGE \
  --enable-private-ip-google-access

echo ""
echo "Network and subnets created successfully."

# Verify
echo ""
echo "=== Network Details ==="
gcloud compute networks describe $NETWORK_NAME

echo ""
echo "=== Subnets ==="
gcloud compute networks subnets list --network=$NETWORK_NAME
```

---

## Script 4: Create VPC Connector

**Filename:** `scripts/04-create-connector.sh`

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Create VPC Connector
# =============================================================================

set -e
source "$(dirname "$0")/01-setup-environment.sh"

echo "Creating VPC Access Connector: $CONNECTOR_NAME"

# Create VPC Access Connector using the dedicated subnet
gcloud compute networks vpc-access connectors create $CONNECTOR_NAME \
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
gcloud compute networks vpc-access connectors describe $CONNECTOR_NAME \
  --region=$REGION

echo ""
echo "VPC Connector created successfully."
echo ""
echo "IMPORTANT: Note the connector subnet for Cloud NAT configuration."
```

---

## Script 5: Create Static IP and Cloud NAT

**Filename:** `scripts/05-create-nat.sh`

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Create Cloud Router and NAT with Static IP
# =============================================================================

set -e
source "$(dirname "$0")/01-setup-environment.sh"

echo "Reserving static IP address: $STATIC_IP_NAME"

# Reserve a static external IP address
gcloud compute addresses create $STATIC_IP_NAME \
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
gcloud compute routers create $ROUTER_NAME \
  --network=$NETWORK_NAME \
  --region=$REGION \
  --description="Router for Cloud Run static IP NAT"

echo ""
echo "Creating Cloud NAT: $NAT_NAME"

# Create Cloud NAT with static IP
# IMPORTANT: Use --nat-all-subnet-ip-ranges to include the VPC connector subnet
gcloud compute routers nats create $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION \
  --nat-external-ip-pool=$STATIC_IP_NAME \
  --nat-all-subnet-ip-ranges \
  --enable-logging \
  --log-filter=ALL \
  --description="NAT gateway with static IP for Cloud Run"

echo ""
echo "=== Cloud Router Details ==="
gcloud compute routers describe $ROUTER_NAME --region=$REGION

echo ""
echo "=== Cloud NAT Details ==="
gcloud compute routers nats describe $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION

echo ""
echo "=============================================="
echo "Static IP Address: $STATIC_IP"
echo "=============================================="
echo ""
echo "This is the IP address to whitelist with your client (e.g., Jira)"
echo ""
echo "Cloud NAT and Router created successfully."
```

---

## Script 6: Deploy Cloud Run Service

**Filename:** `scripts/06-deploy-service.sh`

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Deploy Cloud Run Service
# =============================================================================

set -e
source "$(dirname "$0")/01-setup-environment.sh"

echo "Deploying Cloud Run service: $SERVICE_NAME"

# Get the full connector path
CONNECTOR_PATH="projects/$PROJECT_ID/locations/$REGION/connectors/$CONNECTOR_NAME"

# Deploy Cloud Run service with VPC connector and all-traffic egress
# CRITICAL: The --vpc-egress=all-traffic flag is essential!
gcloud run deploy $SERVICE_NAME \
  --image=$CONTAINER_IMAGE \
  --region=$REGION \
  --platform=managed \
  --vpc-connector=$CONNECTOR_PATH \
  --vpc-egress=all-traffic \
  --allow-unauthenticated \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION"

echo ""
echo "=== Cloud Run Service Details ==="
gcloud run services describe $SERVICE_NAME --region=$REGION

echo ""
echo "=== VPC Configuration ==="
gcloud run services describe $SERVICE_NAME --region=$REGION \
  --format="yaml(spec.template.spec.vpcAccess)"

echo ""
echo "Cloud Run service deployed successfully."

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION \
  --format="value(status.url)")

echo ""
echo "Service URL: $SERVICE_URL"
```

---

## Script 7: Deploy IP Check Service

**Filename:** `scripts/07-deploy-ip-checker.sh`

This deploys a custom service that displays the outbound IP address.

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Deploy IP Checker Service
# =============================================================================
# This service makes an outbound request and shows the IP address
# =============================================================================

set -e
source "$(dirname "$0")/01-setup-environment.sh"

IP_CHECKER_SERVICE="ip-checker"

# Create a simple Dockerfile and application
mkdir -p /tmp/ip-checker
cat > /tmp/ip-checker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN pip install flask requests

COPY app.py .

CMD ["python", "app.py"]
EOF

cat > /tmp/ip-checker/app.py << 'EOF'
import os
import requests
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def check_ip():
    """Check outbound IP address using multiple services"""
    results = {}
    
    services = [
        ('httpbin.org', 'https://httpbin.org/ip'),
        ('ifconfig.me', 'https://ifconfig.me'),
        ('ipify.org', 'https://api.ipify.org'),
    ]
    
    for name, url in services:
        try:
            response = requests.get(url, timeout=10)
            results[name] = {
                'status': 'success',
                'ip': response.text.strip() if 'ifconfig' in name or 'ipify' in name else response.json(),
                'status_code': response.status_code
            }
        except Exception as e:
            results[name] = {
                'status': 'error',
                'error': str(e)
            }
    
    return jsonify({
        'outbound_ip_check': results,
        'project_id': os.getenv('PROJECT_ID', 'unknown'),
        'region': os.getenv('REGION', 'unknown')
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 8080)))
EOF

echo "Building and deploying IP checker service..."

# Build and push to Container Registry
cd /tmp/ip-checker
gcloud builds submit --tag gcr.io/$PROJECT_ID/$IP_CHECKER_SERVICE

# Get connector path
CONNECTOR_PATH="projects/$PROJECT_ID/locations/$REGION/connectors/$CONNECTOR_NAME"

# Deploy with VPC connector
gcloud run deploy $IP_CHECKER_SERVICE \
  --image=gcr.io/$PROJECT_ID/$IP_CHECKER_SERVICE \
  --region=$REGION \
  --platform=managed \
  --vpc-connector=$CONNECTOR_PATH \
  --vpc-egress=all-traffic \
  --allow-unauthenticated \
  --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION"

echo ""
echo "IP Checker service deployed."

# Get service URL
SERVICE_URL=$(gcloud run services describe $IP_CHECKER_SERVICE --region=$REGION \
  --format="value(status.url)")

# Get expected static IP
STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
  --region=$REGION \
  --format="value(address)")

echo ""
echo "=============================================="
echo "IP Checker Service URL: $SERVICE_URL"
echo "Expected Static IP:     $STATIC_IP"
echo "=============================================="
echo ""
echo "Test the service:"
echo "  curl $SERVICE_URL"
echo ""
echo "The response should show your static IP: $STATIC_IP"

# Clean up temp files
rm -rf /tmp/ip-checker
```

---

## Script 8: Test Connectivity

**Filename:** `scripts/08-test-connectivity.sh`

This script tests the outbound connectivity from Cloud Run and verifies the static IP is being used.

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Test Connectivity
# =============================================================================

set -e

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
  RESPONSE=$(curl -s "$IP_CHECKER_URL" 2>/dev/null)
  
  if echo "$RESPONSE" | grep -q "Forbidden\|forbidden\|403"; then
    echo "Public access denied. Using authenticated access..."
    RESPONSE=$(curl -s -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$IP_CHECKER_URL")
  fi
  
  echo ""
  echo "=== Response ==="
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
  echo ""
else
  echo "IP Checker service not deployed. Deploy with ./07-deploy-ip-checker.sh"
fi

echo ""
echo "=========================================="
echo "Verification Steps:"
echo "1. Check that the IP addresses in the response match: $STATIC_IP"
echo "2. If IPs don't match, run the diagnostic script (./09-diagnose.sh)"
echo "3. Verify with your client that they've whitelisted: $STATIC_IP"
echo "=========================================="
```

---

## Script 9: Diagnostic Script

**Filename:** `scripts/09-diagnose.sh`

This script runs comprehensive diagnostics and provides a clear summary of issues with fixes.

---

## Script 10: Simulate Issues

**Filename:** `scripts/10-simulate-issues.sh`

This script can simulate common misconfigurations for testing and demo purposes.

---

## Script 99: Cleanup

**Filename:** `scripts/99-cleanup.sh`

```bash
#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Cleanup All Resources
# =============================================================================

set -e
source "$(dirname "$0")/01-setup-environment.sh"

echo "This will delete ALL demo resources. Are you sure? (yes/no)"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo "Deleting Cloud Run services..."
gcloud run services delete $SERVICE_NAME --region=$REGION --quiet 2>/dev/null || true
gcloud run services delete ip-checker --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting Cloud NAT..."
gcloud compute routers nats delete $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting Cloud Router..."
gcloud compute routers delete $ROUTER_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting VPC Connector..."
gcloud compute networks vpc-access connectors delete $CONNECTOR_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Releasing static IP..."
gcloud compute addresses delete $STATIC_IP_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting subnets..."
gcloud compute networks subnets delete $CONNECTOR_SUBNET_NAME \
  --region=$REGION --quiet 2>/dev/null || true
gcloud compute networks subnets delete $SUBNET_NAME \
  --region=$REGION --quiet 2>/dev/null || true

echo ""
echo "Deleting VPC network..."
gcloud compute networks delete $NETWORK_NAME --quiet 2>/dev/null || true

echo ""
echo "Cleanup complete."
```

---

## Demo Scenarios

### Scenario A: Working Configuration

Run all scripts in order (01-09) to see a working setup.

### Scenario B: Simulate private-ranges-only Issue

After setup, update the service with wrong egress setting:

```bash
gcloud run services update $SERVICE_NAME \
  --vpc-egress=private-ranges-only \
  --region=$REGION
```

Then test - you'll see the timeout behavior.

### Scenario C: Simulate NAT Subnet Issue

Update NAT to not cover the connector subnet:

```bash
gcloud compute routers nats update $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION \
  --nat-custom-subnet-ip-ranges=$SUBNET_NAME
```

Then test - traffic won't reach NAT.

### Scenario D: Simulate Firewall Block

Create a blocking firewall rule:

```bash
gcloud compute firewall-rules create block-egress-test \
  --direction=EGRESS \
  --priority=100 \
  --network=$NETWORK_NAME \
  --action=DENY \
  --rules=all \
  --destination-ranges=0.0.0.0/0
```

Then test - traffic will be blocked.

---

## Quick Reference Commands

```bash
# Check Cloud Run VPC egress setting
gcloud run services describe SERVICE --region=REGION \
  --format="value(spec.template.spec.vpcAccess.egress)"

# Update to all-traffic (the fix for most issues)
gcloud run services update SERVICE --region=REGION \
  --vpc-egress=all-traffic

# Check NAT configuration
gcloud compute routers nats describe NAT --router=ROUTER --region=REGION

# Update NAT to cover all subnets
gcloud compute routers nats update NAT --router=ROUTER --region=REGION \
  --nat-all-subnet-ip-ranges

# Enable NAT logging
gcloud compute routers nats update NAT --router=ROUTER --region=REGION \
  --enable-logging --log-filter=ALL

# View NAT logs
gcloud logging read "resource.type=nat_gateway" --limit=50