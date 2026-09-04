#!/usr/bin/env bash

set -euo pipefail

RECOMMENDATION_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

error() {
  printf 'ERROR - %s\n' "$*" >&2
  exit 2
}

command -v jq >/dev/null 2>&1 \
  || error "jq is required"

[[ -n "$RECOMMENDATION_FILE" ]] \
  || error "usage: $0 <recommendation.json> [output.json]"

[[ -f "$RECOMMENDATION_FILE" ]] \
  || error "recommendation file does not exist: $RECOMMENDATION_FILE"

jq empty "$RECOMMENDATION_FILE" >/dev/null 2>&1 \
  || error "recommendation file is not valid JSON"

schema_version="$(
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

environment="$(
  jq -r '.remediation.environment // empty' "$RECOMMENDATION_FILE"
)"

control_id="$(
  jq -r '.remediation.control_id // empty' "$RECOMMENDATION_FILE"
)"

action_type="$(
  jq -r '.remediation.action_type // empty' "$RECOMMENDATION_FILE"
)"

resource_type="$(
  jq -r '.remediation.resource_type // empty' "$RECOMMENDATION_FILE"
)"

resource_identifier="$(
  jq -r '.remediation.resource_identifier // empty' "$RECOMMENDATION_FILE"
)"

tag_key="$(
  jq -r '.remediation.tag_key // empty' "$RECOMMENDATION_FILE"
)"

requires_approval="$(
  jq -r '.recommendation.requires_approval' "$RECOMMENDATION_FILE"
)"

risk_level="$(
  jq -r '.recommendation.risk_level // empty' "$RECOMMENDATION_FILE"
)"

desired_value="$(
  jq -r '.recommendation.desired_value // empty' "$RECOMMENDATION_FILE"
)"

observed_value_json="$(
  jq -c '.before.observed_value' "$RECOMMENDATION_FILE"
)"

before_compliant="$(
  jq -r '.before.compliant' "$RECOMMENDATION_FILE"
)"

[[ "$schema_version" == "1.0" ]] \
  || error "unsupported recommendation schema version"

[[ -n "$remediation_id" ]] \
  || error "remediation_id is required"

[[ "$cloud" == "aws" || "$cloud" == "azure" ]] \
  || error "unsupported cloud"

[[ "$action_type" == "set-tag" ]] \
  || error "unsupported action_type"

[[ "$requires_approval" == "true" ]] \
  || error "recommendation must require approval"

[[ "$risk_level" == "low" ]] \
  || error "unexpected remediation risk level"

[[ -n "$resource_identifier" ]] \
  || error "resource identifier is required"

[[ -n "$tag_key" ]] \
  || error "tag key is required"

[[ -n "$desired_value" ]] \
  || error "desired value is required"

generated_at="$(
  date -u '+%Y-%m-%dT%H:%M:%SZ'
)"

repository="${GITHUB_REPOSITORY:-local}"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
workflow="${GITHUB_WORKFLOW:-local}"
workflow_run_id="${GITHUB_RUN_ID:-local}"
event="${GITHUB_EVENT_NAME:-local}"

if [[ "$decision" == "RECOMMEND" ]]; then
  remediation_result="PENDING_APPROVAL"
  verification_result="NOT_ATTEMPTED"
  reason="Recommendation generated successfully; controlled remediation has not been approved or executed."
elif [[ "$decision" == "NO_ACTION" ]]; then
  remediation_result="NO_ACTION"
  verification_result="NOT_REQUIRED"
  reason="Finding is already compliant; no remediation is required."
else
  error "unsupported recommendation decision: $decision"
fi

evidence="$(
  jq -n \
    --arg schema_version "1.0" \
    --arg generated_at "$generated_at" \
    --arg repository "$repository" \
    --arg commit "$commit" \
    --arg workflow "$workflow" \
    --arg workflow_run_id "$workflow_run_id" \
    --arg event "$event" \
    --arg environment "$environment" \
    --arg remediation_id "$remediation_id" \
    --arg cloud "$cloud" \
    --arg control_id "$control_id" \
    --arg action_type "$action_type" \
    --arg resource_type "$resource_type" \
    --arg resource_identifier "$resource_identifier" \
    --arg tag_key "$tag_key" \
    --argjson before_compliant "$before_compliant" \
    --argjson observed_value "$observed_value_json" \
    --arg desired_value "$desired_value" \
    --arg risk_level "$risk_level" \
    --argjson requires_approval "$requires_approval" \
    --arg remediation_result "$remediation_result" \
    --arg verification_result "$verification_result" \
    --arg reason "$reason" \
    '{
      schema_version: $schema_version,

      metadata: {
        repository: $repository,
        commit: $commit,
        workflow: $workflow,
        workflow_run_id: $workflow_run_id,
        event: $event,
        environment: $environment,
        generated_at: $generated_at
      },

      remediation: {
        remediation_id: $remediation_id,
        cloud: $cloud,
        control_id: $control_id,
        action_type: $action_type,
        resource_type: $resource_type,
        resource_identifier: $resource_identifier,
        tag_key: $tag_key
      },

      before: {
        compliant: $before_compliant,
        observed_value: $observed_value
      },

      recommendation: {
        desired_value: $desired_value,
        recommended_action:
          ("Set tag " + $tag_key + " to the approved value " + $desired_value + "."),
        risk_level: $risk_level,
        requires_approval: $requires_approval
      },

      approval: {
        required: $requires_approval,
        model: "not-yet-executed",
        approved: false
      },

      execution: {
        attempted: false,
        authentication_type: "none",
        oidc_used: false,
        dedicated_remediation_identity: false,
        command_class: "none"
      },

      after: {
        compliant: null,
        observed_value: null
      },

      result: {
        remediation_result: $remediation_result,
        verification_result: $verification_result,
        reason: $reason
      }
    }'
)"

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  printf '%s\n' "$evidence" > "$OUTPUT_FILE"
else
  printf '%s\n' "$evidence"
fi
