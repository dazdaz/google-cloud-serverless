# Customer Troubleshooting Questions

Use these questions to diagnose Cloud Run static IP configuration issues. Ask them in order - earlier questions often identify the root cause.

## Quick Diagnostic Questions

### 1. VPC Egress Configuration (Most Common Issue)

**Question:** What is your Cloud Run service's VPC egress setting?

```bash
# Customer can run this command to check:
gcloud run services describe SERVICE_NAME --region=REGION --format="value(spec.template.spec.vpcAccess.egress)"
```

**Expected Answer:** `all-traffic`

**If Answer is `private-ranges-only` or blank:**
> This is likely your issue! The `private-ranges-only` setting only routes traffic to private IP ranges through the VPC connector. Public internet traffic bypasses the connector entirely and won't use your Cloud NAT/static IP.
>
> **Solution:** Update to `all-traffic`:
> ```bash
> gcloud run services update SERVICE_NAME \
>   --vpc-egress=all-traffic \
>   --region=REGION
> ```

---

### 2. VPC Connector Attachment

**Question:** Is a VPC connector attached to your Cloud Run service?

```bash
# Customer can run this command to check:
gcloud run services describe SERVICE_NAME --region=REGION --format="value(spec.template.spec.vpcAccess.connector)"
```

**Expected Answer:** A connector name like `projects/PROJECT/locations/REGION/connectors/CONNECTOR_NAME`

**If blank or error:**
> No VPC connector is attached. Without a connector, traffic cannot route through your VPC to the Cloud NAT.
>
> **Solution:** Attach a VPC connector:
> ```bash
> gcloud run services update SERVICE_NAME \
>   --vpc-connector=CONNECTOR_NAME \
>   --vpc-egress=all-traffic \
>   --region=REGION
> ```

---

### 3. VPC Connector Region

**Question:** Is your VPC connector in the same region as your Cloud Run service?

```bash
# Check Cloud Run region:
gcloud run services describe SERVICE_NAME --format="value(metadata.labels['cloud.googleapis.com/location'])"

# Check connector region:
gcloud compute networks vpc-access connectors describe CONNECTOR_NAME --region=REGION
```

**Expected Answer:** Both should be in the same region

**If different regions:**
> VPC connectors must be in the same region as the Cloud Run service. Cross-region attachment is not supported.

---

### 4. Cloud NAT Configuration

**Question:** What subnets is your Cloud NAT configured to handle?

```bash
# Customer can run this command to check:
gcloud compute routers nats describe NAT_NAME --router=ROUTER_NAME --region=REGION
```

**Look for:** `sourceSubnetworkIpRangesToNat` field

**Expected Answer:** Either:
- `ALL_SUBNETWORKS_ALL_IP_RANGES` - Covers all subnets including connector
- The VPC connector's subnet should be explicitly listed

**If using specific subnets and connector subnet is missing:**
> Your Cloud NAT is not configured to handle traffic from the VPC connector subnet.
>
> **Solution:** Either use all subnets or add the connector subnet:
> ```bash
> gcloud compute routers nats update NAT_NAME \
>   --router=ROUTER_NAME \
>   --region=REGION \
>   --nat-all-subnet-ip-ranges
> ```

---

### 5. VPC Connector Subnet

**Question:** What subnet is your VPC connector using?

```bash
# For connectors with custom subnet:
gcloud compute networks vpc-access connectors describe CONNECTOR_NAME \
  --region=REGION \
  --format="value(subnet)"

# For connectors with IP range (creates subnet automatically):
gcloud compute networks vpc-access connectors describe CONNECTOR_NAME \
  --region=REGION \
  --format="value(ipCidrRange)"
```

**Note:** The connector subnet must be included in the Cloud NAT configuration.

---

### 6. Cloud NAT Logging

**Question:** Is Cloud NAT logging enabled?

```bash
gcloud compute routers nats describe NAT_NAME \
  --router=ROUTER_NAME \
  --region=REGION \
  --format="value(logConfig)"
```

**If logging is not enabled:**
> Enable logging to see what traffic is reaching the NAT:
> ```bash
> gcloud compute routers nats update NAT_NAME \
>   --router=ROUTER_NAME \
>   --region=REGION \
>   --enable-logging \
>   --log-filter=ALL
> ```

---

### 7. Firewall Rules

**Question:** Are there any egress deny rules in your VPC?

```bash
# List all egress firewall rules:
gcloud compute firewall-rules list \
  --filter="direction=EGRESS AND network=NETWORK_NAME" \
  --format="table(name,priority,direction,action,sourceRanges,destinationRanges)"
```

**Look for:** Any `DENY` rules with low priority numbers (lower = higher priority)

**If egress deny rules exist with high priority:**
> Firewall rules might be blocking traffic before it reaches NAT. The implicit allow rule for egress is at priority 65535.

---

### 8. Network Routes

**Question:** Does your VPC have a default internet route?

```bash
gcloud compute routes list \
  --filter="network=NETWORK_NAME AND destRange=0.0.0.0/0" \
  --format="table(name,destRange,nextHopGateway)"
```

**Expected Answer:** A route with `destRange: 0.0.0.0/0` and `nextHopGateway: default-internet-gateway`

**If missing:**
> No default route to internet. Traffic has nowhere to go.
>
> **Solution:**
> ```bash
> gcloud compute routes create default-internet-route \
>   --network=NETWORK_NAME \
>   --destination-range=0.0.0.0/0 \
>   --next-hop-gateway=default-internet-gateway
> ```

---

### 9. Static IP Configuration

**Question:** Is your Cloud NAT using a static IP address?

```bash
gcloud compute routers nats describe NAT_NAME \
  --router=ROUTER_NAME \
  --region=REGION \
  --format="value(natIps)"
```

**Expected Answer:** A list of static IP addresses

**If empty or using auto-allocated:**
> Cloud NAT is using auto-allocated IPs which can change.
>
> **Solution:** Reserve and assign a static IP:
> ```bash
> # Reserve a static IP
> gcloud compute addresses create NAT_STATIC_IP --region=REGION
> 
> # Get the IP address
> gcloud compute addresses describe NAT_STATIC_IP --region=REGION --format="value(address)"
> 
> # Update NAT to use static IP
> gcloud compute routers nats update NAT_NAME \
>   --router=ROUTER_NAME \
>   --region=REGION \
>   --nat-external-ip-pool=NAT_STATIC_IP
> ```

---

### 10. Test Results

**Question:** What happens when you test connectivity from your Cloud Run service?

```bash
# Deploy a test container and run:
curl -s https://httpbin.org/ip
curl -s https://ifconfig.me
```

**Expected Answer:** Should return your static NAT IP address

**If returns different IP:**
> Traffic is not going through NAT. Review VPC egress and connector settings.

**If timeout:**
> Traffic is being blocked. Review firewall rules and NAT subnet configuration.

---

## Complete Diagnostic Command Set

Provide this script to the customer for comprehensive diagnostics:

```bash
#!/bin/bash
# Cloud Run Static IP Diagnostic Script

PROJECT_ID="your-project-id"
REGION="your-region"
SERVICE_NAME="your-cloud-run-service"
CONNECTOR_NAME="your-vpc-connector"
ROUTER_NAME="your-router"
NAT_NAME="your-nat"
NETWORK_NAME="your-network"

echo "=== Cloud Run Service Configuration ==="
gcloud run services describe $SERVICE_NAME --region=$REGION \
  --format="yaml(spec.template.spec.vpcAccess)"

echo ""
echo "=== VPC Connector Details ==="
gcloud compute networks vpc-access connectors describe $CONNECTOR_NAME \
  --region=$REGION

echo ""
echo "=== Cloud NAT Configuration ==="
gcloud compute routers nats describe $NAT_NAME \
  --router=$ROUTER_NAME \
  --region=$REGION

echo ""
echo "=== Cloud Router Details ==="
gcloud compute routers describe $ROUTER_NAME --region=$REGION

echo ""
echo "=== Firewall Rules (Egress) ==="
gcloud compute firewall-rules list \
  --filter="direction=EGRESS AND network=$NETWORK_NAME" \
  --format="table(name,priority,action,destinationRanges)"

echo ""
echo "=== Network Routes ==="
gcloud compute routes list \
  --filter="network=$NETWORK_NAME" \
  --format="table(name,destRange,nextHopGateway,priority)"

echo ""
echo "=== Static IP Addresses ==="
gcloud compute addresses list --filter="region=$REGION"
```

## Escalation Path

If all the above checks pass but the issue persists:

1. **Check VPC Service Controls** - Is the project inside a VPC-SC perimeter?
2. **Check Organization Policies** - Are there org policies restricting external access?
3. **Check Cloud Audit Logs** - Look for any denied API calls or network operations
4. **Contact Google Cloud Support** - With all diagnostic output collected

## Quick Reference Card

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| DNS works, public requests timeout, no NAT logs | VPC egress set to private-ranges-only | Set `--vpc-egress=all-traffic` |
| All requests timeout, no NAT logs | NAT not covering connector subnet | Use `--nat-all-subnet-ip-ranges` |
| Requests blocked immediately | Firewall deny rule | Check egress firewall rules |
| Random IP returned | NAT using auto-allocated IPs | Configure static IP for NAT |
| Connector attachment fails | Region mismatch | Create connector in same region |