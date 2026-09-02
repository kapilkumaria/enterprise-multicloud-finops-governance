#!/usr/bin/env bash

set -u

TARGET="${1:-}"

AWS_THRESHOLD="${AWS_COST_THRESHOLD_USD:-25}"
AZURE_THRESHOLD="${AZURE_COST_THRESHOLD_USD:-100}"

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

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR - Terraform is not installed"
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

cleanup() {
  rm -rf "$TMP_BASE"
}

trap cleanup EXIT

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
