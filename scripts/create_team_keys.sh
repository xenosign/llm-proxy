#!/usr/bin/env bash
set -euo pipefail

PROXY_URL="${PROXY_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:?Set LITELLM_MASTER_KEY}"
MAX_BUDGET="${MAX_BUDGET:-50}"
RPM_LIMIT="${RPM_LIMIT:-20}"
TPM_LIMIT="${TPM_LIMIT:-100000}"
KEY_DURATION="${KEY_DURATION:-30d}"

# TEAMS: 쉼표로 구분된 팀 이름 목록 (예: team_a,team_b,team_c,team_d)
# TEAM_BUDGETS / TEAM_RPM_LIMITS / TEAM_TPM_LIMITS: TEAMS와 같은 순서로 매칭되는 팀별 값.
# 없거나 개수가 모자라면 각각 MAX_BUDGET / RPM_LIMIT / TPM_LIMIT 기본값 사용
IFS=',' read -ra TEAMS <<< "${TEAMS:-team_a,team_b,team_c,team_d}"
IFS=',' read -ra TEAM_BUDGETS <<< "${TEAM_BUDGETS:-}"
IFS=',' read -ra TEAM_RPM_LIMITS <<< "${TEAM_RPM_LIMITS:-}"
IFS=',' read -ra TEAM_TPM_LIMITS <<< "${TEAM_TPM_LIMITS:-}"

for i in "${!TEAMS[@]}"; do
  TEAM="${TEAMS[$i]}"
  BUDGET="${TEAM_BUDGETS[$i]:-$MAX_BUDGET}"
  TEAM_RPM="${TEAM_RPM_LIMITS[$i]:-$RPM_LIMIT}"
  TEAM_TPM="${TEAM_TPM_LIMITS[$i]:-$TPM_LIMIT}"
  echo "== $TEAM (budget: \$$BUDGET, rpm: $TEAM_RPM, tpm: $TEAM_TPM) =="

  # 팀 객체를 실제로 등록해야 Admin UI의 Teams 대시보드에 팀별 예산/사용량이 표시됨.
  # 이미 존재하는 팀이면 에러 응답이 오지만 무시하고 키 발급으로 진행
  curl -sS -X POST "$PROXY_URL/team/new" \
    -H "Authorization: Bearer $MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"team_id\": \"$TEAM\",
      \"team_alias\": \"$TEAM\",
      \"max_budget\": $BUDGET,
      \"rpm_limit\": $TEAM_RPM,
      \"tpm_limit\": $TEAM_TPM
    }" > /dev/null

  curl -sS -X POST "$PROXY_URL/key/generate" \
    -H "Authorization: Bearer $MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"team_id\": \"$TEAM\",
      \"max_budget\": $BUDGET,
      \"rpm_limit\": $TEAM_RPM,
      \"tpm_limit\": $TEAM_TPM,
      \"duration\": \"$KEY_DURATION\"
    }"
  echo -e "\n"
done
