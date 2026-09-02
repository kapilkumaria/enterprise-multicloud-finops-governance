#!/usr/bin/env bash

set -u
set -o pipefail

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <terraform-directory>"
  exit 2
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR - directory not found: $TARGET"
  exit 2
fi

REQUIRED_TAGS=(
  Application
  BusinessUnit
  CostCenter
  DataClassification
  Environment
  ManagedBy
  Owner
  Project
)

CHECKS=0
VIOLATIONS=0
DIRECT_TAGGABLE_RESOURCES=0
MODULE_CALLS=0

echo
echo "===== MANDATORY TAG POLICY CHECK ====="
echo
echo "Target: $TARGET"

echo
echo "Required tags:"

for TAG in "${REQUIRED_TAGS[@]}"
do
  echo "  - $TAG"
done


extract_resource_block() {

  local file="$1"
  local resource_type="$2"
  local resource_name="$3"

  python3 - \
    "$file" \
    "$resource_type" \
    "$resource_name" <<'PY'
import re
import sys

path, rtype, rname = sys.argv[1:4]

text = open(path, encoding="utf-8").read()

pattern = (
    r'resource\s+"'
    + re.escape(rtype)
    + r'"\s+"'
    + re.escape(rname)
    + r'"\s*\{'
)

match = re.search(
    pattern,
    text,
    re.MULTILINE
)

if not match:
    sys.exit(1)

start = match.end()
depth = 1
i = start

while i < len(text) and depth > 0:

    if text[i] == "{":
        depth += 1

    elif text[i] == "}":
        depth -= 1

    i += 1

print(text[start:i - 1])
PY
}


extract_map_block() {

  local target_dir="$1"
  local map_name="$2"

  python3 - \
    "$target_dir" \
    "$map_name" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
map_name = sys.argv[2]

for path in root.rglob("*.tf"):

    if ".terraform" in path.parts:
        continue

    text = path.read_text(
        encoding="utf-8"
    )

    pattern = (
        r'\b'
        + re.escape(map_name)
        + r'\s*=\s*\{'
    )

    match = re.search(
        pattern,
        text,
        re.MULTILINE
    )

    if not match:
        continue

    start = match.end()
    depth = 1
    i = start

    while i < len(text) and depth > 0:

        if text[i] == "{":
            depth += 1

        elif text[i] == "}":
            depth -= 1

        i += 1

    print(text[start:i - 1])
    sys.exit(0)

sys.exit(1)
PY
}


extract_tags_map_from_resource() {

  python3 <<'PY'
import re
import sys

text = sys.stdin.read()

match = re.search(
    r'(?m)^[ \t]*tags[ \t]*=[ \t]*\{',
    text
)

if not match:
    sys.exit(0)

start = match.end()
depth = 1
i = start

while i < len(text) and depth > 0:

    if text[i] == "{":
        depth += 1

    elif text[i] == "}":
        depth -= 1

    i += 1

print(text[start:i - 1])
PY
}


check_required_tags_text() {

  local context="$1"
  local text="$2"

  local failed=0

  for TAG in "${REQUIRED_TAGS[@]}"
  do

    CHECKS=$((CHECKS + 1))

    if printf '%s\n' "$text" \
      | grep -Eq \
        "(^|[[:space:]])${TAG}[[:space:]]*="
    then
      :
    else

      if [ "$failed" -eq 0 ]; then
        echo "DENY  $context"
      fi

      echo "      Missing required tag: $TAG"

      VIOLATIONS=$((VIOLATIONS + 1))
      failed=1

    fi

  done

  if [ "$failed" -eq 0 ]; then
    echo "ALLOW $context"
  fi
}


is_direct_taggable() {

  case "$1" in

    aws_budgets_budget|\
    aws_iam_role_policy|\
    aws_route_table_association)
      return 1
      ;;

    aws_*)
      return 0
      ;;

    azurerm_subnet|\
    azurerm_subnet_network_security_group_association|\
    azurerm_consumption_budget_resource_group)
      return 1
      ;;

    azurerm_*)
      return 0
      ;;

    *)
      return 1
      ;;

  esac
}


echo
echo "----- DIRECT RESOURCE TAG POLICY -----"

while IFS= read -r TF_FILE
do

  while IFS=$'\t' read -r RESOURCE_TYPE RESOURCE_NAME
  do

    [ -n "$RESOURCE_TYPE" ] || continue

    if ! is_direct_taggable "$RESOURCE_TYPE"; then

      echo \
        "SKIP  ${RESOURCE_TYPE}.${RESOURCE_NAME} non-taggable/control resource"

      continue

    fi

    DIRECT_TAGGABLE_RESOURCES=$((DIRECT_TAGGABLE_RESOURCES + 1))

    BLOCK="$(
      extract_resource_block \
        "$TF_FILE" \
        "$RESOURCE_TYPE" \
        "$RESOURCE_NAME"
    )"

    TAG_TEXT="$(
      printf '%s\n' "$BLOCK" \
        | extract_tags_map_from_resource
    )"

    if printf '%s\n' "$BLOCK" \
      | grep -Eq '^[[:space:]]*tags[[:space:]]*=[[:space:]]*local\.common_tags[[:space:]]*$'
    then

      echo "ALLOW ${RESOURCE_TYPE}.${RESOURCE_NAME}"
      echo "      Uses governed local.common_tags"

      CHECKS=$((CHECKS + 1))

    elif [ -z "$TAG_TEXT" ]; then

      echo "DENY  ${RESOURCE_TYPE}.${RESOURCE_NAME}"
      echo "      Missing explicit tags block"

      VIOLATIONS=$((VIOLATIONS + 1))
      CHECKS=$((CHECKS + 1))

    else

      check_required_tags_text \
        "${RESOURCE_TYPE}.${RESOURCE_NAME}" \
        "$TAG_TEXT"

    fi

  done < <(

    python3 - "$TF_FILE" <<'PY'
import re
import sys

text = open(
    sys.argv[1],
    encoding="utf-8"
).read()

for match in re.finditer(
    r'resource\s+"([^"]+)"\s+"([^"]+)"\s*\{',
    text
):
    print(
        f"{match.group(1)}\t"
        f"{match.group(2)}"
    )
PY

  )

done < <(
  find \
    "$TARGET" \
    -type f \
    -name '*.tf' \
    -not -path '*/.terraform/*' \
    -print
)


echo
echo "----- MODULE-AWARE GOVERNANCE POLICY -----"

MODULE_CALLS="$(
  grep -Rh \
    --include='*.tf' \
    '^module "' \
    "$TARGET" \
    2>/dev/null \
  | wc -l \
  | tr -d ' '
)"

echo "Module calls discovered: $MODULE_CALLS"


if [ "$MODULE_CALLS" -gt 0 ]; then

  echo
  echo "Resolving shared common_tags governance..."

  COMMON_TAGS="$(
    extract_map_block \
      "$TARGET" \
      "common_tags" \
      2>/dev/null \
      || true
  )"

  if [ -z "$COMMON_TAGS" ]; then

    echo "DENY  shared common_tags governance"
    echo "      common_tags map could not be resolved"

    VIOLATIONS=$((VIOLATIONS + 1))
    CHECKS=$((CHECKS + 1))

  else

    echo "Resolved common_tags:"
    printf '%s\n' "$COMMON_TAGS"

    echo

    check_required_tags_text \
      "shared local.common_tags" \
      "$COMMON_TAGS"

  fi


  if grep -Rq \
    --include='*.tf' \
    'provider "aws"' \
    "$TARGET"
  then

    echo
    echo "Checking AWS provider default_tags propagation..."

    if grep -Rqs \
      --include='*.tf' \
      'tags[[:space:]]*=[[:space:]]*local\.common_tags' \
      "$TARGET"
    then

      echo \
        "ALLOW AWS provider/modules reference local.common_tags"

      CHECKS=$((CHECKS + 1))

    else

      echo \
        "DENY  AWS provider/modules do not reference local.common_tags"

      CHECKS=$((CHECKS + 1))
      VIOLATIONS=$((VIOLATIONS + 1))

    fi

  fi


  if grep -Rq \
    --include='*.tf' \
    'azurerm_' \
    "$TARGET"
  then

    echo
    echo "Checking Azure module governance propagation..."

    AZURE_TAG_PROPAGATION_COUNT="$(
      grep -Rh \
        --include='*.tf' \
        'tags[[:space:]]*=[[:space:]]*local\.common_tags' \
        "$TARGET" \
        2>/dev/null \
      | wc -l \
      | tr -d ' '
    )"

    echo \
      "Azure references to local.common_tags: $AZURE_TAG_PROPAGATION_COUNT"

    if [ "$AZURE_TAG_PROPAGATION_COUNT" -gt 0 ]; then

      echo \
        "ALLOW Azure environment propagates local.common_tags"

      CHECKS=$((CHECKS + 1))

    else

      echo \
        "DENY  Azure environment does not propagate local.common_tags"

      CHECKS=$((CHECKS + 1))
      VIOLATIONS=$((VIOLATIONS + 1))

    fi

  fi

fi


echo
echo "----- TAG POLICY RESULT -----"

echo "Direct taggable resources: $DIRECT_TAGGABLE_RESOURCES"
echo "Module calls:              $MODULE_CALLS"
echo "Checks performed:          $CHECKS"
echo "Violations:                $VIOLATIONS"


if [ "$DIRECT_TAGGABLE_RESOURCES" -eq 0 ] \
  && [ "$MODULE_CALLS" -eq 0 ]; then

  echo \
    "ERROR - no supported Terraform governance surface detected"

  exit 2

fi


if [ "$VIOLATIONS" -gt 0 ]; then

  echo "POLICY RESULT: DENY"
  exit 1

fi


echo "POLICY RESULT: ALLOW"

exit 0
