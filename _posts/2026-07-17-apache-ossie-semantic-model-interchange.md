---
title: "시맨틱 계층 표준화: Apache Ossie로 BI와 AI 지표 불일치 줄이기"
description: "Apache Ossie의 벤더 중립 시맨틱 모델 규격을 바탕으로 BI·데이터·AI 에이전트 사이의 KPI 불일치를 줄이는 도입 순서와 왕복 변환 검증 기준을 정리한다."
author: heracles-jo
date: 2026-07-17 07:35:00 +0900
categories: [Data Engineering, AI Infrastructure]
tags: [apache-ossie, semantic-layer, business-intelligence, data-governance, ai-agent, metrics]
image:
  path: https://heracles-jo.github.io/assets/img/posts/apache-ossie-semantic-model-interchange/cover.svg
  alt: "BI 도구와 AI 에이전트가 Apache Ossie 시맨틱 모델을 공통 계약으로 사용하는 구조"
---

매출이라는 단어는 하나지만 실제 조직에는 여러 매출이 존재한다. 재무팀은 환불과 세금을 반영한 확정 매출을 보고, 제품팀은 결제 이벤트를 기준으로 전환율을 계산하며, 영업팀은 계약 금액을 파이프라인에 쌓는다. 각 BI 도구와 데이터 마트가 같은 이름의 지표를 따로 구현하면 대시보드 차이는 회의에서 조정할 수 있다. 그러나 자연어 질문에 즉시 SQL을 만드는 AI 에이전트까지 이 구조에 들어오면 불일치는 더 빨리, 더 넓게 퍼진다.

[Apache Ossie](https://github.com/apache/ossie)는 이 문제를 또 하나의 BI 제품으로 해결하려 하지 않는다. 분석·AI·BI 플랫폼 사이에서 데이터셋, 차원, 측정값, 지표, 관계와 표현식을 교환할 수 있는 벤더 중립 규격을 만들려는 Apache Incubator 프로젝트다. 이전 이름은 Open Semantic Interchange(OSI)였으며, JSON과 YAML 기반 명세, 기계 판독 스키마, 검증 도구, 예제, 여러 제품 형식과의 변환기를 한 저장소에서 개발한다.

이 글은 7월 17일 자동 발행 실패분을 보충한 글이다. 순위와 수치는 당시 순위를 재구성한 값이 아니라 **2026년 7월 19일 02시 KST 공개 저장소를 다시 확인한 스냅샷**이다. 확인 시점에 저장소는 약 1.2k stars, 151 forks, 56개의 열린 이슈·PR을 표시했고 Apache-2.0 라이선스를 사용했다. 아직 GitHub 정식 릴리스가 없고, CLI scaffold와 변환기 왕복 정확도 수정이 계속 들어오는 초기 단계라는 사실이 별 수보다 중요하다.

## 이번 후보에서 Ossie를 고른 이유

최근 Trending 후보에는 병렬 코딩 에이전트, 터미널 MCP, 제품 분석 플랫폼처럼 이미 이 블로그가 다룬 검색 의도와 가까운 프로젝트가 많았다. Ossie는 “데이터 카탈로그를 어떻게 만들까”보다 더 좁고 실무적인 질문을 던진다. **서로 다른 분석 도구와 AI가 같은 지표 의미를 어떻게 교환할 것인가**다.

| 후보 | 강한 신호 | 이번 글과의 판단 |
|---|---|---|
| Apache Ossie | Apache-2.0, JSON/YAML 규격, dbt·Snowflake·Salesforce·Polaris 등 변환기 | 시맨틱 모델 교환이라는 독립 검색 의도가 분명하다. |
| PostHog | 분석·리플레이·플래그·LLM 관측성을 한 제품에 결합 | 다음 글에서 제품 관측성의 결합 비용을 별도로 다룬다. |
| DesktopCommanderMCP | 로컬 파일·터미널 제어 | [위험 명령 차단](/posts/ai-agent-destructive-command-guard/)과 권한 경계가 겹친다. |
| Orca | worktree 기반 병렬 에이전트 | [병렬 AI 코딩 에이전트 운영](/posts/orca-parallel-ai-coding-agents/)에서 이미 분석했다. |

Search Console과 Analytics 쿼리에는 접근하지 못했으므로 검색량이나 CTR을 확인했다고 가정하지 않았다. 기존 게시물의 제목·태그·저장소 링크와 공식 자료를 대조해 중복 여부를 판단했다.

## 시맨틱 모델은 SQL 조각 모음이 아니라 계약이다

Ossie의 [core specification](https://github.com/apache/ossie/blob/main/core-spec/spec.md)은 시맨틱 모델을 데이터셋과 필드 목록으로만 보지 않는다. 물리 테이블 위에 차원과 측정값을 정의하고, 데이터셋 관계와 지표 계산식을 연결하며, 도구가 이해할 수 있는 형태로 직렬화한다. 저장소에는 TPC-DS 예제, JSON Schema, Python 모델, validator가 함께 있어 문서와 구현의 간격을 줄이려 한다.

여기서 중요한 것은 “지표 정의를 한 파일에 둔다”가 아니다. 계약에는 최소한 다음 정보가 함께 있어야 한다.

- 어떤 원천과 컬럼을 사용하는지
- 시간대, 통화, 소수점, NULL을 어떻게 처리하는지
- 고객·주문·상품 관계가 어떤 cardinality를 갖는지
- 합산 가능한 측정값과 특정 차원에서만 유효한 비율이 무엇인지
- 필터와 기간 비교가 어떤 표현식 의미를 갖는지
- 소유자, 설명, 태그와 확장 속성을 어느 범위까지 교환하는지

이 계약이 없으면 AI 에이전트는 스키마를 읽고도 “활성 고객”의 휴면 기간이나 “순매출”의 환불 기준을 알 수 없다. 반대로 계약이 있어도 실행 엔진이 같은 의미를 보장하지 않으면 YAML만 표준이고 결과는 여전히 달라진다.

![Apache Ossie를 공통 계약으로 둔 시맨틱 계층](https://heracles-jo.github.io/assets/img/posts/apache-ossie-semantic-model-interchange/architecture.svg)

공통 규격은 중앙 실행 엔진과 다르다. Ossie 파일이 모든 쿼리를 대신 실행하는 것이 아니라 각 도구가 자기 런타임으로 가져가거나 내보내는 경계를 정의한다. 따라서 장점은 특정 벤더를 제거하는 데 있지 않고, 이동과 비교가 가능한 중간 표현을 확보하는 데 있다.

## 가장 어려운 문제는 import가 아니라 round-trip이다

데모에서는 기존 모델을 Ossie YAML로 변환하고 validator를 통과시키면 끝난 것처럼 보인다. 운영에서는 `A 도구 → Ossie → B 도구 → Ossie` 왕복 이후 의미가 보존되는지 확인해야 한다. 도구마다 지원하는 조인, 집계, 누적 지표, 필터 문법, 사용자 정의 확장 범위가 다르기 때문이다.

저장소의 변환기 구조가 흥미로운 이유도 여기에 있다. dbt, GoodData, Snowflake, Salesforce, Polaris, Omni와 OrionBelt 계열 형식을 다루는 코드와 테스트가 함께 있고, 최근 커밋에는 round-trip fidelity와 validation robustness 수정이 포함됐다. 변환기는 단순한 YAML 키 이름 매핑이 아니라 의미 손실을 드러내는 호환성 계층이어야 한다.

| 손실 유형 | 겉으로 보이는 증상 | 필요한 검증 |
|---|---|---|
| 표현식 손실 | 파일은 생성되지만 계산식 일부가 기본값으로 바뀜 | canonical expression과 AST 비교 |
| 관계 손실 | 조인은 되지만 중복 집계로 매출이 부풀어 오름 | cardinality별 golden query 결과 비교 |
| 시간 의미 손실 | 월간 지표가 UTC와 현지 시간에서 달라짐 | DST·월말·회계연도 fixture |
| 확장 속성 손실 | 소유자·정책·설명이 이동 과정에서 사라짐 | 필수 metadata 보존률 측정 |
| 미지원 기능의 침묵 | converter가 성공 코드로 끝나지만 기능이 누락됨 | 경고를 오류로 승격하는 strict mode |

특히 “변환 성공”과 “의미 동등”을 같은 상태로 취급하면 안 된다. 파싱 가능한 파일을 만드는 syntactic success, 규격을 만족하는 schema validity, 원래 질의를 재현하는 semantic equivalence를 별도 게이트로 둬야 한다.

## AI 에이전트에 연결할 때 생기는 새로운 보안 경계

시맨틱 모델은 비밀번호를 담지 않아도 민감하다. 아직 공개되지 않은 가격 정책, 고객 분류 기준, 위험 점수, 매출 인식 규칙, 조직 내부 용어가 들어갈 수 있다. 에이전트가 모델 전체를 프롬프트에 넣는 순간 데이터가 아닌 **사업 규칙**이 외부 모델로 전송될 가능성이 생긴다.

그래서 [시스템 프롬프트 거버넌스](/posts/github-trending-system-prompts-leaks-ai-governance/)에서 다룬 비밀 관리와 별도로, semantic metadata에 대한 접근 통제가 필요하다. 사용자가 원천 행을 읽을 수 없는데 지표 정의와 가능한 차원 목록은 볼 수 있는지, 행 수준 보안이 지표 실행 시점에 다시 적용되는지, 에이전트가 생성한 쿼리에 tenant filter가 강제되는지를 분리해서 설계해야 한다.

또 하나의 위험은 표준이 신뢰를 자동으로 만들어 준다는 착각이다. 잘못 승인된 지표를 표준 형식으로 빠르게 배포하면 오류의 전파 속도만 빨라진다. 스키마 validator는 타입과 필수 필드를 확인할 수 있지만 “순매출 정의가 회사 정책과 맞는가”는 판단하지 못한다. 코드 리뷰와 마찬가지로 지표 변경에는 domain owner 승인, 영향 분석, 이전·신규 결과 diff, rollback 가능한 버전이 필요하다.

## 기존 도구를 대체하지 않고 얇게 도입하는 순서

처음부터 모든 BI 모델을 내보내 중앙 저장소로 옮기면 converter의 최소공배수에 조직의 의미를 맞추게 된다. 더 안전한 시작점은 부서 간 논쟁이 잦고 AI 질의에 자주 쓰이는 핵심 지표 5~10개다.

1. 현재 사용 중인 BI·dbt·metric store에서 지표 정의와 실제 SQL을 수집한다.
2. 이름이 같은데 결과가 다른 지표를 먼저 찾아 차이를 문서화한다.
3. 한 도구를 source of authority로 정하고 Ossie 표현으로 export한다.
4. validator뿐 아니라 기준 데이터셋의 golden query 결과를 저장한다.
5. 두 번째 도구로 import한 뒤 차원 조합·기간·필터별 결과를 비교한다.
6. 다시 Ossie로 export해 필드와 표현식, 확장 속성의 손실을 측정한다.
7. 허용할 손실과 배포를 막을 손실을 정책으로 고정한다.

![Ossie 도입 시 왕복 변환 검증 흐름](https://heracles-jo.github.io/assets/img/posts/apache-ossie-semantic-model-interchange/migration.svg)

PoC 지표도 파일 수보다 의미 보존을 측정해야 한다. 변환 가능한 지표 비율, 경고 없는 왕복 비율, golden query 일치율, 수동 수정 시간, 새 도구 onboarding 시간, 정의 변경이 downstream에 반영되는 시간을 기록하면 된다. [TimesFM 도입 글](/posts/github-trending-timesfm-time-series-foundation-model/)에서 모델 정확도만큼 baseline과 운영 설명력을 강조했듯, 시맨틱 계층도 포맷 채택률보다 결과 재현성이 핵심이다.

## 지금 선택할 수 있는 범위

Ossie는 규격과 생태계를 함께 만드는 초기 프로젝트다. Apache 재단의 공개 거버넌스와 Apache-2.0 라이선스는 장기 협업에 유리하지만, 아직 정식 릴리스가 없고 변환기별 완성도도 같지 않다. 프로덕션의 유일한 지표 저장소로 즉시 승격하기보다 interoperability test bed와 export contract로 시작하는 편이 현실적이다.

이미 한 벤더의 semantic layer를 안정적으로 사용하고 외부 교환 요구가 없다면 당장 옮길 이유는 약하다. 반대로 BI가 여러 개이고, M&A나 조직 분리로 도구가 계속 바뀌며, AI 에이전트가 동일 KPI를 사용해야 한다면 공통 중간 표현의 가치가 커진다. 이때도 목표는 “모든 도구에서 모든 기능 지원”이 아니라 핵심 지표가 어디로 이동하더라도 의미 차이를 자동으로 발견하는 것이다.

Apache Ossie가 성공할지는 참여 벤더 수보다 세 가지에 달려 있다. 미지원 의미를 침묵하지 않는가, 왕복 변환 테스트가 실제 현업 모델을 충분히 포함하는가, 확장 기능을 허용하면서도 공통 핵심을 유지하는가다. 표준은 차이를 없애는 문서가 아니라 차이가 생긴 지점을 기계적으로 드러내는 계약이어야 한다.
