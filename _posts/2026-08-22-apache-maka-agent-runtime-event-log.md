---
title: "AI 에이전트 감사 로그 설계: Apache Maka 런타임 이벤트 모델"
description: "Apache Maka의 append-only 런타임 이벤트 로그를 해부해 에이전트 실행 이력, 컨텍스트 압축, 장애 복구와 권한 감사의 설계 기준을 제시한다."
author: heracles-jo
date: 2026-08-22 07:10:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [apache-maka, ai-agent, event-sourcing, audit-log, agent-runtime, local-first]
image:
  path: https://heracles-jo.github.io/assets/img/posts/apache-maka-agent-runtime-event-log/cover.svg
  alt: "Apache Maka의 런타임 이벤트 로그에서 세션 화면, 모델 컨텍스트, 복구 상태가 투영되는 구조"
---

AI 에이전트가 답변만 만들 때는 채팅 기록으로 충분해 보인다. 그러나 파일을 수정하고 셸 명령을 실행하며 권한을 요청하는 순간 기록의 의미가 달라진다. “마지막 답이 무엇이었나”뿐 아니라 **어떤 모델 메시지가 어떤 도구 호출을 만들었고, 사용자가 무엇을 허용했으며, 프로세스가 중단되기 전에 어떤 부작용이 확정됐는가**를 설명할 수 있어야 한다. 채팅 transcript와 애플리케이션 로그를 사후에 맞춰 보는 방식으로는 이 인과관계를 안정적으로 복원하기 어렵다.

2026년 8월 22일 07:14 KST 공개 스냅샷에서 [apache/maka](https://github.com/apache/maka)는 GitHub Trending daily에 **141 stars today**로 표시됐다. GitHub API에서는 약 **2.0k stars**, **240 forks**, **282 open issues/PR**, Apache-2.0 라이선스, 8월 21일의 최신 push와 8월 18일 공개된 [v0.1.11](https://github.com/apache/maka/releases/tag/v0.1.11)을 확인했다. 저장소는 2026년 5월 생성된 Apache Incubator 프로젝트이며, README는 macOS Apple Silicon 데스크톱 빌드를 초기 공개 릴리스로 명시한다. 수치와 상태는 확인 시점의 스냅샷이고 이후 바뀔 수 있다.

이 글의 질문은 “Maka가 다른 AI 채팅 앱보다 좋은가”가 아니다. **에이전트의 대화·도구·권한·종료 사실을 하나의 정렬된 원장으로 남기고, UI와 다음 모델 입력을 그 원장에서 파생시키면 무엇이 달라지는가**다. 이는 일반적인 로그 수집보다 event sourcing, crash consistency, 증거 보존에 가까운 문제다.

![에이전트 이벤트 원장과 투영 구조](https://heracles-jo.github.io/assets/img/posts/apache-maka-agent-runtime-event-log/architecture.svg)

## 후보 비교: 기능 목록보다 독립적인 검색 의도를 골랐다

이번 실행 환경에서는 Search Console과 Analytics의 검색어·노출·CTR 데이터에 접근할 수 없었다. 따라서 데이터를 봤다고 가정하지 않고, GitHub Trending daily 후보와 기존 93개 글의 제목·description·저장소 링크·중심 논지를 대조했다.

| 후보 | 확인 시점 신호 | 콘텐츠 판단 |
|---|---:|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) | 3,368 stars today, MIT, 활발한 push | 에이전트 스킬과 개발 절차는 기존 스킬 엔지니어링·공급망 글의 검색 의도와 겹친다. |
| [mahlernim/google-timeline-visualizer](https://github.com/mahlernim/google-timeline-visualizer) | 1,040 stars today, MIT, Kotlin | 로컬 위치 데이터 시각화는 유효하지만 최근 로컬 퍼스트 사진·주변기기 거버넌스 글과 독자 질문이 인접한다. |
| [modular/modular](https://github.com/modular/modular) | 905 stars today, 약 28.7k stars, Mojo | AI 컴파일러·MAX 런타임은 장기 가치가 크지만 별도의 성능 검증 환경이 필요한 큰 주제다. |
| [santifer/career-ops](https://github.com/santifer/career-ops) | 918 stars today, MIT | AI 구직 자동화는 검색 수요가 있으나 에이전트 워크플로 일반론과 개인정보 위험으로 논지가 분산된다. |
| [apache/maka](https://github.com/apache/maka) | 141 stars today, v0.1.11, Apache-2.0 | 실행 사실과 모델 컨텍스트를 분리하는 log-first runtime이 **AI 에이전트 감사 로그 설계**라는 독립적인 의도에 답한다. |

기존 글에는 위험 명령을 실행 전에 막는 [dcg 도입 기준](/posts/ai-agent-destructive-command-guard/), 병렬 변경 후보를 분리하는 [Orca와 Git worktree 설계](/posts/orca-parallel-ai-coding-agents/), 모델 호출 경로를 통제하는 [Switchyard LLM 라우팅 거버넌스](/posts/github-trending-switchyard-llm-routing-governance/)가 있다. Maka는 그 글들을 반복하지 않는다. 사전 차단이나 작업 공간 격리 뒤에도 남는 질문, 즉 **실제로 일어난 일을 어떤 데이터 모델로 보존할 것인가**에 초점을 둔다.

## “Log is the Runtime”은 디버그 로그와 무엇이 다른가

[Maka Backend Architecture](https://github.com/apache/maka/blob/main/ARCHITECTURE.md)는 Desktop, TUI, CLI, bot, evaluation client가 모두 하나의 `Runtime Host`에 실행을 요청하고, 별도의 두 번째 runtime을 소유하지 않는다고 설명한다. Runtime Host가 Session과 Turn ID, 에이전트 수명주기, continuation, tool, permission, event를 소유한다. 그 아래 `SessionManager`와 `AgentRun`이 실행을 감싸고, model/tool loop가 만든 사실은 `Runtime Event Log`로 들어간다.

여기서 이벤트는 코드가 실행된 뒤 사람이 읽으라고 남기는 문자열이 아니다. 공식 [Runtime core 문서](https://github.com/apache/maka/blob/main/docs/architecture/runtime-core-architecture-draft.md)는 user message, model response, thinking, function call과 response, permission action, usage, terminal status를 **strongly typed fact**로 취급한다. 이벤트에는 순서와 시각, 작성 주체, 부분 스트림인지 확정 사실인지, tool call과 result를 묶는 안정적 ID, 실행 종료 상태가 들어간다.

이 원장이 semantic source of truth가 되면 세션 화면, 다음 모델 호출의 history, 실행 결과 상태, 복구 판단은 모두 projection이 된다. UI가 잘못 렌더링되거나 검색 색인이 깨져도 원장에서 다시 만들 수 있다. 반대로 UI transcript를 원본으로 삼으면 접힌 tool result, 스트리밍 중 교체된 조각, 권한 팝업 상태처럼 화면 밖의 의미를 복원하기 어렵다.

중요한 제한도 있다. Maka 문서는 semantic replay와 bit-exact replay를 구분한다. 이벤트 원장만으로 대화·도구·권한의 의미는 재구성할 수 있지만, 특정 provider에 보낸 HTTP 요청 바이트를 완전히 재현하는 것은 아니다. 당시 system prompt, tool schema, 모델 버전, provider option, context-selection 정책까지 고정해야 byte-level 재현이 가능하다. “로그가 있으니 같은 결과가 다시 나온다”는 주장은 과장이다. 올바른 약속은 **무슨 일이 일어났는지 의미 수준에서 추적할 기반이 있다**는 것이다.

## 컨텍스트 압축은 기록 삭제가 아니라 손실 있는 뷰다

장기 실행 에이전트는 언젠가 context window 한계에 닿는다. 흔한 구현은 오래된 대화를 요약한 뒤 원문을 버리거나, 최근 메시지만 남긴다. 실행 속도에는 도움이 되지만 감사와 복구에는 치명적일 수 있다. 요약 과정에서 정확한 명령, 실패한 tool result, 사용자가 붙인 제약이 사라지면 이후에는 무엇이 누락됐는지조차 알 수 없다.

Maka의 [compaction architecture](https://github.com/apache/maka/blob/main/docs/architecture/llm-compaction-events-log-projection-draft.md)는 이를 명시적으로 분리한다.

```text
canonical history = RuntimeEvents[0..n]
working context    = compact checkpoint + uncovered raw tail + current turn
```

`HistoryCompactCheckpoint`는 단순 요약문이 아니라 어떤 session의 어느 event prefix까지 덮는지, source digest가 무엇인지, 이전 checkpoint와 어떤 관계인지 기록한 durable projection이다. 다음 모델은 checkpoint와 최근 raw tail만 볼 수 있지만, 원장은 그대로 남아 audit, history search, 새로운 projection에 다시 쓰인다. 데이터베이스에 비유하면 checkpoint는 WAL을 잘라 낸 결과가 아니라 재생성 가능한 materialized view에 가깝다.

이 분리는 [코드베이스 기억 계층](/posts/github-trending-codebase-memory-mcp-code-intelligence-layer/)에서 다룬 “검색 가능한 지식”과도 다르다. 기억 계층은 다시 찾을 문맥을 구조화한다. 런타임 원장은 실행 당시의 증거 순서와 commit boundary를 보존한다. 둘을 하나의 벡터 검색 저장소로 합치면 검색 편의는 높아져도, 검색 결과가 빠진 상태에서 완전한 이력이라고 오인할 위험이 있다.

## 실패 모드: append-only라는 이름만으로 감사 가능해지지 않는다

첫 번째 실패는 **부분 기록**이다. tool call은 저장됐지만 result가 없거나, 외부 API는 성공했는데 로컬 terminal event를 쓰기 전에 프로세스가 죽을 수 있다. Maka README는 안전 경계에서의 continuation을 opt-in으로 두며, 부작용 결과가 불명확한 작업을 자동 재시도하지 않고 parked 상태로 남긴다고 설명한다. 이것이 중요한 이유는 `create_payment`나 배포 명령을 “결과를 못 읽었다”는 이유로 다시 실행하면 중복 부작용이 생기기 때문이다. 복구 시스템의 목표는 무조건 계속하는 것이 아니라 **확정·미확정·실패를 구분해 중복 실행을 막는 것**이어야 한다.

두 번째는 **원장과 projection의 원자성**이다. 이벤트 append는 성공했는데 session read model 갱신이 실패할 수 있고, 반대 순서라면 화면에는 성공으로 보이지만 근거 이벤트가 없을 수 있다. canonical append를 먼저 확정하고 projection은 재생 가능하게 만들며, event ID와 run/turn ID에 uniqueness를 강제해야 한다. 장애 주입 테스트에서는 SQLite commit 직전·직후, tool result 수신 직후, terminal event 기록 전을 각각 중단해 재시작 결과를 비교해야 한다.

세 번째는 **무제한 보존 비용**이다. 모델의 thinking, 큰 파일 출력, 바이너리 artifact, 반복되는 test log를 모두 원장에 넣으면 SQLite 크기와 백업 시간이 급증하고 민감정보 노출 면적도 넓어진다. Maka는 artifact payload를 일반 파일로 분리하고 metadata를 SQLite가 소유하며, tool result pruning과 history compaction을 구분한다. 조직은 event class별 보존 기간, payload 외부화 기준, 암호화, 삭제 요구 처리, 백업 복구 RTO를 별도로 정해야 한다. append-only는 “영원히 삭제 금지”와 같은 뜻이 아니다. 규정상 삭제가 필요하면 원본 payload를 암호학적으로 폐기하거나 tombstone과 별도 보존 정책을 설계해야 한다.

네 번째는 **스키마 진화**다. 이벤트 타입이 바뀌면 과거 원장을 새 projection 코드가 읽지 못할 수 있다. 버전 필드, tolerant decoder, migration fixture, 오래된 원장을 대상으로 한 replay test가 필요하다. UI가 최신 이벤트만 예쁘게 보여 주는 테스트로는 부족하다.

## 로컬 퍼스트의 보안 경계를 과대평가하면 안 된다

Maka README는 session, setting, run record가 기본적으로 로컬에 남고 사용자가 cloud API, local model, compatible gateway를 선택한다고 설명한다. 그러나 “데이터가 로컬에 있다”와 “에이전트 실행이 격리됐다”는 다른 명제다. 공식 [Security Policy](https://github.com/apache/maka/blob/main/SECURITY.md)는 적대적 LLM에 대한 유일한 강제 경계가 OS라고 명시한다. permission engine, secret redaction, URL normalization은 유용한 UX 안전장치지만 containment가 아니다.

확인 시점의 루트 보안 정책은 tool이 기본적으로 별도 process나 container에서 실행되지 않으며, macOS Seatbelt transformer가 코드에 있어도 현재 product composition이 command execution을 그 경로로 보내지 않는다고 밝힌다. 따라서 로컬 프로젝트, SSH key, cloud credential, Docker socket에 접근 가능한 계정으로 Maka를 실행하면 그 권한이 trust envelope가 된다. 민감한 작업은 비관리자 OS 계정, 짧은 수명 자격증명, 별도 개발 환경, 네트워크 egress 제한을 먼저 적용해야 한다.

자격증명도 현실적으로 봐야 한다. README와 보안 정책은 API/OAuth material이 로컬 plaintext JSON에 저장되고 POSIX 디렉터리 `0700`, 파일 `0600` 및 OS 계정 경계로 보호된다고 설명한다. renderer에는 cleartext token을 돌려주지 않지만, 같은 OS 계정 권한을 얻은 악성 프로세스까지 막는 vault는 아니다. 로컬 퍼스트는 SaaS 동기화를 피하는 선택이지 endpoint compromise를 해결하는 암호화 경계가 아니다.

또한 model provider를 cloud API로 설정하면 prompt와 선택된 context는 네트워크를 나간다. [Switchyard 글](/posts/github-trending-switchyard-llm-routing-governance/)에서 설명했듯 model route가 바뀌면 데이터 처리 지역과 보존 정책도 달라질 수 있다. “런타임 DB는 로컬”이라는 문구만 보고 inference data flow를 생략해서는 안 된다.

![감사 가능성과 보안 경계를 나눈 Maka 도입 판단표](https://heracles-jo.github.io/assets/img/posts/apache-maka-agent-runtime-event-log/decision.svg)

## 대안 비교: 무엇을 원본으로 둘 것인가

| 방식 | 장점 | 놓치기 쉬운 문제 | 적합한 단계 |
|---|---|---|---|
| 채팅 transcript 저장 | 구현과 사용자 이해가 단순하다 | 권한, 부분 스트림, tool correlation, terminal fact가 약하다 | 답변 중심 보조 도구 |
| OpenTelemetry trace | 서비스 간 지연·오류·span 연결에 강하다 | sampling과 retention 때문에 실행 의미의 완전한 원장으로 쓰기 어렵다 | 관측성과 성능 분석 |
| 애플리케이션 로그 + SIEM | 기존 운영 체계와 연결하기 쉽다 | 자유 형식 문자열, PII redaction, causal order 불일치 | 보안 탐지와 중앙 검색 |
| event-sourced agent runtime | projection 재구축, semantic replay, 명시적 종료 상태가 가능하다 | 스키마·보존·migration·복구 테스트 비용이 크다 | 장기 실행·도구 실행 에이전트 |

선택지는 배타적이지 않다. Runtime Event Log는 실행 의미의 원본, OpenTelemetry는 분산 성능과 서비스 경계, SIEM은 보안 상관 분석, artifact store는 큰 payload의 보존을 맡을 수 있다. 중요한 것은 서로 다른 저장소가 모두 “진실”이라고 주장하지 않게 하는 것이다. event ID, run ID, trace ID를 연결하되 어떤 시스템이 권한 결정과 부작용 결과의 canonical authority인지 정해야 한다.

## 2주 PoC에서 측정할 것은 답변 품질만이 아니다

Maka는 초기 릴리스이고 데이터 형식과 CLI가 바뀔 수 있다고 스스로 경고한다. 즉시 표준 도구로 배포하기보다, 비민감 저장소와 별도 OS 계정에서 다음을 검증하는 편이 현실적이다.

1. **완전성**: 100개의 대표 작업에서 user message, model response, tool call/result, permission decision, terminal fact가 안정적 ID로 연결되는 비율을 측정한다.
2. **장애 복구**: 모델 스트리밍, 파일 write, shell 종료, SQLite commit 경계에서 프로세스를 강제 종료하고 duplicate side effect와 유실 event를 확인한다.
3. **projection 재구축**: read model과 검색 색인을 지운 뒤 원장만으로 같은 session 상태를 복원할 수 있는지 비교한다.
4. **compaction 충실도**: 긴 세션에서 checkpoint가 덮은 event 범위와 raw tail을 검사하고, 중요한 제약·실패 원인이 다음 모델 입력에서 사라지는 비율을 본다.
5. **저장 비용**: turn당 DB 증가량, 큰 tool result 비중, 백업 시간, restore 시간, artifact 무결성 검사 시간을 기록한다.
6. **권한 증거**: 승인 화면의 사용자 선택과 실제 tool 실행 사이에 누락·순서 역전이 없는지 확인한다. 승인 로그가 권한 강제를 대신한다고 해석하지 않는다.
7. **민감정보**: secret fixture를 prompt, file, environment, tool result에 넣고 renderer, DB, artifact, backup, error log 중 어디에 남는지 조사한다.
8. **업그레이드**: v0.1.x에서 만든 테스트 workspace를 다음 버전으로 열고 migration 전후 event 수, session 수, 복구 가능성을 비교한다.

PoC의 성공 기준은 “에이전트가 코드를 잘 고쳤다”가 아니다. 같은 작업을 다시 조사할 때 사람이 UI와 셸 history를 추측하지 않고, **어떤 사실이 확정됐고 어떤 결과가 미확정인지 제한 시간 안에 설명할 수 있는가**다. 장기 실행이나 병렬 실행을 검토한다면 [Orca 운영 글](/posts/orca-parallel-ai-coding-agents/)의 후보별 base SHA·검증 artifact와 이 원장을 연결해 변경 provenance까지 확인해야 한다.

## 도입 판단: 로그는 통제가 아니라 통제를 검증하는 토대다

Apache Maka의 가장 흥미로운 지점은 또 하나의 desktop agent가 아니라, “context is not history”라는 구분을 runtime 구조에 넣었다는 점이다. 모델은 context budget 때문에 일부를 잊어야 하지만 운영자는 실행 증거까지 잃어서는 안 된다. canonical event log와 lossy projection을 분리하면 UI, 검색, compaction, recovery 정책을 바꾸면서도 과거 실행 의미를 다시 해석할 가능성이 생긴다.

다만 append-only event log가 안전한 agent를 자동으로 만들지는 않는다. 과도한 OS 권한, plaintext credential의 endpoint 경계, 불명확한 외부 부작용, schema migration 실패, 무제한 retention은 그대로 남는다. 로그는 잘못된 실행을 막는 방화벽이 아니라, 방화벽과 승인 절차가 실제로 작동했는지 검증하는 증거 기반이다.

따라서 Maka를 지금 검토할 팀은 화려한 멀티 에이전트 기능보다 세 가지를 먼저 물어야 한다. 우리 실행의 canonical fact는 무엇인가, context 압축 뒤에도 감사할 원본이 남는가, crash 직전의 외부 부작용을 안전하게 미확정으로 표현할 수 있는가. 이 질문에 답할 수 있다면 에이전트는 단순한 채팅 세션을 넘어 운영 가능한 runtime이 된다. 답할 수 없다면 모델 성능이 아무리 좋아도 장애가 난 날에는 다시 추측으로 돌아가게 된다.

> 1차 출처: [apache/maka](https://github.com/apache/maka), [README](https://github.com/apache/maka/blob/main/README.md), [Backend Architecture](https://github.com/apache/maka/blob/main/ARCHITECTURE.md), [Runtime core](https://github.com/apache/maka/blob/main/docs/architecture/runtime-core-architecture-draft.md), [Compaction architecture](https://github.com/apache/maka/blob/main/docs/architecture/llm-compaction-events-log-projection-draft.md), [Security Policy](https://github.com/apache/maka/blob/main/SECURITY.md), [Workspace privacy context](https://github.com/apache/maka/blob/main/docs/workspace-privacy-context.md), [v0.1.11](https://github.com/apache/maka/releases/tag/v0.1.11). Trending·저장소 수치는 2026년 8월 22일 07:14 KST 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
