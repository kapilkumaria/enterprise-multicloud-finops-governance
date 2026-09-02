#!/usr/bin/env bash

set -u

TARGET="${1:-}"

APPROVED_AWS_REGION="${APPROVED_AWS_REGION:-us-east-1}"
APPROVED_AZURE_REGION="${APPROVED_AZURE_REGION:-canadacentral}"

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <terraform-directory>"
  exit 2
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR - target directory does not exist: $TARGET"
  exit 2
fi

echo
echo "===== MULTI-CLOUD REGION POLICY CHECK ====="
echo
echo "Target:                 $TARGET"
echo "Approved AWS region:    $APPROVED_AWS_REGION"
echo "Approved Azure region:  $APPROVED_AZURE_REGION"

CHECKS=0
VIOLATIONS=0


############################################################
# HELPERS
############################################################

normalize_region() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -d '[:space:]'
}


extract_terraform_variable_default() {
  local VARIABLE_NAME="$1"
  local VARIABLES_FILE="$2"

  if [ ! -f "$VARIABLES_FILE" ]; then
    return 1
  fi

  sed -n \
    "/variable \"${VARIABLE_NAME}\"/,/^}/p" \
    "$VARIABLES_FILE" \
  | sed -nE \
      's/^[[:space:]]*default[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
  | head -1
}


############################################################
# AWS REGION POLICY
############################################################

AWS_PROVIDER_FILES="$(
  grep -Rl \
    'provider[[:space:]]*"aws"' \
    "$TARGET" \
    --include='*.tf' \
    2>/dev/null \
    || true
)"

if [ -n "$AWS_PROVIDER_FILES" ]; then

  echo
  echo "----- AWS REGION POLICY -----"

  AWS_REGIONS=""

  while IFS= read -r FILE
  do
    [ -z "$FILE" ] && continue

    IN_AWS_PROVIDER=0

    while IFS= read -r LINE
    do

      if printf '%s\n' "$LINE" \
        | grep -Eq \
          '^[[:space:]]*provider[[:space:]]+"aws"[[:space:]]*\{'
      then
        IN_AWS_PROVIDER=1
        continue
      fi

      if [ "$IN_AWS_PROVIDER" -eq 1 ]; then

        if printf '%s\n' "$LINE" \
          | grep -Eq \
            '^[[:space:]]*region[[:space:]]*='
        then

          REGION_EXPR="$(
            printf '%s\n' "$LINE" \
            | sed -E \
                's/^[[:space:]]*region[[:space:]]*=[[:space:]]*//' \
            | sed -E \
                's/[[:space:]]*#.*$//' \
            | sed -E \
                's/[[:space:]]+$//'
          )"

          if printf '%s\n' "$REGION_EXPR" \
            | grep -Eq '^"[^"]+"$'
          then

            REGION="$(
              printf '%s\n' "$REGION_EXPR" \
              | sed -E 's/^"([^"]+)"$/\1/'
            )"

            AWS_REGIONS="$AWS_REGIONS"$'\n'"literal|$REGION"

          elif printf '%s\n' "$REGION_EXPR" \
            | grep -Eq '^var\.[A-Za-z0-9_]+$'
          then

            VAR_NAME="${REGION_EXPR#var.}"

            VARIABLE_VALUE="$(
              printf '%s\n' "$REGION_EXPR" \
              | terraform \
                  -chdir="$TARGET" \
                  console \
                  2>/dev/null \
              | tail -1 \
              | sed -E 's/^"([^"]*)"$/\1/'
            )"

            if [ -n "$VARIABLE_VALUE" ] \
              && [ "$VARIABLE_VALUE" != "$REGION_EXPR" ]
            then

              AWS_REGIONS="$AWS_REGIONS"$'\n'"variable:$VAR_NAME|$VARIABLE_VALUE"

            else

              AWS_REGIONS="$AWS_REGIONS"$'\n'"unresolved:$VAR_NAME|$REGION_EXPR"

            fi

          else

            AWS_REGIONS="$AWS_REGIONS"$'\n'"unsupported|$REGION_EXPR"

          fi

        fi

        if printf '%s\n' "$LINE" \
          | grep -Eq \
            '^[[:space:]]*\}[[:space:]]*$'
        then
          IN_AWS_PROVIDER=0
        fi

      fi

    done < "$FILE"

  done <<< "$AWS_PROVIDER_FILES"

  AWS_REGIONS="$(
    printf '%s\n' "$AWS_REGIONS" \
    | sed '/^[[:space:]]*$/d' \
    | sort -u
  )"

  if [ -z "$AWS_REGIONS" ]; then

    echo "DENY - AWS provider exists but region could not be resolved"

    CHECKS=$((CHECKS + 1))
    VIOLATIONS=$((VIOLATIONS + 1))

  else

    while IFS='|' read -r SOURCE REGION
    do

      [ -z "$SOURCE" ] && continue

      CHECKS=$((CHECKS + 1))

      if [[ "$SOURCE" == unresolved:* ]]; then

        VAR_NAME="${SOURCE#unresolved:}"

        echo "DENY - AWS region variable could not be resolved: $VAR_NAME"
        echo "       Expression: $REGION"

        VIOLATIONS=$((VIOLATIONS + 1))
        continue

      fi

      if [ "$SOURCE" = "unsupported" ]; then

        echo "DENY - unsupported AWS region expression: $REGION"

        VIOLATIONS=$((VIOLATIONS + 1))
        continue

      fi

      REGION_NORMALIZED="$(
        normalize_region "$REGION"
      )"

      EXPECTED_NORMALIZED="$(
        normalize_region "$APPROVED_AWS_REGION"
      )"

      if [ "$REGION_NORMALIZED" = "$EXPECTED_NORMALIZED" ]; then

        if [[ "$SOURCE" == variable:* ]]; then

          VAR_NAME="${SOURCE#variable:}"

          echo "ALLOW - AWS variable $VAR_NAME resolves to: $REGION"

        else

          echo "ALLOW - AWS region: $REGION"

        fi

      else

        if [[ "$SOURCE" == variable:* ]]; then

          VAR_NAME="${SOURCE#variable:}"

          echo "DENY - AWS variable $VAR_NAME resolves to: $REGION"

        else

          echo "DENY - AWS region: $REGION"

        fi

        echo "       Required:   $APPROVED_AWS_REGION"

        VIOLATIONS=$((VIOLATIONS + 1))

      fi

    done <<< "$AWS_REGIONS"

  fi
fi


############################################################
# AZURE REGION POLICY
############################################################

AZURE_RESOURCE_FILES="$(
  grep -Rl \
    'azurerm_' \
    "$TARGET" \
    --include='*.tf' \
    2>/dev/null \
    || true
)"

if [ -n "$AZURE_RESOURCE_FILES" ]; then

  echo
  echo "----- AZURE REGION POLICY -----"

  AZURE_LOCATION_EXPRESSIONS="$(
    grep -RhE \
      '^[[:space:]]*location[[:space:]]*=' \
      "$TARGET" \
      --include='*.tf' \
      2>/dev/null \
    | sed -E \
        's/^[[:space:]]*location[[:space:]]*=[[:space:]]*//' \
    | sed -E \
        's/[[:space:]]*#.*$//' \
    | sort -u
  )"

  if [ -z "$AZURE_LOCATION_EXPRESSIONS" ]; then

    echo "DENY - Azure resources exist but no location controls were found"

    CHECKS=$((CHECKS + 1))
    VIOLATIONS=$((VIOLATIONS + 1))

  else

    while IFS= read -r LOCATION_EXPR
    do
      [ -z "$LOCATION_EXPR" ] && continue

      ########################################################
      # Literal Azure location
      ########################################################

      if [[ "$LOCATION_EXPR" =~ ^\"([^\"]+)\"$ ]]; then

        LOCATION="${BASH_REMATCH[1]}"

        CHECKS=$((CHECKS + 1))

        LOCATION_NORMALIZED="$(
          normalize_region "$LOCATION"
        )"

        EXPECTED_NORMALIZED="$(
          normalize_region "$APPROVED_AZURE_REGION"
        )"

        if [ "$LOCATION_NORMALIZED" = "$EXPECTED_NORMALIZED" ]; then

          echo "ALLOW - Azure literal region: $LOCATION"

        else

          echo "DENY - Azure literal region: $LOCATION"
          echo "       Required:             $APPROVED_AZURE_REGION"

          VIOLATIONS=$((VIOLATIONS + 1))

        fi

        continue
      fi


      ########################################################
      # Azure location variable
      ########################################################

      if [[ "$LOCATION_EXPR" =~ ^var\.([A-Za-z0-9_]+)$ ]]; then

        VARIABLE_NAME="${BASH_REMATCH[1]}"

        VARIABLE_VALUE="$(
          extract_terraform_variable_default \
            "$VARIABLE_NAME" \
            "$TARGET/variables.tf"
        )"

        CHECKS=$((CHECKS + 1))

        if [ -z "$VARIABLE_VALUE" ]; then

          echo \
            "DENY - Azure location variable could not be resolved: $LOCATION_EXPR"

          VIOLATIONS=$((VIOLATIONS + 1))

          continue
        fi

        LOCATION_NORMALIZED="$(
          normalize_region "$VARIABLE_VALUE"
        )"

        EXPECTED_NORMALIZED="$(
          normalize_region "$APPROVED_AZURE_REGION"
        )"

        if [ "$LOCATION_NORMALIZED" = "$EXPECTED_NORMALIZED" ]; then

          echo \
            "ALLOW - Azure variable $VARIABLE_NAME resolves to: $VARIABLE_VALUE"

        else

          echo \
            "DENY - Azure variable $VARIABLE_NAME resolves to: $VARIABLE_VALUE"

          echo \
            "       Required: $APPROVED_AZURE_REGION"

          VIOLATIONS=$((VIOLATIONS + 1))

        fi

        continue
      fi


      ########################################################
      # Derived locations
      #
      # Example:
      # azurerm_resource_group.dev.location
      #
      # These inherit the governed resource-group region.
      ########################################################

      if [[ "$LOCATION_EXPR" =~ ^azurerm_resource_group\.[A-Za-z0-9_-]+\.location$ ]]; then

        echo \
          "INFO - derived Azure location inherits governed resource-group location: $LOCATION_EXPR"

        continue
      fi


      ########################################################
      # Unknown expression: fail closed
      ########################################################

      CHECKS=$((CHECKS + 1))
      VIOLATIONS=$((VIOLATIONS + 1))

      echo \
        "DENY - unsupported Azure location expression: $LOCATION_EXPR"

    done <<< "$AZURE_LOCATION_EXPRESSIONS"

  fi
fi


############################################################
# FINAL POLICY RESULT
############################################################

echo
echo "----- REGION POLICY RESULT -----"

echo "Checks performed: $CHECKS"
echo "Violations:       $VIOLATIONS"

if [ "$CHECKS" -eq 0 ]; then

  echo "ERROR - no supported region controls were detected"
  exit 2

fi

if [ "$VIOLATIONS" -gt 0 ]; then

  echo "POLICY RESULT: DENY"
  exit 1

fi

echo "POLICY RESULT: ALLOW"

exit 0
