# 개인용 Gemini 번역 서버

Cloudflare Workers Free용 모듈입니다. 외부 라이브러리를 사용하지 않습니다. iOS 앱 연결은 프로젝트의 `NETWORK_SETUP.md`를 참고하세요.

## 설정

1. Cloudflare 계정에서 Workers & Pages → Create application → Hello World Worker를 생성합니다. 이름 예: `translator-backend`. Free 플랜을 유지하며 도메인 구매나 유료 업그레이드는 필요하지 않습니다.
2. Worker의 Edit code에서 기본 코드를 `worker.mjs`의 전체 내용으로 교체하고 Deploy합니다. 이 파일에는 실제 키나 토큰을 입력하지 않습니다.
3. Worker → Settings → Variables and Secrets → Add에서 Type을 Secret으로 선택하고 다음 두 값을 등록한 뒤 변경을 배포합니다.
   - `GEMINI_API_KEY`: AI Studio에서 만든 무료 프로젝트의 API Key.
   - `CLIENT_TOKEN`: 개인용 서버 접속 토큰. 최소 32글자 이상의 무작위 값. Gemini 키와 서로 다른 값이어야 합니다.
4. CLIENT_TOKEN은 Windows PowerShell에서 다음 명령으로 생성할 수 있습니다. 출력값은 비밀번호 관리자에 보관하고 채팅이나 GitHub에 올리지 않습니다.

```powershell
$translatorTokenBytes = New-Object byte[] 32
$translatorTokenGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$translatorTokenGenerator.GetBytes($translatorTokenBytes)
$translatorTokenGenerator.Dispose()
[Convert]::ToBase64String($translatorTokenBytes)
```

5. Worker의 `https://translator-backend.<account>.workers.dev` 주소를 기록합니다. GET /는 상태 정보만 반환하며 실제 번역을 호출하지 않습니다. 이 주소 자체는 비밀이 아닙니다.

## 요청 계약

`POST /translate`, `Content-Type: application/json`, `Authorization: Bearer <CLIENT_TOKEN>`.

```json
{
  "text": "오늘 뭐 했어?",
  "sourceLanguage": "ko",
  "targetLanguage": "it",
  "tone": "casual"
}
```

성공: `{"translation":"..."}`. 입력 원문은 응답에서 반복하지 않습니다. 원문 언어 ko/en, 번역 언어 ko/en/it/ja, tone casual/formal. 같은 언어면 원문 그대로 반환하며 API 호출은 하지 않습니다.

401 인증 실패, 400 잘못된 입력, 413 요청 본문 8KB 초과, 429 한도 또는 일시적인 처리 용량 제한, 502 번역 서비스 실패/미완성 결과, 503 서버 비밀 설정 누락, 504 번역 시간 초과. Gemini의 원본 오류와 비밀값은 클라이언트에 반환하지 않습니다.

## 무료 사용과 개인정보

- Gemini `gemini-3.5-flash-lite` 한 모델만 호출합니다. 자동 재시도와 모델 대체는 없습니다. 원문은 최대 1,000 Unicode 코드 포인트, 요청 본문 최대 8KB, 결과 최대 2,048 출력 토큰, 요청 대기 최대 20초입니다.
- 429는 하루 한도뿐 아니라 분당 제한 및 서비스 용량 문제일 수도 있습니다. 서버에는 별도 영구 일일 횟수 카운터가 없으며 Google 프로젝트의 한도를 따릅니다.
- **요금 등급은 서버 코드가 강제로 제한할 수 없습니다.** Google 프로젝트에 유료 결제 계정을 연결하지 말고 Cloudflare도 Free를 유지하세요. 결제를 연결하면 동일 코드라도 API 과금이 발생할 수 있습니다.
- CLIENT_TOKEN을 아는 사용자는 요청할 수 있습니다. 개인용 토큰이 유출되면 Cloudflare에서 교체합니다. Google 키는 앱에 보내지 않습니다. 서버 주소만 안다고 번역 요청을 할 수는 없습니다.
- 입력/결과를 코드에서 로그로 기록하거나 저장하지 않습니다. Cloudflare의 플랫폼 로그 설정과 Google 무료 등급의 데이터 이용은 별개입니다. Workers의 요청 로그 수집은 필요하지 않으면 비활성화하세요. Gemini 무료 등급은 입력·출력을 제품 개선에 사용할 수 있으므로 민감하지 않은 예문부터 테스트하세요.
- 실제 네트워크 호출과 배포는 미검증입니다. 단위 테스트는 가짜 upstream 응답을 사용하며 Gemini 무료 한도를 사용하지 않습니다.

```powershell
node --test Backend/worker.test.mjs
```

공식 문서:
- https://developers.cloudflare.com/workers/platform/pricing/
- https://developers.cloudflare.com/workers/configuration/secrets/
- https://ai.google.dev/gemini-api/docs/rate-limits
- https://ai.google.dev/gemini-api/docs/pricing
