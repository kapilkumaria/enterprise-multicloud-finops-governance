#!/usr/bin/env bash

set -euo pipefail

AWS_DIR="${AWS_COST_REPORT_DIR:-reports/cost/aws}"
AZURE_DIR="${AZURE_COST_REPORT_DIR:-reports/cost/azure}"
SUMMARY_DIR="${MULTICLOUD_COST_REPORT_DIR:-reports/cost/summary}"

mkdir -p "$SUMMARY_DIR"

REPORT_DATE="$(
  date -u \
    +%Y-%m-%d
)"

AWS_FILE="$(
  find "$AWS_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'aws-cost-*.summary.json' \
    -printf '%T@ %p\n' \
  | sort -nr \
  | head -n1 \
  | cut -d' ' -f2-
)"

AZURE_FILE="$(
  find "$AZURE_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'azure-cost-*.summary.json' \
    -printf '%T@ %p\n' \
  | sort -nr \
  | head -n1 \
  | cut -d' ' -f2-
)"

if [ -z "$AWS_FILE" ]; then
  echo "ERROR - AWS summary report not found"
  exit 1
fi

if [ -z "$AZURE_FILE" ]; then
  echo "ERROR - Azure summary report not found"
  exit 1
fi

OUTPUT_FILE="$SUMMARY_DIR/multicloud-cost-${REPORT_DATE}.json"

jq -n \
  --slurpfile aws "$AWS_FILE" \
  --slurpfile azure "$AZURE_FILE" \
  '
  {
    generated_at:
      (
        now
        | todate
      ),
    project:
      "enterprise-multicloud-finops-governance",
    clouds: {
      aws:
        $aws[0],
      azure:
        $azure[0]
    },
    note:
      "AWS and Azure values retain their native billing currencies and are not numerically combined."
  }
  ' \
> "$OUTPUT_FILE"

echo
echo "===== MULTI-CLOUD COST SUMMARY ====="

jq . "$OUTPUT_FILE"

echo
echo "REPORT=$OUTPUT_FILE"
