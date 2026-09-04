#!/usr/bin/env bash

set -euo pipefail

FINDING_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

POLICY_FILE="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)/remediation-policy.json"

error() {
  printf 'ERROR - %s\n' "$*" >&2
  exit 2
}

command -v jq >/dev/null 2>&1 \
  || error "jq is required"

[[ -n "$FINDING_FILE" ]] \
  || error "usage: $0 <finding.json> [output.json]"

[[ -f "$FINDING_FILE" ]] \
  || error "finding file does not exist: $FINDING_FILE"

[[ -f "$POLICY_FILE" ]] \
  || error "remediation policy does not exist: $POLICY_FILE"

jq empty "$FINDING_FILE" >/dev/null 2>&1 \
  || error "finding file is not valid JSON"

jq empty "$POLICY_FILE" >/dev/null 2>&1 \
  || error "remediation policy is not valid JSON"

schema_version="$(
  jq -r '.schema_version // empty' "$FINDING_FILE"
)"

finding_id="$(
  jq -r '.finding_id // empty' "$FINDING_FILE"
)"

cloud="$(
  jq -r '.cloud // empty | ascii_downcase' "$FINDING_FILE"
)"

environment="$(
  jq -r '.environment // empty' "$FINDING_FILE"
)"

control_id="$(
  jq -r '.control_id // empty' "$FINDING_FILE"
)"

resource_type="$(
  jq -r '.resource_type // empty' "$FINDING_FILE"
)"

resource_identifier="$(
  jq -r '.resource_identifier // empty' "$FINDING_FILE"
)"

compliant="$(
  jq -r '.compliant' "$FINDING_FILE"
)"

tag_key="$(
  jq -r '.tag_key // empty' "$FINDING_FILE"
)"

desired_value="$(
  jq -r '.desired_value // empty' "$FINDING_FILE"
)"

observed_value_json="$(
  jq -c '.observed_value' "$FINDING_FILE"
)"

[[ "$schema_version" == "1.0" ]] \
  || error "unsupported finding schema version: ${schema_version:-missing}"

[[ -n "$finding_id" ]] \
  || error "finding_id is required"

[[ -n "$cloud" ]] \
  || error "cloud is required"

[[ -n "$environment" ]] \
  || error "environment is required"

[[ -n "$control_id" ]] \
  || error "control_id is required"

[[ -n "$resource_type" ]] \
  || error "resource_type is required"

[[ -n "$resource_identifier" ]] \
  || error "resource_identifier is required"

[[ "$compliant" == "true" || "$compliant" == "false" ]] \
  || error "compliant must be true or false"

[[ -n "$tag_key" ]] \
  || error "tag_key is required"

[[ -n "$desired_value" ]] \
  || error "desired_value must not be empty"

jq -e \
  --arg cloud "$cloud" \
  '.supported_clouds | index($cloud) != null' \
  "$POLICY_FILE" >/dev/null \
  || error "unsupported cloud: $cloud"

jq -e \
  --arg control "$control_id" \
  '.supported_controls | index($control) != null' \
  "$POLICY_FILE" >/dev/null \
  || error "unsupported control ID: $control_id"

jq -e \
  --arg tag "$tag_key" \
  '.supported_tag_keys | index($tag) != null' \
  "$POLICY_FILE" >/dev/null \
  || error "unsupported remediation tag: $tag_key"

jq -e \
  '.supported_actions | index("set-tag") != null' \
  "$POLICY_FILE" >/dev/null \
  || error "set-tag action is not allow-listed"

approval_required="$(
  jq -r '.human_approval_required' "$POLICY_FILE"
)"

automatic_self_healing="$(
  jq -r '.automatic_self_healing' "$POLICY_FILE"
)"

terraform_mutation_allowed="$(
  jq -r '.terraform_mutation_allowed' "$POLICY_FILE"
)"

risk_level="$(
  jq -r '.risk_levels["set-tag"] // empty' "$POLICY_FILE"
)"

[[ "$approval_required" == "true" ]] \
  || error "policy does not require human approval"

[[ "$automatic_self_healing" == "false" ]] \
  || error "automatic self-healing must remain disabled"

[[ "$terraform_mutation_allowed" == "false" ]] \
  || error "Terraform mutation must remain disabled"

[[ -n "$risk_level" ]] \
  || error "risk level is not defined for set-tag"

generated_at="$(
  date -u '+%Y-%m-%dT%H:%M:%SZ'
)"

remediation_id="rem-${finding_id}"

if [[ "$compliant" == "true" ]]; then
  decision="NO_ACTION"
  recommended_action="No remediation required because the finding is already compliant."
  decision_reason="Finding is already compliant; no remediation is required."
else
  decision="RECOMMEND"
  recommended_action="Set tag ${tag_key} to the approved value ${desired_value}."
  decision_reason="Governance finding is non-compliant and matches an allow-listed low-risk remediation."
fi

recommendation="$(
  jq -n \
    --arg schema_version "1.0" \
    --arg remediation_id "$remediation_id" \
    --arg generated_at "$generated_at" \
    --arg finding_id "$finding_id" \
    --arg cloud "$cloud" \
    --arg environment "$environment" \
    --arg control_id "$control_id" \
    --arg resource_type "$resource_type" \
    --arg resource_identifier "$resource_identifier" \
    --arg tag_key "$tag_key" \
    --argjson observed_value "$observed_value_json" \
    --arg desired_value "$desired_value" \
    --arg action_type "set-tag" \
    --arg risk_level "$risk_level" \
    --arg recommended_action "$recommended_action" \
    --arg decision "$decision" \
    --arg decision_reason "$decision_reason" \
    --argjson finding_compliant "$compliant" \
    --argjson requires_approval "$approval_required" \
    '{
      schema_version: $schema_version,

      metadata: {
        generated_at: $generated_at,
        generator: "generate-remediation-recommendation.sh"
      },

      remediation: {
        remediation_id: $remediation_id,
        finding_id: $finding_id,
        cloud: $cloud,
        environment: $environment,
        control_id: $control_id,
        action_type: $action_type,
        resource_type: $resource_type,
        resource_identifier: $resource_identifier,
        tag_key: $tag_key
      },

      before: {
        compliant: $finding_compliant,
        observed_value: $observed_value
      },

      recommendation: {
        desired_value: $desired_value,
        recommended_action: $recommended_action,
        risk_level: $risk_level,
        requires_approval: $requires_approval
      },

      execution: {
        attempted: false,
        authentication_type: "none",
        oidc_used: false,
        cloud_credentials_used: false,
        cloud_mutation_performed: false,
        terraform_mutation_performed: false
      },

      decision: {
        result: $decision,
        reason: $decision_reason
      }
    }'
)"

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"

  printf '%s\n' "$recommendation" \
    > "$OUTPUT_FILE"
else
  printf '%s\n' "$recommendation"
fi
