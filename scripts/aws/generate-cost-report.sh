#!/usr/bin/env bash

set -euo pipefail

PROJECT_TAG="enterprise-multicloud-finops-governance"

REPORT_DIR="${1:-reports/cost/aws}"

mkdir -p "$REPORT_DIR"

START_DATE="$(
  date -u \
    -d "$(date -u +%Y-%m-01)" \
    +%Y-%m-%d
)"

END_DATE="$(
  date -u \
    -d tomorrow \
    +%Y-%m-%d
)"

REPORT_DATE="$(
  date -u \
    +%Y-%m-%d
)"

RAW_FILE="$REPORT_DIR/aws-cost-${REPORT_DATE}.json"
SUMMARY_FILE="$REPORT_DIR/aws-cost-${REPORT_DATE}.summary.json"

echo
echo "===== AWS COST REPORT ====="

echo "Project tag: $PROJECT_TAG"
echo "Start date:  $START_DATE"
echo "End date:    $END_DATE"

aws ce get-cost-and-usage \
  --time-period \
    Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --metrics \
    UnblendedCost \
    AmortizedCost \
  --filter "{
    \"Tags\": {
      \"Key\": \"Project\",
      \"Values\": [
        \"$PROJECT_TAG\"
      ]
    }
  }" \
  --group-by \
    Type=DIMENSION,Key=SERVICE \
  --output json \
  > "$RAW_FILE"

jq empty "$RAW_FILE"

jq '
  {
    cloud: "AWS",
    currency:
      (
        .ResultsByTime[0]
        .Total.UnblendedCost.Unit
        // "USD"
      ),
    period_start:
      .ResultsByTime[0].TimePeriod.Start,
    period_end:
      .ResultsByTime[0].TimePeriod.End,
    estimated:
      .ResultsByTime[0].Estimated,
    unblended_cost:
      (
        .ResultsByTime[0]
        .Total.UnblendedCost.Amount
        | tonumber
      ),
    amortized_cost:
      (
        .ResultsByTime[0]
        .Total.AmortizedCost.Amount
        | tonumber
      ),
    services:
      [
        .ResultsByTime[0].Groups[]
        | {
            service:
              .Keys[0],
            unblended_cost:
              (
                .Metrics.UnblendedCost.Amount
                | tonumber
              ),
            amortized_cost:
              (
                .Metrics.AmortizedCost.Amount
                | tonumber
              )
          }
      ]
  }
' "$RAW_FILE" \
> "$SUMMARY_FILE"

echo
echo "AWS cost summary:"
jq . "$SUMMARY_FILE"

echo
echo "RAW_REPORT=$RAW_FILE"
echo "SUMMARY_REPORT=$SUMMARY_FILE"
