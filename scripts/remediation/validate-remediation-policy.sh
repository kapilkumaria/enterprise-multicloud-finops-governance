#!/usr/bin/env bash

set -u

POLICY_FILE="${1:-scripts/remediation/remediation-policy.json}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR - jq is required"
  exit 2
fi

if [[ ! -f "$POLICY_FILE" ]]; then
  echo "ERROR - remediation policy not found: $POLICY_FILE"
  exit 2
fi

if ! jq empty "$POLICY_FILE" >/dev/null 2>&1; then
  echo "ERROR - remediation policy is not valid JSON"
  exit 2
fi

fail=0

check() {
  local description="$1"
  local expression="$2"

  if jq -e "$expression" "$POLICY_FILE" >/dev/null; then
    echo "PASS - $description"
  else
    echo "FAIL - $description"
    fail=1
  fi
}

check \
  "automatic self-healing disabled" \
  '.automatic_self_healing == false'

check \
  "human approval required" \
  '.human_approval_required == true'

check \
  "Terraform mutation disabled" \
  '.terraform_mutation_allowed == false'

check \
  "AWS supported" \
  '.supported_clouds | index("aws") != null'

check \
  "Azure supported" \
  '.supported_clouds | index("azure") != null'

check \
  "set-tag is allow-listed" \
  '.supported_actions | index("set-tag") != null'

check \
  "dedicated remediation identity required" \
  '.requirements.dedicated_remediation_identity == true'

check \
  "OIDC required" \
  '.requirements.oidc_required == true'

check \
  "before-state required" \
  '.requirements.before_state_required == true'

check \
  "after-state required" \
  '.requirements.after_state_required == true'

check \
  "verification required" \
  '.requirements.verification_required == true'

check \
  "audit evidence required" \
  '.requirements.audit_evidence_required == true'

check \
  "fail-closed behavior required" \
  '.requirements.fail_closed == true'

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "REMEDIATION SAFETY RESULT: DENY"
  exit 1
fi

echo
echo "REMEDIATION SAFETY RESULT: ALLOW"
exit 0
