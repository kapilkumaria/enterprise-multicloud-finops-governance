#!/usr/bin/env bash

set -u

FILE="${1:-}"

if [[ -z "$FILE" ]]; then
  echo "ERROR - usage: $0 <evidence.json>" >&2
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "ERROR - evidence file not found: $FILE" >&2
  exit 2
fi

if ! jq empty "$FILE" >/dev/null 2>&1; then
  echo "ERROR - evidence is not valid JSON" >&2
  exit 2
fi

fail=0

check() {
  local description="$1"
  local expression="$2"

  if jq -e "$expression" "$FILE" >/dev/null; then
    echo "PASS - $description"
  else
    echo "FAIL - $description"
    fail=1
  fi
}

check \
  "schema version supported" \
  '.schema_version == "1.0"'

check \
  "cloud supported" \
  '.remediation.cloud == "aws" or .remediation.cloud == "azure"'

check \
  "action is set-tag" \
  '.remediation.action_type == "set-tag"'

check \
  "approval required" \
  '.approval.required == true'

check \
  "not approved before execution" \
  '.approval.approved == false'

check \
  "execution not attempted" \
  '.execution.attempted == false'

check \
  "OIDC not used yet" \
  '.execution.oidc_used == false'

check \
  "dedicated remediation identity not used yet" \
  '.execution.dedicated_remediation_identity == false'

check \
  "after-state not fabricated" \
  '.after.compliant == null and .after.observed_value == null'

check \
  "valid lifecycle result" \
  '
    .result.remediation_result == "PENDING_APPROVAL"
    or
    .result.remediation_result == "NO_ACTION"
  '

if [[ "$fail" -ne 0 ]]; then
  echo
  echo "REMEDIATION EVIDENCE RESULT: DENY"
  exit 1
fi

echo
echo "REMEDIATION EVIDENCE RESULT: ALLOW"
exit 0
