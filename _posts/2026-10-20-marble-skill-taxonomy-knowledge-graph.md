---
title: "교육 지식 그래프 구축: Marble Skill Taxonomy 검증 기준"
description: "Marble Skill Taxonomy의 선수학습 DAG와 교육과정 정렬 데이터를 바탕으로 무결성, AI 생성 연구, 라이선스와 개인화 학습 PoC 기준을 정리한다."
author: heracles-jo
date: 2026-10-20 08:20:00 +0900
categories: [Data Engineering, AI Infrastructure]
tags: [marble-skill-taxonomy, knowledge-graph, education-data, data-governance, open-data, curriculum]
image:
  path: https://heracles-jo.github.io/assets/img/posts/marble-skill-taxonomy-knowledge-graph/cover.svg
  alt: "교육 지식 그래프의 토픽과 선수학습 관계를 검증하는 데이터 파이프라인"
---

학습 진도를 개인화하려면 “다음에 무엇을 가르칠까”보다 먼저 **어떤 개념이 무엇에 의존하는지**를 기계가 읽을 수 있어야 한다. 교육과정 문서의 단원 목록만 벡터 검색에 넣으면 관련 문장은 찾을 수 있지만, 분수 비교 전에 필요한 수 감각이나 그래프 해석 전에 필요한 축·척도 개념을 일관된 순서로 설명하기 어렵다. 반대로 선수학습 그래프를 절대적인 정답처럼 사용하면 지역 교육과정, 학습자의 우회 경로, 데이터 작성자의 편향을 알고리즘이 확대할 수 있다.

[withmarbleapp/os-taxonomy](https://github.com/withmarbleapp/os-taxonomy)는 이 중간 지점을 겨냥한 공개 교육 데이터셋이다. 2026년 10월 20일 08시 30분 KST 전후 GitHub Trending daily에서 `301 stars today`로 표시됐고, GitHub API 확인 시점에는 6,097 stars, 1,000 forks, 열린 issue와 PR을 합친 13개, ODbL-1.0 라이선스 식별자를 보였다. 저장소는 1,591개 micro-topic, 3,225개 prerequisite edge, 8개 subject, 176개 domain cluster를 선언하며 별도 정식 GitHub release 없이 `v1` 데이터와 최근 커밋을 갱신하고 있다. 수치와 활동은 확인 시점의 공개 스냅샷이며 데이터 정확도나 교육 효과를 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어 데이터에 접근하지 못해 선정 근거로 사용하지 않았다.

## 후보 비교: 에이전트 도구 사이에서 데이터 계약이 독립 검색 의도를 만들었다

오늘 daily·weekly 후보는 AI 코딩 에이전트와 컨텍스트 최적화에 집중돼 있었다. 최근 글의 저장소뿐 아니라 “에이전트의 기억·권한·토큰을 어떻게 운영할까”라는 중심 질문까지 대조했다.

| 후보 | 확인 시점 신호 | 중복·장기 가치 판단 |
|---|---|---|
| [Marble Skill Taxonomy](https://github.com/withmarbleapp/os-taxonomy) | daily 301, 6,097 stars, ODbL-1.0, 최근 데이터 관계 수정 | 교육 개념의 선수관계를 공개 그래프로 다루는 **교육 지식 그래프 구축** 의도가 기존 글과 분리된다. |
| [OpenCode](https://github.com/anomalyco/opencode) | daily 1,310, 217,759 stars, MIT, v1.19.3 | 오픈소스 코딩 에이전트 운영은 기존 에이전트 권한·메모리·리뷰 글과 검색 의도가 넓게 겹친다. |
| [Headroom](https://github.com/headroomlabs-ai/headroom) | daily 317, 76,220 stars, Apache-2.0, v0.41.0 | 도구 출력 압축과 토큰 절감은 Context Mode 및 토큰 경제 글에서 이미 중심 논지를 다뤘다. |
| [CLI-Anything](https://github.com/HKUDS/CLI-Anything) | daily 607, 55,207 stars, Apache-2.0, v0.4.0 | GUI를 agent-native CLI로 감싸는 접근은 에이전트 네이티브 소프트웨어 글과 직접 겹친다. |
| [Jasna](https://github.com/Kruk2/jasna) | daily 502, 2,872 stars, AGPL-3.0, v0.11.2 | 영상 복원은 별도 의도가 있지만 모자이크 제거 사용례의 권리·동의 위험과 좁은 조직 적용 범위가 크다. |

이 선택은 “교육 AI가 인기다”라는 넓은 주장보다 좁다. 검색자가 해결하려는 문제는 LLM으로 수업 자료를 생성하는 법이 아니라, **교육 개념과 선수관계를 버전 관리 가능한 데이터 계약으로 만들고 검증하는 법**이다. 이 질문은 추천 엔진, 진단 평가, 커리큘럼 매핑, RAG를 모두 연결하지만 어느 하나의 모델 기능으로 환원되지 않는다.

## 평면 목록과 지식 그래프의 차이는 순서가 아니라 설명 가능성이다

저장소의 `topics.json`에서 각 micro-topic은 안정적인 ID, 개념 유형, subject와 domain, 설명, 연령 범위, mastery evidence, assessment prompt, 교육과정 표준 참조를 가진다. `dependencies.json`은 `topicId`가 `prerequisiteId`에 의존한다고 기록하고 edge를 `hard` 또는 `soft`로 구분하며 한 줄짜리 이유를 붙인다.

이 구조는 “5학년 수학 다음은 6학년 수학”처럼 학년을 선형으로 증가시키는 모델과 다르다. 학습자가 어떤 평가에서 실패했을 때 단순히 직전 단원으로 되돌리는 대신, 실패한 개념으로 들어오는 선수 edge를 따라가며 후보 원인을 좁힐 수 있다. 동시에 hard와 soft를 구분하면 필수 기반과 도움이 되는 배경지식을 같은 강도로 강제하는 오류를 줄일 수 있다.

![교육 지식 그래프를 원천 표준, 정규화 토픽, 선수학습 DAG, 검증, 제품 소비 계층으로 분리한 아키텍처](https://heracles-jo.github.io/assets/img/posts/marble-skill-taxonomy-knowledge-graph/architecture.svg)

하지만 그래프가 있다는 사실만으로 학습 순서가 증명되지는 않는다. edge의 이유가 그럴듯해도 특정 학생 집단에서 실제 prerequisite인지, 여러 경로 중 하나인지, 단지 교육과정 편성 관습인지 구분해야 한다. 중앙성이 높은 토픽을 “가장 중요한 개념”으로 곧바로 해석하는 것도 위험하다. 그래프 구조상 연결이 많다는 것과 교육적 영향이 크다는 것은 다른 주장이다.

따라서 제품에서는 taxonomy를 **추천의 유일한 판정기**가 아니라 설명 가능한 후보 생성기로 두는 편이 안전하다. 그래프가 제안한 복습 경로를 실제 문항 반응, 교사 판단, 학습 시간, 반복 오류와 결합하고, 추천 사유를 “이 개념이 미숙해서”가 아니라 “현재 데이터에서 이 선수관계가 후보로 관찰됐다”는 수준으로 표시해야 한다.

## 무결성 검사는 스키마 통과보다 넓어야 한다

공식 `scripts/validate.mjs`는 dependency 없이 실행되는 무결성 검사기다. 선언된 count와 실제 배열 길이, topic ID와 type, 중복 ID, 교육과정 표준 key, edge endpoint, self-dependency, strength 값, topic-to-standard 참조, cluster-to-domain 관계, teaching research coverage, 파일별 SHA-256과 byte count를 확인하고 실패하면 non-zero로 종료한다. `manifest.json`을 별도로 두고 canonical JSON 파일의 checksum을 묶은 점도 배포 데이터셋에 유용하다.

이 검사는 최소 계약으로 좋지만 production 소비자는 세 층을 더 봐야 한다.

1. **구조 무결성**: dangling reference, 중복 ID, cycle, 고립된 component, 연령 범위 역전이 없는가.
2. **의미 무결성**: hard prerequisite의 이유가 양쪽 토픽 정의와 맞는가, 동일 개념이 subject별로 중복되며 충돌하지 않는가.
3. **변경 무결성**: 토픽 이름 수정, edge 삭제, ID 재사용이 기존 학습 기록과 추천 결과를 어떻게 바꾸는가.
4. **제품 무결성**: 특정 국가·언어·연령 데이터가 부족할 때 UI와 모델이 그 공백을 확신으로 채우지 않는가.

최근 커밋에는 연령대가 뒤인 토픽을 선수로 연결한 관계와 고립된 Science cluster를 고치는 변경이 포함됐다. 공개 issue에도 “nonsensical linkages”가 논의된다. 이는 프로젝트의 결함을 단정하는 근거가 아니라, 그래프 데이터가 정적 참고표가 아니라 계속 검토되는 모델이라는 신호다. downstream 팀은 `main` URL을 매번 읽지 말고 commit SHA와 manifest checksum을 함께 고정해야 한다.

[Apache Ossie 시맨틱 계층 글](/posts/apache-ossie-semantic-model-interchange/)에서 포맷 변환 성공과 의미 동등성을 분리했듯, 교육 taxonomy도 JSON Schema 통과와 교육적 타당성을 나눠야 한다. validator는 존재하지 않는 ID를 잡을 수 있지만 “이 개념은 반드시 먼저 배워야 한다”는 판단까지 증명하지 못한다.

## AI가 작성한 teaching research는 근거가 아니라 검토 대기 중인 제안이다

`teaching-research.json`은 Science 547개와 Mathematics 504개 토픽, 합계 1,051개 레코드에 교수 접근, 활동, 피드백, 평가 지침과 출처를 연결한다. 나머지 540개 토픽은 연구 레코드가 없다고 명시한다. 누락을 0이나 낮은 품질 점수로 암묵 변환하지 않고 coverage metadata로 드러낸 것은 중요한 설계다.

더 중요한 것은 README의 제한 사항이다. 이 연구 레이어는 agent-authored이며 별도 factual critic과 표본 검토를 거쳤지만, 원래 source를 이번 릴리스에서 다시 가져와 재검증하지 않았다. 보존된 `verified: true`와 `confidence: high`도 새로운 독립 품질 평가가 아니다. 활동은 research-informed proposal이지 실증적으로 검증된 intervention이 아니라고 선을 긋는다.

이 데이터가 RAG나 수업 생성 에이전트에 들어가면 다음과 같은 신뢰 단계가 필요하다.

- **원천 주장**: 링크가 열리고 실제 문장이 해당 claim을 지지하는지 재검증한다.
- **정렬 주장**: 인용된 연구가 해당 연령·과목·교육과정에 적용 가능한지 확인한다.
- **활동 제안**: 교사가 안전성, 준비물, 접근성, 문화적 맥락을 승인한다.
- **학습 효과**: 별도 실험과 평가 없이 “효과가 있다”는 문구를 생성하지 않는다.
- **모델 출력**: source claim, 프로젝트 요약, 모델 추론을 UI에서 구분한다.

[Marin의 오픈 모델 학습 재현성](/posts/marin-open-model-training-reproducibility/)에서 데이터 계보와 artifact를 함께 추적했듯, 교육 콘텐츠도 최종 문장만 저장하면 안 된다. taxonomy version, topic ID, source URL, 확인 시점, 변환 규칙, reviewer, 제품에 노출된 문구를 하나의 lineage로 남겨야 수정과 철회가 가능하다.

## 라이선스는 저장소 하나가 아니라 데이터 계층별로 읽어야 한다

GitHub API는 저장소 라이선스를 ODbL-1.0으로 표시하지만 실제 재사용 조건은 한 줄로 끝나지 않는다. 공식 README와 `PROVENANCE.md`는 세 계층을 구분한다.

- 데이터베이스의 구조·ID·관계는 **ODbL 1.0**이며 attribution과 derivative database의 share-alike를 요구한다.
- Marble이 작성한 이름·설명·evidence·assessment prompt·연구 문장은 **CC BY-SA 4.0**이다.
- `curriculum-standards.json`의 외부 교육과정은 원 권리자의 조건을 따른다. 일부는 full text를 싣고 일부는 code/key만 제공한다.

예를 들어 영국 National Curriculum은 OGL v3.0 notice가 필요하고, Common Core는 목적 제한이 있는 별도 public license 아래 full text가 포함된다. NGSS, C3, IB PYP 계열은 저장소가 원문을 재라이선스할 수 없어 codes-only로 배포한다. validator도 codes-only source에 verbatim text가 들어오지 않았는지 검사한다.

따라서 “오픈 데이터니까 우리 DB에 복사하면 된다”는 접근은 위험하다. 제품이 taxonomy를 수정·확장하는지, 원본과 별도 DB를 결합해 derivative database를 만드는지, JSON에서 생성한 화면·리포트가 produced work에 해당하는지, 외부 교육과정 원문을 추가하는지에 따라 의무가 달라질 수 있다. 실제 배포 전에는 사용 계층과 변형 방식을 적어 법무 검토를 받아야 하며, 이 글은 법률 자문을 대신하지 않는다.

![Marble Skill Taxonomy를 도입할 때 데이터 무결성, 교육 타당성, 출처, 라이선스, 제품 안전성을 순서대로 확인하는 위험 게이트](https://heracles-jo.github.io/assets/img/posts/marble-skill-taxonomy-knowledge-graph/risk-gates.svg)

라이선스 검토는 마지막 출시 체크박스가 아니라 ingestion 설계에 들어가야 한다. source별 license와 notice, text 포함 여부, 허용된 표시 범위를 metadata로 보존하면 export 시점에 잘못된 원문을 자동 차단할 수 있다. 반대로 모든 문자열을 하나의 embedding index에 섞으면 삭제 요청이나 조건 변경 때 어느 벡터를 제거해야 하는지 찾기 어렵다.

## 개인화 학습 PoC는 추천 정확도보다 반증 가능성을 측정한다

첫 PoC에서 1,591개 토픽 전체를 제품 ontology로 확정할 필요는 없다. 실제 커리큘럼과 평가 자료가 있는 과목·연령대 하나를 고르고 50~100개 토픽의 좁은 subgraph로 시작하는 편이 낫다.

| 검증 축 | 측정 방법 | 중단 조건 예시 |
|---|---|---|
| 구조 | 공식 validator + cycle·component·diff 검사 | 참조 오류, 설명되지 않은 ID 교체, hard cycle 발견 |
| 교육 타당성 | 교사 2명 이상이 edge와 evidence를 독립 검토 | hard edge 합의율이 기준 이하이거나 특정 경로 편향이 큼 |
| 진단 가치 | 실제 오답 뒤 추천한 선수 토픽의 확인 적중률 | 평면 단원 baseline보다 개선이 없고 복습량만 증가 |
| 출처 | teaching research claim의 URL·문장·대상 재검증률 | 고위험 활동의 근거를 재현할 수 없음 |
| 공정성 | 언어·연령·교육과정별 coverage와 추천 차이 | 데이터 공백을 숙련도 부족으로 오판 |
| 운영 | commit pin, checksum, migration, rollback 시간 | upstream 변경 후 기존 학습 기록을 재현하지 못함 |
| 라이선스 | 레코드별 source·license·notice 추적률 | 원천 조건을 모르는 텍스트가 제품 출력에 포함 |

추천 품질은 클릭률만 보면 안 된다. 학생이 제안된 복습을 마친 뒤 목표 문항을 해결하는지, 교사가 추천 이유를 이해하고 수정할 수 있는지, 틀린 edge를 신고해 다음 데이터 버전에 반영할 수 있는지까지 봐야 한다. [Project NOMAD의 오프라인 지식 서버](/posts/project-nomad-offline-knowledge-server/)처럼 교육 자료를 서비스하는 시스템에서는 최신성뿐 아니라 판본·출처·복구 가능성이 운영 품질을 결정한다.

RAG를 붙일 때도 그래프와 문서 검색의 역할을 분리한다. 그래프는 prerequisite와 인접 개념을 좁히고, 문서 검색은 정의·예제·활동의 근거를 찾는다. [LiteParse와 RAG 데이터 파이프라인](/posts/github-trending-document-parser-liteparse/)에서 입력 구조 손실을 경계했듯, 교육과정 PDF를 파싱한 결과가 표·주석·학년 범위를 잃으면 그 위의 taxonomy 정렬도 신뢰할 수 없다.

Marble Skill Taxonomy의 장점은 교육 콘텐츠를 많이 제공한다는 데만 있지 않다. 토픽, 관계, 표준, 연구, checksum, provenance와 license를 서로 다른 파일과 계약으로 드러낸다는 데 있다. 동시에 agent-authored research, 부분 coverage, 계속 수정되는 edge, 국가별 권리 조건은 소비자가 떠안아야 할 검증 비용을 분명히 보여 준다.

교육 지식 그래프의 도입 기준은 “개념을 예쁜 3D 그래프로 그릴 수 있는가”가 아니다. **틀린 관계를 발견하고 되돌릴 수 있는가, 근거와 모델 추론을 구분할 수 있는가, 학습자 데이터 없이도 공백과 편향을 표시하는가, 레코드별 재사용 조건을 추적할 수 있는가**다. 이 네 가지를 입증할 수 있을 때 taxonomy는 추천을 정당화하는 권위가 아니라, 교사와 시스템이 함께 반증하고 개선할 수 있는 데이터 계약이 된다.

> 1차 자료: [Marble Skill Taxonomy 저장소와 README](https://github.com/withmarbleapp/os-taxonomy), [데이터 manifest](https://github.com/withmarbleapp/os-taxonomy/blob/main/data/manifest.json), [무결성 validator](https://github.com/withmarbleapp/os-taxonomy/blob/main/scripts/validate.mjs), [JSON Schema](https://github.com/withmarbleapp/os-taxonomy/tree/main/schema), [provenance와 외부 교육과정 라이선스](https://github.com/withmarbleapp/os-taxonomy/blob/main/PROVENANCE.md), [공개 issues](https://github.com/withmarbleapp/os-taxonomy/issues), [최근 commits](https://github.com/withmarbleapp/os-taxonomy/commits/main). Trending·저장소 수치는 2026년 10월 20일 08시 30분 KST 전후의 공개 스냅샷이며 이후 달라질 수 있다.
