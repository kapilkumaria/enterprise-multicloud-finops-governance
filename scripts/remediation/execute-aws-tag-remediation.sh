#!/usr/bin/env bash

set -euo pipefail

APPROVAL_EVIDENCE_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

error() {
  printf 'AWS REMEDIATION EXECUTION RESULT: DENY\n' >&2
  printf 'ERROR - %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 \
  || error "jq is required"

command -v aws >/dev/null 2>&1 \
  || error "AWS CLI is required"

[[ -n "$APPROVAL_EVIDENCE_FILE" ]] \
  || error "approval evidence file is required"

[[ -n "$OUTPUT_FILE" ]] \
  || error "output file is required"

[[ -f "$APPROVAL_EVIDENCE_FILE" ]] \
  || error "approval evidence file does not exist"

jq empty "$APPROVAL_EVIDENCE_FILE" >/dev/null 2>&1 \
  || error "approval evidence file is not valid JSON"

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
  jq -r '.remediation.environment // empty' "$APPROVAL_EVIDENCE_FILE"
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
  jq -r '.approval.required' "$APPROVAL_EVIDENCE_FILE"
)"

approval_approved="$(
  jq -r '.approval.approved' "$APPROVAL_EVIDENCE_FILE"
)"

confirmation_verified="$(
  jq -r '.approval.confirmation_token_verified' "$APPROVAL_EVIDENCE_FILE"
)"

execution_attempted="$(
  jq -r '.execution.attempted' "$APPROVAL_EVIDENCE_FILE"
)"

lifecycle_result="$(
  jq -r '.result.remediation_result // empty' "$APPROVAL_EVIDENCE_FILE"
)"

[[ "$schema_version" == "1.0" ]] \
  || error "unsupported evidence schema"

[[ "$cloud" == "aws" ]] \
  || error "cloud must be aws"

[[ "$environment" == "dev" ]] \
  || error "environment must be dev"

[[ "$action_type" == "set-tag" ]] \
  || error "action must be set-tag"

[[ "$tag_key" == "CostCenter" ]] \
  || error "only CostCenter remediation is allowed"

[[ "$remediation_id" == "rem-finding-aws-live-tag-001" ]] \
  || error "unexpected remediation ID"

[[ "$resource_identifier" == "arn:aws:ec2:us-east-1:931058976119:instance/i-033b19d090406151a" ]] \
  || error "resource is outside the approved controlled-remediation target"

[[ "$desired_value" == "CC-PLATFORM" ]] \
  || error "desired CostCenter value is not allow-listed"

[[ "$approval_required" == "true" ]] \
  || error "human approval is required"

[[ "$approval_approved" == "true" ]] \
  || error "request has not been approved"

[[ "$confirmation_verified" == "true" ]] \
  || error "confirmation token was not verified"

[[ "$execution_attempted" == "false" ]] \
  || error "remediation has already been attempted"

[[ "$lifecycle_result" == "APPROVED_PENDING_EXECUTION" ]] \
  || error "evidence is not in approved pending execution state"

[[ "$resource_identifier" =~ ^arn:aws:ec2:us-east-1:[0-9]{12}:instance/(i-[a-zA-Z0-9]+)$ ]] \
  || error "resource identifier is not an approved us-east-1 EC2 instance ARN"

instance_id="${BASH_REMATCH[1]}"

account_id="$(
  aws sts get-caller-identity \
    --query Account \
    --output text
)"

caller_arn="$(
  aws sts get-caller-identity \
    --query Arn \
    --output text
)"

[[ "$account_id" == "931058976119" ]] \
  || error "unexpected AWS account"

[[ "$caller_arn" == arn:aws:sts::931058976119:assumed-role/mc-finops-github-aws-remediation/* ]] \
  || error "dedicated remediation role is not active"

project_tag="$(
  aws ec2 describe-tags \
    --region us-east-1 \
    --filters \
      "Name=resource-id,Values=$instance_id" \
      "Name=key,Values=Project" \
    --query 'Tags[0].Value' \
    --output text
)"

environment_tag="$(
  aws ec2 describe-tags \
    --region us-east-1 \
    --filters \
      "Name=resource-id,Values=$instance_id" \
      "Name=key,Values=Environment" \
    --query 'Tags[0].Value' \
    --output text
)"

[[ "$project_tag" == "enterprise-multicloud-finops-governance" ]] \
  || error "resource Project tag is not governed"

[[ "$environment_tag" == "dev" ]] \
  || error "resource Environment tag is not governed dev"

current_value="$(
  aws ec2 describe-tags \
    --region us-east-1 \
    --filters \
      "Name=resource-id,Values=$instance_id" \
      "Name=key,Values=$tag_key" \
    --query 'Tags[0].Value' \
    --output text
)"

if [[ "$current_value" == "None" ]]; then
  current_value="null"
fi

[[ "$current_value" == "$before_value" ]] \
  || error "live resource current value no longer matches approved before-state"

echo "PASS - approved remediation evidence validated"
echo "PASS - dedicated AWS remediation role active"
echo "PASS - governed AWS resource verified"
echo "PASS - live before-state matches approved evidence"

aws ec2 create-tags \
  --region us-east-1 \
  --resources "$instance_id" \
  --tags "Key=${tag_key},Value=${desired_value}"

verified_value="$(
  aws ec2 describe-tags \
    --region us-east-1 \
    --filters \
      "Name=resource-id,Values=$instance_id" \
      "Name=key,Values=$tag_key" \
    --query 'Tags[0].Value' \
    --output text
)"

[[ "$verified_value" == "$desired_value" ]] \
  || error "post-remediation verification failed"

executed_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

mkdir -p "$(dirname "$OUTPUT_FILE")"

jq \
  --arg executed_at "$executed_at" \
  --arg caller_arn "$caller_arn" \
  --arg before_value "$before_value" \
  --arg after_value "$verified_value" \
  '
    .execution.attempted = true
    | .execution.authentication_type = "github-oidc"
    | .execution.oidc_used = true
    | .execution.cloud_credentials_used = true
    | .execution.cloud_mutation_performed = true
    | .execution.terraform_mutation_performed = false
    | .execution.dedicated_remediation_identity = true
    | .execution.executed_at = $executed_at
    | .execution.executor_identity = $caller_arn
    | .execution.command_class = "aws-ec2-create-tags"
    | .before.observed_value = $before_value
    | .after.compliant = true
    | .after.observed_value = $after_value
    | .result.remediation_result = "EXECUTED"
    | .result.verification_result = "PASS"
    | .result.reason = "Approved AWS CostCenter tag remediation executed and verified successfully."
  ' \
  "$APPROVAL_EVIDENCE_FILE" \
  > "$OUTPUT_FILE"

echo "PASS - approved CostCenter mutation executed"
echo "PASS - post-remediation value verified"
echo
echo "AWS REMEDIATION EXECUTION RESULT: PASS"
