---
title: "OpenLogi가 뜬 이유: 로지텍 주변기기 설정을 로컬 퍼스트 엔드포인트 정책으로 보는 법"
description: "GitHub Trending에 오른 OpenLogi를 중심으로 Logitech Options+ 대안, HID++·UVC 기반 장치 제어, TOML 구성, CLI 자동화, Solaar·Piper와의 비교, 보안·운영 리스크와 PoC 체크리스트를 IT 의사결정자 관점에서 분석한다."
author: heracles
date: 2026-08-21 07:25:00 +0900
categories: [Infrastructure, Endpoint Management]
tags: [github-trending, openlogi, logitech-options-alternative, local-first, endpoint-management, hidpp, uvc, rust, device-management, telemetry]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-openlogi-local-first-peripheral-control/cover.svg
  alt: "OpenLogi를 통해 로지텍 마우스·키보드·웹캠 설정을 계정과 텔레메트리 없는 로컬 퍼스트 엔드포인트 정책으로 관리하는 흐름을 요약한 이미지"
---

2026년 8월 21일 07:28 KST 전후 확인한 GitHub Trending daily/weekly 스냅샷에서 [AprilNEA/OpenLogi](https://github.com/AprilNEA/OpenLogi)가 유독 눈에 띄었다. GitHub Trending daily 화면은 OpenLogi를 **Rust 기반, 약 11.7k stars, 321 forks, 1,540 stars today**로 표시했고, weekly 화면에서도 **1,492 stars this week** 수준으로 노출됐다. GitHub API 확인 시점에는 저장소가 2026년 5월 생성, Apache-2.0 라이선스, 208개 수준의 open issues/PR, 2026년 8월 20일 최신 push, 최신 릴리스 [v0.7.3](https://github.com/AprilNEA/OpenLogi/releases/tag/v0.7.3)를 보였다. 이 숫자는 공개 페이지와 API를 조회한 순간의 스냅샷이며 GitHub의 집계 방식, 캐시, 시간대에 따라 달라질 수 있다.

오늘의 주제는 “로지텍 앱 대체재가 하나 나왔다”는 소비자용 소식이 아니다. 더 흥미로운 흐름은 **마우스, 키보드, 웹캠 같은 주변기기 설정이 클라우드 계정 기반 벤더 앱에서 로컬 퍼스트 엔드포인트 정책으로 이동하고 있다는 점**이다. 최근 이 블로그에서는 로컬 AI, 에이전트 실행 환경, 개발자 워크스테이션, 셀프호스팅 사진·문서 플랫폼처럼 비교적 큰 시스템을 다뤘다. OpenLogi는 규모는 작아 보이지만 실무적으로는 엔드포인트 보안, 텔레메트리 최소화, 장치 표준화, 구성 형상관리, 원격 지원 자동화가 만나는 접점에 있다.

## 오늘의 Trending 후보 비교: 왜 OpenLogi인가

이번 조사에서는 daily와 weekly Trending에서 보인 후보 중 최근 글과 중복이 적고 실무 의사결정 논지가 선명한 저장소를 우선했다.

| 후보 저장소 | 확인 시점 공개 신호 | 이번 글에서의 판단 |
|---|---:|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) | daily 최상위권, 2,267 stars today로 표시 | 에이전트 스킬·코딩 워크플로 각도는 기존 글과 중복 가능성이 높아 제외 |
| [modular/modular](https://github.com/modular/modular) | API 기준 약 27.9k stars, Mojo 중심, 최신 push 활발 | MAX·Mojo는 중요하지만 AI 컴파일러/런타임 주제로 별도 장문이 필요하고 오늘의 차별성은 OpenLogi가 더 높음 |
| [cursor/plugins](https://github.com/cursor/plugins) | daily 473 stars today, TypeScript | AI 코딩 도구 플러그인 생태계는 이미 여러 차례 다룬 토큰·CLI·에이전트 주제와 가까움 |
| [semantica-agi/semantica](https://github.com/semantica-agi/semantica) | weekly 약 4,005 stars this week, Python | 그래프 기반 AI 인프라는 흥미롭지만 메모리·RAG·에이전트 거버넌스 글과 겹침 |
| [AprilNEA/OpenLogi](https://github.com/AprilNEA/OpenLogi) | daily 1,540 stars today, weekly 1,492 stars this week, v0.7.3 릴리스 | 계정 없는 로컬 장치 관리, HID++/UVC, TOML 구성, CLI라는 실무형 엔드포인트 정책 논지가 선명함 |

OpenLogi가 선택된 이유는 단순 인기보다 맥락이다. 기업과 개발 조직은 점점 더 많은 주변기기를 표준 장비로 지급한다. 고급 마우스의 버튼 매핑, 키보드의 기능키, 웹캠의 노출·화이트밸런스, 조명 장비의 밝기 같은 설정은 회의 품질과 생산성에 영향을 준다. 그런데 이 설정이 벤더 계정, 자동 업데이트, 백그라운드 서비스, 텔레메트리, 클라우드 동기화에 묶이면 보안팀과 플랫폼팀 입장에서는 “작지만 관리하기 어려운 에이전트”가 하나 더 늘어난다. OpenLogi의 인기는 바로 이 피로감, 특히 “주변기기는 로컬에서 제어하면 충분하지 않은가”라는 질문을 반영한다.

![OpenLogi의 로컬 장치 제어 계층](https://heracles-jo.github.io/assets/img/posts/github-trending-openlogi-local-first-peripheral-control/architecture.svg)

## OpenLogi가 해결하려는 문제: Options+의 불편함보다 넓다

[OpenLogi README](https://github.com/AprilNEA/OpenLogi/blob/master/README.md)는 프로젝트를 “Logitech Options+의 native, local-first alternative”라고 설명한다. 핵심 문구는 세 가지다. 첫째, **Rust와 GPUI 기반의 네이티브 앱**이라는 점이다. 둘째, **macOS, Linux, Windows**를 대상으로 한다는 점이다. 셋째, “No account, no telemetry”와 **plain-text TOML config**, **real CLI**를 전면에 둔다는 점이다.

README 기준 기능 범위도 단순한 버튼 리매핑을 넘는다. Logi Bolt, Unifying, Bluetooth, 유선 연결 장치의 배터리 상태를 다루고, OS input hook을 통해 버튼 리매핑과 커스텀 단축키를 처리하며, 애플리케이션 포커스에 따라 프로필을 전환한다. 마우스 영역에서는 중간 버튼, 모드 시프트, 썸휠, 제스처, DPI 프리셋, SmartShift 휠, 장치별 스크롤 반전이 언급된다. 키보드 영역에서는 기능키 재매핑과 일부 RGB 조명 제어가 있고, 카메라 영역에서는 Logitech UVC 웹캠의 줌, 포커스, 노출, 밝기, 대비, 채도, 샤프니스, 화이트밸런스 같은 이미지 제어를 하드웨어에 직접 쓰는 방향을 제시한다.

여기서 실무자가 봐야 할 핵심은 “어떤 버튼을 바꿀 수 있나”보다 **운영 표면이 어떻게 생겼는가**다. 주변기기 설정은 일반적으로 개인 취향의 영역으로 취급되어 중앙 관리에서 빠진다. 하지만 실제 업무 현장에서는 표준 영상회의 세팅, 접근성 보조 버튼, 개발자 IDE 단축키, CAD·영상 편집 장비 매핑, 보안 사고 시 입력 훅 권한 회수 같은 운영 요구가 존재한다. OpenLogi처럼 설정을 TOML 파일과 CLI로 드러내면, 이 영역을 문서화하고 리뷰하고 롤백하는 길이 생긴다.

## 핵심 아키텍처: HID++, UVC, OS input hook, 그리고 구성 파일

OpenLogi를 과대평가하지 않으려면 아키텍처를 계층으로 나눠 봐야 한다. 가장 아래에는 Logitech 장치와 수신기, 운영체제의 입력 스택이 있다. Logitech 고급 장치는 HID 장치처럼 보이지만, 배터리·DPI·휠 모드·버튼 기능 같은 세부 설정은 벤더 확장 프로토콜인 HID++ 계열 메시지를 통해 노출되는 경우가 많다. 웹캠은 UVC 표준 제어를 활용할 수 있다. 즉 OpenLogi는 단순히 “마우스 이벤트를 가로채는 앱”이 아니라, 장치가 제공하는 특수 메시지와 운영체제별 입력 권한을 함께 다뤄야 한다.

그 위에는 로컬 런타임이 있다. Rust를 선택한 것은 메모리 안전성, 단일 바이너리 배포, 시스템 권한과 장치 I/O를 다루는 코드에서의 예측 가능성 측면에서 설득력이 있다. 다만 Rust라고 해서 자동으로 안전한 것은 아니다. 입력 훅, 접근성 권한, 장치 제어, 자동 업데이트, 패키지 서명 같은 표면은 언어와 별개로 검토해야 한다. 특히 macOS에서는 접근성·입력 모니터링 권한, Windows에서는 저수준 훅과 드라이버/서명 정책, Linux에서는 X11/XWayland와 Wayland의 권한 모델 차이가 중요하다.

운영 계층에서는 TOML 구성과 CLI가 차별점이다. 설정이 사람이 읽을 수 있는 파일이면 Git으로 이력을 남기고, 표준 프로필을 템플릿화하고, 신규 노트북 지급 시 부트스트랩 스크립트에 포함할 수 있다. 반대로 JSON이나 TOML 파일이 생겼다고 해서 곧바로 엔터프라이즈 관리가 되는 것은 아니다. 누가 변경을 승인할지, 개인 설정과 조직 표준의 경계를 어디에 둘지, 장치별 기능 차이를 어떻게 표현할지, 잘못된 매핑이 접근성을 해치거나 업무 앱 단축키와 충돌할 때 어떻게 복구할지를 따로 설계해야 한다.

## Solaar, Piper/libratbag, Logitech Options+와의 비교

OpenLogi를 평가할 때 비교 기준은 세 부류다. 하나는 벤더 공식 앱인 Logitech Options+다. 다른 하나는 오래된 오픈소스 Logitech 관리 도구인 [Solaar](https://github.com/pwr-Solaar/Solaar)다. 세 번째는 게임용 마우스 설정 생태계인 [Piper](https://github.com/libratbag/piper)와 [libratbag](https://github.com/libratbag/libratbag)이다.

| 도구 | 강점 | 한계/주의점 | OpenLogi와의 차이 |
|---|---|---|---|
| Logitech Options+ | 벤더 공식 지원, 장치 호환성, 일반 사용자 UX | 계정·백그라운드 서비스·텔레메트리·자동 업데이트에 대한 조직별 우려 | OpenLogi는 로컬 퍼스트와 구성 파일·CLI를 앞세우지만 공식 지원 범위는 제한적일 수 있음 |
| [Solaar](https://github.com/pwr-Solaar/Solaar) | Linux Logitech 장치 관리에서 긴 역사, Unifying/Bolt/USB/Bluetooth 장치와 규칙 지원 | Linux 중심, Python/GTK 생태계, macOS·Windows 표준화 요구에는 직접 답하기 어려움 | OpenLogi는 크로스 플랫폼 경험과 네이티브 앱, Options+ 대체 메시지를 강조 |
| [Piper](https://github.com/libratbag/piper) / [libratbag](https://github.com/libratbag/libratbag) | 게임용 입력 장치 설정, DBus daemon 기반, 여러 제조사 장치 데이터 | 지원 장치는 libratbag 데이터와 프로토콜 역공학에 의존, 주로 Linux 데스크톱 맥락 | OpenLogi는 Logitech 생산성 장치와 웹캠·조명까지 포함하려는 범위가 다름 |

API 확인 시점 기준 Solaar는 약 9.3k stars, GPL-2.0, 2026년 6월 28일 [1.1.20 릴리스](https://github.com/pwr-Solaar/Solaar/releases/tag/1.1.20), 2026년 8월에도 커밋 활동이 있었다. Piper는 약 5.9k stars, GPL-2.0, libratbag은 약 2.6k stars, MIT 라이선스이며 둘 다 2026년 8월 커밋이 확인됐다. 이 비교는 품질 순위가 아니라 선택지의 성격 차이를 보기 위한 것이다.

실무 관점에서는 “어느 도구가 더 좋은가”보다 “우리 조직의 제어면이 어디에 있는가”가 중요하다. Linux 개발자 워크스테이션만 관리한다면 Solaar가 더 검증된 선택일 수 있다. 게임용 마우스와 오픈소스 데스크톱 생태계라면 Piper/libratbag이 자연스럽다. 반면 macOS·Windows·Linux 혼합 조직에서 Logitech Options+의 계정·텔레메트리·무거운 백그라운드 앱을 줄이고, 장치 설정을 텍스트 구성과 CLI로 운영하고 싶다면 OpenLogi가 검토할 만한 후보가 된다.

## 실무 도입 장점: 주변기기 설정을 코드처럼 다룬다

첫 번째 장점은 **재현성**이다. 개발자 온보딩에서 IDE 설정, 셸, 패키지 매니저, SSH 키, 브라우저 정책은 비교적 잘 문서화된다. 그러나 마우스 버튼, 웹캠 노출, 회의용 조명, 기능키 매핑은 대개 개인이 수동으로 맞춘다. TOML 설정과 CLI가 있다면 “신규 개발자 표준 장비 프로필”, “영상회의용 웹캠 프로필”, “디자인팀용 휠·DPI 프로필” 같은 구성을 저장소로 관리할 수 있다.

두 번째 장점은 **로컬 데이터 경계**다. 주변기기 앱이 반드시 클라우드 계정과 동기화 기능을 가져야 하는 것은 아니다. 물론 클라우드 동기화는 편리하지만, 일부 조직에서는 입력 장치 설정, 앱별 프로필, 장치 식별자, 사용 패턴 정보가 외부 서비스로 나가는 것 자체가 부담이다. OpenLogi가 “No account, no telemetry”를 전면에 둔 것은 이 지점에서 강한 메시지다. 다만 실제 바이너리 배포, 업데이트 체크, 외부 리소스 로딩 여부는 별도로 검증해야 한다.

세 번째 장점은 **원격 지원과 자동화**다. 사용자가 “마우스 휠이 이상하다”, “회의실 웹캠 색감이 다르다”, “특정 앱에서 뒤로가기 버튼이 동작하지 않는다”고 말할 때, GUI 스크린샷만으로는 원인 파악이 어렵다. CLI가 있으면 현재 장치, 프로필, 설정 파일, 권한 상태를 진단 로그로 수집하고, 표준 프로필을 다시 적용하거나 롤백하는 자동화가 가능하다. 이는 사소해 보이지만 헬프데스크와 플랫폼팀의 시간을 줄이는 데 직접적이다.

## 한계와 리스크: 입력 훅 권한은 작은 문제가 아니다

OpenLogi README 상단은 프로젝트가 **active development** 중이며 아직 안정적이지 않고 기능과 설정이 바뀔 수 있다고 경고한다. 이 문구는 도입 판단에서 매우 중요하다. daily Trending에서 수천 stars today를 받았다는 사실은 관심의 신호이지, 장기 안정성이나 조직 도입 적합성을 보장하지 않는다. 특히 저장소가 2026년 5월 생성된 비교적 신생 프로젝트라는 점, open issues/PR이 200개 이상이라는 점은 빠른 성장과 동시에 운영 부담을 의미한다.

보안 측면에서 가장 민감한 부분은 입력 훅과 접근성 권한이다. 버튼 리매핑과 앱별 프로필 전환은 운영체제의 입력 이벤트, 포커스 정보, 전역 단축키, 때로는 접근성 API에 접근해야 한다. 이 권한은 악성 소프트웨어가 키 입력을 관찰하거나 조작할 때도 사용되는 표면이다. 따라서 OpenLogi를 승인 앱 목록에 넣으려면 최소한 다음을 확인해야 한다.

- 바이너리 서명과 배포 경로가 일관적인가
- 릴리스 아티팩트가 GitHub Actions 등 공개 가능한 빌드 파이프라인에서 생성되는가
- 자동 업데이트가 있다면 사용자 승인, 서명 검증, 프록시 환경에서의 동작이 명확한가
- 입력 훅이 어떤 범위의 이벤트를 읽고 기록하지 않는지 문서화되어 있는가
- 로그에 장치 식별자, 앱 이름, 사용자 행동 정보가 남는지 확인했는가
- 조직의 EDR, DLP, MDM 정책과 충돌하지 않는가

운영 리스크도 있다. README는 Logi Options+와 OpenLogi가 HID++ 접근을 두고 충돌할 수 있으므로 Options+를 먼저 종료하라고 안내한다. 이는 파일 동기화 앱 두 개를 동시에 켜면 충돌하는 것과 비슷한 문제다. 장치 수신기와 하드웨어 설정에 대한 소유권은 하나여야 한다. 조직 배포에서는 “Options+ 금지, OpenLogi 허용” 또는 “공식 앱만 허용”처럼 명확한 정책이 필요하다. 둘을 사용자 재량으로 섞으면 장애 재현이 어려워진다.

성능 측면에서는 네이티브 Rust 앱이라는 장점이 있지만, 모든 백그라운드 앱은 CPU wakeup, 메모리 상주, 배터리 소모, 입력 지연에 영향을 줄 수 있다. 특히 앱별 프로필 자동 전환은 포커스 이벤트 감시와 빠른 설정 적용이 필요하므로, 화상회의·게임·CAD·개발 IDE처럼 입력 지연에 민감한 환경에서 측정해야 한다.

## PoC 체크리스트: “설치해 보니 된다”에서 멈추지 말 것

![OpenLogi 도입 의사결정 체크리스트](https://heracles-jo.github.io/assets/img/posts/github-trending-openlogi-local-first-peripheral-control/checklist.svg)

OpenLogi PoC는 개인 노트북 한 대에 설치하는 테스트와 조직 배포 검증을 분리해야 한다. 최소 2주 정도의 파일럿을 권장한다.

### 1단계: 장치 호환성 매트릭스 작성

보유 중인 Logitech 장치를 연결 방식별로 나눈다. Logi Bolt, Unifying, Bluetooth, 유선 연결, UVC 웹캠을 구분하고, 각 장치에서 실제로 필요한 기능을 적는다. 예를 들어 “MX Master 계열의 SmartShift와 DPI”, “키보드 기능키”, “Brio 웹캠의 노출·화이트밸런스”, “Litra 조명”처럼 업무에 필요한 기능만 체크한다. 모든 기능을 다 지원하는지보다, 핵심 업무 기능이 안정적으로 동작하는지가 중요하다.

### 2단계: 권한과 보안 승인 경로 검토

macOS MDM에서는 접근성·입력 모니터링 권한을 어떻게 배포할지, Windows에서는 앱 제어 정책과 코드 서명을 어떻게 처리할지, Linux에서는 X11/XWayland/Wayland 환경별 제약을 어떻게 안내할지 정리한다. EDR이 입력 훅을 의심 행위로 탐지하는지, DLP가 로그 파일을 수집할 때 민감 정보가 포함되는지 확인한다.

### 3단계: 구성 파일 운영 방식 결정

TOML 파일을 개인 설정으로 둘지, 팀 표준 저장소에서 배포할지, MDM/Ansible/Nix/Homebrew Bootstrap과 결합할지 결정한다. 추천 방식은 “기본 표준 프로필 + 개인 오버레이”다. 조직이 모든 버튼을 강제하면 사용성이 떨어지고, 모든 것을 개인에게 맡기면 지원 비용이 오른다. 표준 프로필에는 회의용 웹캠, 공통 단축키, 금지 매핑 정도만 두고, 개인 생산성 매핑은 오버레이로 허용하는 편이 현실적이다.

### 4단계: 충돌과 롤백 시나리오 실험

Logi Options+가 설치된 상태, 제거된 상태, 동시에 실행된 상태를 모두 테스트한다. OpenLogi 업데이트 후 설정 파일 스키마가 바뀌는 경우, 잘못된 버튼 매핑으로 기본 입력이 어려워지는 경우, 웹캠 설정이 회의 앱과 충돌하는 경우를 일부러 만들어 복구 절차를 문서화한다. 롤백은 “앱 제거”만이 아니라 “권한 회수, 설정 파일 복원, 장치 하드웨어 설정 초기화”까지 포함해야 한다.

### 5단계: 운영 지표 수집

파일럿 기간에는 다음 지표를 본다.

- 장치별 기능 성공률과 미지원 기능 목록
- 입력 지연, 앱별 프로필 전환 실패, 배터리 소모 체감
- 헬프데스크 문의 유형과 해결 시간
- EDR/MDM/권한 정책 충돌 건수
- 릴리스 업데이트 후 회귀 버그 발생 여부
- 사용자가 실제로 유지한 커스텀 프로필 수

이 지표가 없으면 PoC는 “새 앱이 마음에 든다”는 취향 평가로 끝난다. 반대로 지표가 있으면 주변기기 설정을 엔드포인트 운영 항목으로 편입할 수 있다.

## 어떤 팀에 적합하고, 어떤 경우 피해야 하나

OpenLogi가 특히 적합한 팀은 세 부류다. 첫째, Linux 데스크톱을 일부라도 공식 지원하는 개발 조직이다. 벤더 공식 앱이 Linux에서 약하거나 정책상 부담스러운 경우, OpenLogi나 Solaar 같은 로컬 도구는 생산성 장비의 사각지대를 줄인다. 둘째, macOS·Windows·Linux를 섞어 쓰는 크로스 플랫폼 팀이다. 동일한 장치 정책을 비슷한 방식으로 문서화하고 싶다면 OpenLogi의 방향성이 매력적이다. 셋째, 영상회의·스트리밍·교육·지원 업무처럼 웹캠과 조명 품질이 업무 결과에 직접 영향을 주는 조직이다. 카메라 설정을 하드웨어에 쓰고 프로필로 관리할 수 있다면 회의실 품질 편차를 줄일 수 있다.

반대로 피해야 할 경우도 분명하다. 규정상 벤더 공식 지원 소프트웨어만 허용되는 산업, 장애 발생 시 로지텍 공식 지원 SLA가 필요한 환경, 입력 훅 권한을 조직 정책상 허용할 수 없는 환경, 핵심 장치가 OpenLogi에서 아직 미지원이거나 불안정한 환경에서는 성급히 표준 도구로 삼지 않는 편이 낫다. 특히 콜센터, 금융 거래 단말, 의료·제조 현장처럼 입력 장치 장애가 업무 중단이나 규제 리스크로 이어지는 곳에서는 파일럿 범위를 엄격히 제한해야 한다.

## 향후 관찰해야 할 지표와 전망

OpenLogi가 단기 Trending을 넘어 의미 있는 프로젝트로 남으려면 몇 가지 지표를 봐야 한다. 첫째, 릴리스 안정성이다. 확인 시점에 v0.7.3이 2026년 8월 20일 공개됐고 같은 날 v0.7.2도 있었다. 빠른 릴리스는 활발함의 신호지만, 조직 도입 관점에서는 회귀 테스트와 안정 채널이 더 중요하다. 둘째, 장치 호환성 데이터베이스의 품질이다. Logitech 장치는 모델·펌웨어·수신기 조합에 따라 기능 차이가 크다. 이 정보를 구조화된 표로 관리하고, 사용자가 쉽게 기여하고, 테스트 상태를 구분해야 한다.

셋째, 권한과 보안 문서의 성숙도다. “No telemetry”는 좋은 선언이지만, 실무자는 네트워크 호출, 로그 정책, 업데이트 검증, 크래시 리포트, 빌드 재현성, SBOM을 확인하려 한다. 넷째, Solaar·libratbag 같은 기존 생태계와의 관계다. OpenLogi가 모든 것을 새로 구현하기보다 프로토콜 지식과 장치 데이터를 어떻게 공유하거나 차별화할지가 장기 유지보수에 영향을 준다. 다섯째, CLI와 구성 스키마의 하위 호환성이다. 로컬 퍼스트 도구가 엔드포인트 정책으로 진화하려면 설정 파일이 자주 깨지지 않아야 한다.

전망을 조심스럽게 말하면, OpenLogi의 부상은 “오픈소스가 모든 벤더 앱을 대체한다”는 단정이 아니라 **작은 엔드포인트 소프트웨어에도 로컬 실행, 투명한 구성, 텔레메트리 최소화, 자동화 가능한 운영 표면을 요구하는 흐름**으로 해석하는 편이 맞다. 주변기기는 더 이상 단순 부속품이 아니다. 개발자 생산성, 접근성, 회의 품질, 보안 권한, 장치 수명주기 관리가 모두 만나는 지점이다. OpenLogi가 오늘 GitHub Trending에 오른 것은 그 지점이 드디어 개발자 커뮤니티의 관심사로 떠올랐다는 신호다.

> 조사 링크: [OpenLogi GitHub](https://github.com/AprilNEA/OpenLogi), [OpenLogi Releases](https://github.com/AprilNEA/OpenLogi/releases), [Solaar](https://github.com/pwr-Solaar/Solaar), [Piper](https://github.com/libratbag/piper), [libratbag](https://github.com/libratbag/libratbag), [Logitech Options+](https://www.logitech.com/software/logi-options-plus.html). 위 GitHub Trending 및 저장소 수치는 2026년 8월 21일 07:28 KST 전후 공개 페이지/API 확인 시점의 스냅샷이며, 이후 변동될 수 있다.
