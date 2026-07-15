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

프록시가 뜬 상태에서 실행하면 team_a~team_d 4개의 가상 키가 생성됩니다.

```bash
LITELLM_MASTER_KEY=<.env에 넣은 값> \
PROXY_URL=http://localhost:4000 \
MAX_BUDGET=50 RPM_LIMIT=20 TPM_LIMIT=100000 \
bash scripts/create_team_keys.sh
```

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
