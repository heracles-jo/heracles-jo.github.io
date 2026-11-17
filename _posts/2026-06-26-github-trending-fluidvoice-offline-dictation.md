---
title: "FluidVoice와 로컬 음성 입력의 재가치화"
description: "FluidVoice의 로컬 음성 인식·텍스트 정리·macOS 입력 전달 구조를 분석하고, 모델 선택·권한·프라이버시·운영 도입 기준을 구체적으로 정리한다."
author: heracles-jo
date: 2026-06-26 07:32:00 +0900
categories: [AI Infrastructure, Productivity]
tags: [fluidvoice, privacy, local-first, macos, speech-to-text, whisper]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-fluidvoice-offline-dictation/cover.svg
  alt: 로컬 음성 인식과 AI 향상 단계를 분리한 FluidVoice의 오프라인 받아쓰기 분석
---

FluidVoice가 보여주는 변화는 “음성 인식 정확도가 좋아졌다”보다 더 크다. 받아쓰기를 클라우드 서비스가 아니라 **운영체제 입력 경로의 로컬 소프트웨어**로 다시 설계한다. 사용자는 전용 문서 편집기로 이동하지 않고 전역 단축키를 눌러 현재 앱에 말하고, 로컬 speech-to-text 모델이 텍스트를 만들며, 선택적으로 로컬 정리 모델이 군더더기와 형식을 다듬고, macOS 접근성 API를 통해 원래 커서 위치에 결과를 넣는다.

이 구조가 중요한 이유는 음성이 회의 녹음만의 문제가 아니기 때문이다. 이메일 초안, 이슈 설명, 코드 리뷰 의견, 고객 응답, 메모, 검색어처럼 하루 동안 반복되는 짧은 입력은 지연과 전환 비용에 민감하다. 클라우드 전송이 필요한 서비스는 네트워크 상태와 데이터 정책을 함께 고민해야 하고, 전용 앱에 결과를 만든 뒤 복사하는 방식은 흐름을 끊는다. FluidVoice는 모델 성능뿐 아니라 hotkey, overlay, paste delivery, 앱별 설정, 로컬 기록을 하나의 제품 경험으로 묶는다.

2026년 11월 17일 공개 GitHub API로 다시 확인한 `altic-dev/FluidVoice`는 13,109 stars, 991 forks, Swift 중심 코드베이스, GPL-3.0 라이선스였고 최신 공개 릴리스는 2026년 11월 13일의 `v1.6.13`이었다. README 기준 macOS 앱은 macOS 15 이상을 요구하며, Apple Silicon에서는 Fluid Speech·Parakeet·Nemotron·Qwen3 ASR·Cohere 등 여러 로컬 모델을, Intel Mac에서는 Whisper를 지원한다. 수치와 지원 목록은 확인 시점의 스냅샷이며 업데이트될 수 있다.

중요한 경계도 먼저 밝혀야 한다. FluidVoice의 macOS 앱은 GPLv3 오픈소스지만, 공식 배포본에 포함되는 **Fluid Intelligence 로컬 정리 runtime은 별도로 비공개 유지되는 구성 요소**라고 README가 명시한다. 따라서 저장소를 검토할 수 있다는 사실과 전체 공식 배포 runtime을 모두 재현·감사할 수 있다는 주장은 같지 않다. 이 글은 그 경계를 포함해 로컬 받아쓰기를 실무 도구로 평가한다.

## FluidVoice의 핵심: 음성 인식과 텍스트 정리를 분리한다

FluidVoice README는 처리 과정을 두 단계로 설명한다.

1. **Speech recognition**: Fluid Speech, Parakeet, Whisper, Apple Speech, Qwen3 ASR 같은 모델이 오디오를 텍스트로 바꾼다.
2. **Text cleanup**: 선택적 Fluid Intelligence 또는 사용자가 연결한 AI provider가 filler 제거, false start 정리, 목록 형식, 앱별 문체 같은 후처리를 한다.

이 분리가 제품적으로 중요하다. 음성을 정확하게 받아쓰는 모델과 이메일·메신저·이슈 트래커에 맞게 문장을 정리하는 모델은 최적화 목표가 다르다. 하나의 거대 모델이 모두 처리하게 하면 편해 보이지만, 지연·비용·수정 범위·데이터 전송 여부를 제어하기 어렵다. FluidVoice는 사용자가 받아쓰기만 사용하거나, 로컬 speech와 로컬 cleanup을 조합하거나, speech는 로컬에서 처리한 뒤 선택한 cloud provider로 정리할 수 있게 한다.

이 구조는 [TurboVec 로컬 벡터 인덱스 분석](/posts/github-trending-turbovec-local-vector-index/)에서 다룬 local-first 원칙과 닮았다. 계산을 기기 가까이에 두면 프라이버시뿐 아니라 응답 시간과 장애 독립성을 얻는다. 다만 로컬 실행은 모델 파일·메모리·배터리·업데이트·권한 관리 책임을 사용자의 장치로 옮긴다. “클라우드 비용이 없다”가 “운영 비용이 없다”는 뜻은 아니다.

## 아키텍처: 마이크에서 현재 앱의 커서까지

![로컬 음성 인식과 AI 향상 단계를 분리한 FluidVoice의 오프라인 받아쓰기 분석](https://heracles-jo.github.io/assets/img/posts/github-trending-fluidvoice-offline-dictation/architecture.svg)

실제 흐름은 `global hotkey → audio capture → preprocessing → local STT → optional cleanup → normalization/dictionary → accessibility paste → local history`로 이해할 수 있다.

### 1. 전역 단축키와 오디오 캡처

사용자는 어느 앱에서든 global hotkey로 녹음을 시작한다. 이 단계는 단순 UI 기능처럼 보이지만 제품 채택을 좌우한다. 단축키가 다른 앱과 충돌하거나, 키를 놓는 타이밍이 불안정하거나, overlay가 포커스를 빼앗으면 사용자는 며칠 안에 기능을 끈다. FluidVoice는 menu bar, live preview overlay, notch 대응 UI, hands-free와 hold-to-mute 같은 입력 경험을 제공한다.

마이크 권한은 당연히 필요하고, 회의·시스템 오디오를 다루는 기능은 별도 오디오 장치와 권한의 영향을 받는다. 로컬 앱이라도 권한이 넓으면 공격 표면이 넓다. 조직 배포에서는 어떤 기능이 microphone, accessibility, screen recording 또는 다른 macOS 권한을 요구하는지 실제 구성별로 확인하고, 필요하지 않은 기능의 권한은 주지 않는 편이 좋다.

### 2. 로컬 음성 인식 모델

README의 모델 표는 모델 선택을 정확도 하나가 아니라 언어, 크기, 하드웨어, 지연의 문제로 보여준다. 확인 시점 기준 Fluid Speech Pro·Mini·Pico는 약 154~622 MiB, Whisper 계열은 약 44 MiB~1.55 GiB, Qwen3 ASR 1.7B는 약 2.03 GiB로 안내된다. Apple Silicon 전용 모델과 Intel에서도 가능한 Whisper가 분리되어 있고, 언어 범위도 다르다.

프로젝트는 Fluid Speech Pro가 25개 언어를 지원한다고 밝히지만, 그 목록에는 한국어가 포함되지 않는다. 한국어 사용자는 README상 14개 언어에 한국어가 포함된 Cohere Transcribe, 최대 99개 언어를 다루는 Whisper, 시스템 의존적인 Apple Speech 등을 실제 샘플로 비교해야 한다. “모델 수가 많다”는 사실보다 자신의 언어·억양·전문 용어·마이크 환경에서 교정 부담이 줄어드는지가 중요하다.

### 3. 선택적 텍스트 정리

Fluid Intelligence의 Ripple과 Splash는 공식 다운로드에서 동작하는 로컬 cleanup 모델이다. README는 Ripple을 더 작고 빠른 선택, Splash를 더 어려운 수정에 유리한 선택으로 설명하며 둘 다 research preview이므로 전송 전 결과를 검토하라고 안내한다. 받아쓰기 원문을 그대로 쓰는 경우 이 단계를 끌 수 있다.

정리 모델은 생산성을 높이지만 의미를 바꿀 위험도 있다. filler 제거가 부정 표현을 지우거나, 숫자와 날짜를 잘못 고치거나, 기술 용어를 일반 단어로 바꾸면 원문보다 더 자연스럽고 더 틀린 문장이 된다. 회의록·법률·의료·재무·장애 대응 기록처럼 정확한 인용이 중요한 업무에서는 raw transcript와 cleaned text를 구분해 보관하고, 자동 정리를 기본값으로 두지 않는 편이 안전하다.

### 4. 현재 앱으로의 텍스트 전달

FluidVoice는 접근성 API를 사용해 현재 앱의 text field에 결과를 삽입한다. 저장소의 `PasteDeliveryCoordinator`, `PasteVerifier`, `PreservedPasteboardSnapshot`, `ClipboardService` 같은 구성은 음성 인식 이후의 전달 안정성이 별도 문제임을 보여준다. 브라우저, Electron 앱, 네이티브 편집기, IDE, 원격 데스크톱은 텍스트 입력 처리 방식이 다르고, 포커스가 이동하거나 clipboard가 바뀌면 결과가 엉뚱한 위치에 들어갈 수 있다.

이 때문에 받아쓰기 도구의 end-to-end 품질은 word error rate만으로 측정할 수 없다. 정확한 텍스트가 생성됐어도 현재 커서가 아닌 검색창이나 채팅방에 붙으면 실패다. 민감한 내용을 말할 때는 대상 앱·필드가 맞는지 overlay와 포커스를 확인해야 하며, 조직 PoC에서는 핵심 앱별 삽입 성공률을 따로 측정해야 한다.

### 5. 기록·검색·회의 계층

README는 선택적 audio history, transcription history, global search, 파일 transcription, FluidMeet 회의 기록과 export를 제공한다고 설명한다. 저장소에는 SQLite 연동, `TranscriptionHistoryDatabase`, `DictationAudioHistoryStore`, meeting transcript assembler·exporter·local API 관련 코드가 있다. 로컬 기록은 클라우드 계정 없이 검색과 재처리를 가능하게 하지만, 장치 분실·백업·악성코드 감염 시 민감한 음성과 텍스트가 한곳에 모이는 결과도 만든다.

로컬 데이터는 “외부로 전송되지 않는다”는 장점과 “내 Mac을 가진 사람이 모두 가져갈 수 있다”는 위험을 동시에 가진다. FileVault, 화면 잠금, MDM, 사용자 계정 분리, 백업 암호화, 기록 보존 한도, ZIP export 취급 정책을 함께 봐야 한다.

## 모델 선택은 정확도 순위가 아니라 작업 부하 배치다

FluidVoice는 사용자가 speech model과 cleanup model을 별도로 고르게 한다. 실무에서는 다음과 같이 시작하는 편이 합리적이다.

| 사용 조건 | 시작 조합 | 평가 포인트 |
|---|---|---|
| Apple Silicon, 짧은 영어 받아쓰기 | Fluid Speech Mini 또는 Pico, cleanup 끔 | 첫 단어 지연, 팬·배터리, 고유명사 교정량 |
| Apple Silicon, 정확도 우선 | Fluid Speech Pro, 필요 시 Ripple/Splash | 긴 문장 누락, 숫자·구두점, cleanup 의미 변경 |
| Intel Mac | Whisper 계열 | 모델 크기별 지연, 메모리, 한국어 품질 |
| 한국어·다국어 전환 | Whisper·Cohere Transcribe·Apple Speech 비교 | 언어 자동 감지, 혼합 언어, 전문 용어 |
| 민감한 기록 | 로컬 speech, cleanup 끔 또는 로컬만 | raw audio/history 보존, 외부 요청 0건 확인 |
| 이메일·문서 초안 | 로컬 speech + 검토 가능한 cleanup | 앱별 문체, 전송 전 검토, 원문 복구 가능성 |

가장 큰 모델을 선택한다고 항상 생산성이 높아지는 것은 아니다. 2초 더 정확한 결과보다 300ms 빨리 시작되는 작은 모델이 짧은 입력에는 낫고, 긴 회의에서는 실시간성보다 화자 분리와 저장 안정성이 중요할 수 있다. 모델 다운로드 크기뿐 아니라 peak memory, 첫 실행 warm-up, 1분 오디오 처리 시간, 장시간 사용 시 thermal throttling을 측정해야 한다.

프로젝트가 공개한 benchmark와 모델 설명은 후보를 좁히는 자료이지 조직의 한국어·소음·마이크 환경을 대신하지 않는다. 20~50개의 실제 발화 세트를 만들고 문자 오류율, 고유명사 정확도, 후편집 시간을 함께 측정하는 편이 더 유용하다.

## 프라이버시: local-first를 정확히 해석하기

FluidVoice README는 음성·오디오·transcript가 사용자가 cloud AI provider를 명시적으로 선택하지 않는 한 기기를 떠나지 않는다고 설명한다. 이는 강한 기본 방향이지만, “네트워크 통신이 전혀 없다”는 뜻은 아니다. 모델 다운로드, 앱 업데이트, analytics, 외부 AI provider 선택, local API와 assistant integration은 서로 다른 데이터 경로다.

### 기본 analytics 경계

공식 Privacy & Analytics 섹션에 따르면 앱은 무작위 installation ID, 활동 날짜, 앱 버전, macOS platform label로 구성된 하루 한 번의 익명 activity signal을 로컬에 모아 주 단위로 업로드한다. detailed anonymous analytics는 기본 활성화되어 있으며 설정에서 끌 수 있고, 기능·모델 사용량과 onboarding·model download의 고수준 결과를 포함한다. 프로젝트는 음성, raw audio, transcript, 선택 텍스트, prompt, AI response, terminal command, window title, file path, clipboard, typed content는 수집하지 않는다고 명시한다.

따라서 엄격한 폐쇄망이나 telemetry 금지 환경에서는 “local-first” 라벨만 보고 승인하지 말고 실제 네트워크 목적지와 설정을 검증해야 한다. detailed analytics를 끄더라도 weekly activity batch가 남는다는 문서상 경계도 정책과 맞는지 확인해야 한다. 필요하면 방화벽과 DNS 로그로 앱의 idle·dictation·update·model download 시 트래픽을 분리 측정한다.

### cloud AI provider 선택

사용자가 OpenAI, Groq 또는 custom provider를 연결하면 cleanup 대상 transcript가 해당 provider로 갈 수 있다. API key는 macOS Keychain에 저장된다고 README가 설명하지만, key 보관이 안전하다고 해서 전송 데이터의 보존·학습·region 문제가 사라지는 것은 아니다. 조직은 허용 provider 목록, 모델 endpoint, data retention, DPA, 민감정보 마스킹, 사용 가능한 앱과 사용자 그룹을 정해야 한다.

### 화면 맥락과 앱별 설정

Fluid Intelligence의 optional screen context는 기본적으로 꺼져 있다고 README가 밝힌다. 화면 맥락은 “이 문장이 어느 앱과 문서에서 쓰이는가”를 이해해 정리 품질을 높일 수 있지만, 주변 텍스트를 읽는 순간 프라이버시 경계가 넓어진다. 비밀번호 관리자, 고객 데이터, 소스 코드, 개인 메시지가 같은 화면에 있을 수 있으므로 기능을 켤 때 수집 범위와 로컬 처리 여부를 확인해야 한다.

## 보안과 공급망 관점에서 볼 것

### 공식 배포 경로 확인

README는 `fluidvoice.org`가 공식 사이트가 아니며 공식 다운로드는 GitHub Releases를 사용하라고 경고한다. 음성·접근성 권한을 받는 앱은 피싱 배포의 가치가 높다. 조직은 `fluidvoice.com`, `altic.dev`, `fluidvoice.app`, GitHub Releases와 Homebrew cask 같은 공식 경로만 허용하고, 서명·notarization·hash·업데이트 채널을 검증해야 한다.

### 접근성 권한의 민감도

macOS 접근성 권한은 다른 앱에 텍스트를 입력하는 핵심 기능을 가능하게 한다. 동시에 악성 또는 변조된 앱이 UI를 조작할 수 있는 강한 권한이다. 사용자는 앱이 요청하는 권한을 무심코 승인하기보다, 설치 출처와 서명을 확인하고 자동 업데이트 경로를 통제해야 한다. 기업 환경에서는 MDM으로 배포·권한 정책을 관리하고, beta channel은 일반 사용자에게 열지 않는 편이 낫다.

### 오픈소스 범위와 비공개 runtime

macOS 앱의 GPLv3 소스와 SPM dependency는 검토할 수 있지만 Fluid Intelligence는 저장소의 source build에 포함되지 않는 비공개 local runtime이다. 완전한 재현 가능한 빌드나 내부 보안 감사가 요구되는 조직은 해당 기능을 끈 오픈소스 경로, 별도 승인된 provider, 또는 자체 모델을 검토해야 한다. “로컬”과 “오픈소스”는 서로 다른 속성이다.

### 라이선스와 내부 배포

README는 2026년 2월 23일 이후 GPLv3로 변경됐고 이전 버전은 Apache-2.0이었다고 밝힌다. 앱을 그대로 내부 사용만 하는 경우와 수정본을 외부에 배포하는 경우의 의무는 다를 수 있다. 사내 패키징·재배포·제품 번들링 계획이 있다면 법무 검토가 필요하다. 특히 비공개 구성 요소와 GPLv3 앱의 배포 경계를 추정으로 판단해서는 안 된다.

## 운영 도입에서 측정할 지표

받아쓰기 앱의 성공 여부는 설치 수보다 **수정 부담이 실제로 줄었는가**로 판단해야 한다.

1. **첫 단어 지연**: hotkey 이후 live preview에 첫 텍스트가 나타나는 시간.
2. **최종 처리 지연**: 발화를 끝낸 뒤 대상 앱에 텍스트가 들어가기까지의 시간.
3. **후편집 시간**: 키보드로 처음부터 쓸 때와 비교한 수정·형식 정리 시간.
4. **용어 정확도**: 사람 이름, 제품명, 약어, 코드 식별자, 숫자와 날짜의 정확도.
5. **전달 성공률**: 브라우저·IDE·메신저·문서 앱별로 올바른 커서에 삽입된 비율.
6. **meaning-change rate**: cleanup이 부정·수치·책임 주체·시제를 잘못 바꾼 비율.
7. **자원 사용량**: 모델별 메모리, CPU/GPU, 배터리, 장시간 사용 시 발열.
8. **네트워크 경계**: dictation 한 건당 외부 전송 목적지와 payload 존재 여부.
9. **채택률**: 1주 후에도 사용자가 자발적으로 쓰는 시나리오와 포기한 시나리오.

[Paperless-ngx 문서 AI 파이프라인 분석](/posts/github-trending-document-ai-paperless-ngx/)에서 OCR 결과가 곧 신뢰할 수 있는 업무 기록은 아니라고 봤듯, 음성 transcript도 검색 가능한 초안과 확정 기록을 구분해야 한다. 회의 합의, 고객 약속, 장애 타임라인은 사람이 확인한 뒤 확정 상태로 승격하는 절차가 필요하다.

## 팀 도입을 위한 2주 PoC

![로컬 음성 인식과 AI 향상 단계를 분리한 FluidVoice의 오프라인 받아쓰기 분석 체크리스트](https://heracles-jo.github.io/assets/img/posts/github-trending-fluidvoice-offline-dictation/checklist.svg)

### 1단계: 시나리오와 데이터 등급 정의

- 짧은 이메일, 이슈 설명, 코드 리뷰, 개인 메모, 회의 기록 중 2~3개를 고른다.
- 공개·내부·기밀 데이터 중 어떤 등급까지 음성 입력을 허용할지 정한다.
- raw audio와 transcript history를 보관할지, 보관 기간과 삭제 책임자를 정한다.
- cloud cleanup과 optional screen context는 초기에는 끄고 로컬 기준선을 만든다.

### 2단계: 모델 비교

- 사용자 언어와 억양을 반영한 실제 발화 세트를 만든다.
- 작은 모델, 정확도 우선 모델, Whisper 또는 Apple Speech를 같은 장치에서 비교한다.
- 문자 오류율뿐 아니라 후편집 시간, 고유명사, 숫자·구두점, 첫 단어 지연을 기록한다.
- custom dictionary가 개선한 항목과 오히려 잘못 치환한 항목을 분리한다.

### 3단계: 앱 호환성과 권한 검증

- Mail, Slack/Teams, 브라우저, VS Code/IDE, Notes, 문서 편집기에서 삽입 성공률을 측정한다.
- 포커스 이동, clipboard 복원, 원격 데스크톱, 다국어 입력기 상황을 포함한다.
- microphone·accessibility 권한을 제거했을 때 앱이 안전하게 실패하는지 확인한다.
- 설치·업데이트·idle·dictation·model download의 네트워크 트래픽을 관찰한다.

### 4단계: cleanup과 회의 기능을 제한적으로 추가

- raw transcript와 cleaned text를 나란히 비교해 meaning-change rate를 기록한다.
- 앱별 prompt는 비민감 시나리오에서만 시작하고 자동 전송 전 검토 단계를 둔다.
- FluidMeet은 회의 참가자의 녹음 동의, 보존·삭제, export 권한을 먼저 정한다.
- assistant integration이나 local API는 최소 권한과 localhost binding, 접근 token 여부를 확인한다.

### 5단계: 채택 결정

- 타이핑 대비 절약 시간과 수정 시간을 합산한다.
- 모델 다운로드·업데이트·지원 문의·MDM 배포 비용을 포함한다.
- 보안팀은 데이터 흐름과 telemetry 경계를 승인하고, 법무·HR은 녹음 정책을 검토한다.
- 생산성이 높아진 사용자군과 오히려 느려진 사용자군을 나눠 선택 배포한다.

## 어떤 사용자와 팀에 적합한가

FluidVoice는 짧은 초안을 자주 만들고, Mac을 주 작업 환경으로 쓰며, 클라우드 음성 전송을 줄이고 싶은 개인 개발자·작가·제품 관리자·지원 담당자에게 잘 맞는다. Apple Silicon 장치에서 영어 또는 지원 언어를 주로 쓰고, 로컬 모델 저장 공간과 초기 설정을 감수할 수 있다면 장점이 크다. 접근성 요구가 있는 사용자에게도 전역 음성 입력은 중요한 인터페이스가 될 수 있다.

팀 단위로는 데이터 등급이 명확하고 MDM·FileVault·업데이트 정책이 있으며, 음성 입력을 “선택 가능한 생산성 도구”로 배포하려는 조직이 적합하다. 전 직원에게 단일 모델을 강제하기보다 직무·언어·장치별 추천 조합을 제공하는 편이 현실적이다.

반대로 정확한 verbatim 기록이 법적 증거가 되는 업무, 녹음 자체가 규제되는 환경, 접근성 권한을 허용할 수 없는 장치, Intel Mac이 많고 성능 여유가 적은 조직, 한국어 품질을 사전 검증하지 않은 팀은 신중해야 한다. cloud provider를 연결하면서도 “로컬이니까 안전하다”고 가정하는 조직도 도입 준비가 부족하다.

## 향후 관찰할 지표

FluidVoice를 계속 볼 때 star 수보다 다음 신호가 중요하다. 첫째, 모델 catalog가 늘어날수록 다운로드·rollback·호환성 관리가 안정적인가. 둘째, 한국어를 포함한 각 언어의 실제 품질과 custom dictionary가 개선되는가. 셋째, accessibility paste가 주요 앱 업데이트 뒤에도 회귀하지 않는가. 넷째, analytics와 cloud provider 경계가 문서와 네트워크 동작에서 일치하는가. 다섯째, Fluid Intelligence의 비공개 경계가 사용자에게 계속 명확히 고지되는가.

여섯째, 회의 기능이 단순 녹음을 넘어 consent, speaker label 수정, export, 삭제, 재처리의 운영 절차를 잘 지원하는가다. 회의 transcript를 Claude Code·Codex 같은 로컬 도구가 읽을 수 있다는 기능은 편리하지만, 로컬 API가 새로운 데이터 접근면이 된다는 점도 함께 봐야 한다. local-first 제품의 다음 경쟁력은 “클라우드를 쓰지 않는다”는 선언이 아니라 **장치 안에서 데이터가 어디에 저장되고 어떤 프로세스가 읽는지 사용자가 통제할 수 있게 하는 것**이다.

## 결론: 로컬 받아쓰기는 모델이 아니라 입력 시스템이다

FluidVoice의 의미는 Whisper나 Parakeet을 GUI로 감싼 데 있지 않다. 음성 캡처, 모델 선택, optional cleanup, dictionary, overlay, 접근성 입력, 기록, 회의, 업데이트를 연결해 받아쓰기를 일상적인 Mac 입력 방식으로 만든 데 있다. 이 통합이 잘 작동하면 사용자는 “녹음하고 변환한다”는 절차를 의식하지 않고 현재 작업을 계속할 수 있다.

그러나 로컬이라는 단어만으로 도입을 결정해서는 안 된다. 모델과 cleanup의 정확도, 접근성 권한, 공식 배포 경로, analytics, 외부 provider 선택, 로컬 기록 보존, 비공개 runtime, GPLv3 배포 조건을 각각 확인해야 한다. 가장 좋은 시작은 모든 기능을 켜는 것이 아니라 로컬 speech와 짧은 입력 시나리오로 기준선을 만들고, 실제 후편집 시간이 줄어드는 기능만 단계적으로 추가하는 것이다.

결국 FluidVoice가 경쟁하는 대상은 다른 음성 모델만이 아니다. 키보드 입력의 즉시성, OS 받아쓰기의 편의, 클라우드 서비스의 정확도, 조직 보안 정책을 동시에 만족해야 한다. 이 네 조건의 균형을 맞출 때 로컬 음성 입력은 데모가 아니라 지속적으로 쓰이는 생산성 인터페이스가 된다.

## 1차 출처

- [FluidVoice GitHub 저장소와 README](https://github.com/altic-dev/FluidVoice) — 기능, 지원 플랫폼·모델, 설치, 권한, local-first 경계, analytics, 라이선스와 오픈소스 범위.
- [FluidVoice v1.6.13 릴리스](https://github.com/altic-dev/FluidVoice/releases/tag/v1.6.13) — 재검증 시점의 최신 공개 릴리스와 변경 사항.
- [FluidVoice Package.swift](https://github.com/altic-dev/FluidVoice/blob/main/Package.swift) — macOS 15 요구사항과 FluidAudio, Hummingbird, WebRTC audio processing 등 주요 package 구성.
- [FluidVoice Sources](https://github.com/altic-dev/FluidVoice/tree/main/Sources/Fluid) — 오디오 캡처, speech provider, paste delivery, history, meeting, local API의 공개 코드 구조.
- [FluidVoice GPLv3 LICENSE](https://github.com/altic-dev/FluidVoice/blob/main/LICENSE) — 2026년 2월 23일 이후 공개 소스에 적용되는 라이선스 원문.
- [Fluid Speech Pro 모델 카드](https://huggingface.co/FluidVoice-Labs/fluid-speech-pro) — 프로젝트가 공개한 모델 설명, 가중치와 benchmark 자료.

저장소 수치와 릴리스 상태는 2026년 11월 17일 공개 GitHub API 확인 시점의 스냅샷이다. 모델 크기·지원 언어·privacy 설명은 프로젝트의 1차 문서를 기준으로 했으며, 정확도·지연·자원 사용량과 네트워크 동작은 사용자의 장치·언어·설정에서 별도 검증해야 한다.
