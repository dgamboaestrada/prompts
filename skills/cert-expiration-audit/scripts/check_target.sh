#!/usr/bin/env bash
# Read-only helper for cert-expiration-audit: does a DNS target (ELB/ALB/CloudFront) still exist?
# Usage: check_target.sh <target-hostname> [region]
set -euo pipefail

TARGET="${1:-}"
REGION="${2:-us-west-2}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target-hostname> [region]" >&2
  exit 1
fi

if [[ "$TARGET" == *.cloudfront.net ]]; then
  echo "=== CloudFront distribution: $TARGET ==="
  MATCH=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?DomainName=='${TARGET}']" --output json 2>/dev/null || echo "[]")
  if [[ "$MATCH" != "[]" && -n "$MATCH" ]]; then
    echo "Found in this account:"
    echo "$MATCH" | jq '.'
  else
    echo "NOT found among this account's CloudFront distributions."
    echo "This usually means the distribution belongs to a different AWS account — treat as 'Report', not 'Do not renew', unless the user confirms otherwise."
  fi
  exit 0
fi

if [[ "$TARGET" == *.elb.amazonaws.com ]]; then
  # Classic ELB names look like "internal-name-1234567890" or "name-1234567890"; strip the numeric suffix and region.
  LB_NAME=$(echo "$TARGET" | sed -E 's/^(internal-)?([a-zA-Z0-9-]+)-[0-9]+\..*/\2/')

  echo "=== Trying as ALB/NLB (elbv2): $LB_NAME ==="
  if aws elbv2 describe-load-balancers --region "$REGION" --names "$LB_NAME" >/tmp/elbv2_out.json 2>/tmp/elbv2_err.txt; then
    cat /tmp/elbv2_out.json
    exit 0
  else
    grep -i "LoadBalancerNotFound\|not found" /tmp/elbv2_err.txt >/dev/null && echo "Not found as ALB/NLB." || cat /tmp/elbv2_err.txt
  fi

  echo "=== Trying as classic ELB: $LB_NAME ==="
  if aws elb describe-load-balancers --region "$REGION" --load-balancer-names "$LB_NAME" >/tmp/elb_out.json 2>/tmp/elb_err.txt; then
    cat /tmp/elb_out.json
    exit 0
  else
    if grep -qi "LoadBalancerNotFound" /tmp/elb_err.txt; then
      echo "LoadBalancerNotFound — this ELB/ALB has been deleted. The DNS record pointing at it is orphaned."
    else
      cat /tmp/elb_err.txt
    fi
  fi
  exit 0
fi

echo "Target '$TARGET' doesn't match known ELB/ALB/CloudFront naming patterns."
echo "Check manually — could be a direct IP, Akamai (edgekey.net/akamaiedge.net), WordPress VIP (go-vip.net), or another AWS account's resource."
