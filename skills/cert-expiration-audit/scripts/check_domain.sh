#!/usr/bin/env bash
# Read-only helper for cert-expiration-audit: DNS (internal+external) + ACM lookup by domain.
# Usage: check_domain.sh <domain> [--regions us-east-1,us-west-2] [--internal-resolver <ip>] [--external-resolver <ip>]
set -euo pipefail

DOMAIN=""
REGIONS="us-east-1,us-west-1,us-west-2"
EXTERNAL_RESOLVER="8.8.8.8"
INTERNAL_RESOLVER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --regions) REGIONS="$2"; shift 2 ;;
    --internal-resolver) INTERNAL_RESOLVER="$2"; shift 2 ;;
    --external-resolver) EXTERNAL_RESOLVER="$2"; shift 2 ;;
    *) DOMAIN="$1"; shift ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 <domain> [--regions r1,r2,...] [--internal-resolver ip] [--external-resolver ip]" >&2
  exit 1
fi

echo "=== DNS: $DOMAIN ==="
echo "-- external (@${EXTERNAL_RESOLVER}) --"
dig +short "@${EXTERNAL_RESOLVER}" "$DOMAIN" || echo "(no answer / NXDOMAIN)"

if [[ -n "$INTERNAL_RESOLVER" ]]; then
  echo "-- internal (@${INTERNAL_RESOLVER}) --"
  dig +short "@${INTERNAL_RESOLVER}" "$DOMAIN" || echo "(no answer / NXDOMAIN)"
fi

echo
echo "=== ACM lookup: $DOMAIN ==="
IFS=',' read -ra REGION_ARR <<< "$REGIONS"
FOUND=0
for region in "${REGION_ARR[@]}"; do
  echo "-- region: $region --"
  MATCH=$(aws acm list-certificates --region "$region" \
    --certificate-statuses ISSUED EXPIRED PENDING_VALIDATION \
    --query "CertificateSummaryList[?DomainName=='${DOMAIN}']" --output json 2>/dev/null || echo "[]")

  if [[ "$MATCH" != "[]" && -n "$MATCH" ]]; then
    FOUND=1
    ARN=$(echo "$MATCH" | jq -r '.[0].CertificateArn')
    echo "Found: $ARN"
    aws acm describe-certificate --region "$region" --certificate-arn "$ARN" \
      --query "Certificate.{DomainName:DomainName,SANs:SubjectAlternativeNames,InUseBy:InUseBy,Status:Status,NotAfter:NotAfter,Serial:Serial}" \
      --output json
  else
    echo "(not found in $region)"
  fi
done

if [[ "$FOUND" -eq 0 ]]; then
  echo
  echo "No ACM match in any of: $REGIONS"
  echo "Check for non-AWS hosting (Akamai edgekey.net/akamaiedge.net, WordPress go-vip.net, direct IP) or a different AWS account."
fi
