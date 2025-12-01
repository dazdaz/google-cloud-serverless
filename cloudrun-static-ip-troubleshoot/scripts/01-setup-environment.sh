#!/bin/bash

# =============================================================================
# Cloud Run Static IP Demo - Environment Setup
# =============================================================================
# This script sets up environment variables for the demo.
#
# USAGE (run from the scripts/ directory):
#   Option 1: Set PROJECT_ID environment variable before running:
#     export PROJECT_ID="my-actual-project-id"
#     source ./01-setup-environment.sh
#
#   Option 2: Edit this file and replace "your-project-id" below
#
# =============================================================================

set -e

# ============================================================================
# REQUIRED: Set your GCP project ID here or via environment variable
# ============================================================================
export PROJECT_ID="${PROJECT_ID:-your-project-id}"

# Validate PROJECT_ID is set
if [ "$PROJECT_ID" == "your-project-id" ]; then
  echo ""
  echo "ERROR: You must set your GCP project ID!"
  echo ""
  echo "Option 1: Set environment variable before running:"
  echo "  export PROJECT_ID=\"your-actual-project-id\""
  echo "  source ./01-setup-environment.sh"
  echo ""
  echo "Option 2: Edit ./01-setup-environment.sh and change 'your-project-id'"
  echo ""
  return 1 2>/dev/null || exit 1
fi

# Project Configuration
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

echo ""
echo "Environment setup complete. Source this file before running other scripts:"
echo "  source ./01-setup-environment.sh"