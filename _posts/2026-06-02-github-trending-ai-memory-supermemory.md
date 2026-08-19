---
title: "AI 에이전트 메모리 설계: Supermemory와 OpenViking 비교"
description: "Supermemory와 OpenViking의 메모리 모델, 검색 경로, 권한·삭제·라이선스 경계를 비교해 AI 에이전트 컨텍스트 계층의 실무 도입 기준을 제시합니다."
author: heracles-jo
date: 2026-06-02 07:38:00 +0900
categories: [AI Infrastructure, Open Source]
tags: [supermemory, openviking, agent-memory, context-engine, rag, data-governance]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-ai-memory-supermemory/cover.svg
  alt: Supermemory와 OpenViking을 비교해 AI 에이전트 메모리 계층의 저장·검색·정책 흐름을 설명하는 이미지
---

AI 에이전트가 이전 대화를 기억하지 못할 때 흔히 “벡터 데이터베이스를 붙이면 된다”고 생각한다. 그러나 운영 환경에서 필요한 것은 문서 유사도 검색만이 아니다. 어떤 대화에서 사실을 추출할지, 변경된 선호를 어떻게 덮어쓸지, 사용자가 삭제를 요청하면 파생 요약까지 지울지, 에이전트가 어떤 경로로 컨텍스트를 골랐는지 설명할 수 있어야 한다. **에이전트 메모리는 검색 기능이 아니라 데이터 수명주기와 실행 정책을 함께 관리하는 컨텍스트 계층**이다.

이 글은 2026년 6월 처음 분석한 [Supermemory](https://github.com/supermemoryai/supermemory)를 2026년 8월 20일 KST 기준 공개 자료로 다시 검토하고, 같은 검색 의도를 가진 [OpenViking](https://github.com/volcengine/OpenViking)과 비교해 보강한 글이다. Search Console과 Analytics의 쿼리·CTR 데이터에는 이번 실행 환경에서 접근할 수 없었다. 따라서 실제 유입 데이터를 봤다고 가정하지 않고, 기존 글의 제목·설명·본문과 GitHub Trending daily·weekly, 공식 README·문서·릴리스·커밋을 대조했다.

## 새 글 대신 기존 글을 보강한 이유

8월 20일 daily Trending에서는 MoneyPrinterTurbo, OpenViking, munder-difflin, Anthropic-Cybersecurity-Skills, NautilusTrader가 강한 신호를 보였다. 하지만 순위가 높다는 이유만으로 새 URL을 만들면 이미 쌓인 검색 의도와 내부 링크를 나누게 된다.

| 후보 | 확인 시점 공개 신호 | 검색 의도와 판단 |
|---|---:|---|
| [OpenViking](https://github.com/volcengine/OpenViking) | daily 803 stars today, weekly 985 stars this week, GitHub API 약 3.0만 stars, v0.4.15 | 에이전트 메모리·RAG·스킬을 통합하는 주제로 기존 Supermemory 글과 의도가 같다. 새 글보다 비교 보강이 낫다. |
| [MoneyPrinterTurbo](https://github.com/harry0703/MoneyPrinterTurbo) | daily 2,221 stars today, API 약 11만 stars, MIT, v1.3.4 | 자동 영상 생성은 기존 영상 편집·콘텐츠 자동화 클러스터와 겹친다. |
| [munder-difflin](https://github.com/chaitanyagiri/munder-difflin) | daily 797 stars today, API 약 2.6천 stars, v0.4.4 | 로컬 멀티 에이전트 하네스는 [Orca의 병렬 에이전트 운영](/posts/orca-parallel-ai-coding-agents/)과 검색 의도가 가깝다. |
| [Anthropic-Cybersecurity-Skills](https://github.com/mukul975/Anthropic-Cybersecurity-Skills) | daily 767 stars today, API 약 3.0만 stars, Apache-2.0 | 보안 스킬 카탈로그는 [SkillSpector 공급망 분석](/posts/github-trending-skillspector-agent-skill-security/)과 에이전트 스킬 거버넌스 클러스터에 이미 자리가 있다. |
| [NautilusTrader](https://github.com/nautechsystems/nautilus_trader) | daily 79 stars today, API 약 2.6만 stars, LGPL-3.0, v1.231.0 | 결정론적 트레이딩 엔진은 장기 가치가 있지만 [에이전트형 금융 리서치 거버넌스](/posts/github-trending-vibe-trading-agentic-finance-governance/)와 별개로 깊은 도메인 검증이 필요하다. |

수치는 모두 확인 시점의 스냅샷이며 이후 달라진다. OpenViking의 최근 커밋에는 세션 간 메모리 갱신·부분 삭제 신뢰성, 엔터티 URI 대소문자 정규화, URI 검증 수정이 포함됐다. 공개 이슈에는 임베딩 차원 절단 누락과 대량 리소스의 배치·스트리밍 가져오기 요청이 보였다. 이는 “컨텍스트 데이터베이스”가 데모를 넘어가면 데이터 정규화, 삭제 일관성, 대량 수집이 핵심 운영 문제가 된다는 신호다.

## 먼저 구분할 것: 상태, 기억, 지식은 같은 데이터가 아니다

에이전트가 다루는 컨텍스트를 한 저장소에 넣더라도 의미는 세 종류로 나눠야 한다.

1. **실행 상태(state)**는 현재 작업 단계, 재시도 횟수, 도구 호출 결과처럼 워크플로를 재개하는 데 필요한 값이다. 정확한 체크포인트와 동시성 제어가 우선이다.
2. **장기 기억(memory)**은 사용자의 선호, 이전 결정, 반복되는 작업 습관처럼 다음 세션에 재사용할 정보다. 추출 근거, 신뢰도, 만료와 수정이 중요하다.
3. **외부 지식(knowledge)**은 문서, 코드, 티켓, 이메일처럼 원본 시스템에 권한과 버전이 있는 자료다. 원본 ACL 동기화와 출처 추적이 필요하다.

이 구분을 하지 않으면 “지난 배포에서 실패했다”는 일시적 사건이 영구 선호처럼 저장되거나, 사용 권한을 잃은 문서의 요약이 장기 기억에 남는다. 장기 실행 에이전트의 체크포인트와 재개 문제는 [DeerFlow 운영 분석](/posts/github-trending-deer-flow-long-horizon-agent-workflow/)의 영역이고, 코드 구조를 지속적으로 색인하는 문제는 [코드베이스 기억 계층](/posts/github-trending-codebase-memory-mcp-code-intelligence-layer/)의 영역이다. 제품 메모리 계층은 이들과 연결되지만 책임까지 섞어서는 안 된다.

![AI 메모리 계층의 기준 아키텍처](https://heracles-jo.github.io/assets/img/posts/github-trending-ai-memory-supermemory/architecture.svg)

## Supermemory: 제품 API와 사용자 프로필 중심

Supermemory의 공식 README는 대화에서 사실을 추출하고, 안정적 사실과 최근 활동으로 사용자 프로필을 만들며, RAG와 기억을 한 질의에서 검색하는 흐름을 전면에 둔다. Google Drive·Gmail·Notion·OneDrive·GitHub 커넥터와 PDF·이미지 OCR·영상 전사·코드 AST 인식 처리를 하나의 API 경험으로 묶는 것도 특징이다. 제품 팀 입장에서는 벡터 DB, 임베딩 파이프라인, 청킹 전략을 각각 조립하지 않고 빠르게 가설을 시험할 수 있다.

2026년 8월 20일 GitHub API 스냅샷에서 저장소는 약 2.9만 stars, 2.5천 forks, 182개의 열린 이슈·PR, MIT 라이선스로 확인됐다. 최신 공개 릴리스는 8월 17일의 `server-v0.0.8`이고, 최근 커밋에는 MCP 응답 정리와 API 키 Bearer 인증 지원이 포함됐다. 6월 글에 적었던 초기 release candidate 상태에서 서버 릴리스가 진행됐으므로, 이전 수치를 그대로 유지하지 않았다.

Supermemory가 잘 맞는 검색 의도는 명확하다. **앱에 사용자별 장기 기억과 커넥터를 빠르게 붙이고 싶은 팀**이다. `containerTag`로 프로젝트·고객·사용자 범위를 나누고, 프로필과 관련 기억을 함께 가져오는 API는 제품 통합이 단순하다. 반면 간단한 API 뒤에 숨은 추출·모순 해결·삭제 동작을 조직의 정책과 일치시키는 검증은 별도로 해야 한다. README의 벤치마크와 지연 시간 주장은 공급자가 제시한 결과이므로 자사 대화와 권한 모델로 재현해야 한다.

## OpenViking: 탐색 가능한 가상 파일시스템 중심

OpenViking은 메모리, 리소스, 스킬을 `viking://` URI 아래의 가상 파일시스템으로 표현한다. 에이전트는 불투명한 벡터 검색 API만 호출하는 대신 `ls`, `tree`, `find`처럼 디렉터리를 탐색한다. 각 항목은 L0 한 문장 요약, L1 개요, L2 원문 세 계층으로 처리되고 작업에 필요한 깊이만 로드된다. 검색은 높은 점수의 디렉터리를 먼저 찾고 하위 경로로 내려가며, 어떤 경로를 거쳤는지 trajectory를 남긴다.

이 구조의 장점은 **검색 실패를 관찰 가능한 탐색 실패로 바꾸는 것**이다. 잘못된 답이 나왔을 때 “벡터 검색이 이상했다”에서 끝나지 않고, 어느 디렉터리를 선택했고 어떤 요약 단계에서 관련 자료를 제외했는지 조사할 단서가 생긴다. 세션 commit 이후 사용자 선호와 에이전트 경험을 비동기로 추출하는 방식도 실행 로그와 장기 기억 사이의 경계를 명시한다.

다만 계층형 요약은 공짜가 아니다. 쓰기 시점에 L0·L1을 생성하는 모델 비용이 들고, 원문이 바뀌면 상위 요약을 다시 만들고 일관성을 유지해야 한다. 디렉터리 구조가 실제 업무 경계를 잘못 반영하면 탐색 경로 자체가 편향된다. 최근 URI 정규화와 부분 삭제 수정이 중요한 이유도 여기에 있다. 파일처럼 보이는 추상화가 편리해도 내부 데이터베이스의 참조 무결성, 비동기 작업, 임베딩 차원, 재색인 문제는 사라지지 않는다.

OpenViking 저장소는 AGPL-3.0이다. README는 오픈소스 판을 기능 제한 없이 자체 운영할 수 있다고 설명하지만, 네트워크로 서비스를 제공하거나 수정본을 조직 제품에 통합할 때의 의무는 MIT인 Supermemory와 다르다. 법무 검토 없이 “둘 다 오픈소스”로 묶어서는 안 된다. 관리형 SaaS, 자체 VPC, 폐쇄망 상용판의 운영·지원 경계도 기술 선택과 별도로 확인해야 한다.

## 두 도구를 기능표가 아니라 통제면으로 비교하기

![AI 메모리 도구 선택 기준](https://heracles-jo.github.io/assets/img/posts/github-trending-ai-memory-supermemory/decision-matrix.svg)

| 비교 기준 | Supermemory | OpenViking | 직접 구축 시 확인할 것 |
|---|---|---|---|
| 중심 추상화 | 사용자 프로필, memory/RAG API, 커넥터 | `viking://` 파일시스템, L0/L1/L2, 탐색 trajectory | 데이터 유형별 스키마와 provenance |
| 검색 설명 가능성 | 검색 결과와 프로필을 제품 API로 소비 | 디렉터리 탐색 경로를 관찰·디버그 | query log, reranker 근거, 평가 세트 |
| 통합 속도 | SDK·MCP·플러그인과 단일 API가 강점 | CLI·MCP·에이전트 통합과 자체 서버가 강점 | 인증, 재시도, 백필, 마이그레이션 비용 |
| 권한 경계 | container/project 범위와 커넥터 ACL 검증 필요 | URI·사용자 디렉터리·리소스별 정책 검증 필요 | 원본 ACL의 질의 시점 재검사 |
| 라이선스 | MIT | AGPL-3.0 | 배포 형태와 수정·소스 제공 의무 |
| 주요 실패 모드 | 잘못 추출한 프로필, 커넥터 권한 지연, 삭제 누락 | 오래된 계층 요약, 잘못된 디렉터리 경로, URI 불일치 | 파생 데이터 고아화와 재색인 실패 |

선택 기준은 “기능이 더 많은가”가 아니다. 사용자 프로필과 커넥터를 제품에 빨리 붙이는 것이 목적이면 Supermemory의 API 중심 모델이 자연스럽다. 에이전트가 컨텍스트를 단계적으로 탐색하고 그 경로를 조사하는 것이 중요하면 OpenViking의 파일시스템 모델이 매력적이다. 규제 데이터나 복잡한 사내 권한이 핵심이면 두 제품을 바로 고르기 전에 원본 ACL, 삭제 증명, 리전, 감사 로그를 만족하는지부터 확인해야 한다.

## 실패 모드: 기억이 많을수록 답이 좋아진다는 착각

### 잘못된 사실이 장기 프로필로 승격된다

사용자의 농담, 일회성 요청, 모델의 추론이 안정적 사실로 저장될 수 있다. “이번 작업에서는 Python을 쓰자”가 “이 사용자는 항상 Python을 선호한다”로 바뀌면 이후 제안이 편향된다. 자동 추출 기억에는 원문 링크, 생성 시각, 추출기 버전, 신뢰도, 확인 주체와 만료 정책이 필요하다. 사용자가 보고 수정할 수 없는 기억은 개인화 기능이 아니라 숨은 정책이 된다.

### 권한을 잃어도 파생 기억이 남는다

Drive 문서 접근 권한을 회수해도 그 문서에서 추출한 요약, 엔터티, 사용자 프로필이 남을 수 있다. 검색 시 원본 권한을 다시 확인하고, 삭제·권한 회수 이벤트가 chunk뿐 아니라 embedding, 요약, 캐시, 백업, 평가 데이터까지 전파되는지 시험해야 한다. “원문을 지웠다”와 “모델에 제공될 모든 파생 데이터를 지웠다”는 다른 주장이다.

### 컨텍스트 오염이 도구 실행으로 이어진다

외부 문서의 프롬프트 인젝션이 기억으로 승격되면 한 번의 검색 오류가 여러 세션에 반복될 수 있다. 특히 스킬과 기억을 같은 네임스페이스에서 다룰 때 설명 데이터와 실행 지침을 구분해야 한다. [시스템 프롬프트 유출과 권한 경계](/posts/github-trending-system-prompts-leaks-ai-governance/)에서 다룬 것처럼 자연어 정책은 IAM, 샌드박스, 승인 게이트를 대체하지 못한다. 기억은 도구 선택의 힌트가 될 수 있지만 고위험 실행의 최종 권한 근거가 되어서는 안 된다.

### 비용이 저장에서 평가로 이동한다

계층 요약, 프로필 추출, 임베딩, 재색인, reranking에는 지속 비용이 든다. 더 큰 비용은 품질 평가다. 최신 정보를 놓친 비율, 오래된 기억을 사용한 비율, 권한 밖 자료가 검색된 비율은 일반적인 API uptime으로 알 수 없다. 메모리 계층을 도입하면 토큰을 줄일 수 있지만, 데이터 품질과 삭제 검증을 운영할 사람이 필요하다.

## 2주 PoC: recall 점수 하나로 결정하지 않는다

PoC는 실제 사용 사례 3개 정도로 좁힌다. 예를 들어 고객 지원의 환경 기억, 개발 도구의 프로젝트 규칙, 내부 비서의 문서 검색을 섞지 말고 하나를 고른다. 동일한 대화·문서·권한 변경 시나리오를 stateless RAG, 후보 메모리 도구, 필요하면 직접 구축 baseline에 반복 적용한다.

측정 항목은 다음과 같이 구성할 수 있다.

- **정확성**: 필요한 사실을 찾은 recall뿐 아니라 잘못된 기억이 답에 사용된 오염률을 측정한다.
- **신선도**: 사실 변경 후 이전 값이 검색에서 사라질 때까지 걸리는 시간을 잰다.
- **삭제 완결성**: 사용자 삭제와 원본 ACL 회수 후 원문·요약·embedding·프로필·캐시를 다시 검색한다.
- **격리**: 사용자, 프로젝트, 고객 tenant를 바꿔 교차 검색과 추론 누출을 시험한다.
- **추적 가능성**: 답변에 사용한 원본과 검색·탐색 경로를 운영자가 재구성할 수 있는지 확인한다.
- **성능과 비용**: p50/p95 검색 지연, 요청당 입력 토큰, 쓰기 시 요약 비용, 백필·재색인 시간을 함께 본다.
- **복구성**: 임베딩 공급자 장애, 비동기 추출 실패, 중복 이벤트, 부분 삭제 중단 후 일관성을 회복하는지 검증한다.

성공 기준도 먼저 정해야 한다. 예를 들어 권한 밖 검색은 0건이어야 하고, 삭제 요청 후 정해진 시간 안에 모든 온라인 파생 데이터가 검색되지 않아야 하며, 오래된 사실 사용률은 허용 임계치 아래여야 한다. 평균 recall이 높아도 이 안전 기준을 넘지 못하면 운영 전환을 보류한다.

## 도입 결론: 메모리 엔진보다 기억 정책을 먼저 고른다

Supermemory와 OpenViking은 같은 문제를 서로 다른 추상화로 푼다. Supermemory는 사용자 프로필, 커넥터, RAG를 제품 API로 빠르게 통합하는 데 초점을 둔다. OpenViking은 기억·리소스·스킬을 탐색 가능한 파일시스템으로 묶고 계층형 로딩과 검색 trajectory를 강조한다. 하나가 보편적으로 우월한 것이 아니라 제품 통합 속도와 탐색 통제 중 어느 쪽이 병목인지에 따라 선택이 달라진다.

더 중요한 것은 도구 밖의 질문이다. 무엇을 기억하지 않을 것인가, 누가 기억을 고칠 수 있는가, 원본 권한이 사라지면 파생 기억을 어떻게 제거할 것인가, 검색 결과가 도구 실행 권한으로 승격되지 않게 어떻게 막을 것인가. 이 질문에 답하지 못한 채 메모리 엔진부터 연결하면 컨텍스트는 자산보다 부채가 되기 쉽다.

AI 에이전트 메모리의 실무 도입 기준은 “얼마나 오래 기억하는가”가 아니다. **필요한 정보만 최신 권한 안에서 불러오고, 잘못된 기억을 설명·수정·삭제하며, 장애 시 기억 없이도 안전하게 축소 운영할 수 있는가**다. 그 통제면을 먼저 설계한 팀에게만 Supermemory나 OpenViking의 편의성이 장기적인 제품 품질로 이어진다.
