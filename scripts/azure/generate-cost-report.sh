#!/usr/bin/env bash

set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-mc-finops-dev-cac}"
REPORT_DIR="${1:-reports/cost/azure}"

MAX_ATTEMPTS="${AZURE_COST_MAX_ATTEMPTS:-5}"
INITIAL_DELAY="${AZURE_COST_INITIAL_DELAY_SECONDS:-5}"

mkdir -p "$REPORT_DIR"

REPORT_DATE="$(
  date -u \
    +%Y-%m-%d
)"

RAW_FILE="$REPORT_DIR/azure-cost-${REPORT_DATE}.json"
SUMMARY_FILE="$REPORT_DIR/azure-cost-${REPORT_DATE}.summary.json"

TEMP_RESPONSE="$(
  mktemp
)"

QUERY_FILE="$(
  mktemp
)"

cleanup() {
  rm -f \
    "$TEMP_RESPONSE" \
    "$QUERY_FILE"
}

trap cleanup EXIT

SUBSCRIPTION_ID="$(
  az account show \
    --query id \
    --output tsv
)"

SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

API_URL="https://management.azure.com${SCOPE}/providers/Microsoft.CostManagement/query?api-version=2023-03-01"

echo
echo "===== AZURE COST REPORT ====="

echo "Subscription:   $SUBSCRIPTION_ID"
echo "Resource group: $RESOURCE_GROUP"
echo "Scope:          $SCOPE"
echo "Max attempts:   $MAX_ATTEMPTS"

cat > "$QUERY_FILE" <<'JSON'
{
  "type": "ActualCost",
  "timeframe": "MonthToDate",
  "dataset": {
    "granularity": "None",
    "aggregation": {
      "totalCost": {
        "name": "Cost",
        "function": "Sum"
      }
    },
    "grouping": [
      {
        "type": "Dimension",
        "name": "ServiceName"
      }
    ]
  }
}
JSON

ATTEMPT=1
DELAY="$INITIAL_DELAY"
SUCCESS=0

while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]
do
  echo
  echo "Azure Cost Management request attempt $ATTEMPT/$MAX_ATTEMPTS"

  rm -f "$TEMP_RESPONSE"

  HTTP_CODE="$(
    az rest \
      --method post \
      --url "$API_URL" \
      --headers \
        Content-Type=application/json \
      --body @"$QUERY_FILE" \
      --output json \
      2>"$TEMP_RESPONSE.stderr" \
      > "$TEMP_RESPONSE" \
      && echo "0" \
      || echo "$?"
  )"

  if jq -e '
      (
        .properties.columns
        | type == "array"
      )
      and
      (
        .properties.rows
        | type == "array"
      )
    ' "$TEMP_RESPONSE" \
    >/dev/null 2>&1
  then
    SUCCESS=1
    echo "PASS - valid Azure Cost Management response received"
    break
  fi

  ERROR_CODE="$(
    jq -r '
      .error.code
      // empty
    ' "$TEMP_RESPONSE" \
    2>/dev/null \
    || true
  )"

  ERROR_MESSAGE="$(
    jq -r '
      .error.message
      // empty
    ' "$TEMP_RESPONSE" \
    2>/dev/null \
    || true
  )"

  echo "Azure request did not return cost data"

  if [ -n "$ERROR_CODE" ]; then
    echo "API error code:    $ERROR_CODE"
  fi

  if [ -n "$ERROR_MESSAGE" ]; then
    echo "API error message: $ERROR_MESSAGE"
  fi

  if [ -s "$TEMP_RESPONSE.stderr" ]; then
    echo
    echo "Azure CLI stderr:"
    cat "$TEMP_RESPONSE.stderr"
  fi

  if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
    break
  fi

  echo
  echo "Retrying after ${DELAY}s..."

  sleep "$DELAY"

  DELAY=$((DELAY * 2))
  ATTEMPT=$((ATTEMPT + 1))
done

rm -f "$TEMP_RESPONSE.stderr"

if [ "$SUCCESS" -ne 1 ]; then
  echo
  echo "ERROR - Azure Cost Management did not return usable cost data"
  echo "No Azure report file will be retained."
  exit 1
fi

cp "$TEMP_RESPONSE" "$RAW_FILE"

jq empty "$RAW_FILE"

echo
echo "PASS - raw Azure cost report stored"

COLUMN_NAMES="$(
  jq -r '
    .properties.columns[]
    | .name
  ' "$RAW_FILE"
)"

echo
echo "Azure Cost Management columns:"
printf '%s\n' "$COLUMN_NAMES"

COST_INDEX="$(
  jq '
    [
      .properties.columns
      | to_entries[]
      | select(
          .value.name == "Cost"
          or
          .value.name == "PreTaxCost"
        )
      | .key
    ][0]
  ' "$RAW_FILE"
)"

SERVICE_INDEX="$(
  jq '
    [
      .properties.columns
      | to_entries[]
      | select(.value.name == "ServiceName")
      | .key
    ][0]
  ' "$RAW_FILE"
)"

CURRENCY_INDEX="$(
  jq '
    [
      .properties.columns
      | to_entries[]
      | select(.value.name == "Currency")
      | .key
    ][0]
  ' "$RAW_FILE"
)"

if \
  [ "$COST_INDEX" = "null" ] \
  || [ "$SERVICE_INDEX" = "null" ]
then
  echo
  echo "ERROR - expected Azure cost columns are missing"
  exit 1
fi

jq \
  --argjson cost_index "$COST_INDEX" \
  --argjson service_index "$SERVICE_INDEX" \
  --argjson currency_index "$CURRENCY_INDEX" \
  '
    {
      cloud: "Azure",

      currency:
        (
          if $currency_index == null then
            "CAD"
          elif (.properties.rows | length) == 0 then
            "CAD"
          else
            .properties.rows[0][$currency_index] // "CAD"
          end
        ),

      total_cost:
        (
          [
            .properties.rows[]
            | .[$cost_index]
            | tonumber
          ]
          | add
          // 0
        ),

      services:
        [
          .properties.rows[]
          | {
              service:
                .[$service_index],

              cost:
                (
                  .[$cost_index]
                  | tonumber
                ),

              currency:
                (
                  if $currency_index == null then
                    "CAD"
                  else
                    .[$currency_index]
                  end
                )
            }
        ]
    }
  ' "$RAW_FILE" \
> "$SUMMARY_FILE"

jq empty "$SUMMARY_FILE"

echo
echo "Azure cost summary:"

jq . "$SUMMARY_FILE"

echo
echo "RAW_REPORT=$RAW_FILE"
echo "SUMMARY_REPORT=$SUMMARY_FILE"
