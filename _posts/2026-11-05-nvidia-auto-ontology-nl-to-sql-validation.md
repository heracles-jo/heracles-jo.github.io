---
title: "NVIDIA Auto Ontology: NL-to-SQL 정확도 검증 기준"
description: "NVIDIA Auto Ontology의 시맨틱 그래프·인증·Text-to-SQL 평가 구조를 분석하고, 지표 정확성·권한·비용·실패 복구를 검증하는 도입 기준을 제시한다."
author: heracles-jo
date: 2026-11-05 08:35:00 +0900
categories: [Data Engineering, AI Infrastructure]
tags: [nvidia-auto-ontology, nl-to-sql, semantic-layer, data-governance, mcp, ai-agent]
image:
  path: https://heracles-jo.github.io/assets/img/posts/nvidia-auto-ontology-nl-to-sql-validation/cover.svg
  alt: "NVIDIA Auto Ontology로 자연어 SQL의 의미와 정확성을 검증하는 구조"
---

데이터베이스에 연결된 AI 에이전트가 SQL을 실행할 수 있다는 사실과, 그 답을 업무 판단에 써도 된다는 사실은 다르다. 스키마만 보고 쿼리를 생성하면 `revenue`가 결제액인지 환불·세금을 반영한 순매출인지 알 수 없고, 이름이 비슷한 키를 잘못 조인해도 문법상 유효한 결과가 나올 수 있다. 더 위험한 경우는 오류가 아니라 그럴듯한 숫자다. 실행은 성공했지만 의미가 틀린 답은 장애 알람도 남기지 않는다.

[NVIDIA/auto-ontology](https://github.com/NVIDIA/auto-ontology)는 이 문제를 자연어 질의 모델 하나로 해결하지 않는다. 데이터베이스 스키마와 표본, 기존 분석 정보를 읽어 용어·컬럼·SQL 속성·관계를 시맨틱 그래프로 만들고, 사람이 이를 수정·인증한 뒤 에이전트가 질문마다 필요한 문맥을 검색해 SQL을 생성하도록 한다. 답변에는 실행 SQL과 처리 단계를 함께 반환한다. 핵심은 **더 많은 메타데이터를 프롬프트에 넣는 것**이 아니라, 업무 의미를 검토 가능한 데이터 제품으로 만들고 질의 결과까지 추적하는 데 있다.

2026년 11월 5일 08시 43분 KST 전후 GitHub Trending daily에서 Auto Ontology는 **2,053 stars today**로 표시됐다. GitHub API 기준 4,884 stars, 391 forks, 열린 issue·PR 42개, Apache-2.0 라이선스였고 11월 5일 KST 새벽에도 Apache Ossie 변환기 경로를 갱신하는 커밋이 반영됐다. 정식 GitHub Release는 아직 없으며 저장소는 외부 pull request를 받지 않는다고 명시한다. 빠른 관심과 활발한 변경은 가능성을 보여 주지만, 버전 안정성이나 커뮤니티 거버넌스를 대신하지는 않는다. 이번 실행에서는 Search Console·Analytics 실제 검색어에 접근하지 못했으므로 유입 데이터에 근거했다고 가정하지 않았다.

## 후보 다섯 개 중 남은 질문은 “SQL이 맞다는 것을 어떻게 증명할까”였다

오늘 daily 후보는 에이전트 개발 워크플로에 치우쳐 있었다. 저장소 이름만 새롭고 중심 질문이 기존 글과 같은 후보를 제외하면, Auto Ontology는 **자연어 데이터 질의의 의미 정확성과 증거를 어떻게 운영할 것인가**라는 독립 검색 의도를 만든다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [NVIDIA Auto Ontology](https://github.com/NVIDIA/auto-ontology) | daily 2,053, API 4,884 stars, Apache-2.0, 당일 push | 기존 시맨틱 표준 글과 연결되지만, 자동 의미 생성·인증·NL-to-SQL 실행 정확도라는 별도 운영 질문이 선명해 선택했다. |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | daily 810, 147,274 stars, MIT, `v1.3.0` | 명세 주도 개발은 유효하지만 스킬·코딩 에이전트 워크플로 클러스터와 독자층이 크게 겹친다. |
| [Worktrunk](https://github.com/max-sixty/worktrunk) | daily 524, 11,006 stars, `v0.81.0` | Git worktree 병렬 실행은 [Orca 운영 글](/posts/orca-parallel-ai-coding-agents/)의 중심 검색 의도와 직접 경쟁한다. |
| [PR Agent](https://github.com/The-PR-Agent/pr-agent) | daily 279, 14,736 stars, MIT, `v0.49.0` | AI 리뷰 자동화는 [Open Code Review](/posts/open-code-review-hybrid-ai-code-review/)에서 결정론적 검사와 LLM 판단 분리를 이미 다뤘다. |
| [MoneyPrinterTurbo](https://github.com/harry0703/MoneyPrinterTurbo) | daily 615, 138,923 stars, MIT | 숏폼 생성 자동화는 기존 AI 비디오 제작·렌더링 글과 검색 의도가 겹치고 저작권·플랫폼 정책 변수가 크다. |

Auto Ontology도 완전히 새로운 문제를 만드는 것은 아니다. [Apache Ossie 시맨틱 계층 표준화](/posts/apache-ossie-semantic-model-interchange/) 글은 여러 BI·AI 도구 사이에서 지표 의미를 교환하고 왕복 변환 손실을 검증하는 문제를 다뤘다. Auto Ontology는 그 다음 단계에 가깝다. 교환 가능한 모델을 가져오거나 데이터에서 초안을 만든 뒤, 실제 질문을 SQL로 바꾸고 결과의 근거를 되돌려주는 **실행형 의미 계층**을 제공한다. 표준과 런타임은 대체 관계가 아니라 계약과 집행의 관계다.

## 자동 생성된 온톨로지는 정답이 아니라 검토 대기 중인 초안이다

공식 구조는 생성, 인증, 질의의 세 단계로 읽는 것이 정확하다.

1. **생성**: 스키마, 컬럼 프로파일, 표본 값을 읽고 업무 용어와 동의어, 컬럼 매핑, 테이블 관계, 재사용할 SQL 속성을 제안한다.
2. **인증**: 데이터 담당자가 이름·설명·계산식·관계를 수정하고 승인한다. 같은 용어가 여러 시스템에서 다르게 쓰이면 어느 정의를 사용할지 결정한다.
3. **질의**: 질문의 의도와 엔티티를 추출하고 관련 용어·컬럼·SQL 속성을 검색해 쿼리를 만든다. 값과 쿼리를 검사·수정한 뒤 실행 SQL과 단계를 반환한다.

![Auto Ontology가 메타데이터를 의미 그래프로 만들고 사람 인증을 거쳐 NL-to-SQL 답변으로 연결하는 구조](https://heracles-jo.github.io/assets/img/posts/nvidia-auto-ontology-nl-to-sql-validation/architecture.svg)

이 흐름에서 가장 중요한 단어는 `auto`보다 `certify`다. 외래 키가 있다고 업무상 올바른 조인이라는 보장은 없고, 컬럼명에서 추론한 `margin`이 재무팀 계산식과 같다는 보장도 없다. query history에서 자주 등장한 식이 잘못된 레거시 관행일 수도 있다. 자동 생성 결과를 곧바로 에이전트의 권위 있는 문맥으로 승격하면, 수작업 SQL의 불일치를 자동화된 불일치로 바꾸는 데 그친다.

그래서 온톨로지 항목에는 코드와 비슷한 수명주기가 필요하다. 소유자, 근거 원천, 생성 모델과 버전, 마지막 검토 시각, 승인자, 유효 범위, 폐기 상태를 남기고 변경 전후에 golden query를 실행해야 한다. 계산식 한 줄이 바뀌면 어떤 대시보드와 에이전트 질문이 영향을 받는지도 추적해야 한다. 모델이 초안을 만들 수는 있지만, 업무 의미의 책임 주체까지 자동 생성할 수는 없다.

## 정확도 평가는 “성공한 SQL 비율”보다 대조군 설계가 먼저다

NVIDIA는 별도 [auto-ontology-eval](https://github.com/NVIDIA/auto-ontology-eval) 저장소에서 온톨로지가 실제로 정확도를 높이는지 비교한다. 동일한 질문과 모델을 두 arm으로 나누고, control에는 스키마 덤프만 제공하며 treatment에는 Auto Ontology가 검색한 문맥과 도구를 제공한다. 두 SQL과 정답 SQL을 같은 데이터베이스에서 실행한 뒤 결과를 결정론적으로 비교한다. 공개 구성은 BIRD, BEAVER, FDABench-Lite, Wide World Importers, BIRD-Interact를 포함한다.

이 평가 방식에서 배울 점은 프로젝트의 벤치마크 숫자보다 **같은 모델·같은 질문·같은 검증기를 유지해 의미 계층의 순효과를 분리한다는 것**이다. 사내 PoC도 같은 구조로 만들어야 한다.

- control과 treatment가 서로 다른 모델을 쓰면 온톨로지 효과와 모델 성능을 분리할 수 없다.
- 성공적으로 실행된 SQL만 세면 의미가 틀린 결과와 우연히 같은 숫자가 나온 쿼리를 놓친다.
- 질문 난이도와 업무 영역을 섞어 평균 하나로 만들면 특정 부서에서 반복되는 실패가 가려진다.
- rate limit이나 model output 누락을 오답으로만 집계하면 시스템 건강 문제를 정확도 문제로 오해한다.
- 온톨로지가 고친 질문뿐 아니라 원래 맞던 질문을 틀리게 만든 회귀 목록을 함께 봐야 한다.

운영용 gold set은 인기 benchmark보다 작아도 된다. 대신 실제로 의사결정에 쓰는 질문, 모호해서 clarification이 필요한 질문, 권한상 답하면 안 되는 질문, 데이터 자체에 답이 없는 질문을 포함해야 한다. “지난달 매출은?” 같은 정상 경로만 넣으면 answerability 판단, 거부, 권한, 시간 의미의 실패를 측정할 수 없다.

## Ossie 호환성은 이동성을 높이지만 의미 보존을 자동 보증하지 않는다

Auto Ontology는 Apache Ossie YAML import·export를 지원한다. 이는 이미 존재하는 semantic model을 가져오고, 생성·수정한 정의를 다른 도구와 교환할 수 있다는 뜻이다. 특정 UI 안에서만 관리되는 용어를 줄일 수 있어 장기적으로 중요한 기능이다.

다만 `Auto Ontology → Ossie → 다른 도구`가 성공했다고 계산 결과까지 같아지는 것은 아니다. SQL dialect, 지원 함수, 시간대, 다대다 관계, 누적 지표, 행 수준 보안 표현이 다르면 형식 변환은 성공해도 의미가 달라질 수 있다. 따라서 import/export gate는 세 층으로 나눠야 한다.

| 게이트 | 확인할 것 | 실패 예시 |
|---|---|---|
| 구문 | YAML·schema validation, 필수 필드 | 파일은 읽히지만 확장 필드가 유실 |
| 구조 | 용어·관계·SQL 속성·소유자 보존 | bridge 관계가 단순 join으로 축소 |
| 의미 | 기준 데이터에서 질문별 결과 동등성 | 월말·환불·중복 집계에서 숫자 차이 |

교환 표준은 vendor lock-in을 줄이지만, 변환기 자체가 새로운 의존성이 된다. converter version과 source model hash를 기록하고, 손실을 경고로만 남기지 말고 중요 지표에서는 배포 차단 조건으로 올려야 한다.

## 보안 경계는 모델보다 데이터 연결과 내부 API에서 먼저 무너진다

공식 README는 frontend를 공개 gateway로 두고 backend와 ingestion service의 3001·3002 포트를 private network에 둘 것을 요구한다. backend FastAPI는 frontend가 전달하는 `x-auto-ontology-user-id`를 신뢰하고, ingestion service의 ingest·delete·reset·compile endpoint에는 자체 인증이 없다고 명시한다. 내부 포트가 ingress, service mesh, 잘못된 Kubernetes Service 설정으로 외부에 노출되면 UI의 인증과 RBAC를 우회할 수 있다.

데이터베이스 자격 증명도 기본값을 확인해야 한다. UI에서 연결을 만들 때 Vault가 없으면 password를 포함한 connection object가 catalog Postgres row에 암호화되지 않은 JSON으로 저장된다. Vault는 네 가지 설정이 모두 있을 때만 켜지고 부분 설정은 경고 후 plaintext 경로로 되돌아간다. “Vault 변수를 넣었다”가 아니라 실제 저장 row에 비밀이 없는지 canary credential로 확인해야 한다.

또 다른 실패는 연결 원천의 불일치다. 공식 문서에 따르면 질문 답변은 UI-managed connection이 있으면 그것을 우선하지만, ingestion은 `CONNECTION_STRINGS`가 설정돼 있으면 환경변수 연결을 우선한다. 두 경로를 동시에 쓰면 에이전트가 A 데이터베이스를 색인하고 B 데이터베이스에 질의하는 식의 drift가 생길 수 있다. 운영 배포에서는 연결 원천을 하나로 정하고 catalog snapshot과 실제 query target의 fingerprint를 비교하는 편이 안전하다.

MCP는 read-only ontology 도구를 제공하지만, read-only가 곧 low-risk는 아니다. 용어, 컬럼, 관계, 인증된 계산식은 회사의 가격 정책과 고객 분류, 위험 모델을 드러낼 수 있다. [AWS Agent Toolkit의 MCP·IAM 설계](/posts/aws-agent-toolkit-mcp-iam-governance/)에서 도구 노출과 backend 권한을 따로 검증했듯, 여기서도 MCP token owner의 role, 접근 가능한 catalog, 질문 결과의 row-level policy, 외부 모델로 전달되는 문맥을 각각 통제해야 한다.

## 답변의 SQL을 보여 주는 것만으로 설명 가능성이 완성되지는 않는다

생성 SQL과 처리 단계를 반환하는 것은 좋은 출발점이다. 하지만 긴 SQL을 화면에 표시한다고 사용자가 결과를 검증할 수 있는 것은 아니다. 운영에서는 최소 네 종류의 provenance가 함께 필요하다.

- 질문이 참조한 인증 용어와 SQL 속성의 version
- 사용한 데이터 source, schema snapshot, query 실행 시각
- 생성·수정한 SQL과 validation·repair 단계
- 최종 row count, 집계 결과, 정책 필터와 거부 사유

이 정보가 있어야 같은 질문의 숫자가 어제와 오늘 달라졌을 때 데이터 변화, 온톨로지 변경, 모델 변경, 권한 변화 중 무엇이 원인인지 구분할 수 있다. [PostHog 통합 제품 관측성](/posts/posthog-unified-product-observability/)에서 이벤트와 trace를 한 화면에 모으는 것보다 데이터 보존·개인정보·원인 연결이 중요했던 것처럼, NL-to-SQL도 채팅 로그만 저장해서는 재현 가능한 감사가 되지 않는다.

로그에는 반대로 민감 정보가 과도하게 쌓일 수 있다. 질문 원문, SQL literal, sample row, 오류 stack, 연결 문자열을 모두 남기면 감사 저장소가 새로운 데이터 유출 지점이 된다. query fingerprint와 승인된 dimension은 보존하되 literal과 결과 row는 마스킹하거나 별도 보존 정책을 적용해야 한다.

## PoC는 정확도·거부·권한·운영비를 같은 판에서 측정한다

초기 도입은 전사 데이터 카탈로그보다 지표 정의가 안정적이고 owner가 명확한 한 도메인이 적합하다. 예를 들어 상품 주문과 환불을 가진 비민감 샘플 mart에서 40~60개 질문을 만들고, 기존 analyst SQL을 gold로 검토한다. 자연어가 같은데 부서마다 답이 다른 지표부터 시작하면 기술 평가 전에 조직 합의 문제로 막힌다.

![Auto Ontology PoC에서 정확도, 거부, 보안, 비용을 함께 검증하는 체크리스트](https://heracles-jo.github.io/assets/img/posts/nvidia-auto-ontology-nl-to-sql-validation/checklist.svg)

| 검증 영역 | 측정할 증거 | 중단 조건 예시 |
|---|---|---|
| 의미 정확도 | control·treatment 실행 결과, 고친 질문과 망가뜨린 질문 | 평균은 올라도 핵심 KPI 회귀가 반복됨 |
| answerability | 답할 수 없는 질문, clarification, 무응답 정확도 | 없는 데이터를 추정하거나 유사 지표로 몰래 대체 |
| 관계·집계 | 다대다, bridge, NULL, 시간대, 환불 fixture | join 중복을 탐지하지 못하고 숫자가 부풀어 오름 |
| 권한 | role별 term·column·row 가시성, MCP token | UI 권한과 SQL 실행 권한이 다르거나 내부 API 우회 가능 |
| 자격 증명 | Vault 저장, 회전, 폐기, 로그 마스킹 | password가 catalog row나 로그에 평문으로 남음 |
| 재현성 | ontology·model·prompt·source snapshot version | 같은 입력의 차이를 설명할 artifact가 없음 |
| 비용·지연 | compile 시간, 질문 p50·p95, model·rerank 비용 | 정확도 이득보다 검토·인프라·추론 비용이 큼 |
| 복구 | catalog backup, ontology export, 재compile, rollback | 변경 후 이전 인증 모델과 답변을 복원할 수 없음 |

권장 승격 순서는 세 단계다. 첫째, snapshot 데이터와 read-only 계정에서 benchmark를 돌린다. 둘째, 실제 분석가가 shadow mode로 질문하고 기존 SQL과 차이를 검수한다. 셋째, 영향이 낮은 내부 의사결정에서만 답변을 노출하고 핵심 재무·규제 지표는 사람 승인과 기존 BI를 유지한다. 에이전트가 직접 production write를 수행하거나 예측 서비스를 켜는 것은 별도 보안·데이터 반출 심사가 필요한 다른 프로젝트다.

## 도입 판단: 시맨틱 그래프보다 인증 가능한 운영 절차가 있는가

Auto Ontology의 장점은 schema-only Text-to-SQL이 놓치는 업무 의미를 용어, 관계, SQL 속성으로 구조화하고, 사람이 인증한 문맥을 에이전트가 질문별로 검색하게 만든다는 점이다. Apache Ossie 호환, MCP·API 노출, 별도 대조군 평가 저장소도 단순 데모를 넘어 운영 가능한 정확도 체계를 지향한다는 신호다.

반면 아직 정식 release가 없고 외부 contribution을 받지 않으며, Next.js·FastAPI·Postgres·pgvector·Vault·NIM을 포함한 스택은 작은 기능 하나보다 운영 면적이 넓다. 내부 API 신뢰, plaintext credential fallback, connection precedence, 외부 모델 endpoint, 선택적 KumoRFM 데이터 업로드까지 검토하지 않으면 “정확한 데이터 에이전트”를 만들기 전에 새로운 데이터 제어면을 노출할 수 있다.

도입 여부는 세 질문으로 결정하는 편이 낫다. **업무 용어와 계산식을 승인할 owner가 있는가. 같은 모델의 schema-only 대조군으로 정확도 순효과와 회귀를 측정할 수 있는가. 내부 API·자격 증명·행 권한·로그를 production 데이터 경계에 맞게 운영할 수 있는가.** 하나라도 답하지 못한다면 먼저 기존 semantic model과 gold query를 정리해야 한다. 세 조건이 갖춰졌다면 Auto Ontology는 자연어를 SQL로 바꾸는 UI가 아니라, AI가 기업 데이터에 답할 때 의미와 증거를 함께 통제하는 실행 계층이 될 수 있다.

> 1차 자료: [NVIDIA Auto Ontology 저장소와 README](https://github.com/NVIDIA/auto-ontology), [Auto Ontology Eval](https://github.com/NVIDIA/auto-ontology-eval), [Authentication 문서](https://github.com/NVIDIA/auto-ontology/blob/main/docs/authentication.md), [Connections 문서](https://github.com/NVIDIA/auto-ontology/blob/main/docs/connections.md), [MCP 문서](https://github.com/NVIDIA/auto-ontology/blob/main/docs/mcp.md), [Apache Ossie converter](https://github.com/apache/ossie-converters/tree/main/nvidia), [SECURITY.md](https://github.com/NVIDIA/auto-ontology/blob/main/SECURITY.md), [Apache-2.0 License](https://github.com/NVIDIA/auto-ontology/blob/main/LICENSE), [최근 commits](https://github.com/NVIDIA/auto-ontology/commits/main/), [공개 issues](https://github.com/NVIDIA/auto-ontology/issues). Trending·저장소 수치는 2026년 11월 5일 08시 43분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
