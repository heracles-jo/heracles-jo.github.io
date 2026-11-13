---
title: "AI 설계 문서 리뷰: Elephant-Goldfish Model 격리 기준"
description: "Elephant-Goldfish Model의 깊은 설계 문맥과 독립 리뷰어 분리를 분석하고, AI 설계 검토의 편향·문서 드리프트·운영 비용을 통제하는 기준을 제시한다."
author: heracles-jo
date: 2026-11-14 08:05:00 +0900
categories: [AI, Developer Tools]
tags: [elephant-goldfish-model, ai-design-review, spec-driven-development, coding-agent, context-isolation, design-doc]
image:
  path: https://heracles-jo.github.io/assets/img/posts/elephant-goldfish-ai-design-review/cover.svg
  alt: "깊은 문맥의 설계 에이전트와 독립된 리뷰 에이전트를 분리하는 Elephant-Goldfish Model"
---

AI 코딩 에이전트에게 요구사항 정리부터 설계, 구현, 자체 리뷰까지 한 세션에서 맡기면 흐름은 매끄럽다. 그러나 매끄러움은 검증의 증거가 아니다. 초반에 세운 가정이 대화 문맥에 남고, 뒤의 설계와 리뷰가 그 가정을 사실처럼 재사용한다. 에이전트는 자신이 선택한 구조를 설명하는 데는 능숙하지만, 왜 그 구조가 틀릴 수 있는지를 같은 문맥에서 독립적으로 판단하기 어렵다.

[google/elephant-goldfish-model](https://github.com/google/elephant-goldfish-model)(이하 EGM)은 이 문제를 **설계 문맥을 오래 보존하는 Elephant**와 **앞선 대화를 보지 않는 Goldfish 리뷰어**로 분리한다. 설계 초안, 검토 결과, 승인된 사양을 채팅의 부산물이 아니라 저장소 안의 문서로 남기고, 구현 후에는 코드와 설계 문서의 드리프트도 찾는다. 핵심 질문은 “리뷰 에이전트를 몇 개 띄울 것인가”가 아니다. **초안을 만든 모델의 확신과 리뷰 판단을 실제로 분리하면서, 사람이 감당할 수 있는 비용으로 설계 품질을 높일 수 있는가**다.

2026년 11월 14일 08시 12분 KST 전후 GitHub Trending weekly에서 EGM은 `5,555 stars this week`로 표시됐다. GitHub API 확인 시점에는 18,593 stars, 1,386 forks, 열린 issue와 pull request를 합친 103개, Apache-2.0 라이선스였고, 최신 릴리스는 11월 6일의 v0.1.1이었다. 11월 14일 KST에도 Windsurf 어댑터와 리뷰 증거 모델 관련 변경이 이어졌다. 이 수치는 공개 페이지의 시점별 스냅샷이며 프로젝트 품질이나 팀 적합성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics 데이터에 접근하지 못했으므로 검색 성과를 주제 선정 근거로 사용하지 않았다.

## 후보 비교: 또 하나의 코딩 스킬보다 독립 검토 문제가 남았다

오늘 daily·weekly 후보에는 에이전트 스킬, 협업 화면, 브라우저 자동화와 셀프호스팅 제품이 함께 있었다. 기존 글의 저장소 이름뿐 아니라 독자가 해결하려는 중심 문제를 대조했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model) | weekly 5,555, API 18,593 stars, Apache-2.0, v0.1.1 | 스킬 설치법보다 **설계자와 리뷰어의 문맥을 분리해 자기확증을 줄이는 방법**이라는 독립 의도가 있어 선택했다. |
| [Plannotator](https://github.com/backnotprop/plannotator) | daily 100, API 10,427 stars, Apache-2.0/MIT, v0.28.64 | 사람의 비동기 주석·승인 UX는 유효하지만 AI 코드 리뷰와 에이전트 워크플로 글에 더 가깝다. |
| [Buzz](https://github.com/block/buzz) | daily 95, API 37,287 stars, Apache-2.0 | 분산 커뮤니케이션·Nostr 운영은 별도 가치가 있으나 제품 범위와 열린 이슈가 넓어 한 글의 판정 질문을 좁히기 어렵다. |
| [Sure](https://github.com/we-promise/sure) | daily 944, API 14,705 stars, AGPL-3.0, v0.7.6-hotfix.1 | 개인 금융 셀프호스팅은 장기 검색 가치가 있지만 금융 데이터 보안·정합성을 검증할 자료 범위가 더 크다. |
| [Open Code Review](https://github.com/alibaba/open-code-review) | daily 206, API 50,565 stars | 결정론적 검사와 LLM 코드 리뷰 결합은 이미 별도 글에서 다뤄 검색 의도가 직접 겹친다. |

기존 [Agent Skills 엔지니어링 워크플로](/posts/github-trending-agent-skills-engineering-workflow/)는 지침을 재사용 가능한 실행 계약으로 만드는 방법을 다뤘다. [Open Code Review 글](/posts/open-code-review-hybrid-ai-code-review/)은 정적 규칙과 LLM 결함 탐지를 결합했다. EGM의 차이는 코드가 나온 뒤 결함을 찾는 데 있지 않다. 구현 전에 설계 문서를 독립된 독자가 이해하고 반박할 수 있는 상태로 만드는 데 있다.

## Elephant와 Goldfish의 분리는 역할 이름보다 데이터 흐름이 중요하다

Elephant는 프로젝트 역사, 요구사항, 기존 코드와 앞선 결정을 읽고 아이디어를 구체화한다. `/egm-brainstorm`은 여러 관점으로 초기 가정을 공격한 뒤 `concepts_brief.md`를 만들고, `/egm-draft`는 이를 `docs/designs/` 아래의 설계 문서로 발전시킨다. 깊은 문맥이 필요한 작업이다. 기존 모듈을 재사용할지, 어떤 실패를 제품이 감수할지, 데이터 경계를 어디에 둘지는 한두 문장의 프롬프트로 결정하기 어렵다.

Goldfish는 반대로 앞선 대화에서 거리를 둔다. 문서와 그 문서가 참조한 소스, 버전이 고정된 검토 기준을 읽고 이해 가능성, 단순성, 시스템 위험, 구현 준비도를 나눠 본다. 공개 아키텍처 문서는 zoom-out, comprehension, critic, 중간 zoom-out, implementation readiness의 다섯 단계를 설명한다. 여러 리뷰 결과는 synthesizer가 중복을 줄여 하나의 보고서로 모은다.

![EGM에서 깊은 설계 문맥과 독립 리뷰 문맥을 분리하는 아키텍처](https://heracles-jo.github.io/assets/img/posts/elephant-goldfish-ai-design-review/architecture.svg)

여기서 중요한 것은 “다른 프롬프트를 썼다”가 아니라 **이전 대화가 리뷰 판단에 들어가지 않도록 별도 실행 문맥을 만들었는가**다. 같은 세션에서 역할 문구만 “이제 냉정한 리뷰어가 되어라”로 바꾸면 모델은 초안을 만들 때의 설명과 사용자의 반응을 계속 본다. 반론처럼 보이는 문장을 만들 수는 있어도 독립 검토라고 부르기는 어렵다.

그렇다고 fresh context가 완전한 무지 상태를 뜻하지는 않는다. EGM의 harness 문서는 Codex와 Antigravity의 하위 에이전트에 프로젝트 `AGENTS.md`나 `GEMINI.md`가 주입된 사례를 공개한다. 부모 대화가 격리됐다는 증거와 호스트가 추가한 지침 파일까지 제외됐다는 증거는 다르다. 팀 규칙이 리뷰어에게 보이는 것은 유용할 수도 있지만, 초안의 결론을 강제하는 지침이 섞이면 독립성은 약해진다.

## 설계 리뷰의 단위는 모델 답변이 아니라 검증 가능한 문서다

EGM은 긴 설계안을 채팅에 쏟아내는 대신 파일과 artifact로 남기는 방식을 택한다. 이 선택은 단순한 UI 취향이 아니다. 설계가 문서가 되면 다음 질문에 답할 수 있다.

- 어떤 요구사항과 비기능 조건이 승인됐는가
- 어떤 대안을 검토했고 왜 제외했는가
- 구현이 수정할 파일·인터페이스·데이터 경계는 어디인가
- 테스트가 어떤 실패 모드를 재현해야 하는가
- 나중에 코드가 바뀌었을 때 어떤 설계 판단이 낡았는가

[AI 코딩 에이전트 컨텍스트 최적화 글](/posts/context-mode-agent-context-optimization/)에서 도구 출력을 압축할 때 정보 손실과 복구 가능성을 따로 봤듯, 설계 문서도 요약 길이보다 **판정 근거를 다시 찾을 수 있는가**가 중요하다. 대화 요약이 “Redis를 사용하기로 했다”고만 남기면 장애 복구, 데이터 유실 허용치, 비용 가정은 사라질 수 있다. 승인 문서는 결정뿐 아니라 조건과 중단 기준을 함께 보존해야 한다.

`/egm-drift-report`는 이 문서와 현재 코드를 비교한다. 다만 자동 드리프트 검출이 의미적 정합성을 보증하지는 않는다. 파일 경로와 함수가 일치해도 운영 규모, 데이터 보존 정책, 외부 API 계약이 달라질 수 있다. 반대로 리팩터링으로 이름만 바뀌었는데 설계 의도는 그대로일 수도 있다. 따라서 드리프트 보고서는 문서 또는 코드를 갱신할 후보를 찾는 장치이며, 어느 쪽이 정답인지 결정하는 판정기는 아니다.

## 다중 리뷰는 독립 표본이 아니라 상관된 모델 호출일 수 있다

여러 Goldfish가 같은 결함을 지적하면 신뢰가 높아 보인다. 하지만 동일 모델, 동일 문서, 비슷한 rubric을 사용한 리뷰는 통계적으로 독립된 표본이 아니다. 공통 사전학습 편향과 같은 누락을 공유할 수 있다. 리뷰어 수를 늘렸는데 모두 비슷한 표현의 사소한 지적만 반복하면 사람의 triage 비용만 커진다.

리뷰 관점을 나누는 이유는 투표 수를 늘리기 위해서가 아니라 탐지 표면을 분리하기 위해서다. comprehension reviewer는 문서가 독립 독자에게 충분한지 보고, design critic은 병목과 실패 모드를 찾으며, implementation readiness는 실제 경로·인터페이스·테스트 사례를 확인해야 한다. 각 결과에는 최소한 다음 증거가 필요하다.

1. 어떤 문장·코드·요구사항을 근거로 했는가
2. 무엇이 불명확하거나 충돌하는가
3. 실제 실패가 발생하는 조건은 무엇인가
4. 문서 수정, 추가 실험, 보류 중 어떤 조치가 필요한가
5. 확신 수준과 아직 읽지 못한 자료는 무엇인가

공개 이슈에도 finding마다 근거를 표시하자는 요구와 승인된 설계 대비 구현을 검사하자는 요구가 올라와 있다. 이는 모델의 평문 보고서만으로는 “그럴듯한 우려”와 “재현 가능한 결함”을 구분하기 어렵다는 신호다. [AI 코딩 에이전트 과잉 구현 글](/posts/ai-coding-agent-overengineering-ponytail/)의 YAGNI 기준도 여기서 유효하다. 리뷰어가 모든 가능성을 문서에 추가하게 만들면 설계는 안전해지는 대신 구현 불가능할 만큼 비대해진다.

## 보안 경계는 EGM 자체보다 호스트와 입력 범위에서 결정된다

공식 privacy 문서에 따르면 EGM 런타임 자체는 별도 호스팅 서비스, 데이터베이스, 분석 클라이언트나 telemetry endpoint를 운영하지 않는다. 그러나 실제 프로젝트 파일과 설계 문서를 처리하는 주체는 선택한 Claude Code, Codex, ChatGPT 등의 호스트다. “EGM이 로컬 문서 워크플로다”와 “모든 데이터가 로컬을 떠나지 않는다”는 같은 말이 아니다.

비공개 저장소에서 PoC를 할 때는 다음 경계를 확인해야 한다.

- 리뷰에 필요 없는 고객 데이터·자격증명·운영 로그를 입력에서 제외했는가
- 하위 에이전트가 읽을 수 있는 디렉터리와 도구가 최소 범위인가
- 호스트의 transcript, artifact, backup과 모델 제공자 보존 정책은 무엇인가
- 리뷰 보고서가 입력의 비밀을 그대로 반복해 저장소에 커밋하지 않는가
- formatter나 프로젝트 명령이 패키지 레지스트리·외부 서비스에 접속하는가
- prompt injection이 포함된 문서나 코드 주석을 신뢰된 지침으로 처리하지 않는가

EGM 문서는 리뷰에 fresh-context subagent가 없으면 같은 문맥에서 흉내 내지 않고 중단하도록 설계했다. 이 fail-closed 선택은 타당하다. 반면 단계 1~4가 소스 코드를 수정하지 않아야 한다는 규칙은 관례이며 강제되지 않는다고 아키텍처 문서가 명시한다. 실무에서는 리뷰어를 읽기 전용 sandbox에 두고, 설계 artifact 디렉터리 외 쓰기와 shell·네트워크 권한을 별도로 차단해야 한다.

![AI 설계 문서 리뷰를 팀 게이트로 승격할 때 확인할 위험과 결정 기준](https://heracles-jo.github.io/assets/img/posts/elephant-goldfish-ai-design-review/decision.svg)

## 모든 변경에 설계 의식을 붙이면 오히려 흐름이 망가진다

EGM의 getting started 문서도 작은 버그를 억지로 design-first 절차에 넣지 말라고 설명한다. 맞는 경계다. 오탈자, 명확한 null 처리, 좁은 의존성 업데이트까지 다단계 설계·15개 안팎의 리뷰 호출에 태우면 검토 피로와 모델 비용이 결함 감소보다 커질 수 있다.

팀에서는 변경 위험으로 라우팅하는 편이 낫다.

| 변경 유형 | 권장 검토 수준 | 이유 |
|---|---|---|
| 국소 버그·기계적 수정 | 기존 테스트와 일반 코드 리뷰 | 설계 문서 비용이 변경 위험보다 클 가능성이 높다. |
| 여러 모듈을 건드리는 기능 | brief + 설계 초안 + 핵심 2~3개 관점 | 경계·실패 모드·롤백을 구현 전에 합의할 가치가 있다. |
| 데이터 모델·권한·외부 API 변경 | 전체 독립 리뷰 + 사람 승인 | 잘못된 가정의 복구 비용과 보안 영향이 크다. |
| 마이그레이션·플랫폼 전환 | 설계 PR과 구현 PR 분리 + 드리프트 추적 | 승인된 전환 조건과 실제 구현을 장기간 비교해야 한다. |

리뷰 호출 수보다 중요한 운영 지표는 finding yield다. 단계별 유효 결함 수, 중복률, 사람이 기각한 비율, 설계 수정에 걸린 시간, 구현 중 설계 밖 변경 비율, 배포 후 발견된 누락을 측정해야 한다. 리뷰가 길어졌는데 구현 중 재설계가 줄지 않는다면 문서 기준이나 reviewer lens가 잘못된 것이다.

## 2주 PoC는 “좋은 문서”가 아니라 재작업 감소를 측정해야 한다

PoC에는 과거에 설계 누락으로 재작업이 컸던 변경 6~10개를 고른다. 인증 흐름, webhook 재시도, 스키마 마이그레이션, 캐시 일관성처럼 실패 조건을 이미 알고 있는 사례가 좋다. 절반은 기존 워크플로로, 절반은 고정한 EGM 버전과 동일한 호스트·모델 조건으로 다시 설계한다. 과거 정답을 맞히는 시험이 아니라 누락을 얼마나 일찍, 근거와 함께 드러내는지 본다.

| 측정 항목 | 통과 질문 |
|---|---|
| 가정 발견률 | 구현 전에 숨은 데이터·권한·복구 가정을 찾아냈는가 |
| finding 정밀도 | 사람이 수용한 지적이 전체의 의미 있는 비율을 차지하는가 |
| 중복·소음 | 여러 리뷰어가 같은 일반론을 반복하지 않는가 |
| 구현 준비도 | 파일·인터페이스·테스트 경계가 실제 저장소와 맞는가 |
| 재작업 감소 | 구현 중 구조 변경과 PR 왕복 시간이 줄었는가 |
| 격리 증거 | 부모 대화와 호스트 지침의 노출 범위를 각각 확인했는가 |
| 비용·지연 | 모델 사용량과 대기 시간이 변경 위험에 비례하는가 |
| 드리프트 대응 | 문서와 코드 불일치를 사람이 판정 가능한 형태로 찾는가 |

성공선은 리뷰 보고서 분량이나 “모든 단계 통과”가 아니다. 높은 위험의 설계에서 구현 전 발견한 결함이 늘고, 사람의 triage와 전체 리드타임을 포함해 재작업 비용이 줄어야 한다. 독립 리뷰가 사소한 표현 교정만 늘리거나, 호스트 제약 때문에 실제 격리를 증명하지 못하거나, 승인 문서가 구현 직후 낡는다면 전체 워크플로를 표준으로 만들 이유가 없다.

EGM이 제시하는 가장 가치 있는 아이디어는 특정 플러그인 명령이 아니라 **설계에 필요한 기억과 검증에 필요한 거리 두기를 같은 컨텍스트에 억지로 넣지 않는 것**이다. Elephant는 충분히 기억해야 하고 Goldfish는 의도적으로 잊어야 한다. 사람은 두 결과를 비교해 트레이드오프를 승인해야 한다.

다만 “새 세션”이라는 표시만으로 독립성이 확보되지는 않는다. 어떤 지침과 파일이 리뷰어에게 전달됐는지, 읽기·쓰기 권한이 어떻게 제한됐는지, 지적이 어떤 증거에 기대는지 확인해야 한다. AI 설계 리뷰를 팀 게이트로 승격하려면 에이전트 수보다 이 세 가지가 먼저다. **격리 경계, 증거가 붙은 finding, 위험에 비례한 운영 비용**이 확인될 때 EGM은 채팅 속 역할극을 넘어 실제 설계 품질 관리 도구가 된다.

> 1차 자료: [Elephant-Goldfish Model 저장소와 README](https://github.com/google/elephant-goldfish-model), [아키텍처와 생명주기](https://github.com/google/elephant-goldfish-model/blob/main/docs/designs/architecture.md), [Getting Started](https://github.com/google/elephant-goldfish-model/blob/main/docs/getting_started.md), [호스트별 설치·격리 한계](https://github.com/google/elephant-goldfish-model/blob/main/docs/harnesses.md), [테스트와 실행 증거](https://github.com/google/elephant-goldfish-model/blob/main/TESTING.md), [데이터 처리 경계](https://github.com/google/elephant-goldfish-model/blob/main/docs/privacy.md), [AI 기여 정책](https://github.com/google/elephant-goldfish-model/blob/main/AI_POLICY.md), [LICENSE](https://github.com/google/elephant-goldfish-model/blob/main/LICENSE), [v0.1.1 릴리스](https://github.com/google/elephant-goldfish-model/releases/tag/v0.1.1), [최근 commits](https://github.com/google/elephant-goldfish-model/commits/main/), [공개 issues](https://github.com/google/elephant-goldfish-model/issues), [공개 pull requests](https://github.com/google/elephant-goldfish-model/pulls). Trending·GitHub 수치는 2026년 11월 14일 08시 12분 KST 전후 공개 스냅샷이며 이후 달라질 수 있다.
