#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Deploy IP Checker Service
# =============================================================================
# This service makes an outbound request and shows the IP address
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
run gcloud builds submit --tag gcr.io/$PROJECT_ID/$IP_CHECKER_SERVICE

# Get connector path
CONNECTOR_PATH="projects/$PROJECT_ID/locations/$REGION/connectors/$CONNECTOR_NAME"

# Deploy with VPC connector
run gcloud run deploy $IP_CHECKER_SERVICE \
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

# Try to grant public access
echo ""
echo "Attempting to grant public access..."
if gcloud run services add-iam-policy-binding $IP_CHECKER_SERVICE \
  --region=$REGION \
  --member="allUsers" \
  --role="roles/run.invoker" 2>/dev/null; then
  echo "Public access granted."
  echo ""
  echo "Test the service (public access):"
  echo "  curl $SERVICE_URL"
else
  echo ""
  echo "=============================================="
  echo "NOTE: Public access not available"
  echo "(Your organization may restrict this)"
  echo "=============================================="
  echo ""
  echo "Use AUTHENTICATED access instead:"
  echo ""
  echo "  curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" \\"
  echo "    $SERVICE_URL"
  echo ""
  echo "=============================================="
fi

echo ""
echo "The response should show your static IP: $STATIC_IP"

# Clean up temp files
rm -rf /tmp/ip-checker