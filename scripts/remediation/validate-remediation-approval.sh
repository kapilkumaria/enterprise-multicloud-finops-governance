#!/usr/bin/env bash

set -euo pipefail

RECOMMENDATION_FILE="${1:-}"
PREAPPROVAL_EVIDENCE_FILE="${2:-}"
REQUESTED_REMEDIATION_ID="${3:-}"
REQUESTED_CLOUD="${4:-}"
REQUESTED_RESOURCE_IDENTIFIER="${5:-}"
REQUESTED_ACTION_TYPE="${6:-}"
REQUESTED_TAG_KEY="${7:-}"
REQUESTED_CURRENT_VALUE="${8:-}"
REQUESTED_DESIRED_VALUE="${9:-}"
CONFIRMATION_TOKEN="${10:-}"
OUTPUT_FILE="${11:-}"

error() {
  printf 'REMEDIATION APPROVAL RESULT: DENY\n' >&2
  printf 'ERROR - %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 \
  || error "jq is required"

[[ -n "$RECOMMENDATION_FILE" ]] \
  || error "recommendation file is required"

[[ -n "$PREAPPROVAL_EVIDENCE_FILE" ]] \
  || error "pre-approval evidence file is required"

[[ -f "$RECOMMENDATION_FILE" ]] \
  || error "recommendation file does not exist: $RECOMMENDATION_FILE"

[[ -f "$PREAPPROVAL_EVIDENCE_FILE" ]] \
  || error "pre-approval evidence file does not exist: $PREAPPROVAL_EVIDENCE_FILE"

jq empty "$RECOMMENDATION_FILE" >/dev/null 2>&1 \
  || error "recommendation file is not valid JSON"

jq empty "$PREAPPROVAL_EVIDENCE_FILE" >/dev/null 2>&1 \
  || error "pre-approval evidence file is not valid JSON"

recommendation_schema="$(
  jq -r '.schema_version // empty' "$RECOMMENDATION_FILE"
)"

decision="$(
  jq -r '.decision.result // empty' "$RECOMMENDATION_FILE"
)"

remediation_id="$(
  jq -r '.remediation.remediation_id // empty' "$RECOMMENDATION_FILE"
)"

cloud="$(
  jq -r '.remediation.cloud // empty' "$RECOMMENDATION_FILE"
)"

resource_identifier="$(
  jq -r '.remediation.resource_identifier // empty' "$RECOMMENDATION_FILE"
)"

action_type="$(
  jq -r '.remediation.action_type // empty' "$RECOMMENDATION_FILE"
)"

tag_key="$(
  jq -r '.remediation.tag_key // empty' "$RECOMMENDATION_FILE"
)"

observed_value="$(
  jq -c '.before.observed_value' "$RECOMMENDATION_FILE"
)"

desired_value="$(
  jq -r '.recommendation.desired_value // empty' "$RECOMMENDATION_FILE"
)"

requires_approval="$(
  jq -r '.recommendation.requires_approval' "$RECOMMENDATION_FILE"
)"

preapproval_remediation_id="$(
  jq -r '.remediation.remediation_id // empty' \
    "$PREAPPROVAL_EVIDENCE_FILE"
)"

preapproval_result="$(
  jq -r '.result.remediation_result // empty' \
    "$PREAPPROVAL_EVIDENCE_FILE"
)"

preapproval_approved="$(
  jq -r '.approval.approved' \
    "$PREAPPROVAL_EVIDENCE_FILE"
)"

preapproval_execution_attempted="$(
  jq -r '.execution.attempted' \
    "$PREAPPROVAL_EVIDENCE_FILE"
)"

preapproval_oidc_used="$(
  jq -r '.execution.oidc_used' \
    "$PREAPPROVAL_EVIDENCE_FILE"
)"

[[ "$recommendation_schema" == "1.0" ]] \
  || error "unsupported recommendation schema"

[[ "$decision" == "RECOMMEND" ]] \
  || error "recommendation decision must be RECOMMEND"

[[ "$requires_approval" == "true" ]] \
  || error "recommendation does not require human approval"

[[ "$preapproval_remediation_id" == "$remediation_id" ]] \
  || error "pre-approval evidence does not match recommendation"

[[ "$preapproval_result" == "PENDING_APPROVAL" ]] \
  || error "evidence is not in PENDING_APPROVAL state"

[[ "$preapproval_approved" == "false" ]] \
  || error "request was already approved"

[[ "$preapproval_execution_attempted" == "false" ]] \
  || error "execution has already been attempted"

[[ "$preapproval_oidc_used" == "false" ]] \
  || error "OIDC must not have been used before approval"

[[ "$REQUESTED_REMEDIATION_ID" == "$remediation_id" ]] \
  || error "remediation ID does not match recommendation"

[[ "$REQUESTED_CLOUD" == "$cloud" ]] \
  || error "cloud does not match recommendation"

[[ "$REQUESTED_RESOURCE_IDENTIFIER" == "$resource_identifier" ]] \
  || error "resource identifier does not match recommendation"

[[ "$REQUESTED_ACTION_TYPE" == "$action_type" ]] \
  || error "action type does not match recommendation"

[[ "$REQUESTED_TAG_KEY" == "$tag_key" ]] \
  || error "tag key does not match recommendation"

[[ "$REQUESTED_CURRENT_VALUE" == "$observed_value" ]] \
  || error "current value does not match recommendation"

[[ "$REQUESTED_DESIRED_VALUE" == "$desired_value" ]] \
  || error "desired value does not match recommendation"

EXPECTED_CONFIRMATION_TOKEN="APPROVE:${remediation_id}"

[[ "$CONFIRMATION_TOKEN" == "$EXPECTED_CONFIRMATION_TOKEN" ]] \
  || error "confirmation token is invalid"

approved_at="$(
  date -u '+%Y-%m-%dT%H:%M:%SZ'
)"

approved_by="${GITHUB_ACTOR:-local-operator}"
workflow_run_id="${GITHUB_RUN_ID:-local}"
repository="${GITHUB_REPOSITORY:-local}"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"

approval_evidence="$(
  jq \
    --arg approved_at "$approved_at" \
    --arg approved_by "$approved_by" \
    --arg repository "$repository" \
    --arg commit "$commit" \
    --arg workflow_run_id "$workflow_run_id" \
    '
    .metadata.repository = $repository
    | .metadata.commit = $commit
    | .metadata.workflow_run_id = $workflow_run_id

    | .approval.model = "workflow_dispatch-confirmation-token"
    | .approval.approved = true
    | .approval.approved_at = $approved_at
    | .approval.approved_by = $approved_by
    | .approval.confirmation_token_verified = true

    | .execution.attempted = false
    | .execution.authentication_type = "none"
    | .execution.oidc_used = false
    | .execution.dedicated_remediation_identity = false
    | .execution.command_class = "none"

    | .after.compliant = null
    | .after.observed_value = null

    | .result.remediation_result = "APPROVED_PENDING_EXECUTION"
    | .result.verification_result = "NOT_ATTEMPTED"
    | .result.reason =
        "Human approval validated successfully; remediation execution has not yet been attempted."
    ' \
    "$PREAPPROVAL_EVIDENCE_FILE"
)"

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  printf '%s\n' "$approval_evidence" > "$OUTPUT_FILE"
else
  printf '%s\n' "$approval_evidence"
fi

echo "PASS - remediation recommendation matched"
echo "PASS - pre-approval evidence matched"
echo "PASS - requested cloud matched"
echo "PASS - requested resource matched"
echo "PASS - requested action matched"
echo "PASS - requested tag matched"
echo "PASS - current value matched"
echo "PASS - desired value matched"
echo "PASS - confirmation token verified"
echo "PASS - no cloud authentication performed"
echo "PASS - no remediation execution attempted"
echo
echo "REMEDIATION APPROVAL RESULT: ALLOW"
