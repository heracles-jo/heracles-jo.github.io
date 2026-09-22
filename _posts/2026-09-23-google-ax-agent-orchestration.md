---
title: "AI 에이전트 오케스트레이션: Google AX 운영 경계"
description: "Google AX의 Task·Workspace·Gateway와 Agent Substrate 계층을 바탕으로 장기 실행 에이전트의 격리, 재개, 용량 부족, 업그레이드와 PoC 기준을 정리한다."
author: heracles-jo
date: 2026-09-23 07:55:00 +0900
categories: [AI Infrastructure, Platform Engineering]
tags: [google-ax, agent-orchestration, kubernetes, agent-substrate, sandbox, platform-engineering]
image:
  path: https://heracles-jo.github.io/assets/img/posts/google-ax-agent-orchestration/cover.svg
  alt: "Google AX가 에이전트 작업, 워크스페이스, 네트워크 게이트웨이와 샌드박스를 조정하는 구조"
---

AI 에이전트 한 개를 실행하는 일과 수천 개를 운영하는 일 사이에는 모델 API 호출 횟수 이상의 차이가 있다. 에이전트는 저장소를 복제하고 도구를 설치하며, 외부 승인을 기다리다가 다시 실행되고, 때로는 잘못된 명령을 반복해 비용을 태운다. 작업이 끝난 것처럼 보여도 파일과 대화 상태는 남겨야 하고, 다른 사용자의 실행 환경과 네트워크는 분리해야 한다. **에이전트 오케스트레이션의 핵심은 프롬프트 순서를 연결하는 것이 아니라, 오래 살아 있는 상태 보유 작업을 격리하고 멈추고 되살리며 실패 원인을 설명하는 실행 제어면을 만드는 데 있다.**

[google/ax](https://github.com/google/ax)는 이 문제를 Kubernetes와 비슷한 선언형 리소스로 다루는 초기 단계의 오픈소스 프로젝트다. `Task`, `Workspace`, `Gateway`, `Model`을 YAML로 선언하면 AX control plane이 [Agent Substrate](https://github.com/agent-substrate/substrate)에 샌드박스를 만들고, 작업 공간과 도구를 준비하고, egress 정책을 적용한다. AX는 에이전트 프레임워크나 멀티 에이전트 대화 라이브러리가 아니다. LangGraph·ADK·자체 harness가 만든 프로세스를 **어디에서 어떤 권한과 상태 수명주기로 실행할지** 맡는 플랫폼 계층에 가깝다.

2026년 9월 23일 08시 5분 KST 전후 GitHub Trending daily에서 AX는 **2,324 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 **7,520 stars**, 351 forks, Apache-2.0 라이선스였고, 최신 릴리스는 9월 20일의 `v0.3.0`이다. 저장소 README는 안정 버전 이전에 핵심 개념과 프로토콜이 크게 바뀔 수 있다고 경고한다. 공개 이슈는 31건, 열린 PR은 0건으로 확인됐으며, 최근 이슈에는 용량 부족 처리, 자원 제한 미적용, worker pool 선택, ARM64 빌드, workspace 설정의 명령 주입 가능성 등이 집중됐다. 수치와 활동 상태는 확인 시점의 스냅샷이며 성숙도나 성능을 보증하지 않는다. 이번 실행 환경에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근하지 못해 주제 선정에 사용하지 않았다.

## 후보를 비교하면 새 질문은 “에이전트를 어디서 어떻게 살려 둘 것인가”였다

오늘 daily·weekly 후보는 에이전트 도구와 업무 플러그인에 크게 치우쳐 있었다. 기존 글의 저장소명뿐 아니라 중심 검색 의도를 대조하면 스킬 작성, 오피스 자동화, 코드 리뷰, GUI 에이전트 평가는 이미 충분히 다뤘다. AX는 에이전트가 무엇을 할 수 있는지가 아니라 **실행 수명주기와 플랫폼 책임을 어떻게 분리할지**라는 독립된 질문을 제공했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Google AX](https://github.com/google/ax) | daily 2,324, 7,520 stars, Apache-2.0, v0.3.0 | 선언형 Task·Workspace·Gateway와 suspend/resume을 묶은 에이전트 실행 제어면이라는 검색 의도가 분명해 선택했다. |
| [Agent Substrate](https://github.com/agent-substrate/substrate) | daily 301, 2,941 stars, Apache-2.0, v0.1.0 | AX의 하위 실행 계층으로 중요하지만, 단독 분석보다 AX와 함께 제어면·데이터면 경계를 설명할 때 더 유용하다. |
| [Univer](https://github.com/dream-num/univer) | daily 202, 15,347 stars, Apache-2.0, v0.25.2 | AI 에이전트용 오피스 SDK는 장기 가치가 있으나 기존 OfficeCLI 문서 자동화 글과 검색 의도가 가깝다. |
| [treg](https://github.com/superdesigndev/treg) | daily 197, 2,187 stars, 추가 제한이 있는 Apache 계열 라이선스 | 도구 카탈로그·비밀 주입은 흥미롭지만 MCP·스킬 공급망과 도구 권한 클러스터의 반복 위험이 높다. |
| [Claude for Financial Services](https://github.com/anthropics/financial-services) | daily 436, 36,303 stars, Apache-2.0 | 금융 업무 에이전트 템플릿은 별도 분야지만 규제·데이터 권리·전문가 검증까지 다루려면 범위가 지나치게 넓다. |

[CubeSandbox의 MicroVM 격리](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)가 비신뢰 코드를 어디까지 가둘 것인가를 다뤘다면, AX의 질문은 그 샌드박스를 작업 단위로 생성하고 준비하고 중단·재개하는 상위 제어면이다. [Cua의 컴퓨터 사용 에이전트 평가](/posts/cua-computer-use-agent-evaluation/)가 동일한 시작 상태와 결과 판정을 고정했다면, AX는 평가 이전에 실행 환경·네트워크·작업 공간을 반복 가능하게 공급하는 문제를 맡는다.

## 네 개의 리소스는 에이전트 책임을 운영 객체로 바꾼다

AX의 API는 `ax.io/v1alpha1` 리소스 네 개를 중심으로 구성된다.

- **Task**는 격리 실행의 최소 단위다. 이미지, 명령, CPU·메모리 요청과 제한, 환경 변수, Workspace와 Gateway 참조를 가진다.
- **Workspace**는 Git 저장소, MCP 서버·registry, skill 경로와 초기 설정 목표를 준비한다. 여러 Task가 같은 선언을 재사용할 수 있다.
- **Gateway**는 Task가 노출하는 listener와 외부로 나갈 수 있는 host·port allowlist를 정의한다.
- **Model**은 provider, model ID, 생성 파라미터와 Kubernetes Secret 참조를 중앙화한다.

이 분리는 단순한 YAML 취향이 아니다. 에이전트 명령 안에 `git clone`, 패키지 설치, API key, 프록시 설정을 모두 넣으면 실행 코드와 플랫폼 정책이 한 덩어리가 된다. 모델을 교체하려다 네트워크 권한이 달라지고, 저장소 branch를 바꾸려다 이미지 재빌드가 필요하며, 팀마다 bootstrap script가 갈라진다. Workspace와 Gateway를 별도 객체로 두면 “무엇을 할 것인가”와 “어떤 재료·통신 경계에서 할 것인가”를 독립적으로 검토할 수 있다.

![Google AX의 선언형 리소스가 Redis 제어면과 Agent Substrate 실행 계층으로 이어지는 아키텍처](https://heracles-jo.github.io/assets/img/posts/google-ax-agent-orchestration/architecture.svg)

Control plane도 Kubernetes CRD를 그대로 쓰지 않는다. AX 설계 문서는 수백만 개의 짧은 Task를 CRD로 저장하면 etcd 용량과 write rate가 병목이 될 수 있다는 판단 아래, 상태를 Redis hash에 저장하고 Redis Streams를 API server와 수평 확장 controller 사이의 작업 큐로 사용한다고 설명한다. `ax-server`는 manifest를 검증해 저장하고 event를 발행하며, `ax-controller`가 이를 소비해 Agent Substrate의 atespace·actor·egress policy를 조정한다.

여기서 중요한 아키텍처 판단은 Kubernetes를 버린 것이 아니라 **서로 다른 변화율을 분리한 것**이다. 클러스터·worker pod처럼 비교적 느리게 바뀌는 인프라는 Kubernetes가 맡고, 에이전트 Task의 고빈도 상태 전이는 AX와 Substrate가 별도 제어면에서 처리한다. 다만 Redis가 새로운 일관성 경계가 된다. 실제 공개 이슈에는 controller가 시작되기 전에 발행된 event를 놓치는 문제, worker 장애 뒤 미확인 stream event를 회수하지 않는 문제, spec 편집과 status update가 경쟁해 변경을 덮을 수 있다는 지적이 올라와 있다. 선언형 API 모양만 보고 Kubernetes 수준의 reconciliation 내구성을 가정해서는 안 된다.

## suspend/resume은 비용 절감 기능이면서 상태 무결성 계약이다

에이전트는 CPU를 계속 쓰는 서비스가 아니다. 사람 승인, 외부 API, 장기 도구 실행을 기다리는 시간이 길다. Agent Substrate는 많은 actor를 적은 ready worker에 multiplex하고, idle actor를 suspend해 filesystem과 실행 상태를 snapshot으로 보존한 뒤 다른 worker에서 resume하는 구조를 지향한다. AX는 이를 `ax suspend`와 `ax resume`으로 노출한다.

그러나 “정지했다가 이어서 실행한다”는 설명에는 세 종류의 상태가 섞여 있다.

1. **지속 파일 상태**: `/workspace`에 있는 repository, 산출물, checkpoint, 도구 설정
2. **프로세스 상태**: 메모리, 열린 파일, 실행 중인 child process와 signal 처리
3. **외부 세계의 상태**: 이미 전송한 메시지, 생성한 PR, 결제·배포 요청, 만료된 token

AX runner 문서에 따르면 `/workspace`는 suspend 뒤 복원되지만 container는 새 process tree로 다시 시작될 수 있다. runner는 `SIGTERM`을 child process group에 전달하고 10초 뒤 남은 프로세스를 종료한다. 그러므로 에이전트가 메모리에만 진행 상태를 두거나, 외부 부작용과 로컬 checkpoint를 원자적으로 맞추지 않으면 resume 뒤 같은 작업을 반복할 수 있다. suspend 직전 “API 호출 성공, checkpoint 기록 실패”가 일어나면 재개된 에이전트는 호출을 다시 보낼 가능성이 있다.

[Apache Maka의 런타임 이벤트 로그](/posts/apache-maka-agent-runtime-event-log/)에서 실행 사실과 context projection을 분리했듯, AX 위의 업무 에이전트도 durable event ID, idempotency key, 외부 작업 receipt, 마지막으로 확정된 checkpoint를 별도로 남겨야 한다. snapshot은 디스크와 프로세스를 보존할 수 있어도 외부 시스템과의 분산 transaction을 대신하지 않는다.

운영 비용도 함께 본다. suspend가 너무 공격적이면 짧은 idle마다 snapshot upload와 restore가 반복돼 지연과 저장 비용이 커진다. 반대로 worker를 오래 점유하면 multiplexing 이점이 사라진다. PoC에서는 idle threshold 하나를 정답처럼 고르지 말고 작업 유형별 active time, 대기 시간, snapshot 크기, resume p95·p99, 재개 후 중복 부작용률을 측정해야 한다.

## Gateway allowlist만으로 비밀정보가 안전해지지는 않는다

Gateway가 egress host·port allowlist를 제공하는 점은 에이전트 플랫폼에서 중요하다. 모델 endpoint와 Git host만 허용하면 prompt injection이나 잘못된 스크립트가 임의 도메인으로 데이터를 보내는 범위를 줄일 수 있다. 하지만 allowlist는 목적지 이름을 제한할 뿐, 허용된 목적지로 어떤 데이터가 나가는지는 판단하지 않는다. GitHub와 모델 provider가 허용돼 있다면 저장소 secret이나 고객 데이터가 그쪽으로 전송되는 경로는 여전히 존재한다.

Agent Substrate의 공식 threat model은 프로젝트가 빠르게 변하고 현재 보안 hardening이 거의 없다고 명시한다. actor의 Kubernetes API 접근 차단, worker 재사용 전 상태 완전 초기화, snapshot 서명·무결성 검증, actor별 snapshot 권한, control plane과 data plane 분리, credential-injecting proxy 같은 항목을 핵심 완화 조건으로 제시한다. 이는 완료된 보안 기능 목록이 아니라 구현해야 할 요구사항에 가깝다.

AX 자체에도 점검할 경계가 있다.

- Workspace의 Git URL과 branch는 비신뢰 입력으로 취급해야 한다. 9월 22일 공개 이슈 #363은 repository URL·branch 처리 과정의 명령 주입 가능성을 제기했다. 해결 여부를 확인하기 전에는 외부 사용자가 Workspace spec을 직접 제출하게 두면 안 된다.
- `spec.debug: true`는 guest gRPC service를 켜고 샌드박스 안에서 임의 process 실행과 파일 접근을 허용한다. 운영 기본값이 아니라 제한된 break-glass 권한으로 다뤄야 한다.
- Model 리소스가 Kubernetes Secret을 참조하더라도 실제 token이 sandbox 환경 변수로 들어가면 에이전트가 읽고 출력할 수 있다. 가능하면 목적지 제한 프록시가 자격증명을 대신 주입하고 actor에는 원문 key를 주지 않는 편이 낫다.
- suspend snapshot에는 filesystem뿐 아니라 민감한 실행 상태가 남을 수 있다. 암호화, actor별 IAM, retention, 삭제 검증과 복원 시 digest 검증이 필요하다.

[dcg 위험 명령 차단 글](/posts/ai-agent-destructive-command-guard/)에서 다룬 사전 실행 guard는 실수 방지에 유용하지만 sandbox·IAM을 대체하지 못한다. AX도 마찬가지다. 선언형 Gateway가 있다고 해서 cluster firewall, Kubernetes NetworkPolicy, workload identity, secret broker, 보호 브랜치가 불필요해지는 것은 아니다.

## 실패는 모델보다 scheduler와 runner에서 먼저 난다

AX의 현재 공개 이슈는 초기 플랫폼에서 어떤 실패가 먼저 드러나는지 보여 준다. worker가 꽉 찼을 때 Substrate의 `ResourceExhausted`를 받은 Task가 `Pending`으로 재시도되지 않고 영구 `Failed`가 된다는 이슈가 있다. 문서화된 CPU·메모리 제한이 ActorTemplate에 적용되지 않는다는 지적, AX가 만든 template에 `workerSelector`가 없어 관련 없는 pool로 배치될 수 있다는 지적도 있다. 이는 모델 품질과 무관한 **용량·격리·배치 정확성** 문제다.

runner 계약도 결과 판정에 빈틈이 있다. 기본 runner는 agent command가 끝나도 metadata와 SSH를 위해 계속 실행되며, 현재 control plane은 command exit status를 container 밖으로 읽지 않는다. 따라서 프로세스가 `exit 1`로 끝났는데 Task가 계속 살아 있거나, 반대로 command는 끝났지만 결과 artifact가 정상인지 모르는 상태가 생길 수 있다. `Ready`는 workspace가 준비되고 sandbox가 실행 중이라는 뜻이지 업무 성공을 뜻하지 않는다.

플랫폼 위에 다음과 같은 별도 completion contract가 필요하다.

- 결과 artifact의 경로·schema·hash 또는 외부 receipt
- command 종료 코드와 종료 원인
- task-level deadline, retry budget, 비용 한도
- 재시도 가능한 infrastructure failure와 재시도하면 안 되는 workload failure 구분
- 사람 승인이 필요한 상태와 자동 재개 가능한 상태

[Cua 평가 글](/posts/cua-computer-use-agent-evaluation/)에서 reward 하나로 실패 원인을 설명할 수 없다고 했듯, AX에서도 `Failed` 한 단어로는 부족하다. workspace bootstrap, image pull, worker assignment, snapshot download, command, egress, result validation을 다른 failure domain으로 집계해야 한다.

## 운영성은 actor identity를 pod보다 오래 유지하는 데서 시작한다

suspend된 actor는 다른 worker pod에서 resume될 수 있다. pod 이름만 log label로 쓰면 하나의 에이전트 실행 이력이 여러 pod에 조각난다. Agent Substrate 관측성 문서는 `ate.actor.uid`, `ate.actor.name`, `ate.atespace`, template 정보를 log에 주입하고, metrics에는 고카디널리티 actor identity를 넣지 않는 모델을 설명한다. per-actor 세부 사용량은 log event로, fleet capacity·restore duration·scheduler assignment는 제한된 label의 metric으로 분리한다.

이 선택은 실무적으로 타당하다. 모든 actor UID를 Prometheus label로 넣으면 실행량이 늘수록 시계열 비용이 폭발한다. 반대로 aggregate metric만 있으면 특정 고객 작업이 어느 snapshot에서 실패했는지 추적할 수 없다. 운영자는 세 층을 연결해야 한다.

- **fleet metric**: free·assigned worker, no-capacity 비율, assignment latency, image cache hit
- **lifecycle event**: actor state transition, suspend·resume 원인, command exit, snapshot ID
- **diagnostic trace/log**: router → control API → worker → runner의 요청 경로와 세부 오류

업그레이드도 일반 Deployment rollout보다 어렵다. Substrate의 공식 runbook은 새 worker pool을 복제하고, node별로 actor를 suspend해 durable snapshot을 만든 뒤 version label을 전환하는 절차를 제시한다. serving pool을 바로 수정하거나 scale down하면 actor가 terminal `CRASHED`로 이동해 복구할 수 없고 상태를 잃을 수 있다고 경고한다. 아직 일상적인 managed platform의 업그레이드 경험과는 거리가 있다는 뜻이다.

## PoC는 “몇 개 실행했는가”보다 중단·복구의 정직성을 본다

![Google AX PoC에서 기능 데모를 운영 후보로 승격하기 전에 확인할 게이트](https://heracles-jo.github.io/assets/img/posts/google-ax-agent-orchestration/decision-gates.svg)

AX와 Agent Substrate는 모두 초기 단계이므로 처음부터 production multi-tenant control plane으로 채택하기보다, 격리된 비프로덕션 Kubernetes cluster에서 제한된 workload로 검증하는 편이 안전하다. 코드 수정처럼 결과를 Git diff로 판정할 수 있고 외부 부작용을 쉽게 차단할 수 있는 작업이 좋다.

| 측정 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 수명주기 | create·ready·suspend·resume·delete p50/p95/p99, stuck 상태 | 동일 입력이 영구 Pending·Failed에 머물고 자동 복구 근거가 없음 |
| 상태 정확성 | workspace hash, checkpoint·artifact 일치, resume 후 중복 실행 | 외부 부작용을 중복 수행하거나 마지막 확정 상태를 잃음 |
| 용량 | free worker, assignment latency, no-capacity 비율, queue age | worker 부족이 재시도 가능한 대기가 아니라 영구 실패로 변함 |
| 격리 | actor 간 filesystem·network 접근, K8s API, metadata endpoint | 다른 actor·node·control plane 데이터에 접근 가능 |
| 비밀정보 | sandbox 내 평문 secret, egress log, snapshot 포함 여부 | 모델·Git 이외 경로로 secret이 나가거나 snapshot 권한을 분리하지 못함 |
| 관측성 | actor UID 기반 전체 이력, failure domain, command exit 수집 | pod 교체 뒤 한 실행의 원인·비용·결과를 연결하지 못함 |
| 업그레이드 | node별 drain·suspend·resume, rollback 시간, state loss | pool 변경 중 terminal crash 또는 복구 불가능한 snapshot 발생 |

검증 순서는 기능보다 경계를 먼저 보는 편이 낫다. 첫째, network default-deny와 workload identity를 적용한 뒤 허용 목적지만 연다. 둘째, 합성 저장소와 가짜 secret으로 workspace injection·path traversal·egress 시나리오를 시험한다. 셋째, agent command를 강제 종료하고 worker를 제거해 checkpoint와 retry semantics를 확인한다. 넷째, capacity를 일부러 고갈시켜 Pending·backoff·quota가 기대대로 작동하는지 본다. 마지막에만 실제 모델과 긴 작업을 올려 token·compute·snapshot 비용을 잰다.

AX가 잘 맞는 조직은 이미 Kubernetes 플랫폼팀이 있고, 에이전트 harness와 실행 인프라를 분리하려 하며, 장기 작업의 suspend/resume과 tenant 격리를 제품 요구사항으로 가진 곳이다. 반대로 하루 수십 건의 내부 자동화, 단일 팀의 코딩 에이전트, 외부 부작용이 거의 없는 batch라면 Kubernetes·Redis·Substrate까지 운영하는 비용이 더 클 수 있다. 이 경우 기존 Job, workflow engine, 격리된 ephemeral runner와 idempotent queue가 더 단순하다.

Google AX가 보여 주는 중요한 변화는 에이전트 플랫폼이 “어떤 모델과 프롬프트를 쓸까”에서 **상태를 가진 비신뢰 workload를 어떤 제어면으로 운영할까**로 이동한다는 점이다. Task·Workspace·Gateway의 분리는 유용한 방향이고, Substrate의 suspend/resume은 idle이 긴 에이전트의 자원 효율을 겨냥한다. 다만 현재 버전은 API·보안·reconciliation·업그레이드 계약이 계속 변하는 단계다. 도입 판단은 선언형 YAML의 익숙함보다, 용량 부족을 안전하게 기다리는지, snapshot이 무결한지, secret이 sandbox에 남지 않는지, 실패한 command를 정확히 판정하는지에 달려 있다.

> 1차 자료: [Google AX 저장소와 README](https://github.com/google/ax), [AX architecture](https://github.com/google/ax/blob/main/DESIGN.md), [core concepts](https://github.com/google/ax/blob/main/docs/concepts.md), [runner contract](https://github.com/google/ax/blob/main/docs/runner.md), [sandbox](https://github.com/google/ax/blob/main/docs/sandbox.md), [networking](https://github.com/google/ax/blob/main/docs/networking.md), [AX v0.3.0](https://github.com/google/ax/releases/tag/v0.3.0), [공개 issues](https://github.com/google/ax/issues), [Agent Substrate README](https://github.com/agent-substrate/substrate), [threat model](https://github.com/agent-substrate/substrate/blob/main/docs/threat-model.md), [observability](https://github.com/agent-substrate/substrate/blob/main/docs/observability.md), [rolling upgrade runbook](https://github.com/agent-substrate/substrate/blob/main/docs/upgrade.md), [Google Cloud 공개 소개](https://cloud.google.com/blog/products/ai-machine-learning/agent-executor-googles-distributed-agent-runtime). Trending·저장소 수치는 2026년 9월 23일 08시 5분 KST 전후 확인한 공개 스냅샷이다.
