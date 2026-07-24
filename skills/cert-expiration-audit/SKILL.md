---
name: cert-expiration-audit
description: |
  Invoke whenever the user needs to audit a list of expiring or soon-to-expire TLS/SSL certificates against AWS (ACM, ELB/ALB, CloudFront) to decide which ones to renew. Trigger on phrases like "audit these certificates before they expire", "check which of these domains are still in use", "we got an AWS Certificate Manager expiration notice for a bunch of domains", "classify these certs as renew / don't renew", or when the user pastes/attaches a list of Common Names with expiration dates and serials (e.g. from an ACM export or an AWS Health notification) and wants to know which are safe to let expire.

  This skill's purpose: for each certificate, resolve DNS (internal and external resolvers), search AWS Certificate Manager across regions, fall back to checking Subject Alternative Names when the primary Common Name no longer resolves, verify whether the DNS target (ELB/ALB/CloudFront) still exists, detect non-AWS hosting (Akamai, WordPress VIP, direct IP, other AWS accounts), and produce a per-domain evidence log plus a final results table classifying each certificate as Renew / Do not renew / Report (out of scope).

  Do NOT invoke for: provisioning or requesting new certificates, renewing/deleting/modifying an actual ACM certificate or AWS resource (this skill is read-only/audit-only), general AWS cost audits unrelated to certificates, or one-off "is this single cert expiring" questions that don't need a structured audit.
license: MIT
metadata:
  author: Daniel Gamboa Estrada
  version: "0.1.0"
  category: security
  tags:
    - aws
    - acm
    - tls
    - certificates
    - dns
    - audit
    - sre
---

# Certificate Expiration Audit

You are auditing a batch of TLS/SSL certificates that are expiring soon (typically surfaced via an AWS Health/ACM expiration notice) to decide, for each one, whether it should be **renewed**, **not renewed**, or **reported** as out of scope. The core question for every certificate is the same: *is anything actually still using this domain?* Everything else in this skill is evidence-gathering toward that one question.

This is a **read-only audit**. Never renew, delete, re-request, or modify a certificate or any AWS resource as part of this skill — the deliverable is a classification and the evidence behind it, not an action. If the user's request implies making changes, stop and confirm with them separately; that is outside this skill's scope.

## Inputs you need before starting

- The list of certificates: Common Name, expiration date, serial number (and ideally the ARN or region if already known). If the user only pastes a raw AWS Health notification, extract these fields from it.
- Which AWS account/profile and which regions to search. Don't assume — ask if it isn't obvious from context (e.g. from `aws configure list-profiles` or a CLAUDE.md). Most orgs concentrate certs in 2-3 regions; once you learn which ones for this account, reuse them for the rest of the batch instead of re-asking.
- Whether there's an internal DNS resolver (VPN/VPC resolver) reachable, in addition to a public one. Internal-only records won't show up from `8.8.8.9` alone, and a domain that's dead externally but alive internally is still in use.

## Workflow: batch through every domain without stopping to ask permission

Audits like this are read-only by nature, so once you have the inputs above, process every domain in the list back-to-back — don't pause after each one to ask "should I continue?". The moment you should stop and ask the user is when a finding is genuinely ambiguous and guessing would risk a wrong classification (see "When to flag instead of guess" below), not as a matter of routine.

For **each** certificate, in order:

### 1. Resolve DNS, internal and external

Run `dig +short <domain>` against both an internal resolver (if available) and a public one (`8.8.8.8` or similar), and compare. Three outcomes:

- **Resolves the same both ways, to a live target** → good sign the domain is active; move to step 3.
- **Resolves only internally** → still in use, just not internet-facing. Treat as active.
- **NXDOMAIN both ways** → don't conclude "unused" yet. Go to step 2 (SAN fallback) before giving up on it.

### 2. SAN fallback when the primary CN is dead

A certificate's primary Common Name going dark doesn't mean the certificate is unused — check its other Subject Alternative Names. Pull the SAN list from ACM (`describe-certificate`, see step 3) or from the input if already provided, and re-run the DNS check from step 1 against each SAN. It's common for a service to be renamed or accessed by an alternate hostname while the original CN bitrots. If **any** SAN resolves to something live, the certificate is in use — classify accordingly and note which SAN saved it.

Only conclude "genuinely dead" if the primary CN and every SAN are NXDOMAIN (or resolve to nothing that traces back to a real resource).

### 3. Search ACM across the target regions

For each region in scope, look for the certificate by domain name:

```bash
aws acm list-certificates --region <region> --certificate-statuses ISSUED EXPIRED \
  --query "CertificateSummaryList[?DomainName=='<domain>']" --output json
```

`scripts/check_domain.sh` wraps steps 1-3 into one command — see "Bundled scripts" below.

When you find the certificate, `describe-certificate` for its `InUseBy` list, status, and full SAN set:

```bash
aws acm describe-certificate --region <region> --certificate-arn <arn> \
  --query "Certificate.{DomainName:DomainName,SANs:SubjectAlternativeNames,InUseBy:InUseBy,Status:Status,NotAfter:NotAfter}"
```

`InUseBy` is direct evidence — if it lists a load balancer or CloudFront distribution ARN, the cert is actively attached to something, independent of what DNS shows. `InUse: false` with dead DNS is your strongest "do not renew" signal; treat it as a signal, not a rule, and back it with the DNS/target-existence evidence rather than citing "InUse: false" alone.

If the certificate isn't in any of the regions you searched, it may not be an AWS-managed cert at all — see step 5 (non-AWS hosting) before concluding it's simply missing.

### 4. Verify the DNS target actually exists

DNS can lag behind reality — a CNAME can point at a load balancer or distribution that was deleted long ago, which is exactly the kind of orphaned record that produces a false "looks active" read in step 1. Once you know what the domain resolves to, confirm the target itself is real:

- **Classic ELB** (`*.elb.amazonaws.com`, older naming): `aws elb describe-load-balancers --region <region> --load-balancer-names <name>` — a `LoadBalancerNotFound` error means the DNS record is orphaned.
- **ALB/NLB** (elbv2): `aws elbv2 describe-load-balancers --region <region> --names <name>`.
- **CloudFront** (`*.cloudfront.net`): `aws cloudfront list-distributions --query "DistributionList.Items[?DomainName=='<target>']"`. If it's not in this account's distribution list, the distribution likely belongs to a **different AWS account** — this is a "report" case, not necessarily "unused" (see "When to flag instead of guess").

`scripts/check_target.sh <target> [region]` automates the pattern-matching and lookup for a given CNAME/target value.

### 5. Recognize non-AWS hosting

Not every certificate you're auditing lives in this account's AWS footprint. The reliable tell is usually the hostname at the end of the CNAME chain — most CDNs and PaaS providers put a recognizable suffix there, so you can usually place a domain without needing console access to the other platform. These are examples of patterns to watch for, not an exhaustive list — the same reasoning applies to whatever provider you actually encounter:

- **Akamai CDN**: hostname ends in `edgekey.net` or `akamaiedge.net`.
- **WordPress VIP**: hostname ends in `go-vip.net`.
- **Cloudflare**: hostname resolves through Cloudflare's proxy IP ranges, or the CNAME target ends in `cdn.cloudflare.net`.
- **Fastly**: CNAME target ends in `fastly.net` or `fastlylb.net`.
- **Azure**: target ends in `azurewebsites.net`, `azureedge.net`, or `trafficmanager.net`.
- **Google Cloud**: target resolves to a Google Front End IP or ends in `googlehosted.com` / `ghs.googlehosted.com`.
- **Heroku**: target ends in `herokudns.com` or `herokuapp.com`.
- **Direct IP with no AWS PTR/ASN**: resolves to a bare IP that doesn't belong to an AWS range or match any ELB/CloudFront/CDN naming pattern — often a third-party host you'll need to identify from the ASN/WHOIS or ask the user about.

These are inferred from the CNAME chain or IP range, not verified inside that provider's own console — say so if the user asks how you know. A domain hosted this way can still be very much alive; it's just outside this AWS account's ACM/ELB/CloudFront scope, which makes it a **Report** case rather than **Renew** or **Do not renew** (this skill can't act on certs it doesn't manage).

### 6. Classify

Once you have DNS, ACM, and target-existence evidence for a domain, assign exactly one of:

- **Renew** — something real (ELB, ALB, CloudFront, internal service) is still resolving to and/or `InUseBy` references this certificate.
- **Do not renew** — DNS is dead (CN and every SAN), or DNS points at a target that no longer exists, and ACM confirms `InUse: false`. Recommend letting it expire, not renewing.
- **Report** — the domain is demonstrably alive but the certificate/resource lives outside this AWS account's ACM (a different account, a CDN, WordPress VIP, or another platform entirely). Flag it for whoever owns that scope; don't guess a renew/don't-renew verdict for infrastructure you can't see into.

## When to flag instead of guess

Most domains in a batch like this resolve cleanly into one of the three buckets above from the evidence alone. A few won't — and those are worth surfacing to the user rather than picking the most likely answer, because a wrong guess here becomes a real outage (if you say "don't renew" on something actually in use) or noise (if you say "report" on something you could have just confirmed).

Flag rather than guess when:

- A DNS target (e.g. a CloudFront distribution) doesn't show up in the account you're searching — it might belong to a sibling AWS account the user has access to but you don't. Report it as "active but outside this account's scope, possibly in another account" rather than asserting it's unused.
- Evidence is genuinely split (e.g. DNS is dead but the cert's `InUseBy` is non-empty, or vice versa).
- The user later tells you they independently verified something (e.g. "this cert is actually in account X, still in use") — take that finding at face value, update your classification and evidence log to match, and don't re-investigate or second-guess it unless they ask you to. They're closing a gap you couldn't see from where you're standing, not asking for a review of their conclusion.

## Deliverables

Produce two documents per audit (see `assets/` for starting templates):

1. **Process log** (`assets/process-log-template.md`) — one section per domain, with the DNS/ACM/target commands you ran and their raw output, ending in a one-line conclusion. This is the audit trail — write enough that someone else could re-derive your classification from it without rerunning anything.
2. **Results table** (`assets/results-table-template.md`, and `.csv` if the user wants a shareable/spreadsheet-friendly version) — one row per domain: `#, Common Name, Expires, Serial, DNS resolves to, In ACM?, Region, Associated resource, Recommendation`. Keep this table free of the command-by-command evidence — that belongs in the process log — but the "Associated resource" and "Recommendation" columns should say *why* in a phrase (e.g. "Renew — in use via alternate SAN", "Do not renew — ELB deleted, cert unused").

Match the language of the ticket/request — if the user is working in Spanish, write both deliverables in Spanish; translate to English (or produce a parallel English + CSV version) only if the user asks to, e.g. to share results externally.

## Bundled scripts

- `scripts/check_domain.sh <domain> [--regions us-east-1,us-west-2,...] [--internal-resolver <ip>] [--external-resolver <ip>]` — runs the DNS (internal + external) and ACM-by-region lookup from steps 1 and 3 in one shot, and prints `describe-certificate` details (SANs, InUseBy, status) for any match found.
- `scripts/check_target.sh <target> [region]` — given a resolved CNAME target, detects whether it's a classic ELB, ALB/NLB, or CloudFront distribution and checks whether that resource still exists in the current account/region.

Both scripts only ever call read-only `describe`/`list`/`dig` operations — nothing they run can modify or delete a resource.
