#!/usr/bin/env bash

set -u

TARGET="${1:-}"

AWS_THRESHOLD="${AWS_COST_THRESHOLD_USD:-25}"
AZURE_THRESHOLD="${AZURE_COST_THRESHOLD_USD:-100}"

###############################################################################
# Optional structured governance evidence
###############################################################################

EVIDENCE_FILE="${MC_FINOPS_EVIDENCE_FILE:-}"

# Initialize evidence fields before any fail-closed branch can exit.
CLOUD="unknown"
MODE="unknown"
THRESHOLD=""
MONTHLY_COST=""
CURRENCY="USD"

TOTAL_RESOURCES=""
PRICED_RESOURCES=""
PROJECT_ERRORS=""
CRITICAL_DIAGNOSTICS=""
WARNING_DIAGNOSTICS=""

TMP_BASE=""

emit_evidence() {
  local EXIT_CODE="$1"

  [ -n "$EVIDENCE_FILE" ] || return 0

  # Evidence generation must never change enforcement semantics.
  if ! command -v jq >/dev/null 2>&1; then
    echo "WARNING - evidence requested but jq is unavailable" >&2
    return 0
  fi

  local POLICY_RESULT
  local GOVERNANCE_RESULT
  local REASON
  local TERRAFORM_PLAN_USED
  local OIDC_USED
  local AUTHENTICATION_TYPE

  case "$EXIT_CODE" in
    0)
      POLICY_RESULT="ALLOW"
      GOVERNANCE_RESULT="ALLOW"
      REASON="Estimated monthly cost is within the governed threshold."
      ;;
    1)
      POLICY_RESULT="DENY"
      GOVERNANCE_RESULT="DENY"
      REASON="Estimated monthly cost exceeds the governed threshold."
      ;;
    *)
      POLICY_RESULT="ERROR"
      GOVERNANCE_RESULT="DENY"
      REASON="Policy evaluation failed closed."
      ;;
  esac

  if [ "$MODE" = "plan-json" ]; then
    TERRAFORM_PLAN_USED="true"
  else
    TERRAFORM_PLAN_USED="false"
  fi

  if [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    OIDC_USED="true"
  else
    OIDC_USED="false"
  fi

  if [ "${GITHUB_ACTIONS:-false}" = "true" ] \
    && [ "$OIDC_USED" = "true" ]; then
    AUTHENTICATION_TYPE="github-oidc"
  elif [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    AUTHENTICATION_TYPE="github-actions"
  else
    AUTHENTICATION_TYPE="local-or-existing-credentials"
  fi

  local REPOSITORY
  local COMMIT_SHA
  local WORKFLOW
  local WORKFLOW_RUN_ID
  local EVENT_NAME
  local GENERATED_AT

  REPOSITORY="${GITHUB_REPOSITORY:-}"

  if [ -z "$REPOSITORY" ]; then
    REPOSITORY="$(
      git config --get remote.origin.url 2>/dev/null \
        || printf '%s' 'local'
    )"
  fi

  COMMIT_SHA="${GITHUB_SHA:-}"

  if [ -z "$COMMIT_SHA" ]; then
    COMMIT_SHA="$(
      git rev-parse HEAD 2>/dev/null \
        || printf '%s' 'unknown'
    )"
  fi

  WORKFLOW="${GITHUB_WORKFLOW:-local}"
  WORKFLOW_RUN_ID="${GITHUB_RUN_ID:-local}"
  EVENT_NAME="${GITHUB_EVENT_NAME:-local}"

  GENERATED_AT="$(
    date -u '+%Y-%m-%dT%H:%M:%SZ'
  )"

  mkdir -p "$(dirname "$EVIDENCE_FILE")"

  jq -n \
    --arg schema_version "1.0" \
    --arg generated_at "$GENERATED_AT" \
    --arg repository "$REPOSITORY" \
    --arg commit_sha "$COMMIT_SHA" \
    --arg workflow "$WORKFLOW" \
    --arg workflow_run_id "$WORKFLOW_RUN_ID" \
    --arg event "$EVENT_NAME" \
    --arg environment "${MC_FINOPS_ENVIRONMENT:-dev}" \
    --arg control_id "FINOPS-COST-001" \
    --arg control_type "monthly-cost-threshold" \
    --arg cloud "$CLOUD" \
    --arg target "$TARGET" \
    --arg evaluation_mode "$MODE" \
    --arg currency "$CURRENCY" \
    --arg estimated_monthly_cost "$MONTHLY_COST" \
    --arg threshold_monthly_cost "$THRESHOLD" \
    --arg priced_resources "$PRICED_RESOURCES" \
    --arg total_resources "$TOTAL_RESOURCES" \
    --arg projects_with_errors "$PROJECT_ERRORS" \
    --arg critical_diagnostics "$CRITICAL_DIAGNOSTICS" \
    --arg warning_diagnostics "$WARNING_DIAGNOSTICS" \
    --arg policy_result "$POLICY_RESULT" \
    --argjson policy_exit_code "$EXIT_CODE" \
    --argjson terraform_plan_used "$TERRAFORM_PLAN_USED" \
    --argjson terraform_apply_used false \
    --argjson oidc_used "$OIDC_USED" \
    --arg authentication_type "$AUTHENTICATION_TYPE" \
    --arg governance_result "$GOVERNANCE_RESULT" \
    --arg reason "$REASON" '
      def number_or_null:
        if . == "" or . == "null"
        then null
        else tonumber
        end;

      {
        schema_version: $schema_version,
        generated_at: $generated_at,

        metadata: {
          repository: $repository,
          commit_sha: $commit_sha,
          workflow: $workflow,
          workflow_run_id: $workflow_run_id,
          event: $event,
          environment: $environment
        },

        control: {
          control_id: $control_id,
          control_type: $control_type,
          cloud: $cloud,
          target: $target,
          evaluation_mode: $evaluation_mode
        },

        cost: {
          currency: $currency,
          estimated_monthly_cost:
            (
              if
                ($estimated_monthly_cost == "")
                or ($estimated_monthly_cost == "null")
              then
                null
              else
                (($estimated_monthly_cost | tonumber) * 100 | round) / 100
              end
            ),
          threshold_monthly_cost:
            (
              if
                ($threshold_monthly_cost == "")
                or ($threshold_monthly_cost == "null")
              then
                null
              else
                (($threshold_monthly_cost | tonumber) * 100 | round) / 100
              end
            ),
          cost_delta_monthly:
            (
              if
                ($estimated_monthly_cost == "")
                or ($threshold_monthly_cost == "")
                or ($estimated_monthly_cost == "null")
                or ($threshold_monthly_cost == "null")
              then
                null
              else
                (
                  (
                    ($estimated_monthly_cost | tonumber)
                    -
                    ($threshold_monthly_cost | tonumber)
                  )
                  * 100
                  | round
                )
                / 100
              end
            ),
          priced_resources:
            ($priced_resources | number_or_null),
          total_resources:
            ($total_resources | number_or_null)
        },

        policy: {
          policy_result: $policy_result,
          policy_exit_code: $policy_exit_code,
          projects_with_errors:
            ($projects_with_errors | number_or_null),
          critical_diagnostics:
            ($critical_diagnostics | number_or_null),
          warning_diagnostics:
            ($warning_diagnostics | number_or_null)
        },

        execution: {
          terraform_plan_used: $terraform_plan_used,
          terraform_apply_used: $terraform_apply_used,
          oidc_used: $oidc_used,
          authentication_type: $authentication_type
        },

        decision: {
          governance_result: $governance_result,
          reason: $reason
        }
      }
    ' >"$EVIDENCE_FILE"

  if jq empty "$EVIDENCE_FILE" >/dev/null 2>&1; then
    echo
    echo "Evidence file: $EVIDENCE_FILE"
  else
    echo "WARNING - evidence file could not be validated" >&2
  fi
}

on_exit() {
  local EXIT_CODE=$?

  # Disable recursion while handling EXIT.
  trap - EXIT

  # Evidence is advisory output; enforcement exit code remains authoritative.
  set +e
  emit_evidence "$EXIT_CODE"

  if [ -n "${TMP_BASE:-}" ] \
    && [ -d "${TMP_BASE:-}" ]; then
    rm -rf "$TMP_BASE"
  fi

  exit "$EXIT_CODE"
}

trap on_exit EXIT

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <terraform-directory>"
  exit 2
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR - target directory does not exist: $TARGET"
  exit 2
fi

if ! command -v infracost >/dev/null 2>&1; then
  echo "ERROR - Infracost is not installed"
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR - jq is not installed"
  exit 2
fi

echo
echo "===== FINOPS COST POLICY CHECK ====="
echo
echo "Target:                   $TARGET"
echo "AWS monthly threshold:    USD $AWS_THRESHOLD"
echo "Azure monthly threshold:  USD $AZURE_THRESHOLD"

AWS_FILES="$(
  grep -RlE \
    '(^|[[:space:]])(aws_|provider[[:space:]]*"aws")' \
    "$TARGET" \
    --include='*.tf' \
    2>/dev/null \
    | wc -l \
    | tr -d ' '
)"

AZURE_FILES="$(
  grep -RlE \
    '(^|[[:space:]])(azurerm_|provider[[:space:]]*"azurerm")' \
    "$TARGET" \
    --include='*.tf' \
    2>/dev/null \
    | wc -l \
    | tr -d ' '
)"

echo
echo "----- DETECT CLOUD -----"
echo "AWS Terraform source files:   $AWS_FILES"
echo "Azure Terraform source files: $AZURE_FILES"

if [ "$AWS_FILES" -gt 0 ] \
  && [ "$AZURE_FILES" -gt 0 ]; then

  echo
  echo "ERROR - target contains both AWS and Azure Terraform"
  echo "POLICY RESULT: ERROR"
  exit 2

elif [ "$AWS_FILES" -gt 0 ]; then

  CLOUD="AWS"
  THRESHOLD="$AWS_THRESHOLD"

elif [ "$AZURE_FILES" -gt 0 ]; then

  CLOUD="Azure"
  THRESHOLD="$AZURE_THRESHOLD"

else

  echo
  echo "ERROR - supported AWS/Azure Terraform was not detected"
  echo "POLICY RESULT: ERROR"
  exit 2

fi

echo
echo "Detected cloud: $CLOUD"

TARGET_ABS="$(
  cd "$TARGET" 2>/dev/null \
    && pwd
)"

REPO_ROOT="$(
  git rev-parse --show-toplevel 2>/dev/null
)"

AWS_REAL_ABS="$REPO_ROOT/terraform/aws/environments/dev"
AZURE_REAL_ABS="$REPO_ROOT/terraform/azure/environments/dev"

MODE="hcl"

if [ "$TARGET_ABS" = "$AWS_REAL_ABS" ] \
  || [ "$TARGET_ABS" = "$AZURE_REAL_ABS" ]; then
  MODE="plan-json"
fi

echo
echo "Evaluation mode: $MODE"

TMP_BASE="$(
  mktemp -d /tmp/mc-finops-cost-policy.XXXXXX
)"

INFRACOST_JSON="$TMP_BASE/infracost.json"
INSPECT_JSON="$TMP_BASE/inspect.json"

if [ "$MODE" = "hcl" ]; then

  echo
  echo "----- DIRECT HCL COST EVALUATION -----"

  infracost scan \
    "$TARGET" \
    --currency USD \
    --json \
    >"$INFRACOST_JSON"

  SCAN_EXIT=$?

  echo "Infracost scan exit code: $SCAN_EXIT"

  if [ "$SCAN_EXIT" -ne 0 ]; then

    echo
    echo "ERROR - Infracost HCL scan failed"

    if jq empty "$INFRACOST_JSON" >/dev/null 2>&1; then
      jq '.' "$INFRACOST_JSON"
    fi

    echo
    echo "POLICY RESULT: ERROR"
    echo "Fail-closed: deployment must not proceed."
    exit 2
  fi

else

  echo
  echo "----- TERRAFORM PLAN-JSON COST EVALUATION -----"

  if ! command -v terraform >/dev/null 2>&1; then
    echo
    echo "ERROR - Terraform is required for plan-json evaluation"
    echo "POLICY RESULT: ERROR"
    echo "Fail-closed: deployment must not proceed."
    exit 2
  fi

  PLAN_FILE="$TMP_BASE/cost.tfplan"
  PLAN_JSON="$TMP_BASE/cost-plan.json"

  AZURE_KEY_TEMPORARY=0

  if [ "$CLOUD" = "Azure" ] \
    && [ -z "${TF_VAR_azure_ssh_public_key:-}" ]; then

    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then

      export TF_VAR_azure_ssh_public_key="$(
        cat "$HOME/.ssh/id_ed25519.pub"
      )"

      AZURE_KEY_TEMPORARY=1

      echo "INFO - loaded Azure SSH public key temporarily"

    else

      echo "ERROR - Azure SSH public key variable is unavailable"
      echo
      echo "POLICY RESULT: ERROR"
      exit 2

    fi

  fi

  echo
  echo "Validating Terraform configuration..."

  terraform \
    -chdir="$TARGET" \
    validate \
    >/dev/null

  VALIDATE_EXIT=$?

  echo "Terraform validate exit code: $VALIDATE_EXIT"

  if [ "$VALIDATE_EXIT" -ne 0 ]; then

    [ "$AZURE_KEY_TEMPORARY" -eq 1 ] \
      && unset TF_VAR_azure_ssh_public_key

    echo
    echo "ERROR - Terraform validation failed"
    echo "POLICY RESULT: ERROR"
    exit 2

  fi

  echo
  echo "Generating read-only Terraform plan..."

  terraform \
    -chdir="$TARGET" \
    plan \
    -refresh=false \
    -input=false \
    -lock=false \
    -out="$PLAN_FILE" \
    >/dev/null

  PLAN_EXIT=$?

  echo "Terraform plan exit code: $PLAN_EXIT"

  if [ "$PLAN_EXIT" -ne 0 ]; then

    [ "$AZURE_KEY_TEMPORARY" -eq 1 ] \
      && unset TF_VAR_azure_ssh_public_key

    echo
    echo "ERROR - Terraform cost plan failed"
    echo "POLICY RESULT: ERROR"
    exit 2

  fi

  terraform \
    -chdir="$TARGET" \
    show \
    -json \
    "$PLAN_FILE" \
    >"$PLAN_JSON"

  SHOW_EXIT=$?

  echo "Terraform plan JSON exit code: $SHOW_EXIT"

  if [ "$AZURE_KEY_TEMPORARY" -eq 1 ]; then
    unset TF_VAR_azure_ssh_public_key
  fi

  if [ "$SHOW_EXIT" -ne 0 ] \
    || ! jq empty "$PLAN_JSON" >/dev/null 2>&1; then

    echo
    echo "ERROR - Terraform plan JSON could not be generated"
    echo "POLICY RESULT: ERROR"
    exit 2

  fi

  echo "PASS - fully resolved Terraform plan JSON generated"

  infracost scan \
    "$PLAN_JSON" \
    --currency USD \
    --json \
    >"$INFRACOST_JSON"

  SCAN_EXIT=$?

  echo "Infracost plan scan exit code: $SCAN_EXIT"

  if [ "$SCAN_EXIT" -ne 0 ]; then

    echo
    echo "ERROR - Infracost plan-JSON scan failed"

    if jq empty "$INFRACOST_JSON" >/dev/null 2>&1; then
      jq '.' "$INFRACOST_JSON"
    fi

    echo
    echo "POLICY RESULT: ERROR"
    echo "Fail-closed: deployment must not proceed."
    exit 2

  fi

fi

if ! jq empty "$INFRACOST_JSON" >/dev/null 2>&1; then
  echo
  echo "ERROR - Infracost output is not valid JSON"
  echo "POLICY RESULT: ERROR"
  exit 2
fi

echo
echo "----- NORMALIZE INFRACOST SUMMARY -----"

infracost inspect \
  --file "$INFRACOST_JSON" \
  --summary \
  --json \
  >"$INSPECT_JSON"

INSPECT_EXIT=$?

echo "Infracost inspect exit code: $INSPECT_EXIT"

if [ "$INSPECT_EXIT" -ne 0 ] \
  || ! jq empty "$INSPECT_JSON" >/dev/null 2>&1; then

  echo
  echo "ERROR - Infracost summary could not be generated"
  echo "POLICY RESULT: ERROR"
  exit 2

fi

MONTHLY_COST="$(
  jq -r \
    '.monthly_cost // empty' \
    "$INSPECT_JSON"
)"

PROJECT_ERRORS="$(
  jq -r \
    '.projects_with_errors // 0' \
    "$INSPECT_JSON"
)"

CRITICAL_DIAGNOSTICS="$(
  jq -r \
    '.critical_diagnostics // 0' \
    "$INSPECT_JSON"
)"

CURRENCY="$(
  jq -r \
    '.currency // "USD"' \
    "$INSPECT_JSON"
)"


TOTAL_RESOURCES="$(
  jq -r \
    '.resources // 0' \
    "$INSPECT_JSON"
)"

PRICED_RESOURCES="$(
  jq -r \
    '.costed_resources // 0' \
    "$INSPECT_JSON"
)"

WARNING_DIAGNOSTICS="$(
  jq -r \
    '.warning_diagnostics // 0' \
    "$INSPECT_JSON"
)"

echo
echo "Infracost summary:"
jq '{
  projects,
  projects_with_errors,
  resources,
  costed_resources,
  free_resources,
  monthly_cost,
  critical_diagnostics,
  warning_diagnostics,
  currency
}' "$INSPECT_JSON"

if [ -z "$MONTHLY_COST" ] \
  || [ "$MONTHLY_COST" = "null" ]; then

  echo
  echo "ERROR - monthly cost could not be resolved"
  echo "POLICY RESULT: ERROR"
  exit 2

fi

if [ "$PROJECT_ERRORS" -ne 0 ] \
  || [ "$CRITICAL_DIAGNOSTICS" -ne 0 ]; then

  echo
  echo "ERROR - Infracost returned pricing diagnostics"
  echo "POLICY RESULT: ERROR"
  echo "Fail-closed: deployment must not proceed."
  exit 2

fi

if ! python3 - \
  "$MONTHLY_COST" \
  "$THRESHOLD" <<'PY'
import math
import sys

try:
    cost = float(sys.argv[1])
    threshold = float(sys.argv[2])
except (ValueError, IndexError):
    sys.exit(2)

if not math.isfinite(cost) or not math.isfinite(threshold):
    sys.exit(2)

sys.exit(0)
PY
then

  echo
  echo "ERROR - non-numeric cost or threshold"
  echo "POLICY RESULT: ERROR"
  exit 2

fi

echo
echo "----- COST POLICY EVALUATION -----"

python3 - \
  "$CLOUD" \
  "$MONTHLY_COST" \
  "$THRESHOLD" \
  "$CURRENCY" <<'PY'
import sys

cloud = sys.argv[1]
cost = float(sys.argv[2])
threshold = float(sys.argv[3])
currency = sys.argv[4]

print(f"Cloud:                  {cloud}")
print(f"Estimated monthly cost: {currency} {cost:.2f}")
print(f"Governed threshold:     {currency} {threshold:.2f}")

if cost > threshold:
    print()
    print("POLICY RESULT: DENY")
    print("Estimated monthly cost exceeds the governed threshold.")
    sys.exit(1)

print()
print("POLICY RESULT: ALLOW")
print("Estimated monthly cost is within the governed threshold.")
sys.exit(0)
PY

exit $?
