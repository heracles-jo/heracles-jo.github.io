---
title: "AI 웹 코드 검증: Modern Web Guidance 도입 기준"
description: "Modern Web Guidance의 로컬 검색·Baseline 호환성·Playwright 평가 구조를 분석하고, AI가 만든 웹 코드를 안전하게 검증하는 팀 도입 기준을 제시한다."
author: heracles-jo
date: 2026-11-13 08:10:00 +0900
categories: [Developer Tools, Web Platform]
tags: [modern-web-guidance, ai-coding-agent, web-platform, browser-compatibility, playwright, developer-tools]
image:
  path: https://heracles-jo.github.io/assets/img/posts/modern-web-guidance-agent-web-validation/cover.svg
  alt: "Modern Web Guidance를 AI 웹 코드 생성과 브라우저 검증 사이에 배치하는 도입 구조"
---

AI 코딩 에이전트에게 “접근 가능한 모달을 만들어 달라”고 요청하면 결과는 대개 작동한다. 문제는 그다음이다. 이미 브라우저가 제공하는 `<dialog>`와 Popover API 대신 포커스 트랩·`Escape` 처리·스크롤 잠금을 JavaScript로 다시 만들고, 오래된 polyfill을 기본 의존성으로 추가하며, 지원 범위를 확인하지 않은 최신 CSS를 섞을 수 있다. 화면 한 장이 정상으로 보인다는 사실만으로 접근성, 점진적 향상, 브라우저 호환성까지 맞았다고 말할 수 없다.

[GoogleChrome/modern-web-guidance-src](https://github.com/GoogleChrome/modern-web-guidance-src)는 이 간극을 줄이려는 Modern Web Guidance의 소스 저장소다. 웹 플랫폼 지침을 AI 에이전트가 필요할 때 검색·조회하도록 만들고, 정적 규칙뿐 아니라 실제 웹 애플리케이션과 Playwright grader로 지침의 효과를 비교한다. 핵심 질문은 “최신 Web API를 더 많이 쓰게 할 수 있는가”가 아니다. **에이전트가 제안한 최신 구현이 제품의 지원 브라우저·접근성·성능 계약을 지키는지 어떻게 판정할 것인가**다.

2026년 11월 13일 08시 20분 KST 전후 GitHub Trending daily에서 소스 저장소는 `799 stars today`로 표시됐다. GitHub API 확인 시점에는 2,831 stars, 191 forks, 열린 issue와 pull request를 합친 385개, Apache-2.0 라이선스였고 당일에도 legacy scan 규칙과 가이드 변경이 이어졌다. npm의 `modern-web-guidance` 최신 버전은 1.0.0이었다. 이 수치는 공개 페이지의 시점별 스냅샷이며 품질이나 특정 팀의 적합성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics 데이터에 접근하지 못했으므로 검색 성과를 주제 선정 근거로 사용하지 않았다.

## 후보 비교: 범용 스킬보다 웹 호환성 판정이 남아 있었다

오늘 후보는 에이전트 도구와 프런트엔드 프로젝트에 몰려 있었다. 단순 인기도보다 기존 글이 이미 답한 질문과 장기 검색 의도를 대조했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Modern Web Guidance](https://github.com/GoogleChrome/modern-web-guidance-src) | daily 799, 2,831 stars, Apache-2.0, npm 1.0.0 | 언어별 코딩 지침이 아니라 **AI 웹 코드의 Baseline·접근성·브라우저 동작을 검증하는 문제**가 별도 의도로 남아 선택했다. |
| [ASTRYX](https://github.com/meta/astryx) | daily 1,789, 26,461 stars, MIT, v0.7.15 | 에이전트 친화적 디자인 시스템은 흥미롭지만 생성 UI·디자인 시스템 범위가 넓고 제품 평가가 더 필요하다. |
| [Agent Skills](https://github.com/addyosmani/agent-skills) | daily 812, 116,639 stars, MIT, v0.6.15 | 범용 스킬 설계와 공급망은 기존 Agent Skills 글의 중심 의도와 직접 겹친다. |
| [Codex Security](https://github.com/openai/codex-security) | daily 663, 전날 글에서 조사·발행 | CI 보안 게이트라는 독립 의도는 이미 11월 12일 글에서 다뤄 연속 중복을 피했다. |
| [TensorFold](https://github.com/ashhart/TensorFold) | daily 94, 1,923 stars, Apache-2.0 | Metal·CUDA·Vulkan LLM 추론은 장기 가치가 있지만 저VRAM·이기종 추론 클러스터와 인접한다. |

기존 [Agent Skills 엔지니어링 워크플로](/posts/github-trending-agent-skills-engineering-workflow/)는 스킬을 재사용 가능한 실행 계약으로 만드는 일반 원칙을 다뤘다. [Android Skills 검증 글](/posts/android-skills-agent-workflow-validation/)과 [Modern Go Guidelines 글](/posts/modern-go-guidelines-ai-code-modernization/)은 공식·버전별 지침도 빌드와 테스트를 대체하지 못한다고 봤다. 이번에는 그 원칙을 브라우저 플랫폼에 좁힌다. HTML·CSS·JavaScript는 컴파일 성공 뒤에도 브라우저 지원, 키보드 조작, 렌더링, 네트워크와 성능에서 조용히 실패하기 때문이다.

## 이 프로젝트의 단위는 긴 프롬프트가 아니라 검색 가능한 가이드다

공식 README에 따르면 Modern Web Guidance는 CSS·HTML·JavaScript·성능·접근성·UI 컴포넌트 등 250개 웹 기능을 다룬다. 에이전트는 전체 문서를 매번 컨텍스트에 넣지 않는다. `search`로 작업과 가까운 가이드를 찾고, `retrieve`로 특정 가이드만 가져온다. 검색은 로컬 임베딩과 BM25를 결합하며 네트워크나 API 키 없이 동작하도록 설계돼 있다.

예를 들어 dialog 가이드는 “모달이면 `<dialog>`를 사용하라”에서 끝나지 않는다. modal과 non-modal을 나누고, `showModal()`, Popover, `closedby`, `overscroll-behavior`, invoker command의 역할을 구분한다. 수동 포커스 트랩과 `aria-modal` 중복을 피하게 하고, 지원이 부족한 기능에는 조건부 fallback을 제시한다. 에이전트가 흔히 만드는 “동작하지만 플랫폼 기능을 다시 구현한 코드”를 줄이는 방향이다.

![Modern Web Guidance의 로컬 검색과 브라우저 검증을 분리한 아키텍처](https://heracles-jo.github.io/assets/img/posts/modern-web-guidance-agent-web-validation/architecture.svg)

이 구조의 장점은 지식의 신선도와 토큰 비용을 동시에 다룬다는 점이다. 모델 전체를 다시 학습하지 않고 웹 기능별 문서를 갱신할 수 있고, 작업에 필요한 내용만 주입한다. [SWC와 Rust 웹 툴체인 글](/posts/github-trending-swc-rust-web-toolchain/)에서 빌드 도구의 성능과 생태계 호환성을 따로 봤듯, 여기서도 “지침 검색이 빠르다”와 “생성된 웹 코드가 맞다”는 다른 품질 축이다.

## Baseline 인식은 자동 허용이 아니라 지원 계약을 명시하는 장치다

Modern Web Guidance의 중요한 설계는 Baseline 호환성 데이터를 가이드에 연결한 것이다. 안정적으로 폭넓게 지원되는 기능과 최신·실험 기능을 같은 무게로 추천하지 않는다. Origin Trial API나 단일 엔진에 최근 도입된 volatile feature는 검색 결과에는 나타날 수 있지만, 명시적으로 허용하기 전에는 조회 단계에서 제한한다. 팀은 `.mwgrc`로 Origin Trial과 volatile feature 허용 여부를 공유할 수 있다.

하지만 Baseline이 “우리 제품에서 사용 가능”을 자동으로 뜻하지는 않는다. 실제 지원 계약은 더 복잡하다.

- 사내 브라우저가 자동 업데이트되지 않거나 장기 지원 채널에 묶여 있을 수 있다.
- WebView, 인앱 브라우저, 전자정부·금융 단말처럼 일반 데스크톱 브라우저와 다른 분포가 있을 수 있다.
- API 자체는 지원돼도 접근성 트리, 입력 장치, 특정 OS 조합에서 동작 차이가 날 수 있다.
- 점진적 향상 기능과 핵심 업무 기능은 fallback 실패 비용이 다르다.
- 번들 크기·CSP·서드파티 스크립트 정책 때문에 권장 polyfill을 그대로 쓸 수 없을 수 있다.

따라서 `.mwgrc`는 지원 브라우저 정책의 대체물이 아니라 에이전트가 넘지 말아야 할 1차 경계다. 실제 저장소에는 Browserslist, RUM의 브라우저 분포, 접근성 기준, CSP, 성능 예산과 테스트 매트릭스를 함께 둬야 한다. 최신 기능 사용률을 KPI로 삼으면 에이전트는 제품 가치와 무관한 현대화를 늘릴 수 있다.

## 평가 파이프라인은 프롬프트 만족도가 아니라 관찰 가능한 결과를 본다

소스 저장소는 가이드마다 `guide.md`, 기준 구현인 `demo.html`, 관찰 가능한 조건을 적은 `expectations.md`를 둔다. 평가 단계에서는 실제 애플리케이션에 적용할 task와 여러 에이전트의 golden patch, untouched baseline, Playwright grader를 만든다. grader는 정적 코드 패턴뿐 아니라 computed style, DOM 상태, 런타임 동작과 접근성을 확인한다.

공개 README의 최근 평가 스냅샷은 여러 에이전트에서 guided 결과가 unguided 결과보다 높은 pass rate를 보였다고 보고한다. 다만 이 수치를 그대로 팀 ROI로 가져오면 안 된다. 프로젝트가 선택한 과제, base app, grader와 모델 조합에 대한 결과이며, 사내 디자인 시스템·지원 브라우저·테스트 품질·레거시 제약을 반영하지 않는다. 특히 golden solution이 통과하고 untouched app이 실패하도록 grader를 교정했다는 사실은 평가의 내부 일관성을 높이지만, 모든 실제 결함을 찾는다는 뜻은 아니다.

실무 도입에서는 upstream uplift를 “가능성 신호”로만 사용하고 로컬 corpus를 만든다. 최근 코드 리뷰에서 실제로 발생한 오래된 API 사용, 과도한 JS, 접근성 누락, 무거운 polyfill, 지원 범위 이탈 사례를 모아 같은 task를 guided·unguided로 반복한다. 에이전트가 정답처럼 보이는 다른 구현을 만들 수 있으므로 selector 한 개를 강제하는 grader보다 사용자 관찰 결과와 플랫폼 계약을 검사해야 한다.

## 실패는 오래된 API보다 과도한 확신에서 시작된다

가이드가 최신이고 전문가가 관리해도 네 가지 실패는 남는다.

첫째, 지침과 프로젝트 문맥이 충돌할 수 있다. native dialog가 일반적으로 옳아도 기존 focus manager, iframe 경계, 오래된 WebView 지원 때문에 즉시 전환할 수 없는 저장소가 있다. 둘째, `@latest` 설치는 재현성을 약화시킨다. 같은 PR을 재실행할 때 가이드나 검색 인덱스가 바뀌면 diff가 달라질 수 있다. 셋째, 검색 질의와 retrieve ID는 원격 분석 정보에 포함될 수 있다. 공식 설명은 raw 사용자 prompt를 수집하지 않는다고 밝히고 `DISABLE_TELEMETRY=1` opt-out을 제공하지만, 비공개 제품명이나 기능명이 검색어에 들어가는 조직은 데이터 경계를 검토해야 한다. 넷째, 최신 기능의 fallback이 코드량을 다시 키워 원래의 단순화 이점을 없앨 수 있다.

라이선스도 두 층이다. 소프트웨어 코드는 Apache-2.0이지만 `guides/`의 문서와 가이드 콘텐츠는 CC-BY 4.0으로 안내된다. 내부 mirror, 재배포, 수정본을 운영한다면 코드 의존성뿐 아니라 가이드 콘텐츠의 attribution과 변경 관리도 확인해야 한다.

![Modern Web Guidance를 팀 정책으로 승격하기 전 확인할 위험과 중단 조건](https://heracles-jo.github.io/assets/img/posts/modern-web-guidance-agent-web-validation/decision.svg)

## 팀 도입은 세 개의 게이트로 좁히는 편이 낫다

### 지식 게이트: 버전과 허용 범위를 고정한다

PoC에서는 `@latest`를 개발자 개인 실험에만 쓰고, CI나 재현 가능한 에이전트 작업에는 검토한 npm 버전 또는 commit을 고정한다. 설치된 skill pack, 검색 결과의 guide ID, retrieve한 가이드 버전, `.mwgrc`를 작업 artifact로 남긴다. 업데이트는 일반 의존성처럼 별도 PR에서 가이드 diff와 Baseline·fallback 변경을 검토한다.

외부 지침이 shell·package install을 유도할 수 있으므로 [AI 에이전트 위험 명령 차단 글](/posts/ai-agent-destructive-command-guard/)의 원칙도 적용된다. 문서 조회 권한과 의존성 설치 권한, 애플리케이션 수정 권한을 분리한다. CI에서는 telemetry를 명시적으로 끄거나 허용 범위를 승인하고, 검색어가 운영 로그에 남는지도 확인한다.

### 코드 게이트: “현대적”보다 저장소 계약을 먼저 검사한다

에이전트가 만든 diff에는 최소한 다음 판정이 필요하다.

1. semantic HTML과 접근 가능한 이름·키보드·포커스 이동
2. 지원 브라우저와 WebView에서의 기능 탐지·점진적 향상
3. fallback과 polyfill의 조건부 로딩, 번들 크기 변화
4. CSP·Trusted Types·권한·외부 네트워크 요청 변화
5. 기존 디자인 시스템·SSR·hydration·라우팅과의 충돌
6. JavaScript 감소가 실제 복잡도와 장애 표면 감소로 이어졌는지

lint와 typecheck는 이 목록의 일부만 본다. Storybook interaction test, axe 계열 검사, Playwright의 키보드·viewport·브라우저 프로젝트, 시각 회귀, 실제 RUM 성능을 영향 범위에 맞춰 조합해야 한다.

### 승격 게이트: 로컬 corpus에서 효과와 비용을 함께 측정한다

2주 PoC는 UI 작업 10~20개면 충분하다. modal, tooltip, responsive card, form validation, image loading, view transition처럼 이미 팀이 구현해 본 작업을 고른다. 절반은 기존 에이전트 설정으로, 절반은 고정된 Modern Web Guidance를 사용해 같은 리뷰·테스트를 통과시킨다.

| 측정 항목 | 판정 질문 |
|---|---|
| 플랫폼 재구현 감소 | 불필요한 focus trap·event handler·polyfill이 줄었는가 |
| 호환성 이탈률 | 지원 브라우저 밖 API가 승인 없이 들어왔는가 |
| 접근성 결함 검출 | keyboard·screen reader·focus 회귀를 테스트가 잡았는가 |
| 번들·성능 변화 | JS bytes, INP, LCP와 long task가 개선됐는가 |
| 리뷰 수정 시간 | 제안을 승인 가능한 상태로 고치는 사람 시간이 줄었는가 |
| 지침 재현성 | 같은 버전·task에서 검색 결과와 diff가 안정적인가 |
| 업데이트 비용 | 새 가이드 버전이 기존 정책·테스트를 얼마나 바꾸는가 |

성공선은 최신 API 사용 개수가 아니다. 지원 범위를 벗어난 변경과 접근성 결함이 늘지 않으면서, 불필요한 JavaScript와 리뷰 시간이 줄어야 한다. upstream eval uplift가 높아도 팀 corpus에서 이 조건을 충족하지 못하면 참고 도구로만 남기는 편이 낫다.

Modern Web Guidance의 강점은 웹 표준 지식을 에이전트의 사전학습 기억에 맡기지 않고, 검색 가능한 지침·Baseline 데이터·평가 가능한 결과로 분리했다는 데 있다. Chrome만의 팁 모음에 머물지 않도록 Chrome·Edge·Firefox·MDN 관계자와 커뮤니티가 거버넌스에 참여하는 구조도 긍정적이다.

그렇다고 최신 웹 구현의 승인 권한까지 외부 스킬에 넘길 수는 없다. 현실적인 역할은 **에이전트가 오래된 패턴을 선택할 확률을 낮추는 지식 계층**이다. 최종 계약은 저장소가 정한 브라우저 지원 범위, 접근성 테스트, 성능 예산, 보안 정책과 실제 사용자 환경이 결정한다. 가이드는 더 나은 첫 diff를 만들 수 있다. 그 diff가 배포 가능한지는 브라우저에서 재현되는 증거로 판정해야 한다.

> 1차 자료: [Modern Web Guidance 소스 저장소와 README](https://github.com/GoogleChrome/modern-web-guidance-src), [배포 저장소](https://github.com/GoogleChrome/modern-web-guidance), [공식 문서](https://developer.chrome.com/docs/modern-web-guidance), [프로젝트 구조와 평가 파이프라인](https://github.com/GoogleChrome/modern-web-guidance-src/blob/main/docs/CONTEXT.md), [평가 환경 문서](https://github.com/GoogleChrome/modern-web-guidance-src/blob/main/docs/EVALS.md), [dialog guide](https://github.com/GoogleChrome/modern-web-guidance-src/blob/main/guides/ui-components/dialog/guide.md), [거버넌스](https://github.com/GoogleChrome/modern-web-guidance-src/blob/main/GOVERNANCE.md), [LICENSE](https://github.com/GoogleChrome/modern-web-guidance-src/blob/main/LICENSE), [최근 commits](https://github.com/GoogleChrome/modern-web-guidance-src/commits/main/), [공개 issues](https://github.com/GoogleChrome/modern-web-guidance-src/issues), [공개 pull requests](https://github.com/GoogleChrome/modern-web-guidance-src/pulls). Trending·GitHub·npm 수치는 2026년 11월 13일 08시 20분 KST 전후 공개 스냅샷이며 이후 달라질 수 있다.
