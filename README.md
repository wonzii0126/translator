# Translator Keyboard — iOS 1차 프로토타입

빈 프로젝트에서 생성한 UIKit Host App + Custom Keyboard Extension입니다. iOS 16 이상을 대상으로 합니다. 외부 라이브러리, 네트워크, API Key, App Group, 전체 접근 권한을 사용하지 않습니다.

## 구성

- `Translator.xcodeproj`: Translator 앱과 TranslatorKeyboard 확장 타깃. 앱이 확장에 의존하며 Embed App Extensions 단계에서 `.appex`를 포함합니다. 공유 Translator scheme이 있습니다.
- `HostApp/AppDelegate.swift`: 설치 안내와 일반 UITextView 테스트 입력창.
- `KeyboardExtension/KeyboardViewController.swift`: UIInputViewController, 문자/공백/삭제/줄바꿈, 예문, 키보드 전환, Translate 버튼.
- `KeyboardExtension/ConversationalTranslator.swift`: sourceLanguage, targetLanguage, casual/formal tone 옵션 및 로컬 테스트 구현.
- 각 타깃의 `Info.plist`: 확장은 `com.apple.keyboard-service`와 principal class를 선언하고 `RequestsOpenAccess = false`로 설정합니다.

이미 확장 타깃을 포함하므로 Xcode에서 다시 추가할 필요가 없습니다. 기존 프로젝트로 옮기는 경우 File → New → Target → Custom Keyboard Extension을 만들고 확장 Swift 파일 두 개를 해당 타깃에 포함시키세요. principal class 및 plist 설정과 Host App의 확장 포함 단계를 유지하세요.

## Mac에서 빌드 및 설치

1. 이 폴더를 Mac으로 옮기고 `Translator.xcodeproj`를 Xcode로 엽니다.
2. 두 타깃의 Signing & Capabilities에서 자신의 Team을 선택합니다.
3. 앱 Bundle Identifier를 자신의 고유 ID로 변경하고 확장 ID는 앱 ID 뒤에 `.keyboard`를 붙입니다. 예: `com.yourname.Translator` / `com.yourname.Translator.keyboard`.
4. 연결한 iPhone을 실행 대상으로 선택하고 Translator scheme으로 Run 합니다. 필요하면 iPhone에서 개발자 모드를 활성화하고 개발자 프로파일을 신뢰합니다.
5. 설정 → 일반 → 키보드 → 키보드 → 새로운 키보드 추가 → Translator를 선택합니다. 전체 접근은 켜지 않아도 됩니다.
6. Host App의 입력창을 누르고 기존 키보드의 지구본을 길게 눌러 Translator를 선택합니다.
7. `오늘 뭐 했어?` 예문 버튼을 누른 다음 Translate를 누릅니다.

예상 결과:

```text
오늘 뭐 했어?
[Italian translation test]
```

8. WhatsApp, KakaoTalk, LINE, Instagram DM, Telegram 등의 일반 메시지 입력창에서도 같은 순서로 확인합니다. 메시지 전송 버튼은 직접 누릅니다.

서명 없이 시뮬레이터용 컴파일 확인:

```sh
xcodebuild -project Translator.xcodeproj -scheme Translator \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## 수동 검증 항목

- 영문 키, space, 삭제, 줄바꿈이 활성 입력창에 반영되는지 확인합니다.
- 기본 한국어 키보드로 원문을 작성한 후 Translator로 전환해도 Translate가 작동하는지 확인합니다. 이번 버전은 한글 조합 입력기를 구현하지 않으며 예문 버튼을 제공합니다.
- 빈 입력창에서는 Translate가 안내만 표시하는지 확인합니다.
- 원문 중간에 커서를 놓거나 텍스트를 선택하면 안내가 표시되고 원문이 유지되는지 확인합니다.
- 원문 끝에서는 줄바꿈과 테스트 문구만 추가되며 메시지는 전송되지 않는지 확인합니다. 원문이 이미 줄바꿈으로 끝나면 줄바꿈을 중복 추가하지 않습니다.
- Translate를 다시 누르면 테스트 문구가 다시 추가됩니다. 삭제와 재입력을 확인하세요.
- 지구본으로 다른 키보드로 전환하고 가로/세로 회전 시 키가 보이는지 확인합니다.
- 전체 접근 없이 위 동작을 확인합니다.

## iOS 범위와 향후 확장

보안 입력창 및 전화번호 관련 입력창에서는 시스템 키보드로 전환될 수 있고 앱이 사용자 키보드를 거부할 수도 있습니다. 모든 메신저의 모든 입력창에서 사용 가능하다고 보장할 수는 없습니다. 이 제한은 Apple의 Custom Keyboard 문서를 참고하세요:
https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html

`textDocumentProxy`는 커서 위치에 삽입합니다. 현재 구현은 선택된 텍스트나 커서 뒤의 문맥이 보이면 삽입을 거부합니다. iOS가 문맥을 제공하지 않거나 일부만 제공할 수 있으므로 항상 원문 끝에 커서를 놓고 테스트하세요. 전체 입력 내용이나 채팅 기록을 읽거나 저장하지 않습니다. 커서 앞 문맥은 테스트 번역기에 전달되지만 테스트 구현은 내용을 해석하지 않고 고정 문구를 반환합니다.

실제 번역 단계에서는 부분 문맥을 전체 원문으로 간주하지 않도록 원문 범위를 별도로 설계해야 합니다. 비동기 번역 중 입력창 변경, 커서 이동, 선택 변경도 삽입 전에 확인해야 합니다. `ConversationalTranslator`는 현재 동기식 로컬 계약이며 네트워크 도입 시 async/throws 계약으로 확장할 수 있습니다. TranslationOptions를 공통 backend 요청의 언어/말투 필드에 매핑하면 Android와 같은 backend를 공유할 수 있습니다. 현재 stub은 자연스러운 번역 품질을 검증하지 않습니다.

향후 네트워크 구현은 별도 단계에서 RequestsOpenAccess 및 사용자 전체 접근 동의, 오류 처리와 개인정보 정책을 함께 설계해야 합니다. 현재 버전에는 관련 기능이 없습니다.

## 검증 상태

개발 환경은 Windows이며 Xcode/iOS SDK/Swift 컴파일러가 없습니다. plist 및 scheme XML, 프로젝트 참조와 타깃 연결을 정적으로 확인했지만 실제 컴파일 및 iPhone 실행은 미검증입니다. 위 Mac 빌드 명령과 수동 검증 절차로 확인해야 합니다.
