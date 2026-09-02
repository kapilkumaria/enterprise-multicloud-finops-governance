#!/usr/bin/env bash

set -u

TARGET="${1:-}"

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" \
  && pwd
)"

REPO_ROOT="$(
  cd "$SCRIPT_DIR/../.." \
  && pwd
)"

REGION_GATE="$SCRIPT_DIR/check-region-policy.sh"
TAG_GATE="$SCRIPT_DIR/check-mandatory-tags.sh"
COST_GATE="$REPO_ROOT/scripts/cost/check-cost-policy.sh"

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <terraform-directory>"
  exit 2
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR - target directory does not exist: $TARGET"
  exit 2
fi

for GATE in \
  "$REGION_GATE" \
  "$TAG_GATE" \
  "$COST_GATE"
do
  if [ ! -x "$GATE" ]; then
    echo "ERROR - required policy gate unavailable: $GATE"
    exit 2
  fi
done

echo
echo "===== PRE-DEPLOYMENT MULTI-CLOUD GOVERNANCE ====="
echo
echo "Target: $TARGET"

echo
echo "============================================================"
echo "POLICY CLASS 1 - REGION GOVERNANCE"
echo "============================================================"

"$REGION_GATE" "$TARGET"
REGION_EXIT=$?

echo
echo "Region policy exit code: $REGION_EXIT"

echo
echo "============================================================"
echo "POLICY CLASS 2 - MANDATORY TAG GOVERNANCE"
echo "============================================================"

"$TAG_GATE" "$TARGET"
TAG_EXIT=$?

echo
echo "Mandatory-tag policy exit code: $TAG_EXIT"

echo
echo "============================================================"
echo "POLICY CLASS 3 - FINOPS COST GOVERNANCE"
echo "============================================================"

"$COST_GATE" "$TARGET"
COST_EXIT=$?

echo
echo "FinOps cost policy exit code: $COST_EXIT"

echo
echo "============================================================"
echo "UNIFIED GOVERNANCE RESULT"
echo "============================================================"

printf '%-24s %-10s\n' "Policy" "Exit"
printf '%-24s %-10s\n' "Region" "$REGION_EXIT"
printf '%-24s %-10s\n' "Mandatory tags" "$TAG_EXIT"
printf '%-24s %-10s\n' "Modeled cost" "$COST_EXIT"

if \
  [ "$REGION_EXIT" -eq 2 ] \
  || [ "$TAG_EXIT" -eq 2 ] \
  || [ "$COST_EXIT" -eq 2 ]
then
  echo
  echo "GOVERNANCE RESULT: ERROR"
  echo "A policy engine could not safely evaluate the configuration."
  echo "Fail-closed: infrastructure deployment must be blocked."
  exit 2
fi

if \
  [ "$REGION_EXIT" -ne 0 ] \
  || [ "$TAG_EXIT" -ne 0 ] \
  || [ "$COST_EXIT" -ne 0 ]
then
  echo
  echo "GOVERNANCE RESULT: DENY"
  echo "Infrastructure deployment must be blocked."
  exit 1
fi

echo
echo "GOVERNANCE RESULT: ALLOW"
echo "Configuration satisfies all active pre-deployment governance policies."

exit 0
