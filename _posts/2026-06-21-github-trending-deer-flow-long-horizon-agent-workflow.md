---
title: "DeerFlow와 장기 실행 에이전트 워크플로의 조건"
description: "bytedance/deer-flow의 lead agent·sub-agent·sandbox·memory·checkpoint 구조를 바탕으로 장기 실행 AI 에이전트의 아키텍처, 운영 통제, 실패 복구와 도입 기준을 정리한다."
author: heracles-jo
date: 2026-06-21 07:35:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [deer-flow, governance, llmops, ai-agents, automation, workflow]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-deer-flow-long-horizon-agent-workflow/cover.svg
  alt: "DeerFlow형 장기 실행 에이전트가 조사, 계획, 실행, 검증, 사람 승인 단계를 순환하는 구조"
---

GitHub Trending에서 [bytedance/deer-flow](https://github.com/bytedance/deer-flow)가 눈에 띈 이유는 “또 하나의 에이전트 프레임워크”라서가 아니다. DeerFlow는 몇 번의 도구 호출로 끝나는 챗봇보다 **수 분에서 수 시간 동안 조사하고, 코드를 실행하고, 파일을 만들고, 하위 에이전트에 일을 나누는 작업 시스템**에 가깝다. 이런 시스템의 성패는 모델이 한 번에 얼마나 영리한 답을 내는지가 아니라, 긴 실행을 얼마나 관찰 가능하고 중단 가능하며 다시 검증할 수 있게 만드는지에 달려 있다.

이 글은 2026년 6월의 Trending 관찰을 출발점으로 삼되, 2026년 11월 17일 기준 DeerFlow 공식 README, 아키텍처 문서와 2.1·2.2 릴리스 노트를 다시 확인해 보강했다. 현재 문서에서 DeerFlow 2.x는 초기 Deep Research 코드의 점진적 확장이 아니라 처음부터 다시 만든 super-agent harness로 설명된다. 따라서 과거 1.x 사용 경험이나 예전 예제만으로 현재 구조를 평가하면 안 된다. 중요한 판단 대상은 “리서치 봇의 답변 품질”이 아니라 lead agent, sub-agent, sandbox, memory, skill, Gateway, checkpoint가 만든 운영 경계다.

![DeerFlow 장기 실행 워크플로](https://heracles-jo.github.io/assets/img/posts/github-trending-deer-flow-long-horizon-agent-workflow/architecture.svg)

## 장기 실행 에이전트에서 바뀌는 실패의 단위

짧은 LLM 작업은 입력과 출력 사이가 가깝다. 요약이 틀리면 원문과 비교하고, 코드 한 조각이 실패하면 테스트를 다시 돌리면 된다. 반면 long-horizon agent는 검색 결과를 전제로 계획을 만들고, 그 계획을 바탕으로 하위 작업을 나누고, 여러 도구의 결과를 다시 다음 판단에 사용한다. 초반의 작은 오류가 뒤 단계의 합리적인 행동을 연쇄적으로 잘못 만들 수 있다.

예를 들어 시장 조사 에이전트가 오래된 가격표를 최신 자료로 오인하면, 이후 비교표와 비용 모델과 도입 권고가 모두 정돈된 형태로 틀릴 수 있다. 코드 변경 에이전트가 잘못된 base branch를 읽으면 수정 자체는 문법적으로 정확해도 배포할 수 없는 결과가 나온다. 브라우저 에이전트가 로그인 상태를 오해하면 동일한 폼을 반복 제출하거나 외부 시스템에 중복 레코드를 만들 수 있다. 장기 실행에서 위험한 것은 눈에 띄는 예외보다 **오류를 포함한 채 계속 전진하는 조용한 성공**이다.

그래서 에이전트의 다음 병목은 실행 시간이 아니라 통제다. [Agent Skills를 작업 절차로 다룬 글](/posts/github-trending-agent-skills-engineering-workflow/)에서 강조했듯, 강한 에이전트일수록 더 자유로운 프롬프트보다 명시적인 단계, 허용 도구와 검증 규칙이 필요하다. DeerFlow는 이 문제를 하나의 거대한 prompt가 아니라 런타임과 서비스 구조로 풀려고 한다.

## DeerFlow 2.x 아키텍처: 프롬프트가 아니라 실행 하네스

공식 [Architecture 문서](https://github.com/bytedance/deer-flow/blob/main/docs/ARCHITECTURE.md)는 DeerFlow를 LangGraph 기반의 open-source super-agent harness로 정의한다. 배포 토폴로지는 Nginx, FastAPI Gateway, Next.js frontend, 선택적 provisioner로 나뉘며, Gateway 안의 agent runtime이 실행 수명주기를 관리한다. backend 내부도 재사용 가능한 harness와 애플리케이션 계층을 분리한다. 이 구분은 장기 실행 기능을 제품 UI에 묶인 기능이 아니라 별도 런타임 능력으로 보게 한다.

### 1. Lead agent는 모든 일을 직접 하는 실행자가 아니다

lead agent는 목표를 해석하고, 도구를 고르고, 필요한 경우 sub-agent에 경계가 분명한 일을 위임한다. 공식 README는 sub-agent를 복잡한 작업의 기본값이 아니라 병렬 지연 감소, 전문 능력, 문맥 격리의 이익이 분명할 때 쓰는 최적화로 설명한다. 이는 중요한 운영 원칙이다. “큰 작업이니 에이전트를 많이 띄운다”는 접근은 동일한 조사를 중복하고, 같은 파일에 경쟁적으로 쓰고, 마지막 합성 단계의 비용을 키운다.

좋은 분할은 서로 독립적인 읽기 작업에서 나온다. 예를 들어 법률 자료 조사, 기술 아키텍처 조사, 경쟁 제품 조사처럼 출처와 결과 형식이 분리되는 일은 병렬화할 수 있다. 반대로 같은 저장소의 리팩터링, 하나의 마이그레이션 순서, 테스트 실패를 보고 다음 패치를 정하는 작업은 순차 피드백이 핵심이므로 lead agent 또는 하나의 scoped sub-agent가 맡는 편이 안전하다.

### 2. Middleware는 장기 실행의 숨은 제어면이다

DeerFlow의 agent runtime은 thread data, upload, sandbox, context summarization, todo, image handling, clarification 같은 middleware를 모델 호출 전후에 배치한다. 이 계층이 없으면 모델은 “현재 파일이 어디에 있는가”, “업로드된 자료가 무엇인가”, “질문을 멈추고 사람에게 물어야 하는가”, “문맥 한계에 가까워졌는가”를 매번 prompt 관습으로 추측해야 한다.

여기서 핵심은 계획 목록 자체가 아니다. todo가 있어도 완료 판정이 모델의 자기보고에만 의존하면 체크박스는 장식이 된다. 각 단계에는 파일, 명령 결과, 테스트 리포트, 출처 목록처럼 외부에서 확인 가능한 artifact가 필요하다. [코드베이스 기억 계층 글](/posts/github-trending-codebase-memory-mcp-code-intelligence-layer/)에서 다룬 persistent graph도 같은 이유로 유용하다. 반복 탐색 비용을 줄일 수 있지만, 기억이나 요약은 증거를 대신하지 않으며 현재 branch와 실제 파일 상태를 다시 확인해야 한다.

### 3. Thread state와 sandbox는 대화와 실행 환경을 분리한다

공식 문서상 각 thread는 workspace, uploads, outputs를 포함한 격리된 데이터 경로를 갖고, sandbox provider가 실제 코드 실행 경계를 담당한다. 개발용 local provider는 호스트에서 직접 실행될 수 있으므로 production isolation으로 해석하면 안 된다. 아키텍처 문서는 production에서 Docker 기반 provider 사용을 권고하고, Gateway의 구성 문서도 host bash를 기본적으로 허용하지 않는 방향을 제시한다.

이 차이는 단순 배포 옵션이 아니다. 에이전트가 `bash`, 파일 쓰기, 패키지 설치, 브라우저 조작을 할 수 있다면 sandbox는 비용·보안·복구의 최소 단위가 된다. thread ID만 나뉘고 실제 파일 시스템과 credential이 공유되면 한 작업의 잘못된 삭제나 환경 오염이 다른 작업으로 번진다. 반대로 sandbox를 매번 새로 만들면 격리는 좋아지지만 이미지 준비, 의존성 설치, 캐시 손실 때문에 지연과 비용이 커진다. 실무에서는 격리 수준, warm pool, 수명, 네트워크 정책을 함께 설계해야 한다.

### 4. Memory와 compaction은 원본 기록의 대체물이 아니다

장기 작업은 결국 context window 한계에 닿는다. DeerFlow 문서는 오래된 대화를 요약하고 최근 도구 활동을 유지하는 compaction, 장기 memory, task continuity 기능을 구분한다. 운영자가 주의할 점은 요약이 정확한 실행 원장이 아니라는 사실이다. “테스트 통과”라는 문장이 남아 있어도 어느 commit에서 어떤 명령으로 통과했는지 없으면 재현할 수 없다.

[이벤트 로그 기반 agent runtime 글](/posts/apache-maka-agent-runtime-event-log/)에서 다룬 것처럼, 장기 실행에는 최소한 원본 tool receipt, checkpoint, artifact hash, 사용자 승인 기록과 요약된 작업 문맥을 분리할 필요가 있다. 검색용 memory는 빠른 재개를 돕고, event log는 감사와 복구를 돕는다. 둘을 하나의 “에이전트 기억”으로 묶으면 오래된 선호, 검증되지 않은 모델 보고, 실제 실행 결과가 같은 신뢰도로 섞인다.

## Checkpoint가 있어도 외부 효과는 자동으로 되돌아가지 않는다

DeerFlow의 checkpoint와 대화 재생 기능은 긴 작업을 복구하는 데 중요하다. 그러나 공식 README는 최근 사용자 메시지를 편집해 다시 실행할 때 대화 상태를 이전 checkpoint로 복원하더라도 **파일, memory update, 외부 도구의 side effect는 되돌리지 않는다**고 명시한다. plugin 문서도 cancellation이 외부 효과나 이미 실행 중인 worker operation의 rollback을 보장하지 않는다고 설명한다.

이 제약은 모든 agent 운영에 적용된다. 데이터베이스 insert, 이메일 발송, Git push, 결제 요청, 티켓 생성은 대화 checkpoint를 과거로 돌린다고 취소되지 않는다. 따라서 재시작 가능한 장기 작업에는 다음 설계가 필요하다.

- **멱등성 키**: 같은 단계가 재실행돼도 중복 티켓이나 중복 결제가 생기지 않게 한다.
- **prepare와 commit 분리**: 초안 생성과 외부 전송을 별도 단계로 나누고 commit 직전에 승인한다.
- **side-effect ledger**: 어떤 API에 어떤 요청을 보냈고 응답이 확정됐는지 기록한다.
- **보상 작업**: 완전한 rollback이 불가능한 경우 취소, revert, 후속 정정 절차를 정의한다.
- **불확실 상태 격리**: timeout 후 성공 여부를 모르면 자동 재시도하지 않고 사람이 확인하게 한다.

“checkpoint가 있다”와 “transactional하다”는 전혀 다른 말이다. 장기 실행 에이전트를 업무 시스템에 붙일 때 가장 자주 생기는 오해가 이 둘을 같은 것으로 보는 것이다.

## 관찰성: 최종 답변보다 실행 증거를 본다

DeerFlow 2.1 릴리스 노트는 trace ID, verifiable execution, durable batch delegation과 pluggable memory를 강조했고, 2.2 릴리스는 multi-Gateway 운영, workflow, provider-independent retrieval과 fail-closed validation으로 운영 범위를 넓혔다. 특정 기능 이름보다 중요한 것은 long-horizon agent의 관찰 단위를 정하는 일이다. 일반 웹 요청처럼 HTTP latency와 error rate만 보면 모델이 논리적으로 잘못된 경로를 오래 따라가는 문제를 찾기 어렵다.

최소 운영 지표는 다음처럼 나눌 수 있다.

| 관찰 영역 | 확인할 지표 | 실패 해석 |
|---|---|---|
| 실행 | wall-clock time, 단계별 tool latency, retry 수 | 느린 모델인지, 외부 API 병목인지, loop인지 구분 |
| 비용 | 모델별 input/output token, 검색·브라우저·sandbox 비용 | 완료율이 높아도 단위 작업 비용이 수작업보다 큰지 확인 |
| 진행 | 완료된 artifact, 남은 todo, clarification 대기 | 모델의 “진행 중” 문장 대신 실제 산출물을 측정 |
| 품질 | 출처 검증률, 테스트 통과, 요구사항 누락 | 자연스러운 최종 문장이 오류를 가리지 못하게 함 |
| 안전 | 거부된 도구 호출, 승인 대기, 권한 상승 시도 | 정책이 실제 실행 경계에서 작동하는지 확인 |
| 복구 | checkpoint resume 성공률, 중복 side effect, 수동 개입 시간 | 중단 후 재개가 비용 절감인지 장애 증폭인지 평가 |

로그에는 prompt 전문과 secret을 무차별 저장해서는 안 된다. 대신 run ID, thread ID, agent와 skill version, tool 이름, 정규화된 인자, 결과 상태, artifact 위치, 승인 주체를 구조화하는 편이 낫다. 민감한 문서와 고객 데이터가 들어가는 환경에서는 trace 접근 권한과 보존 기간도 제품 로그와 같은 수준으로 다뤄야 한다.

## 보안 경계: 로컬 데모의 기본값을 서비스 배포로 옮기지 말 것

DeerFlow README의 [Security Notice](https://github.com/bytedance/deer-flow#%EF%B8%8F-security-notice)는 시스템 명령 실행, 자원 조작, 업무 로직 호출처럼 높은 권한을 가진 기능 때문에 기본 배포를 `127.0.0.1`의 신뢰된 로컬 환경으로 둔다. 공식 아키텍처도 Nginx만 공개 진입점으로 두고 Gateway 포트를 직접 publish하지 않으며, non-loopback 배포 전에 인증 gateway, IP allowlist, 네트워크 격리를 요구한다.

여기서 “사내망이니 안전하다”는 판단은 부족하다. prompt injection이 포함된 문서, 악성 웹 페이지, 오염된 skill, MCP server, 과도한 admin 권한이 내부 경계에서 실행될 수 있다. 특히 Gateway admin은 stdio MCP server를 등록할 수 있으므로 공식 경고대로 사실상 code execution 권한으로 봐야 한다. 운영 계정과 일반 사용자를 분리하고, skill과 MCP 등록을 배포 변경으로 취급하며, sandbox network egress와 credential 전달을 명시적으로 제한해야 한다.

권한은 agent 단위가 아니라 **단계와 도구 단위**로 좁히는 편이 좋다. 조사 단계에는 read-only web과 문서 검색만 허용하고, 코드 수정 단계에는 특정 workspace만 쓰게 하며, 외부 전송 단계는 별도 승인 뒤 짧은 수명의 token을 제공한다. 모든 도구를 처음부터 열어 두고 prompt에 “조심하라”고 쓰는 것은 권한 설계가 아니다.

## 비용과 용량 계획: 병렬성은 공짜가 아니다

sub-agent는 wall-clock time을 줄일 수 있지만 총 token과 tool call은 오히려 늘 수 있다. parent가 배경을 설명하고, child가 다시 조사하고, parent가 결과를 합성하면 동일한 맥락이 여러 번 전송된다. snapshot context는 handoff 품질을 높일 수 있지만 입력 token을 증가시킨다. sandbox prewarm은 첫 실행 지연을 줄이지만 사용하지 않은 컨테이너도 자원을 점유할 수 있다.

따라서 비용 모델은 “한 번 실행 가격”보다 완료된 유효 산출물 기준으로 계산해야 한다.

```text
유효 작업 단가 = (모델 + 검색 + 브라우저 + sandbox + 사람 검토 비용) / 승인된 산출물 수
```

이 지표와 함께 p50/p95 완료 시간, 중단률, 재시도율, 사람이 수정한 비율을 봐야 한다. 단순 리서치처럼 실패 비용이 낮은 작업은 넓게 자동화할 수 있지만, production 변경이나 고객 커뮤니케이션은 사람 검토 시간이 전체 비용에서 큰 비중을 차지한다. 그럼에도 검토 가능한 artifact와 diff가 잘 만들어진다면 가치가 있다. 자동화의 목적은 사람을 완전히 제거하는 것이 아니라 검토해야 할 범위와 불확실성을 줄이는 데 있기 때문이다.

## 어디에 먼저 적용하고, 어디에는 늦춰야 하나

가장 좋은 초기 대상은 입력과 산출물이 명확하고, 외부 side effect가 적으며, 사람이 결과를 샘플링할 수 있는 작업이다.

1. **반복 리서치**: 후보 수집, 중복 검사, 공식 문서 확인, 비교표와 출처 목록 생성.
2. **코드 변경 전 탐색**: 호출 경로, 설정, 테스트 범위, 위험 파일을 조사해 계획서 작성.
3. **운영 문서 초안**: 장애 자료와 로그를 모아 timeline과 미확인 항목 정리.
4. **비파괴적 품질 검사**: 링크, 문서 일관성, dependency 영향 범위, 릴리스 체크리스트 점검.

반대로 직접 결제, 대량 삭제, production 권한 변경, 법적 판단, 검증되지 않은 보안 공격처럼 잘못된 실행의 영향이 큰 영역은 자동 실행보다 evidence collection과 제안 단계에서 멈추는 편이 낫다. [Google AX 운영 글](/posts/google-ax-agent-orchestration/)에서 다룬 workspace 격리와 suspend/resume 문제도 같은 판단 기준을 가진다. 장기 실행 능력이 있다는 사실은 장기 권한을 줘도 된다는 근거가 아니다.

## PoC는 데모 성공률이 아니라 실패 복구를 측정해야 한다

DeerFlow를 검토한다면 “복잡한 보고서 하나를 만들었다”는 데모보다 대표 작업 20~50개를 준비해 반복 평가하는 편이 낫다. 정상 입력뿐 아니라 오래된 자료, 충돌하는 요구사항, API timeout, 빈 검색 결과, sandbox 실패, 사용자 승인 대기를 섞어야 한다.

PoC의 종료 기준은 다음처럼 구체화할 수 있다.

- 작업 시작 전에 산출물·제약·완료 조건을 구조화하는가.
- 출처와 실제 tool result를 최종 주장까지 추적할 수 있는가.
- 같은 thread의 동시 실행과 재시작에서 상태가 섞이지 않는가.
- checkpoint 이후 외부 side effect를 중복 실행하지 않는가.
- 비용 또는 시간 상한에 도달하면 명확한 미완료 상태로 멈추는가.
- 사람이 중간에 방향을 바꿀 때 오래된 계획과 artifact를 구분하는가.
- 잘못된 skill, prompt injection, 권한 없는 tool call을 실행 경계에서 차단하는가.
- 실패 후 운영자가 제한 시간 안에 원인과 마지막 안전 상태를 찾을 수 있는가.

성공률만 보면 쉬운 작업을 많이 넣어 점수를 높일 수 있다. 더 유용한 지표는 **무해한 실패율**이다. 끝내지 못했더라도 잘못된 외부 변경 없이, 확인한 사실과 미확인 상태를 구분하고, 다음 사람이 이어받을 수 있게 멈췄다면 운영적으로는 좋은 실패다.

## 도입 판단: DeerFlow는 자동 조종 장치가 아니라 제어 가능한 실행 기반이다

DeerFlow가 보여주는 변화는 AI가 더 긴 답변을 만든다는 데 있지 않다. agent를 대화 인터페이스가 아니라 실행 수명주기, 상태, 격리, 도구 정책, artifact와 관찰성을 가진 시스템으로 다룬다는 데 있다. 공식 문서가 2.x에서 harness와 application을 나누고, sub-agent capacity, sandbox, checkpoint, trace, authentication을 강조하는 이유도 같다.

다만 기능 목록이 운영 성숙도를 자동으로 보장하지는 않는다. checkpoint는 외부 효과를 되돌리지 않고, memory는 원본 증거가 아니며, sandbox는 설정에 따라 host 실행이 될 수 있고, 병렬 sub-agent는 비용과 충돌을 늘릴 수 있다. 조직이 이 경계를 이해하지 못한 채 “몇 시간 일하는 AI 직원”으로 도입하면 긴 실행 시간만큼 실패 반경도 커진다.

좋은 long-horizon agent는 사람을 보이지 않게 제거하는 시스템이 아니다. 목표를 작은 검증 단위로 나누고, 각 단계의 증거를 남기며, 위험한 효과 앞에서 멈추고, 실패해도 다음 사람이 복구할 수 있게 만드는 시스템이다. DeerFlow를 평가할 때도 모델 벤치마크보다 이 운영 조건을 먼저 보는 편이 정확하다.

## 공식 자료

- [DeerFlow GitHub README](https://github.com/bytedance/deer-flow)
- [DeerFlow Architecture](https://github.com/bytedance/deer-flow/blob/main/docs/ARCHITECTURE.md)
- [Backend Configuration](https://github.com/bytedance/deer-flow/blob/main/backend/docs/CONFIGURATION.md)
- [Deployment and checkpoint operations](https://github.com/bytedance/deer-flow/blob/main/docs/guide/deployment.md)
- [Task continuity design](https://github.com/bytedance/deer-flow/blob/main/docs/task-continuity.md)
- [DeerFlow 2.1.0 release notes](https://github.com/bytedance/deer-flow/discussions/5832)
- [DeerFlow 2.2.0 release notes](https://github.com/bytedance/deer-flow/releases/tag/v2.2.0)
