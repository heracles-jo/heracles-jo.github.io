---
title: "AI 데스크톱 자동화: agent-desktop 접근성 트리 검증 기준"
description: "agent-desktop의 접근성 트리·snapshot ref·재시도 계약을 화면 인식 방식과 비교해 권한, 오작동, 개인정보, 크로스 OS 운영의 검증 기준을 정리한다."
author: heracles-jo
date: 2026-11-03 08:35:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [agent-desktop, desktop-automation, computer-use-agent, accessibility-api, gui-automation, ai-agent]
image:
  path: https://heracles-jo.github.io/assets/img/posts/agent-desktop-accessibility-automation/cover.svg
  alt: "agent-desktop 접근성 트리 기반 AI 데스크톱 자동화의 검증 기준 표지"
---

AI 에이전트가 데스크톱 앱을 조작하는 장면은 대개 화면 캡처, 비전 모델, 좌표 클릭으로 설명된다. 이 방식은 접근성 정보가 빈약한 앱에도 적용할 수 있지만, 창 위치와 배율이 달라지거나 같은 모양의 버튼이 여러 개 나타나면 판단이 흔들린다. 클릭 API가 성공해도 실제 대상이 맞았는지, 저장이나 전송이 끝났는지는 별도 문제다.

[vercel-labs/agent-desktop](https://github.com/vercel-labs/agent-desktop)는 다른 경로를 택한다. 운영체제가 제공하는 macOS Accessibility, Windows UI Automation, Linux AT-SPI 트리를 읽어 각 요소에 snapshot 단위 ref를 부여하고, 에이전트는 좌표가 아니라 `@snapshot:element`를 대상으로 행동한다. 결과와 오류는 구조화된 JSON으로 돌아오며, 도구가 정답을 추론하기보다 **관찰한 UI 객체를 다시 식별할 수 없으면 실행을 거부하는 것**이 설계의 중심이다.

2026년 11월 3일 08시 46분 KST 전후 공개 스냅샷에서 agent-desktop은 GitHub Trending daily에 **2,243 stars today**로 표시됐다. GitHub API 기준 9,543 stars, 646 forks, Apache-2.0 라이선스였고, 최신 릴리스 `v1.0.2`는 10월 30일 공개됐다. 11월 2일까지 문서와 성능·운영 변경이 이어졌으며 저장소에는 122개의 열린 issue·PR이 집계됐다. 이 수치는 확인 시점의 관심도와 활동 신호일 뿐 안정성 보증은 아니다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근할 수 없어 주제 선정에 사용하지 않았다.

## 후보를 비교하니 “화면을 보는 모델”보다 실행 계층의 계약이 남았다

오늘 후보에는 로컬 대형 모델 실행, 웹 수집, 공간 비전처럼 강한 주제가 함께 있었다. 기존 글의 제목과 저장소뿐 아니라 독자가 해결하려는 질문을 대조하면 FreeToken과 colibri는 저VRAM·로컬 추론 글과, Kornia는 컴퓨터 비전 라이브러리 선택과, Scrapling은 이미 다룬 웹 수집 운영과 가깝다. agent-desktop도 컴퓨터 사용 에이전트라는 말만 앞세우면 Cua 평가 글과 겹친다. 차이는 모델 평가가 아니라 **실제 OS UI를 어떤 식별자와 재시도 규칙으로 안전하게 변경할 것인가**에 있다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [agent-desktop](https://github.com/vercel-labs/agent-desktop) | daily 2,243, 9,543 stars, Apache-2.0, `v1.0.2` | screenshot 좌표 대신 접근성 트리와 fail-closed ref를 쓰는 **데스크톱 실행 계층 검증**이 별도 질문이라 선택했다. |
| [Scrapling](https://github.com/D4Vinci/Scrapling) | daily 858, 92,797 stars, BSD-3-Clause, `v0.5` | 웹 수집·stealth browser·MCP는 기존 Scrapling 및 Lightpanda 글의 검색 의도와 직접 경쟁한다. |
| [FreeToken](https://github.com/FlashML-org/FreeToken) | daily 654, 16,033 stars, Apache-2.0, `v0.2.1` | CPU·GPU·메모리를 묶는 MoE serving은 유효하지만 AirLLM·OMLX의 로컬 추론 운영과 인접하다. |
| [colibri](https://github.com/JustVugg/colibri) | daily 655, 46,510 stars, Apache-2.0, `v2.1.0` | 디스크 expert streaming은 독립 가치가 있으나 저VRAM·스토리지 병목이라는 기존 중심 논지와 겹친다. |
| [Kornia](https://github.com/kornia/kornia) | daily 412, 12,120 stars, Apache-2.0, `v0.9.0` | 차분 가능한 비전·기하 연산은 장기성이 높지만 오늘 후보 중 운영 경계가 더 선명한 것은 desktop actuator였다. |

[컴퓨터 사용 에이전트 평가 글](/posts/cua-computer-use-agent-evaluation/)은 태스크 시작 상태, 격리 데스크톱, trajectory, evaluator를 고정해 모델과 환경을 공정하게 비교하는 방법을 다뤘다. agent-desktop은 그 평가 스택의 아래쪽에 놓일 수 있는 actuator다. 어느 모델이 더 똑똑한지보다, 모델이 선택한 행동을 OS에 전달할 때 대상 식별과 전달 여부를 얼마나 보수적으로 표현하는지가 핵심이다.

## snapshot ref는 선택자가 아니라 짧게 사는 실행 권한이다

agent-desktop의 기본 루프는 단순하다.

```text
snapshot → qualified ref 선택 → action → 결과·상태 재관찰
```

`snapshot`은 창의 접근성 트리를 읽고 상호작용 가능한 요소에 `@s8f3k2p9:e8` 같은 ref를 붙인다. 이 ref는 CSS selector나 영구 객체 ID가 아니다. 특정 snapshot과 session namespace에 묶이고, UI가 바뀌면 다시 발급받아야 한다. bare ref인 `@e8`을 거부하는 이유도 과거 관찰의 요소를 현재 창에 임의로 대입하지 않기 위해서다.

![agent-desktop의 접근성 snapshot부터 ref 식별, 행동, 사후 검증까지의 실행 구조](https://heracles-jo.github.io/assets/img/posts/agent-desktop-accessibility-automation/architecture.svg)

더 중요한 부분은 ref를 다시 찾는 방법이다. 프로젝트의 현재 JSON contract 2.6은 Windows와 Linux에서 capture 시점의 완전한 창 관찰로 해당 요소가 유일했는지 증명하고, 실행 시점에도 role과 안정적인 name·description·native id가 정확히 하나만 일치할 때만 행동한다. 같은 이름과 역할을 가진 버튼이 둘이면 위치가 가까운 것을 추측하지 않고 `AMBIGUOUS_TARGET`으로 멈춘다. 요소가 사라졌으면 `STALE_REF`, 창 전체를 제한 시간 안에 읽지 못해 유일성을 증명하지 못했으면 `identity_unproven` 상태로 ref 행동을 거부한다.

이 태도는 좌표 클릭보다 느리고 답답해 보일 수 있다. 하지만 “삭제” 버튼이 두 개 있는데 첫 번째를 고르는 것보다, 자동화가 추가 맥락을 요청하도록 멈추는 편이 운영 시스템에서는 맞다. ref는 편리한 별칭이 아니라 **한 번 관찰한 UI 객체에만 행동하겠다는 제한된 권한**으로 보는 것이 정확하다.

다만 접근성 트리가 항상 좋은 진실 원천인 것은 아니다. 커스텀 캔버스, 게임 엔진 UI, 원격 데스크톱 화면, 접근성 속성을 잘못 구현한 Electron 앱은 이름·role·state가 비거나 왜곡될 수 있다. 동일한 목록 행이 안정적인 native id 없이 반복되면 엄격한 식별은 자주 실패한다. 이때 headed 좌표 입력으로 우회하면 적용 범위는 넓어지지만, 다시 포커스·좌표·가림·배율 위험을 떠안는다. 자동화 플랫폼은 semantic path와 visual fallback을 한 성공률로 섞지 말고 별도 경로로 측정해야 한다.

## `ok: true`와 업무 성공은 같은 뜻이 아니다

agent-desktop의 JSON은 성공을 한 비트로 단순화하지 않는다. 행동 결과에는 `delivery`와 `retry`가 따라온다. `delivered_verified`는 어댑터가 요청한 사후 상태를 읽어 확인했다는 뜻이고, `delivered_unverified`는 전달은 끝났지만 효과를 증명하지 못했다는 뜻이다. `not_delivered`만 자동 재시도가 안전하며, 전달 여부가 불명확하거나 이미 전달됐을 가능성이 있으면 `retry: unsafe`다.

예를 들어 버튼 클릭 명령이 운영체제 접근성 API까지 전달됐어도, 그 결과 서버에 주문이 등록됐는지까지 증명하지는 않는다. 창 크기 변경은 새 geometry를 읽어 검증할 수 있지만, 이메일 발송이나 파일 업로드는 앱 내부 상태와 외부 시스템을 따로 조회해야 한다. 공식 문서도 `ok: true`를 애플리케이션 효과의 완전한 증명으로 해석하지 말라고 구분한다.

이 구분이 필요한 이유는 자동 재시도 때문이다. timeout 뒤 같은 “전송” 버튼을 다시 누르면 메시지나 결제가 중복될 수 있다. 포커스를 주기 위한 preparatory scroll만 적용되고 본 동작은 실패했을 수도 있다. 따라서 오케스트레이터는 오류 코드 이름보다 먼저 `disposition.retry`를 읽어야 한다.

| 결과 | 자동화의 해석 | 다음 행동 |
|---|---|---|
| `not_delivered` + `safe` | 대상에 변경이 전달되지 않았음 | 새 snapshot 또는 조건 수정 후 제한적으로 재시도 |
| `delivered_verified` + `unsafe` | 도구가 정의한 로컬 사후 상태까지 확인 | 업무 시스템의 최종 결과를 별도 assertion으로 확인 |
| `delivered_unverified` + `unsafe` | 변경은 전달됐으나 효과가 불명확 | 재클릭하지 말고 snapshot·파일·API 상태를 조회 |
| `delivery_uncertain` 또는 `unknown` | 전달 여부 자체가 불명확 | 사람 검토나 idempotency 기반 reconciliation로 전환 |

[AI E2E 테스트의 재생 캐시 글](/posts/ai-e2e-agent-replay-testing/)에서 행동 재사용과 최종 assertion을 분리했듯, 데스크톱 자동화도 “명령이 실행됐다”와 “업무 결과가 맞다”를 나눠야 한다. 저장 버튼 뒤에는 예상 파일의 hash·경로·수정 시각을, CRM 변경 뒤에는 API의 record version을, 메일 작성 뒤에는 outbox의 message id를 확인해야 한다.

## 접근성 API는 headless가 아니라 권한 있는 로컬 제어면이다

README는 ref 기반 행동을 headless-by-default라고 부른다. 이는 마우스 포인터를 움직이거나 전경 포커스를 강제로 빼앗지 않고 접근성 API로 행동한다는 뜻이지, 격리된 서버 환경이라는 뜻이 아니다. 도구는 사용자의 실제 그래픽 세션과 앱 접근 권한 안에서 동작한다.

플랫폼별 신뢰 경계도 다르다.

- **macOS**: Accessibility 권한이 기본이고 screenshot에는 Screen Recording, Notification Center 제어에는 System Events Automation 권한이 추가된다.
- **Windows**: 같은 integrity level의 앱은 별도 grant 없이 다룰 수 있지만 관리자 권한 앱에 입력하려면 에이전트도 elevated 상태여야 한다. 브라우저로 받은 unsigned binary는 SmartScreen이나 보안 제품에 막힐 수 있다.
- **Linux**: 사용자 graphical session과 accessibility bus가 필요하다. Wayland에서는 앱 pointer input과 native window control의 제약이 있고, clipboard·키 입력도 세션 구성 요소에 의존한다.

그러므로 “크로스 플랫폼 지원”은 같은 명령이 세 OS에서 동일한 보안 의미를 갖는다는 뜻이 아니다. PoC에는 OS별 capability manifest를 두고, 실제 앱·세션·권한 조합에서 명령 가능 여부와 거부 방식을 기록해야 한다. 관리자 앱을 다루기 위해 전체 agent process를 상시 elevated로 실행하는 방식은 피하고, 별도 broker·승인·짧은 수명의 권한 상승 경로를 두는 편이 낫다.

[OpenShell의 에이전트 정책 런타임 글](/posts/openshell-agent-policy-runtime/)에서 네트워크와 자격증명 정책을 모델 바깥에 둬야 한다고 정리했다. 데스크톱에서도 같은 원칙이 필요하다. agent-desktop이 올바른 버튼을 식별해도 그 프로세스가 홈 디렉터리 전체, 클립보드, 사내 네트워크, 브라우저 세션에 접근할 수 있다면 blast radius는 여전히 크다. 테스트 계정, 전용 OS 사용자, 허용 앱·창 목록, egress 제한, 작업별 파일 디렉터리로 외부 경계를 좁혀야 한다.

## 가장 먼저 새는 것은 screenshot이 아니라 구조화된 텍스트다

시각 기반 에이전트의 개인정보 위험은 screenshot으로 쉽게 떠올린다. 접근성 트리는 이미지가 아니므로 안전하다고 오해하기 쉽지만, 실제로는 창 제목, 버튼 label, 문서 내용, 입력 필드 value, 알림, 클립보드가 구조화된 텍스트로 노출될 수 있다. 검색과 로그 적재가 쉬워 오히려 더 넓게 복제될 가능성도 있다.

공식 FAQ는 snapshot tree, window title, clipboard read, notification, command result, debug HTML, session trace가 private desktop content를 담을 수 있다고 명시한다. debug HTML은 screenshot과 접근성 데이터를 함께 포함하며, trace의 구조화 필드를 가려도 evidence artifact에 원문이 남을 수 있다. optional JEV helper는 구성한 모델 제공자에게 화면 설명을 보내므로 native CLI와 별도의 데이터 경계로 봐야 한다.

![AI 데스크톱 자동화에서 권한·개인정보·오작동을 분리해 통제하는 위험 경계](https://heracles-jo.github.io/assets/img/posts/agent-desktop-accessibility-automation/risk-boundary.svg)

운영 로그는 다음처럼 계층화하는 편이 안전하다.

1. 기본 metric에는 command type, latency, error code, delivery disposition만 남긴다.
2. element name·value·window title은 allowlist된 테스트 환경에서만 짧게 보존한다.
3. screenshot, clipboard, full snapshot, debug HTML은 장애 ticket에 연결된 암호화 저장소로 분리한다.
4. 모델 제공자 전송 전에는 앱·tenant·data classification 정책을 적용하고, label과 ancestor path까지 포함해 검사한다.
5. trace 삭제가 object storage, CI artifact, observability backend, 백업에 함께 반영되는지 시험한다.

[OpenBot의 AI 동료 승인·감사 글](/posts/openbot-ai-coworker-governance/)에서 지속형 에이전트의 메모리와 unattended routine을 통제했듯, 데스크톱 trace도 디버깅 편의 때문에 무기한 축적하면 안 된다. 증거 보존과 직원 화면 감시는 같은 시스템으로 쉽게 변할 수 있으므로 목적, 접근자, 보존 기간을 명시해야 한다.

## 화면 기반 자동화와 경쟁시키지 말고 라우팅해야 한다

접근성 트리 방식과 screenshot 방식은 어느 하나가 항상 우월하지 않다. semantic UI는 role·name·state를 직접 제공해 token과 좌표 의존성을 줄이고, list·form·menu 같은 업무 앱에서 안정적인 경우가 많다. 반면 canvas, 지도, CAD, 영상 편집, 원격 화면은 픽셀과 공간 관계가 필수다. 웹 앱은 DOM·CDP가 가장 직접적일 수 있으며, 공개 API가 있다면 GUI 자체를 거치지 않는 것이 낫다.

현실적인 실행 순서는 다음과 같다.

```text
공식 API/SDK → DOM·프로토콜 → OS 접근성 트리 → 시각 인식·좌표 → 사람 처리
```

이 순서는 기능 우열이 아니라 검증 가능성과 실패 비용의 순서다. API는 idempotency와 상태 조회를 설계할 수 있고, 접근성 트리는 객체 identity와 state를 제공한다. 좌표 입력은 마지막 호환 계층으로 남기되 destructive action에는 사람 승인을 요구한다. [Lightpanda 헤드리스 브라우저 글](/posts/lightpanda-headless-browser-validation/)에서 HTTP, 전용 브라우저, Chromium fallback을 나눴던 것처럼 desktop task도 앱과 단계별로 actuator를 선택해야 한다.

## 2주 PoC는 성공률보다 거부 품질을 측정한다

대표 태스크 20~30개를 고르고 테스트 계정과 가짜 데이터로 반복한다. 폼 입력, 파일 저장, 목록 선택, 알림 처리, 여러 창 전환을 포함하되, 동일한 이름의 버튼, 느린 앱, 재시작, popup, 권한 거부, 네트워크 지연을 의도적으로 넣는다. 정상 경로만 돌리면 fail-closed 설계의 가치도 운영 마찰도 알 수 없다.

| 검증 영역 | 측정값 | 중단 조건 예시 |
|---|---|---|
| 대상 식별 | stale·ambiguous ref 비율, 잘못된 대상 변경 0건, 재-snapshot 횟수 | 중복 label에서 추측 실행하거나 다른 창에 행동 |
| 결과 검증 | delivery disposition 분포, 최종 업무 assertion, 중복 부작용 | `delivered_unverified`를 성공 처리해 재전송 발생 |
| 접근성 품질 | 앱별 role·name·state·native id coverage, partial snapshot | 핵심 앱의 interactive element를 안정적으로 구분하지 못함 |
| 권한·격리 | OS permission, elevated action, 앱·파일·egress allowlist | 태스크 외 앱·비밀·내부망에 접근 가능 |
| 개인정보 | snapshot·trace·screenshot의 민감 필드, 보존·삭제 검증 | label·clipboard·debug artifact가 일반 로그에 남음 |
| 운영성 | p50·p95 latency, app unresponsive, recovery 시간, OS별 차이 | 실패를 15분 안에 identity·permission·app 문제로 분류 불가 |
| 공급망 | npm·release provenance, attestation, 버전 pin, rollback | binary와 helper 버전이 섞이거나 출처 검증 불가 |

첫 주에는 read-only snapshot과 find만 사용해 앱별 접근성 품질을 지도화한다. 둘째 단계에서 입력·선택·저장처럼 되돌릴 수 있는 행동을 열고, 모든 결과를 독립 assertion으로 확인한다. 마지막에만 외부 전송이나 삭제를 테스트하되 idempotency key, 별도 승인, 테스트 tenant를 유지한다. 동일 태스크를 semantic path와 visual baseline 양쪽에서 실행해 성공률뿐 아니라 action 수, token, latency, 잘못된 변경, 사람이 복구한 시간을 비교한다.

release archive를 직접 배포한다면 같은 release의 checksum만으로 출처가 증명되는 것은 아니다. 공식 설치 문서가 제시하는 GitHub artifact attestation 검증과 버전 pin을 적용하고, CLI와 platform helper를 같은 릴리스로 유지해야 한다. npm postinstall이 차단되면 native link 대신 Node launcher가 남아 호출 비용이 달라질 수 있으므로 성능 측정 환경도 기록해야 한다.

agent-desktop의 의미는 데스크톱을 클릭하는 명령이 많다는 데 있지 않다. **과거 관찰을 현재 객체로 억지로 연결하지 않고, 전달 여부를 재시도 가능성과 분리하며, 측정하지 못한 애플리케이션 결과를 성공으로 꾸미지 않는 계약**에 있다. 접근성 트리가 빈약한 앱과 OS별 권한 차이, 민감한 trace, 아직 짧은 릴리스 역사는 분명한 운영 비용이다. 도입 판단은 데모의 클릭 성공이 아니라 잘못된 대상을 얼마나 확실히 거부하고, 불명확한 전달 뒤 중복 실행을 막으며, 최종 업무 상태를 별도 증거로 확인할 수 있는지로 내려야 한다.

> 1차 자료: [agent-desktop 저장소와 README](https://github.com/vercel-labs/agent-desktop), [Concepts와 ref identity](https://github.com/vercel-labs/agent-desktop/blob/main/CONCEPTS.md), [JSON output contract](https://github.com/vercel-labs/agent-desktop/blob/main/docs/json-output.md), [설치·권한 문서](https://github.com/vercel-labs/agent-desktop/blob/main/docs/install.md), [개인정보 FAQ](https://github.com/vercel-labs/agent-desktop/blob/main/docs/faq.md), [SECURITY.md](https://github.com/vercel-labs/agent-desktop/blob/main/SECURITY.md), [v1.0.2 release](https://github.com/vercel-labs/agent-desktop/releases/tag/v1.0.2), [Apache-2.0 LICENSE](https://github.com/vercel-labs/agent-desktop/blob/main/LICENSE), [최근 commits](https://github.com/vercel-labs/agent-desktop/commits/main/), [공개 issues와 pull requests](https://github.com/vercel-labs/agent-desktop/issues). Trending·저장소 수치는 2026년 11월 3일 08시 46분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
