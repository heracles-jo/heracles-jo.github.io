---
title: "PostHog 통합 제품 관측성: 분석·리플레이·LLM 추적을 한곳에 둘 때의 대가"
description: "PostHog의 제품 분석·세션 리플레이·기능 플래그·LLM 관측성을 하나의 문맥으로 결합할 때 얻는 진단 속도와 데이터 경계·비용·셀프호스팅 리스크를 검토한다."
author: heracles-jo
date: 2026-07-18 07:30:00 +0900
categories: [Observability, Platform Engineering]
tags: [posthog, product-analytics, session-replay, feature-flags, llm-observability, data-governance]
image:
  path: https://heracles-jo.github.io/assets/img/posts/posthog-unified-product-observability/cover.svg
  alt: "제품 이벤트와 세션 리플레이, 기능 플래그, 오류, LLM trace를 PostHog 문맥으로 연결하는 구조"
---

장애가 발생했을 때 개발팀은 로그를 보고, 제품팀은 퍼널을 보고, 고객지원은 세션 리플레이를 찾는다. AI 기능이 포함되면 여기에 prompt, generation, model, token cost와 evaluation 결과가 추가된다. 도구가 각각 잘 작동해도 동일한 사용자의 한 번의 실패를 연결하려면 시간대와 ID를 맞추고 여러 화면을 오가야 한다. 통합 제품 관측성 플랫폼은 이 조사 비용을 줄이지만, 동시에 가장 민감한 사용자 문맥을 한곳에 모은다.

[PostHog](https://github.com/PostHog/posthog)는 제품 분석에서 시작해 웹 분석, 세션 리플레이, 기능 플래그, 실험, 오류 추적, 로그, 설문, 데이터 웨어하우스, 파이프라인, AI observability와 자동화 workflow까지 넓어진 플랫폼이다. 공식 README는 최근 방향을 “self-driving products”라고 설명한다. 제품 데이터에서 오류·rage click·실패한 질의를 신호로 찾고, 에이전트가 원인을 조사해 검토 가능한 보고서와 pull request까지 제안하는 흐름이다.

이 글은 7월 18일 예약 작업 timeout으로 발행하지 못한 내용을 보충한다. 아래 수치는 당시 정확한 Trending 순위를 복원한 것이 아니라 **2026년 7월 19일 02시 KST에 다시 확인한 공개 스냅샷**이다. PostHog 저장소는 약 36.5k stars, 3.0k forks와 4.9k개의 열린 이슈·PR을 표시했고, 같은 날에도 LLM gateway, 실험 UI, signal ranking 관련 변경이 반영되고 있었다. 저장소 바깥 기능과 `ee/` 디렉터리는 별도 조건이 있을 수 있으므로 “GitHub에 보인다”와 “전체가 동일한 오픈소스 라이선스다”를 혼동하면 안 된다.

## 별도 도구 다섯 개보다 문맥 하나가 강한 순간

PostHog의 장점은 체크박스의 수보다 공통 식별자에 있다. 하나의 사용자 또는 세션에 이벤트, flag variant, replay, exception, survey, LLM trace를 연결할 수 있다면 “전환율이 떨어졌다”에서 “새 모델을 받은 모바일 사용자가 응답 지연 후 결제를 포기했다”까지 조사 범위를 빠르게 줄일 수 있다.

| 분리된 관측 도구 | 흔한 단절 | 통합했을 때 얻는 질문 |
|---|---|---|
| 제품 분석 | 퍼널 이탈 이유를 화면에서 재현하기 어려움 | 이탈 세션의 replay와 오류를 바로 볼 수 있는가 |
| 기능 플래그 | 배포 버전과 사용자 노출 variant가 분리됨 | 특정 variant가 오류·비용·전환에 미친 영향은 무엇인가 |
| APM·오류 추적 | 기술 오류가 사업 지표에 미친 영향이 늦게 연결됨 | 예외를 겪은 cohort의 retention이 달라졌는가 |
| LLM trace | prompt 품질과 실제 사용자 행동이 따로 측정됨 | 느리거나 비싼 generation이 완료 행동을 줄였는가 |
| 설문·지원 | 정성 피드백이 이벤트 데이터와 떨어져 있음 | 불만을 남긴 사용자의 직전 행동과 flag는 무엇인가 |

최근 Trending 후보 가운데 Apache Ossie는 BI와 AI 사이의 **정의 이동** 문제를 다루고, PostHog는 제품 실행 중 발생하는 **행동 문맥 결합** 문제를 다룬다. 전자는 [시맨틱 계층 표준화](/posts/apache-ossie-semantic-model-interchange/)의 주제로 분리했고, 이 글은 관측 데이터를 한 제품에 모을 때 운영 경계가 어떻게 바뀌는지에 집중한다.

## 데이터 흐름을 먼저 그리지 않으면 도구 목록만 늘어난다

브라우저와 모바일 SDK는 클릭·페이지뷰·식별 이벤트를 보내고, backend는 비즈니스 이벤트와 예외를 보낸다. replay SDK는 DOM 변화와 입력 마스킹 상태를 기록하며, feature flag SDK는 사용자별 variant를 결정하거나 캐시한다. LLM wrapper는 trace와 span, prompt, generation, latency, token과 cost를 전송한다. 이 흐름을 같은 person·session·request·trace ID로 연결할 때 통합의 가치가 생긴다.

![PostHog 중심 통합 제품 관측성 데이터 흐름](https://heracles-jo.github.io/assets/img/posts/posthog-unified-product-observability/data-flow.svg)

그러나 모든 데이터를 하나의 person profile에 붙이면 편리함이 곧 위험이 된다. replay에 입력값이 남고 LLM prompt에 고객 문서가 포함되며, 오류 stack에 내부 경로가 기록되고, warehouse join으로 결제 정보까지 연결될 수 있다. 수집 SDK마다 masking과 allowlist가 달라 한 제품의 “개인정보 수집 끄기” 설정만 믿어서는 안 된다.

도입 전에 데이터 분류표를 이벤트 단위로 만들어야 한다.

- 어떤 속성이 직접 식별자, 간접 식별자, 민감정보인지
- replay에서 기본 마스킹할 DOM과 절대 수집하지 않을 입력이 무엇인지
- prompt와 generation을 원문으로 저장할지, hash·길이·평가 결과만 보낼지
- 사용자 삭제 요청이 event, replay, trace, export와 backup까지 전파되는지
- EU·US 프로젝트 분리가 실제 residency 요구를 충족하는지
- support, product, engineering, AI 팀의 조회 범위를 어떻게 나눌지

[시스템 프롬프트 유출 글](/posts/github-trending-system-prompts-leaks-ai-governance/)에서 로그와 대화 내보내기를 별도 노출 경로로 본 이유도 같다. 관측성 데이터는 디버깅을 위한 사본이 아니라 원본보다 더 많은 문맥이 결합된 고위험 데이터셋이 될 수 있다.

## “오픈소스니까 셀프호스팅”이라는 계산이 틀리는 지점

PostHog README는 Cloud를 가장 빠르고 신뢰할 수 있는 시작점으로 권장한다. 오픈소스 hobby deploy는 Linux와 Docker로 시작할 수 있지만 약 월 100k events 규모를 안내하고, 그 이상은 Cloud migration을 권한다. 오픈소스 배포에는 고객 지원이나 보장을 제공하지 않는다는 문구도 명확하다.

이는 설치가 불가능하다는 뜻이 아니라 운영 모델을 구분하라는 신호다. 제품 분석만 해도 event ingestion, ClickHouse 계열 분석 저장, PostgreSQL metadata, cache·queue, object storage와 background job이 얽힌다. replay와 logs, trace를 함께 보관하면 ingest throughput보다 retention과 object storage, query concurrency, compaction, backup·restore가 비용을 결정한다.

셀프호스팅 판단에서 다음 비용을 빠뜨리기 쉽다.

1. SDK 잘못 배포로 event volume이 폭증했을 때의 rate limit과 비용 차단
2. schema-less 속성이 늘면서 query 성능과 governance가 무너지는 비용
3. replay·trace 보존 기간에 따른 object storage와 삭제 작업
4. 버전 업그레이드 중 migration, ClickHouse compatibility, rollback 검증
5. 제품팀이 직접 운영 DB를 조회하지 않도록 권한과 export 경계를 만드는 비용
6. 플래그 평가 장애가 사용자 요청 경로에 영향을 주지 않게 하는 local evaluation과 fallback

[Home Assistant의 local-first 운영](/posts/github-trending-home-assistant-local-first-automation/)처럼 데이터 통제권이 중요한 경우 셀프호스팅은 매력적이다. 하지만 local-first가 자동으로 단순하거나 저렴하다는 뜻은 아니다. 제품 관측성은 서비스가 정상일 때보다 트래픽 폭증과 장애 중에 더 필요하므로, 관측 플랫폼 자체의 장애 복구가 본 서비스와 같은 수준으로 설계돼야 한다.

## 기능 플래그와 AI 평가를 같은 루프에 넣을 때

PostHog가 단순 analytics보다 흥미로운 지점은 feature flag와 experiment, LLM observability가 같은 제품 문맥에 있다는 것이다. 모델 A와 B를 flag로 나누고 latency·cost·evaluation score뿐 아니라 실제 activation과 retention까지 비교할 수 있다. 모델 평가가 offline benchmark에서 끝나지 않고 제품 결과로 연결된다.

하지만 이 폐루프는 잘못 설계하면 빠른 오판 장치가 된다. LLM judge가 선호한 응답이 사용자의 장기 행동과 일치하지 않을 수 있고, prompt 변경과 UI 변경이 동시에 flag에 묶이면 원인을 분리하기 어렵다. 비용이 낮은 모델을 더 많이 노출해 표본 수가 커지면 단순 평균 비교도 왜곡된다.

실험 단위는 다음처럼 분리하는 편이 좋다.

- 모델·prompt·retrieval 설정을 versioned configuration으로 고정한다.
- 사용자 경험을 바꾸는 UI flag와 모델 routing flag를 별도로 둔다.
- trace에는 configuration ID와 release SHA를 기록한다.
- quality, latency, cost, task completion, retention을 서로 다른 guardrail로 본다.
- 자동 rollback은 명확한 오류율·지연 임계치에만 적용하고 주관 평가에는 사람 승인을 둔다.

[LMCache 분석](/posts/github-trending-lmcache-kv-cache-llm-serving/)에서 cache hit ratio 하나로 LLM serving을 판단할 수 없다고 본 것처럼, AI 제품도 token cost나 judge score 하나로 최적화하면 안 된다. 관측성을 결합하는 목적은 하나의 만능 점수를 만드는 것이 아니라 서로 충돌하는 품질·비용·행동 지표를 같은 변경과 연결하는 것이다.

## 도입 경로는 기능 수가 아니라 조사 시간을 기준으로 고른다

PostHog, 여러 전문 SaaS, 자체 오픈소스 스택 중 무엇이 맞는지는 “기능이 더 많은가”보다 현재 장애 조사에서 문맥 연결에 쓰는 시간을 측정하면 선명해진다.

| 선택지 | 적합한 조직 | 주요 장점 | 막히기 쉬운 지점 |
|---|---|---|---|
| PostHog Cloud | 빠른 통합과 관리형 운영이 필요한 제품팀 | 분석·replay·flag·실험·AI trace의 연결 | 데이터 집중, 사용량 비용, 제품 종속성 |
| PostHog hobby self-host | 제한된 규모의 내부 PoC와 데이터 통제 실험 | 코드·데이터 경로를 직접 확인 | 지원·보장 없음, 확장과 업그레이드 부담 |
| 전문 도구 조합 | APM·analytics·flag별 깊은 기능이 중요한 대규모 팀 | 영역별 최적 도구와 독립된 장애 경계 | identity mapping과 조사 UX를 직접 통합 |
| warehouse 중심 자체 분석 | 데이터 플랫폼 역량과 규제 요구가 강한 조직 | 장기 보존·모델링·감사 통제 | 실시간성, replay, 운영 UI 구축 비용 |

![제품 관측성 플랫폼 선택 기준](https://heracles-jo.github.io/assets/img/posts/posthog-unified-product-observability/decision.svg)

2주 PoC에서는 전사 이벤트를 옮기지 말고 실제로 자주 조사하는 한 흐름을 고른다. 예를 들어 회원가입에서 첫 AI 결과 생성까지의 funnel에 feature flag, backend exception, LLM trace와 replay를 연결한다. 과거 장애 3건을 재현해 원인 파악 시간, 필요한 화면 수, 누락된 식별자, 민감정보 노출, 사용자 삭제 처리 시간과 일일 event·replay·trace 용량을 측정한다.

성공 기준은 대시보드 개수가 아니다.

- 동일 장애의 median time-to-context가 줄었는가
- person·session·trace 연결 실패율이 허용 범위인가
- replay와 prompt에서 금지 데이터가 실제로 차단되는가
- flag 장애 시 기본 동작과 rollback이 검증됐는가
- 한 달 보존 비용을 제품·팀·환경별로 설명할 수 있는가
- export 후에도 분석 정의와 삭제 정책을 재현할 수 있는가

## 통합은 목적이 아니라 운영 선택이다

PostHog의 넓은 기능 범위는 제품팀과 개발팀이 동일한 사용자 사건을 보는 시간을 줄일 수 있다. 특히 AI 기능의 prompt·generation·cost를 제품 행동과 연결하고, feature flag로 안전하게 비교하려는 팀에는 강력한 출발점이다. 반면 데이터 종류가 많아질수록 개인정보, 권한, 보존, 비용과 플랫폼 장애의 영향 범위도 함께 커진다.

따라서 “도구를 하나로 줄인다”는 이유만으로 도입하면 안 된다. 전문 도구가 다섯 개여도 공통 ID와 조사 runbook이 잘 설계돼 있으면 운영 가능하다. 반대로 통합 플랫폼 하나를 설치해도 event taxonomy와 masking, flag ownership, trace sampling이 없으면 더 큰 데이터 늪이 된다.

PostHog를 평가할 때 가장 좋은 질문은 기능 목록이 아니라 이것이다. **우리가 자주 겪는 제품 문제 하나를 더 빨리 설명하면서도, 그 설명에 필요 없는 사용자 데이터는 덜 모을 수 있는가.** 두 조건을 함께 만족할 때 통합 제품 관측성은 대시보드 통합을 넘어 실제 개발 속도와 신뢰성을 높인다.
