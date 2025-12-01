#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Enable Required APIs
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

echo "Enabling required APIs..."

# Enable required APIs
run gcloud services enable compute.googleapis.com
run gcloud services enable run.googleapis.com
run gcloud services enable vpcaccess.googleapis.com
run gcloud services enable cloudresourcemanager.googleapis.com
run gcloud services enable cloudbuild.googleapis.com

echo ""
echo "APIs enabled successfully."
echo ""
echo "Enabled APIs:"
run gcloud services list --enabled \
  --filter="NAME=compute.googleapis.com OR NAME=run.googleapis.com OR NAME=vpcaccess.googleapis.com OR NAME=cloudbuild.googleapis.com" \
  --format="table(NAME,TITLE)"