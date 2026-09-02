#!/usr/bin/env bash

set -u
set -o pipefail

AZURE_DEV="${AZURE_DEV:-terraform/azure/environments/dev}"

PROJECT="${PROJECT:-enterprise-multicloud-finops-governance}"
EXPECTED_REGION="${EXPECTED_REGION:-canadacentral}"
EXPECTED_VM_SIZE="${EXPECTED_VM_SIZE:-Standard_D2s_v3}"
EXPECTED_BUDGET="${EXPECTED_BUDGET:-100}"

REPORT_DATE="$(
  date -u +%Y-%m-%d
)"

REPORT_DIR="${REPORT_DIR:-reports/compliance/azure}"
REPORT="${REPORT:-$REPORT_DIR/azure-compliance-${REPORT_DATE}.json}"

mkdir -p "$REPORT_DIR"

echo
echo "===== AZURE LIVE COMPLIANCE SCAN ====="
echo "Project:          $PROJECT"
echo "Expected region:  $EXPECTED_REGION"
echo "Expected VM size: $EXPECTED_VM_SIZE"
echo "Report:           $REPORT"

echo
echo "----- VERIFY AZURE IDENTITY -----"

ACCOUNT_JSON="$(
  az account show \
    --output json
)"

SUBSCRIPTION_ID="$(
  jq -r '.id' <<<"$ACCOUNT_JSON"
)"

TENANT_ID="$(
  jq -r '.tenantId' <<<"$ACCOUNT_JSON"
)"

IDENTITY="$(
  jq -r '.user.name' <<<"$ACCOUNT_JSON"
)"

echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant:       $TENANT_ID"
echo "Identity:     $IDENTITY"

echo
echo "----- RESOLVE TERRAFORM RESOURCE NAMES -----"

RESOURCE_GROUP="$(
  terraform -chdir="$AZURE_DEV" output \
    -raw resource_group_name
)"

VM_NAME="$(
  terraform -chdir="$AZURE_DEV" output \
    -raw baseline_vm_name
)"

NSG_NAME="$(
  terraform -chdir="$AZURE_DEV" output \
    -raw network_security_group_name
)"

SUBNET_NAME="$(
  terraform -chdir="$AZURE_DEV" output \
    -raw subnet_name
)"

VNET_NAME="$(
  terraform -chdir="$AZURE_DEV" output \
    -raw virtual_network_name
)"

BUDGET_NAME="$(
  terraform -chdir="$AZURE_DEV" output \
    -raw azure_monthly_budget_name
)"

NIC_NAME="mc-finops-dev-nic"

echo "Resource Group: $RESOURCE_GROUP"
echo "VM:             $VM_NAME"
echo "NIC:            $NIC_NAME"
echo "NSG:            $NSG_NAME"
echo "VNet:           $VNET_NAME"
echo "Subnet:         $SUBNET_NAME"
echo "Budget:         $BUDGET_NAME"

echo
echo "----- COLLECT LIVE AZURE DATA -----"

RG_JSON="$(
  az group show \
    --name "$RESOURCE_GROUP" \
    --output json
)"

VM_JSON="$(
  az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --output json
)"

NIC_JSON="$(
  az network nic show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --output json
)"

NSG_JSON="$(
  az network nsg show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --output json
)"

SUBNET_JSON="$(
  az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --output json
)"

BUDGET_JSON="$(
  az consumption budget show \
    --resource-group "$RESOURCE_GROUP" \
    --budget-name "$BUDGET_NAME" \
    --output json
)"

echo "PASS - live Azure resource data collected"

CONTROL_FILE="$(
  mktemp
)"

: > "$CONTROL_FILE"

add_control() {
  local id="$1"
  local description="$2"
  local status="$3"
  local actual="$4"
  local expected="$5"

  jq -n \
    --arg id "$id" \
    --arg description "$description" \
    --arg status "$status" \
    --arg actual "$actual" \
    --arg expected "$expected" \
    '{
      id: $id,
      description: $description,
      status: $status,
      actual: $actual,
      expected: $expected
    }' \
    >> "$CONTROL_FILE"
}

echo
echo "----- EVALUATE CONTROLS -----"

RG_LOCATION="$(
  jq -r '.location' <<<"$RG_JSON"
)"

if [ "$RG_LOCATION" = "$EXPECTED_REGION" ]; then
  add_control \
    "AZURE-REGION-001" \
    "Azure resources must operate in the approved region" \
    "PASS" \
    "$RG_LOCATION" \
    "$EXPECTED_REGION"
else
  add_control \
    "AZURE-REGION-001" \
    "Azure resources must operate in the approved region" \
    "FAIL" \
    "$RG_LOCATION" \
    "$EXPECTED_REGION"
fi

VM_PUBLIC_IP="$(
  jq -r '.publicIps // ""' <<<"$VM_JSON"
)"

if [ -z "$VM_PUBLIC_IP" ]; then
  add_control \
    "AZURE-VM-001" \
    "Baseline Azure VM must not have a public IP address" \
    "PASS" \
    "none" \
    "none"
else
  add_control \
    "AZURE-VM-001" \
    "Baseline Azure VM must not have a public IP address" \
    "FAIL" \
    "$VM_PUBLIC_IP" \
    "none"
fi

VM_SIZE="$(
  jq -r '.hardwareProfile.vmSize' <<<"$VM_JSON"
)"

if [ "$VM_SIZE" = "$EXPECTED_VM_SIZE" ]; then
  add_control \
    "AZURE-VM-002" \
    "Baseline Azure VM must use the approved SKU" \
    "PASS" \
    "$VM_SIZE" \
    "$EXPECTED_VM_SIZE"
else
  add_control \
    "AZURE-VM-002" \
    "Baseline Azure VM must use the approved SKU" \
    "FAIL" \
    "$VM_SIZE" \
    "$EXPECTED_VM_SIZE"
fi

SECURE_BOOT="$(
  jq -r \
    '.securityProfile.uefiSettings.secureBootEnabled // false' \
    <<<"$VM_JSON"
)"

if [ "$SECURE_BOOT" = "true" ]; then
  add_control \
    "AZURE-VM-003" \
    "Azure VM Secure Boot must be enabled" \
    "PASS" \
    "$SECURE_BOOT" \
    "true"
else
  add_control \
    "AZURE-VM-003" \
    "Azure VM Secure Boot must be enabled" \
    "FAIL" \
    "$SECURE_BOOT" \
    "true"
fi

VTPM="$(
  jq -r \
    '.securityProfile.uefiSettings.vTpmEnabled // false' \
    <<<"$VM_JSON"
)"

if [ "$VTPM" = "true" ]; then
  add_control \
    "AZURE-VM-004" \
    "Azure VM vTPM must be enabled" \
    "PASS" \
    "$VTPM" \
    "true"
else
  add_control \
    "AZURE-VM-004" \
    "Azure VM vTPM must be enabled" \
    "FAIL" \
    "$VTPM" \
    "true"
fi

IDENTITY_TYPE="$(
  jq -r '.identity.type // "none"' <<<"$VM_JSON"
)"

PRINCIPAL_ID="$(
  jq -r '.identity.principalId // ""' <<<"$VM_JSON"
)"

if [ "$IDENTITY_TYPE" = "SystemAssigned" ] \
  && [ -n "$PRINCIPAL_ID" ]; then
  add_control \
    "AZURE-VM-005" \
    "Azure VM must use a system-assigned managed identity" \
    "PASS" \
    "$IDENTITY_TYPE" \
    "SystemAssigned"
else
  add_control \
    "AZURE-VM-005" \
    "Azure VM must use a system-assigned managed identity" \
    "FAIL" \
    "$IDENTITY_TYPE" \
    "SystemAssigned"
fi

IP_FORWARDING="$(
  jq -r '.enableIPForwarding // false' <<<"$NIC_JSON"
)"

if [ "$IP_FORWARDING" = "false" ]; then
  add_control \
    "AZURE-NIC-001" \
    "Azure NIC IP forwarding must be disabled" \
    "PASS" \
    "$IP_FORWARDING" \
    "false"
else
  add_control \
    "AZURE-NIC-001" \
    "Azure NIC IP forwarding must be disabled" \
    "FAIL" \
    "$IP_FORWARDING" \
    "false"
fi

NIC_PUBLIC_IP_COUNT="$(
  jq '
    [
      .ipConfigurations[]
      | select(.publicIPAddress != null)
    ]
    | length
  ' <<<"$NIC_JSON"
)"

if [ "$NIC_PUBLIC_IP_COUNT" -eq 0 ]; then
  add_control \
    "AZURE-NIC-002" \
    "Azure NIC must not reference a Public IP resource" \
    "PASS" \
    "$NIC_PUBLIC_IP_COUNT" \
    "0"
else
  add_control \
    "AZURE-NIC-002" \
    "Azure NIC must not reference a Public IP resource" \
    "FAIL" \
    "$NIC_PUBLIC_IP_COUNT" \
    "0"
fi

NSG_RULE_COUNT="$(
  jq '.securityRules | length' <<<"$NSG_JSON"
)"

if [ "$NSG_RULE_COUNT" -eq 0 ]; then
  add_control \
    "AZURE-NSG-001" \
    "Baseline Azure NSG must not contain custom exposure rules" \
    "PASS" \
    "$NSG_RULE_COUNT" \
    "0"
else
  add_control \
    "AZURE-NSG-001" \
    "Baseline Azure NSG must not contain custom exposure rules" \
    "FAIL" \
    "$NSG_RULE_COUNT" \
    "0"
fi

OUTBOUND_ALLOW_RULES="$(
  jq '
    [
      .securityRules[]
      | select(
          (.direction | ascii_downcase) == "outbound"
          and
          (.access | ascii_downcase) == "allow"
        )
    ]
    | length
  ' <<<"$NSG_JSON"
)"

if [ "$OUTBOUND_ALLOW_RULES" -eq 0 ]; then
  add_control \
    "AZURE-NSG-002" \
    "Baseline Azure NSG must not contain custom outbound allow rules" \
    "PASS" \
    "$OUTBOUND_ALLOW_RULES" \
    "0"
else
  add_control \
    "AZURE-NSG-002" \
    "Baseline Azure NSG must not contain custom outbound allow rules" \
    "FAIL" \
    "$OUTBOUND_ALLOW_RULES" \
    "0"
fi

DEFAULT_OUTBOUND="$(
  jq -r '.defaultOutboundAccess // false' <<<"$SUBNET_JSON"
)"

if [ "$DEFAULT_OUTBOUND" = "false" ]; then
  add_control \
    "AZURE-SUBNET-001" \
    "Azure subnet default outbound access must be disabled" \
    "PASS" \
    "$DEFAULT_OUTBOUND" \
    "false"
else
  add_control \
    "AZURE-SUBNET-001" \
    "Azure subnet default outbound access must be disabled" \
    "FAIL" \
    "$DEFAULT_OUTBOUND" \
    "false"
fi

SUBNET_NSG="$(
  jq -r '.networkSecurityGroup.id // ""' <<<"$SUBNET_JSON"
)"

if [[ "$SUBNET_NSG" == *"/networkSecurityGroups/$NSG_NAME" ]]; then
  add_control \
    "AZURE-SUBNET-002" \
    "Azure subnet must be associated with the governed compute NSG" \
    "PASS" \
    "$NSG_NAME" \
    "$NSG_NAME"
else
  add_control \
    "AZURE-SUBNET-002" \
    "Azure subnet must be associated with the governed compute NSG" \
    "FAIL" \
    "$SUBNET_NSG" \
    "$NSG_NAME"
fi

PROJECT_TAG="$(
  jq -r '.tags.Project // ""' <<<"$VM_JSON"
)"

if [ "$PROJECT_TAG" = "$PROJECT" ]; then
  add_control \
    "AZURE-TAG-001" \
    "Project governance tag must match the project" \
    "PASS" \
    "$PROJECT_TAG" \
    "$PROJECT"
else
  add_control \
    "AZURE-TAG-001" \
    "Project governance tag must match the project" \
    "FAIL" \
    "$PROJECT_TAG" \
    "$PROJECT"
fi

ENVIRONMENT_TAG="$(
  jq -r '.tags.Environment // ""' <<<"$VM_JSON"
)"

if [ "$ENVIRONMENT_TAG" = "dev" ]; then
  add_control \
    "AZURE-TAG-002" \
    "Environment governance tag must be dev" \
    "PASS" \
    "$ENVIRONMENT_TAG" \
    "dev"
else
  add_control \
    "AZURE-TAG-002" \
    "Environment governance tag must be dev" \
    "FAIL" \
    "$ENVIRONMENT_TAG" \
    "dev"
fi

MANAGED_BY="$(
  jq -r '.tags.ManagedBy // ""' <<<"$VM_JSON"
)"

if [ "$MANAGED_BY" = "Terraform" ]; then
  add_control \
    "AZURE-TAG-003" \
    "ManagedBy governance tag must identify Terraform" \
    "PASS" \
    "$MANAGED_BY" \
    "Terraform"
else
  add_control \
    "AZURE-TAG-003" \
    "ManagedBy governance tag must identify Terraform" \
    "FAIL" \
    "$MANAGED_BY" \
    "Terraform"
fi

LIVE_BUDGET_NAME="$(
  jq -r '.name // ""' <<<"$BUDGET_JSON"
)"

if [ "$LIVE_BUDGET_NAME" = "$BUDGET_NAME" ]; then
  add_control \
    "AZURE-BUDGET-001" \
    "Native Azure monthly budget must exist" \
    "PASS" \
    "$LIVE_BUDGET_NAME" \
    "$BUDGET_NAME"
else
  add_control \
    "AZURE-BUDGET-001" \
    "Native Azure monthly budget must exist" \
    "FAIL" \
    "$LIVE_BUDGET_NAME" \
    "$BUDGET_NAME"
fi

LIVE_BUDGET_AMOUNT="$(
  jq -r '.amount // 0' <<<"$BUDGET_JSON"
)"

if awk \
  -v actual="$LIVE_BUDGET_AMOUNT" \
  -v expected="$EXPECTED_BUDGET" \
  'BEGIN { exit !(actual == expected) }'
then
  add_control \
    "AZURE-BUDGET-002" \
    "Azure monthly budget must match the governed amount" \
    "PASS" \
    "$LIVE_BUDGET_AMOUNT" \
    "$EXPECTED_BUDGET"
else
  add_control \
    "AZURE-BUDGET-002" \
    "Azure monthly budget must match the governed amount" \
    "FAIL" \
    "$LIVE_BUDGET_AMOUNT" \
    "$EXPECTED_BUDGET"
fi

NOTIFICATION_COUNT="$(
  jq '
    [
      .notifications
      | to_entries[]
      | .value
      | select(
          (.enabled == true)
          and
          ((.threshold | tonumber) == 80)
          and
          (.operator == "GreaterThanOrEqualTo")
        )
    ]
    | length
  ' <<<"$BUDGET_JSON"
)"

if [ "$NOTIFICATION_COUNT" -ge 1 ]; then
  add_control \
    "AZURE-BUDGET-003" \
    "Azure budget must contain an enabled 80 percent actual-cost notification" \
    "PASS" \
    "$NOTIFICATION_COUNT" \
    "1"
else
  add_control \
    "AZURE-BUDGET-003" \
    "Azure budget must contain an enabled 80 percent actual-cost notification" \
    "FAIL" \
    "$NOTIFICATION_COUNT" \
    "1"
fi

echo
echo "----- BUILD COMPLIANCE REPORT -----"

CONTROLS_JSON="$(
  jq -s '.' "$CONTROL_FILE"
)"

TOTAL="$(
  jq 'length' <<<"$CONTROLS_JSON"
)"

PASSED="$(
  jq '
    [
      .[]
      | select(.status == "PASS")
    ]
    | length
  ' <<<"$CONTROLS_JSON"
)"

FAILED="$(
  jq '
    [
      .[]
      | select(.status == "FAIL")
    ]
    | length
  ' <<<"$CONTROLS_JSON"
)"

if [ "$FAILED" -eq 0 ]; then
  COMPLIANT=true
else
  COMPLIANT=false
fi

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg project "$PROJECT" \
  --arg cloud "Azure" \
  --arg subscription_id "$SUBSCRIPTION_ID" \
  --arg tenant_id "$TENANT_ID" \
  --arg identity "$IDENTITY" \
  --arg expected_region "$EXPECTED_REGION" \
  --argjson total "$TOTAL" \
  --argjson passed "$PASSED" \
  --argjson failed "$FAILED" \
  --argjson compliant "$COMPLIANT" \
  --argjson controls "$CONTROLS_JSON" \
  '{
    generated_at: $generated_at,
    project: $project,
    cloud: $cloud,
    subscription_id: $subscription_id,
    tenant_id: $tenant_id,
    identity: $identity,
    expected_region: $expected_region,
    summary: {
      total_controls: $total,
      passed: $passed,
      failed: $failed,
      compliant: $compliant
    },
    controls: $controls
  }' \
  > "$REPORT"

rm -f "$CONTROL_FILE"

echo
echo "----- VALIDATE GENERATED REPORT -----"

if jq empty "$REPORT" >/dev/null 2>&1; then
  echo "PASS - compliance report is valid JSON"
else
  echo "FAIL - generated compliance report is invalid JSON"
  exit 1
fi

echo
echo "----- AZURE COMPLIANCE SUMMARY -----"

jq '.summary' "$REPORT"

echo
echo "----- AZURE CONTROL RESULTS -----"

jq -r '
  .controls[]
  | [
      .status,
      .id,
      .description
    ]
  | @tsv
' "$REPORT" \
| column -t -s $'\t'

echo
echo "Azure failed controls: $FAILED"

if [ "$FAILED" -eq 0 ]; then
  echo "PASS - Azure runtime baseline is compliant"
  exit 0
else
  echo "FAIL - Azure runtime compliance violations detected"
  exit 1
fi
