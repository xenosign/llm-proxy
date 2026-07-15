#!/usr/bin/env bash
set -euo pipefail

PROXY_URL="${PROXY_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:?Set LITELLM_MASTER_KEY}"
MAX_BUDGET="${MAX_BUDGET:-50}"
RPM_LIMIT="${RPM_LIMIT:-20}"
TPM_LIMIT="${TPM_LIMIT:-100000}"
KEY_DURATION="${KEY_DURATION:-30d}"

TEAMS=(team_a team_b team_c team_d)

for TEAM in "${TEAMS[@]}"; do
  echo "== $TEAM =="
  curl -sS -X POST "$PROXY_URL/key/generate" \
    -H "Authorization: Bearer $MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"team_id\": \"$TEAM\",
      \"max_budget\": $MAX_BUDGET,
      \"rpm_limit\": $RPM_LIMIT,
      \"tpm_limit\": $TPM_LIMIT,
      \"duration\": \"$KEY_DURATION\"
    }"
  echo -e "\n"
done
