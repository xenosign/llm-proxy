# llm-proxy

4개 팀이 하나의 공유 `OPENAI_API_KEY`를 안전하게 나눠 쓰기 위한 LiteLLM Proxy 배포 설정입니다.
각 팀은 실제 OpenAI 키를 모른 채, 프록시가 발급한 가상 키(virtual key)로만 요청을 보냅니다.

```
팀 A~D (virtual key)  →  LiteLLM Proxy (인증/예산/속도 제한)  →  OPENAI_API_KEY  →  OpenAI
```

## 로컬에서 실행

1. `.env.example`을 `.env`로 복사하고 값 채우기

   ```
   cp .env.example .env
   ```

   - `OPENAI_API_KEY`: 팀들이 공유할 실제 OpenAI 키
   - `LITELLM_MASTER_KEY`: 관리자 전용 키(가상 키 발급 권한). 랜덤 문자열로 직접 생성
   - `DATABASE_URL`: 로컬 compose에서는 기본값 그대로 사용

2. 실행

   ```
   docker compose up --build
   ```

   `http://localhost:4000`에서 OpenAI 호환 API가 뜹니다.

## 팀별 가상 키 발급

프록시가 뜬 상태에서 실행하면 `.env`의 `TEAMS`에 지정한 팀들의 가상 키가 생성됩니다.

```bash
LITELLM_MASTER_KEY=<.env에 넣은 값> \
PROXY_URL=http://localhost:4000 \
MAX_BUDGET=50 RPM_LIMIT=20 TPM_LIMIT=100000 \
bash scripts/create_team_keys.sh
```

- `TEAMS`: 생성할 팀 이름 목록, 쉼표 구분 (예: `team_1,team_2,team_3,team_4`). 팀 개수는 이 목록의 길이로 정해집니다.
- `TEAM_BUDGETS` / `TEAM_RPM_LIMITS` / `TEAM_TPM_LIMITS`: `TEAMS`와 같은 순서로 매칭되는 팀별 예산(USD)/분당 요청수(RPM)/분당 토큰수(TPM), 쉼표 구분 (예: `TEAM_BUDGETS=50,30,50,50`). 비어있거나 개수가 모자라면 각각 `MAX_BUDGET`/`RPM_LIMIT`/`TPM_LIMIT` 기본값이 적용됩니다.

출력된 `key` 값(`sk-litellm-...`)을 각 팀에 전달하면 됩니다. 팀은 아래처럼 기존 OpenAI SDK의
`base_url`과 `api_key`만 바꿔서 그대로 사용합니다.

```python
from openai import OpenAI

client = OpenAI(
    api_key="sk-litellm-teamA-...",       # 발급받은 가상 키
    base_url="https://<배포된 도메인>",
)
client.chat.completions.create(model="gpt-4o", messages=[...])
```

## 클라우드타입 배포

1. 이 저장소를 GitHub에 올리고 클라우드타입에서 **Dockerfile 배포**로 새 프로젝트 생성
2. 클라우드타입 콘솔의 환경변수(Secret)에 `OPENAI_API_KEY`, `LITELLM_MASTER_KEY` 등록
3. 클라우드타입 **Postgres 애드온**을 하나 생성하고, 발급되는 연결 문자열을 `DATABASE_URL` 환경변수로 등록
4. 배포 완료 후 클라우드타입이 자동으로 부여하는 `https://xxx.cloudtype.app` 도메인이 팀들이 접속할 엔드포인트
5. 로컬에서 했던 것과 동일하게 `scripts/create_team_keys.sh`를 `PROXY_URL`만 배포 도메인으로 바꿔서 실행 → 팀별 가상 키 발급

## 사용량 확인

- `GET /spend/logs`, `GET /team/info?team_id=team_a` 등으로 팀별 사용량 조회 가능 (Authorization: Bearer `LITELLM_MASTER_KEY`)
- 예산 초과 시 프록시가 자동으로 429/401을 반환하므로 별도 로직 불필요

## 팀별 예산 대시보드

LiteLLM Proxy에 내장된 Admin UI에서 팀별 예산 잔량을 바로 확인할 수 있습니다.

1. `<프록시 도메인>/ui` 접속
2. Username: `admin`, Password: `.env`에 넣은 `LITELLM_MASTER_KEY` 값으로 로그인
3. 좌측 **Teams** 메뉴 → 팀별 `Spend / Budget`(예: `$3.20 of $50`) 확인
   - `scripts/create_team_keys.sh`가 `/team/new`로 팀 객체를 실제로 등록하기 때문에 이 화면에 표시됩니다.
4. **Virtual Keys** 메뉴에서는 키 단위로 더 세부적인 Spend/Budget 확인 가능
