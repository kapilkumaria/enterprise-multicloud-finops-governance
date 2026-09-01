#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_NAME="enterprise-multicloud-finops-governance"
EXPECTED_REGION="us-east-1"

AWS_DEV="${AWS_DEV:-terraform/aws/environments/dev}"

REPORT_DATE="${REPORT_DATE:-$(date -u +%Y-%m-%d)}"

REPORT_DIR="${AWS_COMPLIANCE_DIR:-reports/compliance/aws}"

REPORT_FILE="${REPORT_DIR}/aws-compliance-${REPORT_DATE}.json"

mkdir -p "$REPORT_DIR"

echo
echo "===== AWS LIVE COMPLIANCE SCAN ====="

echo "Project:         $PROJECT_NAME"
echo "Expected region:$EXPECTED_REGION"
echo "Report:          $REPORT_FILE"

echo
echo "----- VERIFY AWS IDENTITY -----"

ACCOUNT_ID="$(
  aws sts get-caller-identity \
    --query Account \
    --output text
)"

IDENTITY_ARN="$(
  aws sts get-caller-identity \
    --query Arn \
    --output text
)"

echo "Account: $ACCOUNT_ID"
echo "Identity:$IDENTITY_ARN"

echo
echo "----- VERIFY CONFIGURED REGION -----"

CONFIGURED_REGION="$(
  aws configure get region
)"

echo "Configured region: $CONFIGURED_REGION"

echo
echo "----- RESOLVE TERRAFORM RESOURCE IDS -----"

INSTANCE_ID="$(
  terraform -chdir="$AWS_DEV" \
    output -raw baseline_instance_id
)"

VPC_ID="$(
  terraform -chdir="$AWS_DEV" \
    output -raw vpc_id
)"

SUBNET_ID="$(
  terraform -chdir="$AWS_DEV" \
    output -raw public_subnet_id
)"

SECURITY_GROUP_ID="$(
  terraform -chdir="$AWS_DEV" \
    output -raw security_group_id
)"

FLOW_LOG_ID="$(
  terraform -chdir="$AWS_DEV" \
    output -raw vpc_flow_log_id
)"

LOG_GROUP="$(
  terraform -chdir="$AWS_DEV" \
    output -raw vpc_flow_log_group_name
)"

BUDGET_NAME="$(
  terraform -chdir="$AWS_DEV" \
    output -raw aws_monthly_budget_name
)"

echo "Instance:       $INSTANCE_ID"
echo "VPC:            $VPC_ID"
echo "Subnet:         $SUBNET_ID"
echo "Security Group: $SECURITY_GROUP_ID"
echo "Flow Log:       $FLOW_LOG_ID"
echo "Log Group:      $LOG_GROUP"
echo "Budget:         $BUDGET_NAME"

echo
echo "----- COLLECT LIVE AWS RESOURCE DATA -----"

INSTANCE_JSON="$(
  aws ec2 describe-instances \
    --region "$EXPECTED_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --output json
)"

VPC_JSON="$(
  aws ec2 describe-vpcs \
    --region "$EXPECTED_REGION" \
    --vpc-ids "$VPC_ID" \
    --output json
)"

SUBNET_JSON="$(
  aws ec2 describe-subnets \
    --region "$EXPECTED_REGION" \
    --subnet-ids "$SUBNET_ID" \
    --output json
)"

SG_JSON="$(
  aws ec2 describe-security-groups \
    --region "$EXPECTED_REGION" \
    --group-ids "$SECURITY_GROUP_ID" \
    --output json
)"

FLOW_JSON="$(
  aws ec2 describe-flow-logs \
    --region "$EXPECTED_REGION" \
    --flow-log-ids "$FLOW_LOG_ID" \
    --output json
)"

LOG_JSON="$(
  aws logs describe-log-groups \
    --region "$EXPECTED_REGION" \
    --log-group-name-prefix "$LOG_GROUP" \
    --output json
)"

BUDGET_JSON="$(
  aws budgets describe-budget \
    --account-id "$ACCOUNT_ID" \
    --budget-name "$BUDGET_NAME" \
    --output json
)"

echo "PASS - live AWS resource data collected"

echo
echo "----- BUILD COMPLIANCE REPORT -----"

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg project "$PROJECT_NAME" \
  --arg account "$ACCOUNT_ID" \
  --arg identity "$IDENTITY_ARN" \
  --arg expected_region "$EXPECTED_REGION" \
  --arg configured_region "$CONFIGURED_REGION" \
  --argjson instance "$INSTANCE_JSON" \
  --argjson vpc "$VPC_JSON" \
  --argjson subnet "$SUBNET_JSON" \
  --argjson sg "$SG_JSON" \
  --argjson flow "$FLOW_JSON" \
  --argjson logs "$LOG_JSON" \
  --argjson budget "$BUDGET_JSON" \
'
  def instance_data:
    $instance.Reservations[0].Instances[0];

  def tag_value($key):
    (
      instance_data.Tags
      | map(select(.Key == $key))
      | .[0].Value
    ) // null;

  def control($id; $description; $passed; $actual; $expected):
    {
      id: $id,
      description: $description,
      status:
        (
          if $passed
          then "PASS"
          else "FAIL"
          end
        ),
      actual: $actual,
      expected: $expected
    };

  [
    control(
      "AWS-REGION-001";
      "AWS resources must operate in the approved region";
      ($configured_region == $expected_region);
      $configured_region;
      $expected_region
    ),

    control(
      "AWS-EC2-001";
      "Baseline EC2 instance must not have a public IPv4 address";
      (instance_data.PublicIpAddress == null);
      (instance_data.PublicIpAddress // "none");
      "none"
    ),

    control(
      "AWS-EC2-002";
      "EC2 Instance Metadata Service must require IMDSv2";
      (instance_data.MetadataOptions.HttpTokens == "required");
      instance_data.MetadataOptions.HttpTokens;
      "required"
    ),

    control(
      "AWS-EC2-003";
      "Detailed EC2 monitoring must be enabled";
      (instance_data.Monitoring.State == "enabled");
      instance_data.Monitoring.State;
      "enabled"
    ),

    control(
      "AWS-SUBNET-001";
      "Subnet must not auto-assign public IPv4 addresses";
      (
        $subnet.Subnets[0].MapPublicIpOnLaunch
        == false
      );
      $subnet.Subnets[0].MapPublicIpOnLaunch;
      false
    ),

    control(
      "AWS-SG-001";
      "Baseline compute security group must have no ingress rules";
      (
        ($sg.SecurityGroups[0].IpPermissions | length)
        == 0
      );
      ($sg.SecurityGroups[0].IpPermissions | length);
      0
    ),

    control(
      "AWS-SG-002";
      "Baseline compute security group must have no egress rules";
      (
        ($sg.SecurityGroups[0].IpPermissionsEgress | length)
        == 0
      );
      ($sg.SecurityGroups[0].IpPermissionsEgress | length);
      0
    ),

    control(
      "AWS-LOG-001";
      "VPC Flow Logs must be active";
      ($flow.FlowLogs[0].FlowLogStatus == "ACTIVE");
      $flow.FlowLogs[0].FlowLogStatus;
      "ACTIVE"
    ),

    control(
      "AWS-LOG-002";
      "CloudWatch VPC Flow Log retention must be at least 365 days";
      (
        ($logs.logGroups[0].retentionInDays // 0)
        >= 365
      );
      ($logs.logGroups[0].retentionInDays // 0);
      365
    ),

    control(
      "AWS-LOG-003";
      "CloudWatch VPC Flow Log group must use KMS encryption";
      (
        $logs.logGroups[0].kmsKeyId
        != null
      );
      (
        $logs.logGroups[0].kmsKeyId
        // "none"
      );
      "KMS key ARN"
    ),

    control(
      "AWS-TAG-001";
      "Project governance tag must match the project";
      (
        tag_value("Project")
        == $project
      );
      tag_value("Project");
      $project
    ),

    control(
      "AWS-TAG-002";
      "Environment governance tag must be dev";
      (
        tag_value("Environment")
        == "dev"
      );
      tag_value("Environment");
      "dev"
    ),

    control(
      "AWS-TAG-003";
      "ManagedBy governance tag must identify Terraform";
      (
        tag_value("ManagedBy")
        == "Terraform"
      );
      tag_value("ManagedBy");
      "Terraform"
    ),

    control(
      "AWS-BUDGET-001";
      "Native AWS monthly budget must exist";
      (
        $budget.Budget.BudgetName
        != null
      );
      (
        $budget.Budget.BudgetName
        // "missing"
      );
      "mc-finops-dev-monthly-budget"
    ),

    control(
      "AWS-BUDGET-002";
      "AWS monthly budget must be USD 25";
      (
        ($budget.Budget.BudgetLimit.Amount | tonumber)
        == 25
      );
      ($budget.Budget.BudgetLimit.Amount | tonumber);
      25
    )
  ]
  as $controls

  |
  {
    generated_at: $generated_at,
    project: $project,

    cloud: "AWS",

    account_id: $account,

    identity_arn: $identity,

    expected_region: $expected_region,

    summary: {
      total_controls:
        ($controls | length),

      passed:
        (
          [
            $controls[]
            | select(.status == "PASS")
          ]
          | length
        ),

      failed:
        (
          [
            $controls[]
            | select(.status == "FAIL")
          ]
          | length
        ),

      compliant:
        (
          (
            [
              $controls[]
              | select(.status == "FAIL")
            ]
            | length
          )
          == 0
        )
    },

    controls: $controls
  }
' \
> "$REPORT_FILE"

echo
echo "----- VALIDATE GENERATED REPORT -----"

jq empty "$REPORT_FILE"

echo "PASS - compliance report is valid JSON"

echo
echo "----- AWS COMPLIANCE SUMMARY -----"

jq '.summary' "$REPORT_FILE"

echo
echo "----- AWS CONTROL RESULTS -----"

jq -r '
  .controls[]
  | [
      .status,
      .id,
      .description
    ]
  | @tsv
' "$REPORT_FILE" \
| column -t -s $'\t'

FAILURE_COUNT="$(
  jq -r '.summary.failed' \
    "$REPORT_FILE"
)"

echo
echo "AWS failed controls: $FAILURE_COUNT"

if [ "$FAILURE_COUNT" -eq 0 ]; then
  echo "PASS - AWS runtime baseline is compliant"
  exit 0
else
  echo "FAIL - AWS runtime compliance violations detected"
  exit 2
fi
