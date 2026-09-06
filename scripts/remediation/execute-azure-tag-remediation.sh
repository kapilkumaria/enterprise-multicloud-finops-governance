#!/usr/bin/env bash
set -euo pipefail

APPROVAL_EVIDENCE_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

error() {
  echo "AZURE REMEDIATION EXECUTION RESULT: DENY"
  echo "ERROR - $1"
  exit 1
}

[[ -n "$APPROVAL_EVIDENCE_FILE" ]] \
  || error "approval evidence file is required"

[[ -n "$OUTPUT_FILE" ]] \
  || error "output evidence file is required"

command -v jq >/dev/null 2>&1 \
  || error "jq is required"

command -v az >/dev/null 2>&1 \
  || error "Azure CLI is required"

jq empty "$APPROVAL_EVIDENCE_FILE" >/dev/null 2>&1 \
  || error "approval evidence is not valid JSON"

schema_version="$(
  jq -r '.schema_version // empty' "$APPROVAL_EVIDENCE_FILE"
)"

remediation_id="$(
  jq -r '.remediation.remediation_id // empty' "$APPROVAL_EVIDENCE_FILE"
)"

cloud="$(
  jq -r '.remediation.cloud // empty' "$APPROVAL_EVIDENCE_FILE"
)"

environment="$(
  jq -r '
    .remediation.environment
    // .metadata.environment
    // empty
  ' "$APPROVAL_EVIDENCE_FILE"
)"

action_type="$(
  jq -r '.remediation.action_type // empty' "$APPROVAL_EVIDENCE_FILE"
)"

resource_identifier="$(
  jq -r '.remediation.resource_identifier // empty' "$APPROVAL_EVIDENCE_FILE"
)"

tag_key="$(
  jq -r '.remediation.tag_key // empty' "$APPROVAL_EVIDENCE_FILE"
)"

before_value="$(
  jq -r '
    .before.observed_value
    | if . == null then "null" else tostring end
  ' "$APPROVAL_EVIDENCE_FILE"
)"

desired_value="$(
  jq -r '.recommendation.desired_value // empty' "$APPROVAL_EVIDENCE_FILE"
)"

approval_required="$(
  jq -r '.approval.required // false' "$APPROVAL_EVIDENCE_FILE"
)"

approved="$(
  jq -r '.approval.approved // false' "$APPROVAL_EVIDENCE_FILE"
)"

confirmation_verified="$(
  jq -r '.approval.confirmation_token_verified // false' "$APPROVAL_EVIDENCE_FILE"
)"

execution_attempted="$(
  jq -r '
    if .execution.attempted == null
    then true
    else .execution.attempted
    end
  ' "$APPROVAL_EVIDENCE_FILE"
)"

lifecycle="$(
  jq -r '.result.remediation_result // empty' "$APPROVAL_EVIDENCE_FILE"
)"

[[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]] || error "AZURE_SUBSCRIPTION_ID is required"
[[ -n "${AZURE_TENANT_ID:-}" ]] || error "AZURE_TENANT_ID is required"
[[ -n "${AZURE_GOVERNED_VM_ID:-}" ]] || error "AZURE_GOVERNED_VM_ID is required"

EXPECTED_VM_ID="$AZURE_GOVERNED_VM_ID"

[[ "$schema_version" == "1.0" ]] \
  || error "unsupported schema version"

[[ "$remediation_id" == "rem-finding-azure-live-tag-001" ]] \
  || error "unexpected remediation ID"

[[ "$cloud" == "azure" ]] \
  || error "unexpected cloud"

[[ "$environment" == "dev" ]] \
  || error "unexpected environment"

[[ "$action_type" == "set-tag" ]] \
  || error "unsupported action type"

[[ "$resource_identifier" == "$EXPECTED_VM_ID" ]] \
  || error "resource is outside the approved controlled-remediation target"

[[ "$tag_key" == "CostCenter" ]] \
  || error "only CostCenter remediation is allowed"

[[ "$desired_value" == "CC-PLATFORM" ]] \
  || error "desired CostCenter value is not allow-listed"

[[ "$approval_required" == "true" ]] \
  || error "approval is not marked required"

[[ "$approved" == "true" ]] \
  || error "human approval is missing"

[[ "$confirmation_verified" == "true" ]] \
  || error "confirmation token was not verified"

[[ "$execution_attempted" == "false" ]] \
  || error "evidence indicates execution was already attempted"

[[ "$lifecycle" == "APPROVED_PENDING_EXECUTION" ]] \
  || error "invalid remediation lifecycle state"

echo "PASS - approved remediation evidence validated"

subscription_id="$(
  az account show \
    --query id \
    --output tsv
)"

tenant_id="$(
  az account show \
    --query tenantId \
    --output tsv
)"

signed_in_user_type="$(
  az account show \
    --query user.type \
    --output tsv
)"

signed_in_identity="$(
  az account show \
    --query user.name \
    --output tsv
)"

[[ "$subscription_id" == "$AZURE_SUBSCRIPTION_ID" ]] \
  || error "unexpected Azure subscription"

[[ "$tenant_id" == "$AZURE_TENANT_ID" ]] \
  || error "unexpected Azure tenant"

[[ "$signed_in_user_type" == "servicePrincipal" ]] \
  || error "Azure authentication is not using a service principal"

[[ -n "${AZURE_REMEDIATION_CLIENT_ID:-}" ]] \
  || error "AZURE_REMEDIATION_CLIENT_ID is required"

[[ "$signed_in_identity" == "$AZURE_REMEDIATION_CLIENT_ID" ]] \
  || error "dedicated Azure remediation identity is not active"

echo "PASS - dedicated Azure remediation identity active"

project_tag="$(
  az resource show \
    --ids "$resource_identifier" \
    --query 'tags.Project' \
    --output tsv
)"

environment_tag="$(
  az resource show \
    --ids "$resource_identifier" \
    --query 'tags.Environment' \
    --output tsv
)"

[[ "$project_tag" == "enterprise-multicloud-finops-governance" ]] \
  || error "live Project guard tag is invalid"

[[ "$environment_tag" == "dev" ]] \
  || error "live Environment guard tag is invalid"

echo "PASS - governed Azure resource verified"

live_before="$(
  az resource show \
    --ids "$resource_identifier" \
    --query 'tags.CostCenter' \
    --output tsv
)"

[[ -n "$live_before" ]] || live_before="null"

[[ "$live_before" == "$before_value" ]] \
  || error "live before-state does not match approved evidence"

echo "PASS - live before-state matches approved evidence"

az tag update \
  --resource-id "$resource_identifier" \
  --operation Merge \
  --tags "${tag_key}=${desired_value}" \
  >/dev/null

echo "PASS - approved CostCenter mutation executed"

live_after="$(
  az resource show \
    --ids "$resource_identifier" \
    --query 'tags.CostCenter' \
    --output tsv
)"

[[ "$live_after" == "$desired_value" ]] \
  || error "post-remediation value does not match approved desired value"

echo "PASS - post-remediation value verified"

executed_at="$(
  date -u '+%Y-%m-%dT%H:%M:%SZ'
)"

mkdir -p "$(dirname "$OUTPUT_FILE")"

jq \
  --arg executed_at "$executed_at" \
  --arg executor_identity "$signed_in_identity" \
  --arg live_after "$live_after" \
  '
    .execution = {
      attempted: true,
      authentication_type: "github-oidc",
      oidc_used: true,
      cloud_credentials_used: true,
      cloud_mutation_performed: true,
      terraform_mutation_performed: false,
      dedicated_remediation_identity: true,
      executed_at: $executed_at,
      executor_identity: $executor_identity,
      command_class: "azure-tag-update"
    }
    |
    .after = {
      compliant: true,
      observed_value: $live_after
    }
    |
    .result = {
      remediation_result: "EXECUTED",
      verification_result: "PASS",
      reason: "Approved Azure CostCenter remediation executed and independently verified."
    }
  ' "$APPROVAL_EVIDENCE_FILE" \
  > "$OUTPUT_FILE"

echo
echo "AZURE REMEDIATION EXECUTION RESULT: PASS"
