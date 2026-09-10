---
title: "AI 아키텍처 다이어그램 자동화: Diagram Design 검증 기준"
description: "Diagram Design의 에이전트 스킬·HTML/SVG 생성 구조를 살펴보고, 예쁜 그림을 신뢰할 수 있는 아키텍처 문서로 운영하기 위한 리뷰·보안·PoC 기준을 제시한다."
author: heracles-jo
date: 2026-09-11 08:05:00 +0900
categories: [AI Engineering, Developer Tools]
tags: [diagram-design, architecture-diagram, agent-skills, documentation, diagram-as-code, developer-tools]
image:
  path: https://heracles-jo.github.io/assets/img/posts/ai-architecture-diagram-automation-diagram-design/cover.svg
  alt: "AI가 만든 아키텍처 다이어그램을 사실성, 가독성, 보안 기준으로 검증하는 흐름"
---

아키텍처 다이어그램을 AI에게 맡기면 초안은 빨리 나온다. 문제는 그다음이다. 존재하지 않는 연결이 그럴듯하게 추가되고, 인증 경계가 색상 하나로 축약되며, 운영자가 꼭 봐야 할 실패 경로는 화면 밖으로 밀려난다. 반대로 모든 구성 요소를 넣으라고 하면 선이 얽힌 그림이 되어 아무도 읽지 않는다. 생성 속도보다 어려운 일은 **무엇을 생략했는지 설명할 수 있고, 코드와 운영 현실이 바뀔 때 틀린 부분을 찾아낼 수 있는 문서로 유지하는 것**이다.

2026년 9월 11일 08시 15분 KST 전후 GitHub 공개 페이지를 확인한 스냅샷에서 [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design)은 daily Trending에 **1,287 stars today**로 표시됐다. GitHub API 기준 약 **37.7k stars**, **2.4k forks**, MIT 라이선스였고, 마지막 push는 9월 11일 KST 직전까지 이어졌다. 저장소는 버전 릴리스를 따로 발행하지 않으며 보안 정책도 최신 `main`만 지원한다고 밝힌다. 따라서 높은 관심과 빠른 변경은 채택 신호인 동시에 버전을 고정하고 결과물을 재검증해야 한다는 신호다.

이 글의 질문은 “AI가 더 예쁜 그림을 그리는가”가 아니다. Diagram Design을 사례로 **에이전트가 만든 다이어그램을 리뷰 가능한 소프트웨어 산출물로 바꾸려면 어떤 경계가 필요한가**를 따진다. Search Console과 Analytics의 검색어·노출 데이터에는 이번 실행 환경에서 접근할 수 없었으므로 트래픽 근거가 있는 것처럼 해석하지 않았다.

## 후보 신호: 다이어그램 생성과 검증이 갈라지고 있다

이번 daily·weekly Trending에서는 다이어그램 도구 두 개와 에이전트 운영 도구, 로컬 모델 선택기, 오래된 C++ 기반 라이브러리가 함께 강한 신호를 보였다. README, 라이선스, 최근 commit, release와 이슈·PR 활동을 비교했다.

| 후보 | 확인 시점 신호 | 기존 글 중복과 검색 의도 판단 |
|---|---|---|
| [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) | daily 1,287 stars today, 약 37.7k stars, MIT, 9월 10일 UTC push | AI 다이어그램의 시각 품질과 리뷰·보안 경계를 함께 다룰 수 있다. 기존 디자인 시스템 글과 달리 아키텍처 문서의 사실성이 중심이다. |
| [tt-a1i/archify](https://github.com/tt-a1i/archify) | weekly 12,541 stars this week, 약 57.3k stars, MIT, v2.16.0 | typed JSON IR와 deterministic validation이 강점이다. Diagram Design의 보완·대조군으로 가치가 크지만 검색 의도가 거의 같아 별도 글로 분리하지 않았다. |
| [Tencent/teamai-cli](https://github.com/Tencent/teamai-cli) | daily 837 stars today, 약 3.8k stars, v0.23.1 | 팀 스킬·규칙 배포는 유용하지만 기존 Agent Skills·Cursor Plugins 글과 중심 논지가 겹친다. API의 라이선스 식별도 불명확했다. |
| [AlexsJones/llmfit](https://github.com/AlexsJones/llmfit) | daily 247 stars today, 약 35.7k stars, MIT, v1.1.15 | 로컬 하드웨어에 맞는 모델 탐색 의도는 분명하지만 AirLLM·OMLX·이기종 추론 클러스터와 인접한다. |
| [fmtlib/fmt](https://github.com/fmtlib/fmt) | weekly 1,847 stars this week, 약 25.7k stars, MIT, v12.2.0 | 장기 가치가 높은 C++ 포매팅 주제지만 오늘 관찰된 에이전트 문서화 흐름과는 거리가 있다. |

Diagram Design과 Archify가 동시에 주목받은 점이 중요하다. 전자는 39개 시각 유형, 브랜드 토큰, 접근성 계약, draw.io·Mermaid·Excalidraw 가져오기와 self-contained HTML/SVG를 강조한다. 후자는 typed JSON IR, 검증된 snapshot 비교, 결정론적 compiler를 전면에 둔다. 방향은 다르지만 메시지는 같다. 프롬프트 한 번으로 이미지를 뽑는 단계에서 벗어나 **구조화된 의미, 렌더링 규칙, 검증 영수증**을 분리하려는 수요가 커지고 있다.

## Diagram Design은 렌더러보다 운영 규약에 가깝다

Diagram Design의 핵심은 SaaS 캔버스가 아니라 에이전트가 읽는 `SKILL.md`와 유형별 reference다. 사용자가 시스템을 설명하면 에이전트는 먼저 의미 패턴을 고르고, architecture·sequence·data flow·deployment 같은 시각 유형을 선택한 뒤 self-contained HTML 안에 SVG와 CSS를 만든다. 정적 출력이 기본이며, 동작을 설명할 필요가 있을 때만 제한된 motion template을 쓴다.

이 구조의 장점은 그림을 만드는 판단 기준이 저장소에 남는다는 것이다. “노드는 다른 개념을 대표해야 한다”, “9개가 넘으면 둘로 나눌 가능성을 검토한다”, “강조색은 한두 개의 초점에만 쓴다” 같은 규칙은 프롬프트의 취향을 팀 규약으로 바꾼다. 접근성도 사후 장식이 아니다. SVG에 `role="img"`, `<title>`, `<desc>`, 고유 ID를 요구하고 reduced-motion 환경에서는 완전한 정적 프레임을 제공하도록 계약한다.

![요구사항에서 검증된 다이어그램으로 이어지는 생성·리뷰 워크플로](https://heracles-jo.github.io/assets/img/posts/ai-architecture-diagram-automation-diagram-design/workflow.svg)

하지만 이 파이프라인이 원본 시스템을 자동으로 증명하지는 않는다. 에이전트가 읽은 README가 낡았거나, 코드 탐색 범위에서 Terraform과 런타임 설정을 놓쳤거나, 사람이 구두로 설명한 연결이 틀렸다면 아름다운 SVG도 틀린 문서다. `lint-render.py` 같은 저장소의 검사는 겹침, 잘림, 접근성, 스킨 규칙을 찾는 데 유용하지만 “결제 API가 실제로 데이터베이스에 직접 접근하는가”까지 확인하지는 못한다.

여기서 [DESIGN.md와 AI 코딩 시대의 디자인 시스템 운영](/posts/github-trending-design-md-design-system-ai-agents/)에서 다룬 원칙이 이어진다. 토큰과 컴포넌트 규칙은 출력의 일관성을 높이지만, 제품 요구사항과 구현의 진실을 대신하지 않는다. 다이어그램 스킬도 같은 방식으로 봐야 한다. **시각 문법의 source of truth**와 **시스템 사실의 source of truth**는 서로 다른 계층이다.

## 그림을 두 층으로 리뷰해야 하는 이유

AI 다이어그램 리뷰가 자주 실패하는 이유는 시각 품질과 기술 정확성을 한 번에 승인하기 때문이다. 깔끔한 정렬과 색 대비가 좋으면 연결도 맞을 것이라고 느끼는 자동화 편향이 생긴다. 리뷰를 두 층으로 분리하면 이 오류를 줄일 수 있다.

첫 번째는 **semantic review**다. 노드와 edge마다 근거를 확인한다. 서비스는 배포 manifest, 모듈 경계, ownership catalog 중 어디에서 왔는가. 호출 방향은 trace·코드 import·API 명세 중 무엇으로 확인했는가. 추론한 연결이라면 `observed`가 아니라 `inferred`로 표시했는가. 외부 SaaS, PII, secret, trust boundary가 빠지지 않았는가를 본다.

두 번째는 **presentation review**다. 독자가 10초 안에 주 경로를 찾는지, 글자 크기와 대비가 충분한지, 선이 노드를 관통하지 않는지, 모바일 폭에서도 의미가 유지되는지 확인한다. 임원용 문구를 간단히 만드는 일과 기술 요소를 삭제하는 일도 구분해야 한다. Diagram Design이 import 시 `faithful`, `balanced`, `simplified`와 audience를 별도 dial로 둔 이유다. 표현을 줄였다고 원본 사실이 사라진 것은 아니며, 무엇을 병합·축약·제외했는지 fidelity ledger로 남겨야 한다.

[drawDB와 데이터베이스 스키마 설계 거버넌스](/posts/github-trending-drawdb-database-schema-design-governance/)에서 ERD를 실제 migration과 대조해야 했던 것처럼, 아키텍처 다이어그램도 배포 상태와 독립적으로 떠다니면 빠르게 낡는다. 차이는 범위다. ERD는 table·column·foreign key라는 비교적 강한 구조가 있지만, 고수준 아키텍처는 ownership, network, data classification, fallback처럼 코드 한 파일에서 읽히지 않는 사실까지 합쳐야 한다.

## self-contained HTML은 편리하지만 신뢰 경계이기도 하다

단일 HTML은 공유하기 쉽다. 서버나 별도 빌드 없이 열 수 있고, SVG를 추출해 문서·슬라이드에 넣을 수 있다. 반면 HTML은 이미지 포맷이 아니라 실행 가능한 컨테이너다. Diagram Design은 일반 출력에서 JavaScript와 외부 이미지를 쓰지 않고, motion이 필요할 때 검토된 controller만 허용하며 임의 script·원격 asset·실행 가능한 HTML attribute를 거부하도록 규약을 둔다. Excalidraw import도 text만 분석하고 링크를 따라가지 않는다고 명시한다. 이런 제한은 디자인 취향이 아니라 공급망 통제다.

![AI 다이어그램 산출물의 입력·실행·공개 단계별 위험 경계](https://heracles-jo.github.io/assets/img/posts/ai-architecture-diagram-automation-diagram-design/risk-boundary.svg)

조직에서 적용할 때는 다음 세 경계를 분리해야 한다.

1. **입력 경계**: 외부 `.drawio`, Mermaid, Excalidraw, 웹사이트 brand URL은 비신뢰 데이터로 취급한다. parser를 secret이 없는 sandbox에서 실행하고 파일 크기·압축 해제량·허용 scheme을 제한한다.
2. **생성 경계**: 에이전트가 임의의 `<script>`, `onload`, 외부 font·image URL을 넣지 못하도록 정적 검사한다. 승인된 motion template의 digest를 고정하고 차이가 나면 실패시킨다.
3. **공개 경계**: 내부 hostname, 계정 ID, IP range, 장애 우회 경로, 보안 제품명 같은 정보가 외부 문서로 나가지 않는지 별도 검토한다. 기술적으로 정확한 그림도 공개 범위에는 과도할 수 있다.

브라우저에서 “잘 열린다”는 결과는 안전성 검증이 아니다. CSP가 강한 문서 포털에서 동작하는지, 외부 요청이 0인지, SVG 안에 링크와 foreign object가 없는지, 다운로드 파일명이 사용자 입력으로 오염되지 않는지 검사해야 한다. PNG export가 Playwright와 Chromium을 요구한다면 CI image와 browser version도 고정해야 재현성을 얻을 수 있다.

## Mermaid, draw.io, Archify와의 선택은 편집 단위를 보면 된다

도구 비교에서 흔히 “예쁜가”만 보지만, 운영에서는 **어떤 단위를 diff하고 승인할 것인가**가 더 중요하다.

| 선택지 | 주 편집 단위 | 강점 | 비용과 한계 |
|---|---|---|---|
| Mermaid | text DSL | Git diff가 쉽고 Markdown 가까이 유지된다 | 복잡한 editorial layout과 세밀한 강조에는 제약이 있다 |
| draw.io | XML canvas | 자유로운 수동 편집과 넓은 사용자층 | 의미 변경과 좌표 변경이 섞여 리뷰가 어렵고 스타일 drift가 생긴다 |
| Diagram Design | 에이전트 규약 + HTML/SVG | 다양한 시각 문법, 브랜드·접근성·출력 크기 통제 | 생성 결과의 semantic source와 검증 기록을 팀이 별도로 남겨야 한다 |
| Archify | typed JSON IR + compiler | 결정론적 렌더링과 구조 검증, snapshot 비교에 유리하다 | 정해진 schema와 renderer 범위를 받아들여야 한다 |
| 손으로 관리한 SVG/Figma | 시각 객체 | 디자이너의 세밀한 제어 | 코드·운영 상태와의 동기화 자동화가 약하다 |

이미 README에 단순 sequence가 있고 개발자가 직접 고친다면 Mermaid가 여전히 좋은 기본값이다. 시스템 현황을 워크숍에서 계속 이동시키고 주석을 붙인다면 draw.io가 편하다. 여러 채널의 브랜드 문서와 슬라이드를 반복 생성하면서 접근성과 밀도를 통일하려면 Diagram Design이 강하다. PR마다 아키텍처 snapshot을 비교하고 machine-readable 검증이 중요하다면 Archify식 typed IR가 더 잘 맞는다.

따라서 Diagram Design 도입을 “Mermaid 교체”로 시작할 이유는 없다. 기존 Mermaid나 draw.io를 입력으로 가져오되, fidelity ledger와 원본 링크를 보존하는 보조 경로로 붙이는 편이 안전하다. [MarkItDown 문서 인입 거버넌스](/posts/github-trending-markitdown-document-ingestion-governance/)에서 변환 결과와 원문을 함께 보관해야 했듯, 다이어그램 재표현에서도 원본과 변환물을 분리해 추적해야 한다.

## 2주 PoC는 그림 수가 아니라 발견한 오류를 측정한다

다이어그램 생성 시간만 측정하면 결론은 거의 항상 자동화 도구에 유리하다. 그러나 팀의 목표는 SVG 생산량이 아니라 잘못된 아키텍처 판단을 줄이는 것이다. 서비스 하나와 실제 변경 PR 세 개를 골라 Mermaid 기준선, Diagram Design, 필요하면 Archify를 비교하는 편이 낫다.

- **사실성**: 근거 없는 노드·edge 수, 빠진 외부 의존성과 trust boundary 수, reviewer가 수정한 기술 오류 비율
- **추적성**: 각 요소가 코드·IaC·ADR·운영 문서 중 하나로 연결되는 비율, 추론 표시의 정확도
- **리뷰 효율**: 초안 시간뿐 아니라 승인까지 걸린 시간, 질문 왕복 횟수, 의미 변경과 스타일 변경을 분리할 수 있는 정도
- **가독성**: 10초 내 주 경로 식별률, 축소 화면의 최소 글자 크기, 색 대비와 screen reader 설명 품질
- **재현성**: 같은 입력·버전으로 생성한 구조와 렌더링의 차이, 브라우저·font 환경별 screenshot diff
- **보안**: 외부 네트워크 요청, executable markup, 민감 정보 노출, import parser의 malformed input 처리
- **유지 비용**: 시스템 변경 후 stale diagram을 감지하고 수정하는 시간, plugin·browser update가 만든 회귀

합격선도 생성 전에 쓴다. 예를 들어 “근거 없는 edge 0개, 모든 외부 데이터 흐름에 trust boundary 표시, 접근성 lint 통과, 외부 요청 0개, 변경 PR merge 전 다이어그램 diff 승인”처럼 정의할 수 있다. 이 숫자는 프로젝트의 보장값이 아니라 팀이 정할 예시다. 실패하면 더 강한 schema를 도입하거나 Mermaid로 돌아가고, 시각 스타일만 Diagram Design reference에서 차용하면 된다.

이때 [AI가 최신 Go 코드를 쓰게 하는 법](/posts/modern-go-guidelines-ai-code-modernization/)에서 사용한 원칙도 유효하다. 에이전트에게 최신 규칙을 주는 것과 결과가 실제 코드베이스에 맞는지는 별개다. 버전이 빠르게 움직이는 skill은 commit SHA로 고정하고, 업그레이드는 샘플 corpus에 lint·render·semantic review를 돌린 뒤 진행해야 한다.

## 채택 기준은 ‘그림 자동화’가 아니라 ‘검증 가능한 축약’이다

Diagram Design은 다이어그램을 덜 지루하게 만드는 스타일 팩만은 아니다. 의미 패턴과 시각 유형을 분리하고, 밀도·강조·접근성·import fidelity·motion 안전성을 규약으로 만든 점이 실무적이다. 특히 문서마다 색과 노드 모양이 달라지고, AI가 generic rounded box를 반복하며, 슬라이드와 웹용 산출물을 매번 다시 만드는 조직에는 생산성과 품질의 공통 기준을 제공할 수 있다.

다만 아키텍처의 진실을 자동으로 수집하는 시스템은 아니다. 코드, IaC, runtime trace, ownership catalog를 무엇까지 읽었는지 명시하지 않으면 결과는 정교한 추측에 머문다. 저장소가 버전 릴리스 없이 최신 `main`만 보안 지원하는 현재 운영 방식도 조직 배포에서는 commit pinning과 자체 회귀 검사를 요구한다.

도입 여부를 가르는 질문은 간단하다. **에이전트가 무엇을 합치고 버렸는지 남기고, 모든 중요한 연결을 1차 근거로 되짚으며, 실행 가능한 HTML과 공개 정보의 경계를 자동 검사할 수 있는가.** 그렇다면 Diagram Design은 문서 병목을 줄이는 유용한 생성 계층이 된다. 그 과정을 생략한다면 더 빠르게 만든 예쁜 그림이 더 빠르게 낡은 오해가 될 뿐이다.

> 1차 자료: [Diagram Design 저장소와 README](https://github.com/cathrynlavery/diagram-design), [Diagram Design SKILL.md](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/SKILL.md), [보안 정책](https://github.com/cathrynlavery/diagram-design/blob/main/SECURITY.md), [기여·검증 게이트](https://github.com/cathrynlavery/diagram-design/blob/main/CONTRIBUTING.md), [Archify 저장소](https://github.com/tt-a1i/archify). Trending와 저장소 수치는 2026년 9월 11일 08시 15분 KST 전후 공개 페이지·GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
