---
title: "AI E2E 테스트: 자연어 에이전트와 재생 캐시 검증 기준"
description: "tester-army/e2e의 자연어 행동·결정론적 검증·재생 캐시를 분해해 AI E2E 테스트의 플레이크, 비용, 보안 경계와 도입 기준을 정리한다."
author: heracles-jo
date: 2026-10-12 08:05:00 +0900
categories: [Software Engineering, Testing]
tags: [tester-army-e2e, ai-testing, e2e-testing, test-automation, replay-cache, playwright]
image:
  path: https://heracles-jo.github.io/assets/img/posts/ai-e2e-agent-replay-testing/cover.svg
  alt: "자연어 에이전트 행동을 결정론적 검증과 재생 캐시로 통제하는 AI E2E 테스트 구조"
---

브라우저 E2E 테스트는 정확한 locator를 쓰면 안정적이지만, 화면 구조가 자주 바뀌는 긴 사용자 흐름을 모두 스크립트로 유지하는 비용이 크다. 반대로 “회원으로 가입하고 Pro 요금제로 전환하라”처럼 목표만 주고 AI 에이전트가 화면을 조작하게 하면 작성은 쉬워지지만 결과가 비결정적이고 모델 호출 비용도 반복된다. **AI E2E 테스트의 핵심 문제는 자연어로 테스트를 쓰는 편의가 아니라, 불확정적인 행동과 결정론적인 릴리스 판정을 어디서 분리할 것인가**다.

[tester-army/e2e](https://github.com/tester-army/e2e)는 이 경계를 비교적 명시적으로 드러낸다. `agent.act`는 화면을 읽고 목표를 달성할 행동을 선택하지만, 정확한 결과는 locator 기반 `expect`나 별도의 assertion으로 확인할 수 있다. 한 번 검증된 행동은 replay cache에 기록해 다음 실행에서 모델 호출 없이 재생하고, UI가 달라져 기록을 적용할 수 없을 때만 에이전트가 이어받는다. 웹은 Playwright 기반 Chromium·Firefox·WebKit을, 모바일은 시뮬레이터·에뮬레이터를 대상으로 같은 runner 모델을 제공한다.

2026년 10월 12일 08시 13분 KST 전후 공개 스냅샷에서 이 저장소는 GitHub Trending weekly 2위에 표시됐고 **6,564 stars this week**를 기록했다. GitHub API 기준 9,021 stars, 435 forks, 열린 issue와 PR 합산 105개, Apache-2.0 라이선스였으며 10월 10일까지 커밋이 이어졌다. 핵심 `e2e` 패키지는 `0.19.0`이고 README도 1.0 이전 active development 상태라 API와 설정 변경 가능성을 명시한다. 수치와 활동은 확인 시점의 값이며 제품 안정성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근하지 못했으므로 선정 근거로 사용하지 않았다.

## 후보를 비교하니 남은 검색 의도는 “AI 행동을 어떻게 테스트 자산으로 고정하는가”였다

오늘 daily·weekly Trending에는 이미 다룬 REA, Diagram Design, claude-mem, RAD Debugger, text-to-cad가 다시 보였다. 새 저장소여도 멀티 에이전트 일반론이나 AI 영상 생성 소개로 접근하면 최근 글과 검색 의도가 겹친다. 후보는 기능 신선도보다 기존 테스트 자산과 연결되는 장기 질문을 기준으로 좁혔다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [tester-army/e2e](https://github.com/tester-army/e2e) | weekly 6,564, API 9,021 stars, Apache-2.0, `e2e` 0.19.0 | 자연어 행동을 검증된 replay로 전환하는 구조는 기존 Cypress 운영론과 구별되는 **AI E2E 테스트의 비용·재현성** 질문을 만든다. |
| [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes) | weekly 4,081, 60,937 stars, Apache-2.0, v0.8.149 | HTML 기반 결정론적 영상 렌더링은 강한 신호지만 최근 AI 영상·콘텐츠 자동화 글과 인접하다. |
| [mvschwarz/openrig](https://github.com/mvschwarz/openrig) | weekly 2,068, 6,959 stars, Apache-2.0, v0.6.9 | 영속 에이전트 팀 운영은 Orca·Google AX·세션 메모리 글과 중심 논지가 겹친다. |
| [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill) | weekly 945, 4,460 stars, MIT | 에이전트 지시문의 통제 언어는 독립적이지만 적용 범위와 한국어 독자의 즉시 검색 수요가 상대적으로 좁다. |
| [storytold/artcraft](https://github.com/storytold/artcraft) | daily 2,956, 17,718 stars, Apache-2.0, v0.41.0 | 창작 엔진의 가치보다 현재 사이트의 개발자 도구·테스트 클러스터와 연결성이 약하다. |

이 글은 기존 [Cypress 브라우저 E2E 테스트 거버넌스](/posts/github-trending-cypress-browser-e2e-testing-governance/)를 반복하지 않는다. Cypress 글의 중심은 고정된 spec, 브라우저 매트릭스, 플레이크와 CI 게이트였다. 여기서는 **자연어 목표를 실행하는 에이전트가 만든 행동을 언제 신뢰하고, 언제 버리며, 어떤 검증으로 다시 결정론적 자산으로 바꿀지**를 다룬다. 또한 [Cua의 컴퓨터 사용 에이전트 평가](/posts/cua-computer-use-agent-evaluation/)가 모델과 환경을 비교하는 벤치마크 인프라에 초점을 맞췄다면, e2e는 제품 저장소의 반복 가능한 회귀 테스트 안에 에이전트 행동을 섞는 쪽에 가깝다.

## 테스트를 세 종류의 단계로 나누면 책임이 선명해진다

공식 문서는 테스트 단계를 goal, assertion, locator로 구분한다. 이 구분이 단순 API 분류보다 중요하다.

- `agent.act`: “장바구니에 상품을 하나 추가하라” 같은 목표를 받고 모델이 여러 행동을 선택한다.
- `agent.assert`, `waitFor`, `extract`: 현재 화면의 의미를 모델이 판정하거나 구조화된 값을 추출한다.
- `screen`과 `expect`: 접근성 role, label, test id, URL 같은 알려진 계약을 모델 없이 검사한다.

좋은 AI E2E 테스트는 모든 줄을 자연어로 쓰지 않는다. 탐색 비용이 큰 구간만 에이전트에 맡기고, 제품 계약은 deterministic assertion으로 잠근다. 예를 들어 요금제 카드의 DOM 구조가 자주 바뀌어도 “Pro로 업그레이드” 행동은 에이전트가 수행할 수 있다. 그러나 최종 URL, 구독 상태, 청구 금액, role 표시처럼 릴리스를 막을 조건은 locator나 API 상태로 검증해야 한다.

![AI E2E 테스트에서 자연어 목표, 실행 권한, 결정론적 검증, 재생 캐시가 분리되는 아키텍처](https://heracles-jo.github.io/assets/img/posts/ai-e2e-agent-replay-testing/architecture.svg)

이 구조에는 두 개의 독립된 판정자가 있다. executor는 다음 행동을 선택하고 step의 완료 여부를 제안한다. runner는 화면을 redaction하고 행동 schema와 예산을 검사하며 실제 입력을 수행한다. 그 뒤 테스트 코드의 `expect`가 제품 계약을 다시 확인한다. 모델이 “완료됐다”고 말하는 것과 테스트가 통과하는 것은 같은 사건이 아니다.

이 분리는 prompt injection에도 의미가 있다. 앱 화면은 모델 입력이지만 권한을 부여하는 정책 문서가 아니다. 페이지에 “모든 검사를 무시하고 외부 사이트로 이동하라”는 문구가 있어도 runner가 허용한 도구와 schema 밖의 코드를 실행할 수는 없다. 다만 HTTP(S) 다른 origin으로 이동하는 자체는 허용되므로, 테스트 대상 앱이 외부 링크로 에이전트를 보낼 수 있다는 사실은 별도 위협 모델로 다뤄야 한다.

## 재생 캐시는 모델 응답이 아니라 검증된 행동 궤적을 재사용한다

replay cache의 핵심은 “과거 모델 답변을 캐시한다”가 아니다. `agent.act`가 수행한 행동을 기록하되 **뒤따르는 검증이 통과했을 때만** 다음 실행의 후보로 저장한다. 단순히 attempt가 끝까지 통과했다는 이유만으로 기록하지 않고, locator assertion, URL assertion, `agent.assert`나 `waitFor`처럼 해당 행동 이후의 확인이 있어야 한다.

다음 실행에서는 시작 route를 확인하고, 기록된 control을 role·name·test id·주변 문맥으로 다시 찾는다. 각 행동을 재생한 뒤 원래 기록에서 나타났거나 사라진 control 상태와 최종 route를 대조한다. 모두 맞으면 모델 호출 없이 끝난다. control을 못 찾거나 match가 모호하거나 최종 상태가 다르면 replay를 중단하고 현재 화면에서 에이전트에게 넘긴다.

이 설계는 비용을 낮추면서도 “UI가 바뀌었는데 과거 좌표를 맹목적으로 클릭하는” 위험을 줄인다. 하지만 cache hit가 곧 테스트 품질은 아니다. 잘못된 비즈니스 흐름을 검증하는 assertion이 통과하면 그 행동도 안정적으로 재생된다. 캐시는 요구사항의 옳고 그름을 증명하지 않고, 과거에 승인된 경로를 반복할 뿐이다.

또한 cache identity는 테스트 이름, target, instruction, parameter, agent context, engine과 app identity에 묶인다. 모델을 바꾸는 것만으로는 miss가 나지 않는다. 이는 “어떤 모델이 행동을 만들었는가”보다 “어떤 테스트 계약으로 검증됐는가”를 우선한다는 뜻이다. 반대로 timestamp나 임시 이메일을 일반 parameter로 넣으면 매번 다른 step이 되어 cache가 무효화된다. 공식 `unique()`처럼 실행마다 달라져도 같은 역할을 하는 테스트 데이터를 별도 표현으로 다뤄야 한다.

## 자연어가 locator 유지보수를 없애는 것이 아니라 실패 위치를 바꾼다

locator 기반 테스트는 selector가 깨지면 명시적으로 실패한다. 에이전트 기반 테스트는 비슷한 이름의 버튼을 찾아 우회할 수 있어 작은 UI 변화에는 강하다. 그러나 이 유연성은 새로운 플레이크를 만든다.

첫째, **의미 모호성**이다. “설정을 저장하라”는 목표에 저장 버튼이 여러 개면 모델이 범위를 잘못 잡을 수 있다. 자연어 step은 한 번에 하나의 목표로 좁히고, 제품 화면에서 쓰는 용어와 test parameter를 명시해야 한다.

둘째, **판정 모호성**이다. 성공 toast가 잠깐 보였다는 이유로 통과했지만 실제 서버 상태가 반영되지 않을 수 있다. 의미 assertion만으로 끝내지 말고 URL, 접근성 상태, API 또는 후속 화면처럼 지속되는 결과를 확인해야 한다.

셋째, **환경 변동**이다. 쿠키 배너, 실험 flag, 지역·언어, 느린 네트워크, 모바일 키보드가 행동 경로를 바꾼다. agent가 우회에 성공하면 테스트는 통과하지만 동일한 변경의 회귀 비용과 action 수가 크게 출렁일 수 있다. pass/fail과 함께 model call, action count, replay hand-off, duration을 추적해야 한다.

넷째, **cache 은폐**다. 로컬에서 새 recording을 만들고 CI에서 read-only replay만 쓰면 빠르지만, 오래된 기록이 계속 agent로 hand-off되어도 기본 모드에서는 테스트가 통과할 수 있다. 그 결과 팀은 매 CI마다 모델 비용을 내면서 cache가 깨졌다는 사실을 놓친다. `--strict-cache`는 stale replay를 `REPLAY_STALE`로 실패시키지만, 새 테스트나 의도적으로 live 실행할 step과 구분해 적용해야 한다.

## 보안 경계는 secret redaction보다 넓다

공식 보안 모델은 앱 콘텐츠를 untrusted input으로 보고, test code·config·custom tool·engine·reporter·cache store는 **운영체제 권한으로 실행되는 신뢰 코드**로 본다. 즉 프레임워크가 모델 출력을 임의 코드로 평가하지 않는다고 해서 테스트 실행 전체가 sandbox가 되는 것은 아니다. 외부 기여자의 PR에서 변경된 테스트와 설정을 secrets가 있는 runner에서 실행하면 dependency와 app command가 그대로 호스트 권한을 가진다.

`Secret`은 plaintext accessor 없이 이름과 목적만 모델에 보이고, runner가 선택된 secure field를 확인한 뒤 값을 채운다. secret fill 이후에는 screenshot 전송을 중단하고 알려진 secret 문자열을 text output에서 치환한다. 이 경계는 합리적이지만 다음은 남는다.

- video와 binary download는 자동 redaction되지 않는다.
- 앱의 stdout·stderr를 담는 `command.log`는 원문을 보존한다.
- secret의 일부나 변형값, 일반 문자열로 전달한 자격증명은 탐지되지 않을 수 있다.
- cache entry는 secret fill 외의 typed value를 그대로 저장하고 서명되지 않은 채 테스트 권한으로 재생된다.
- 다른 origin으로 이동할 때 origin allowlist가 없으므로, step에 제공한 secret이 외부 인증 흐름에서 쓰일 가능성을 설계 단계에서 통제해야 한다.

따라서 공유 cache는 생성 산출물이 아니라 코드 리뷰 대상 테스트 데이터로 취급해야 한다. 민감한 흐름은 외부 sandbox, 전용 tenant, 최소 권한 계정, egress 제한, 짧은 artifact 보존 기간을 결합하는 편이 안전하다. [Cloudflare Security Audit Skill의 검증 파이프라인](/posts/cloudflare-security-audit-skill-validation-pipeline/)에서 다룬 것처럼 AI가 만든 판단은 증거와 권한 경계를 분리할 때만 운영 신호가 된다.

기본 활성화된 익명 telemetry도 조직 정책에 따라 명시적으로 결정해야 한다. 공식 문서는 test title, URL, instruction, screenshot, credential을 보내지 않고 명령·엔진·실패 코드·모델 식별자·token과 같은 집계값을 PostHog로 전송한다고 설명한다. 규제 환경이나 폐쇄망에서는 `E2E_TELEMETRY_DISABLED=1` 또는 `DO_NOT_TRACK=1`을 CI 설정에 고정하고 실제 outbound를 검증해야 한다.

## Playwright·Cypress를 대체하기보다 그 위의 불확정 구간을 제한하는 도구다

`@e2e-dev/web`이 Playwright 브라우저 엔진을 사용한다는 점에서 e2e를 Playwright의 완전한 대체재로 보는 것은 정확하지 않다. browser lifecycle, accessibility tree, locator와 실제 상호작용은 결정론적 자동화 엔진의 기반 위에 있다. 차이는 테스트 작성자가 모든 행동 경로를 미리 코딩하는 대신 일부 목표를 agent executor에 위임한다는 데 있다.

| 접근 | 강한 영역 | 주된 비용 | 적합한 사용법 |
|---|---|---|---|
| Playwright/Cypress locator | 정확한 계약, 빠른 실행, 원인 재현 | UI 구조 변화에 따른 spec 유지보수 | 결제 결과, 권한, URL, 데이터 상태 같은 핵심 게이트 |
| 자연어 `agent.act` | 탐색적 UI 조작, 자주 바뀌는 긴 흐름 | 모델 비용, 비결정성, 지시문 모호성 | 중간 탐색과 설정, 사람이 의미로 설명하기 쉬운 행동 |
| replay cache | 검증된 agent 경로의 빠른 반복 | stale 기록 관리, cache review | PR·회귀 실행에서 모델 호출을 줄이는 최적화 계층 |
| Cua류 benchmark | 여러 모델·환경의 공정한 비교 | 환경 이미지·평가기·trajectory 운영 | GUI 에이전트 자체의 성능 평가와 연구 |

이 조합에서 중요한 원칙은 **agent-first가 아니라 contract-first**다. 비즈니스 계약을 먼저 locator, API, 데이터 assertion으로 정의하고, 그 계약에 도달하는 경로 중 유지보수 비용이 높은 부분만 agent로 대체한다. 화면에 정확한 role과 label이 있다면 굳이 모델을 호출할 이유가 없다. [Context Mode의 도구 출력 최적화](/posts/context-mode-agent-context-optimization/)와 마찬가지로 AI 계층은 모든 입력을 맡길수록 좋은 것이 아니라, 비용이 큰 비정형 구간을 제한적으로 중재할 때 가치가 선명하다.

## 2주 PoC는 통과율보다 replay 전환율과 잘못된 통과를 측정한다

![AI E2E 테스트 PoC에서 정확성, 재생 안정성, 비용, 보안을 순서대로 검증하는 위험 게이트](https://heracles-jo.github.io/assets/img/posts/ai-e2e-agent-replay-testing/risk-gates.svg)

PoC 대상은 핵심 사용자 흐름 8~12개면 충분하다. 가입, 권한 초대, 설정 변경, 결제 sandbox, 파일 업로드처럼 UI 탐색은 복잡하지만 최종 상태를 명확히 검증할 수 있는 흐름을 고른다. 각 흐름에는 기존 locator-only 기준선을 남겨 비교한다.

1. **계약 정확성**: 최종 assertion을 인위적으로 깨뜨렸을 때 agent가 다른 화면을 성공으로 오판해도 테스트가 반드시 실패하는지 본다.
2. **반복 재현성**: 같은 commit·browser·fixture에서 20회 이상 반복해 live agent 성공률과 replay 성공률을 분리한다.
3. **replay 전환율**: 검증된 `act` 중 다음 실행에서 모델 호출 없이 끝난 비율, hand-off와 miss 사유를 기록한다.
4. **변경 내성**: 버튼 위치, 문구, DOM wrapper, route parameter를 의도적으로 바꾸고 locator·replay·agent가 각각 어디서 실패하는지 비교한다.
5. **비용과 지연**: test별 model calls, input/output token, wall-clock p50·p95, cache 사용 전후 CI 비용을 측정한다.
6. **플레이크 분류**: 제품 결함, assertion 결함, model 판단, replay stale, 브라우저·데이터·환경 실패를 별도 코드로 집계한다.
7. **secret canary**: prompt, AI trace, report, screenshot, video, download, command log, committed cache에서 canary가 노출되는 경로를 확인한다.
8. **공급망·PR 격리**: 외부 PR이 config, custom tool, app command를 바꿔도 secrets와 write token이 없는 sandbox에서만 실행되는지 검증한다.
9. **telemetry·egress**: 모델 provider, 앱, browser download, telemetry 이외의 목적지로 트래픽이 나가지 않는지 관측한다.
10. **업그레이드 회귀**: 0.x minor 업데이트 시 cache key, engine resolution, report schema, 실패 코드 변화가 CI 정책을 깨지 않는지 확인한다.

중단 조건은 단순하다. deterministic assertion을 우회한 잘못된 통과가 한 번이라도 발생하거나, secret canary가 공유 artifact에 남거나, 동일 fixture에서 실패 원인을 15분 안에 재현하지 못하면 적용 범위를 넓히지 않는다. 비용 절감도 전체 테스트 수가 아니라 **검증된 replay가 안정적으로 반복되고 stale 상태가 명시적으로 관리되는가**로 판단해야 한다.

현재 버전이 0.19.0이고 공식 지원 정책도 최신 0.x minor만 보안 수정을 받는다고 밝히므로, 전사 표준으로 고정하기에는 변화 비용을 감수해야 한다. 처음에는 한 제품 팀의 비핵심 관리 화면이나 수동 회귀 비용이 큰 흐름에서 시작하고, 결제 승인·데이터 삭제·권한 상승처럼 실패 비용이 큰 작업은 locator와 API 검증, 사람 승인 단계를 유지하는 편이 맞다.

AI E2E 테스트가 주는 실제 이점은 테스트 코드를 자연어로 짧게 쓰는 데 있지 않다. **불확정적인 화면 탐색을 에이전트에 맡기되, 결과는 결정론적으로 검증하고, 성공한 행동만 재생 가능한 자산으로 승격하는 것**이 핵심이다. 이 경계를 지키면 AI는 기존 테스트 자동화를 흐리게 만드는 대체물이 아니라, 유지보수 비용이 높은 구간을 흡수하는 제한된 실행 계층이 된다.

> 1차 출처: [tester-army/e2e 저장소와 README](https://github.com/tester-army/e2e), [Core concepts](https://github.com/tester-army/e2e/blob/main/docs/core-concepts.mdx), [Agent steps](https://github.com/tester-army/e2e/blob/main/docs/agent-steps.mdx), [Replay cache](https://github.com/tester-army/e2e/blob/main/docs/cache.mdx), [Security](https://github.com/tester-army/e2e/blob/main/docs/security.mdx), [Decision models](https://github.com/tester-army/e2e/blob/main/docs/decision-models.mdx), [Telemetry](https://github.com/tester-army/e2e/blob/main/docs/telemetry.mdx), [Security policy](https://github.com/tester-army/e2e/blob/main/SECURITY.md), [공개 releases](https://github.com/tester-army/e2e/releases), [최근 commits](https://github.com/tester-army/e2e/commits/main/), [공개 issues와 PR](https://github.com/tester-army/e2e/issues). Trending·저장소 수치는 2026년 10월 12일 08시 13분 KST 전후 확인한 공개 스냅샷이다.
