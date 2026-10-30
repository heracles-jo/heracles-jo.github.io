---
title: "OpenBot AI 동료 운영: 승인·감사·격리 설계 기준"
description: "OpenBot의 AG-UI 게이트웨이, 작업별 승인, 컴퓨터 격리와 감사 로그를 바탕으로 지속형 AI 동료를 안전하게 운영하는 경계와 PoC 기준을 정리한다."
author: heracles-jo
date: 2026-10-31 08:25:00 +0900
categories: [AI Infrastructure, Security]
tags: [openbot, ai-coworker, ag-ui, agent-governance, approval-workflow, audit-log]
image:
  path: https://heracles-jo.github.io/assets/img/posts/openbot-ai-coworker-governance/cover.svg
  alt: "AI 동료의 브라우저·파일·MCP 작업이 승인 게이트와 감사 로그를 거치는 운영 구조"
---

AI 에이전트가 질문에 답하는 동안에는 잘못된 응답을 폐기하면 된다. 그러나 매일 같은 채널에 들어와 브라우저를 열고, 회사 계정으로 로그인하며, 파일을 저장하고, 외부 SaaS를 호출하는 **AI 동료**가 되면 실패의 성격이 달라진다. 누가 시킨 일인지 불명확한 채 환불을 실행하거나, 예약 작업이 새벽에 만료된 자격증명으로 계속 재시도하거나, 한 에이전트의 브라우저 세션이 다른 에이전트와 섞일 수 있다. 이 단계에서 필요한 것은 더 긴 프롬프트가 아니라 실행 전에 권한을 판정하고, 사람이 자리를 비운 작업을 구분하며, 결과를 사후에 재구성할 수 있는 운영 평면이다.

[CopilotKit/OpenBot](https://github.com/CopilotKit/OpenBot)은 자신을 완성된 SaaS가 아니라 조직이 복제해 바꾸는 self-hosted 템플릿으로 설명한다. AG-UI endpoint로 연결된 에이전트를 Bot으로 등록하고, 각 Bot에 브라우저·파일·MCP 도구를 부여한다. 중요한 차이는 도구 호출이 곧바로 실행 계층으로 가지 않는다는 점이다. 서버 게이트웨이가 대상과 행위 주체를 확인하고 CEL 정책을 평가해 감사 행을 먼저 기록한 뒤 허용된 작업만 컴퓨터로 전달한다. **AI 동료 운영의 핵심은 에이전트가 무엇을 할 수 있는지가 아니라, 어떤 조건에서 누구의 권한으로 실행되고 어디서 멈추는지를 시스템이 강제하는 데 있다.**

2026년 10월 31일 08시 35분 KST 전후 GitHub Trending daily에서 OpenBot은 `707 stars today`로 표시됐다. GitHub API 확인 시점에는 8,757 stars, 1,106 forks, 열린 issue와 PR을 합친 64개, MIT 라이선스, 10월 31일 KST까지 이어진 최근 push를 확인했다. 최신 정식 릴리스는 10월 12일의 `v0.2.0`이며 공유 앱 계정의 승인 범위, Bot별 통합 화면, 파일을 바꾸는 명령의 반복 승인 같은 운영 경계를 다듬었다. 이 수치는 관심도와 개발 활동을 보여 주는 시점별 스냅샷일 뿐 보안성이나 프로덕션 적합성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어 데이터에 접근하지 못해 선정 근거로 사용하지 않았다.

## 후보 5개에서 남은 질문은 ‘지속 권한의 통제’였다

오늘 후보는 에이전트 스킬과 코딩 인터페이스에 집중돼 있었다. 저장소 이름과 키워드뿐 아니라 기존 글의 중심 논지까지 비교하면, 새 글로 남길 수 있는 의도는 “AI 에이전트를 더 잘 만드는 법”보다 **사람이 항상 지켜보지 않는 AI 동료의 지속 권한을 어떻게 통제할 것인가**였다.

| 후보 | 확인 시점 신호 | 기존 글 중복·검색 의도 판단 |
|---|---|---|
| [OpenBot](https://github.com/CopilotKit/OpenBot) | daily 707, 8,757 stars, MIT, `v0.2.0` | 브라우저 능력이나 평가가 아니라 승인·감사·예약 실행·Bot별 컴퓨터를 묶은 **지속형 AI 동료 운영 통제**라는 독립 질문이 있어 선택했다. |
| [Impeccable](https://github.com/pbakaus/impeccable) | daily 2,299, 97,003 stars, Apache-2.0, `skill-v4.8.0` | UI 품질 검사는 유효하지만 다이어그램·디자인 스킬과 AI 과잉 구현 글의 독자 문제에 가깝다. |
| [expo/skills](https://github.com/expo/skills) | daily 108, 3,882 stars, MIT | 공식 모바일 개발 스킬은 장기 가치가 있으나 Android Skills의 빌드·테스트 검증 의도와 직접 경쟁한다. |
| [mattpocock/skills](https://github.com/mattpocock/skills) | daily 889, 307,443 stars, MIT, `v1.3.2` | 스펙·TDD·리뷰를 스킬로 표준화하는 주제는 기존 에이전트 스킬·코딩 워크플로 클러스터에서 반복됐다. |
| [T3 Code](https://github.com/pingdotgg/t3code) | daily 920, 32,710 stars, MIT, 초기 `v0.1.6` 계열 | 여러 로컬 코딩 에이전트를 원격 제어하는 수요는 분명하지만 IDE·병렬 에이전트·원격 제어 의도와 겹치는 폭이 더 크다. |

[컴퓨터 사용 에이전트 평가 글](/posts/cua-computer-use-agent-evaluation/)이 동일한 시작 상태와 평가기로 GUI 에이전트의 성공률을 비교했다면, OpenBot의 질문은 평가를 통과한 에이전트에게 실제 계정과 반복 업무를 맡긴 뒤의 통제다. [OpenShell 정책 런타임](/posts/openshell-agent-policy-runtime/)이 커널·네트워크·자격증명 경계를 강제하는 하부 런타임이라면, OpenBot은 사람·Bot·채널·승인·예약 작업을 연결하는 상위 업무 제어면에 가깝다.

## 신뢰 경계는 AG-UI 모델이 아니라 서버 게이트웨이에 둔다

OpenBot에서 Bot은 LangGraph, Mastra, CrewAI, Pydantic AI 또는 직접 작성한 endpoint일 수 있다. AG-UI는 모델·프레임워크와 사용자 표면을 연결하지만, 프로토콜을 사용한다는 사실 자체가 권한을 제한하지는 않는다. 실제 경계는 서버가 Bot에게 어떤 도구를 노출하고, 호출이 돌아왔을 때 무엇을 허용하는지에 있다.

![OpenBot에서 AG-UI Bot의 요청이 승인·정책·감사 게이트를 거쳐 격리 컴퓨터와 외부 도구에 도달하는 구조](https://heracles-jo.github.io/assets/img/posts/openbot-ai-coworker-governance/architecture.svg)

공식 architecture 문서의 실행 흐름을 운영 책임으로 나누면 네 계층이다.

1. **대화·주체 계층**: 로그인한 사람, 선택한 Bot, 채널과 run initiator를 결정한다.
2. **도구 제공 계층**: 해당 Bot에 grant된 브라우저·파일·MCP·component만 모델에게 보인다.
3. **정책·감사 계층**: 서버가 URL, element, command, file path, MCP server·tool·effect와 initiator를 CEL 규칙으로 평가한다.
4. **실행 계층**: 허용된 작업만 Bot의 computer container나 외부 MCP server로 전달된다.

정책 엔진은 deny를 allow보다 먼저 평가하고, 정책 누락·깨진 deny rule·깨진 allow rule에서 허용 범위를 넓히지 않는 fail-closed 동작을 설명한다. 하지만 shipped startup default는 명시적인 `allow: ["true"]`다. 즉 엔진이 fail-closed라는 사실과 새 설치가 최소 권한이라는 주장은 다르다. 조직 도입 시 기본 허용을 제거하고 Bot 역할별로 browser host, shell, file path, MCP write를 좁히지 않으면 감사 기능이 있는 전권 에이전트가 될 수 있다.

또한 “모델에게 도구를 적게 보여 주는 기능”과 보안 grant를 구분해야 한다. OpenBot은 메시지와 skill을 바탕으로 run마다 도구 목록을 좁히지만, 문서는 이를 boundary가 아니라고 명시한다. 분류가 실패하면 grant된 전체 catalogue를 다시 제공할 수 있기 때문이다. 도구 narrowing은 선택 정확도와 토큰 비용을 개선하는 UX 계층이고, 실제 권한은 grant·policy·audit가 결정해야 한다.

## ‘누구의 권한’과 ‘누가 지켜봤는가’를 분리해야 한다

지속형 동료에서 가장 위험한 혼동은 실행 주체와 실행 계기를 같은 필드로 표현하는 것이다. 예약 routine은 생성자의 권한으로 실행된다. 다른 Bot이 넘긴 handoff도 최초 사용자를 대신해 실행된다. 감사 로그에 actor만 남기면 사람이 직접 클릭한 작업과 새벽에 자동으로 발생한 작업이 모두 같은 사용자 이름으로 보인다.

OpenBot은 이를 `initiator_kind`로 분리한다. `person`, `routine`, `responsibility`, `memory`, `handoff`, `deployment`를 구분하고, “Nobody watching” 필터로 사람이 보고 있지 않았던 실행을 모은다. 이 설계는 운영에서 매우 중요하다. 같은 파일 쓰기라도 대화 중 사용자가 화면을 보는 상황과, 3주 전에 만든 routine이 자동 실행하는 상황은 승인 기준과 사고 대응 우선순위가 달라야 한다.

승인 정책에는 최소한 다음 문맥이 들어가야 한다.

- **interactive인가 unattended인가**: routine·handoff·memory import에는 더 좁은 allowlist를 적용한다.
- **read인가 write인가**: 읽기와 외부 부작용을 만드는 변경·삭제·전송을 분리한다.
- **개인 계정인가 공유 계정인가**: 팀 공용 SaaS 계정의 write는 Bot grant와 별개로 매번 사람 승인을 요구한다.
- **일회성인가 지속 권한인가**: “이번 한 번 허용”과 “이 폴더에서 항상 허용”을 분리하되 변경·삭제 명령에는 영구 허용을 제공하지 않는다.
- **누가 결과를 받는가**: handoff의 답변 channel과 attribution을 모델이 정하지 못하게 한다.

`v0.2.0`에서 desktop 공유 폴더를 수정할 수 있는 명령은 매번 묻고 “Always allow”를 제공하지 않도록 바뀐 점은 이 차이를 잘 보여 준다. 승인 피로를 줄이기 위해 read까지 매번 묻는 것은 비효율적이지만, write 권한을 한 번의 클릭으로 영구화하면 오래된 대화 문맥이나 prompt injection이 미래의 변경 권한을 상속한다.

## 한 Bot에 한 브라우저가 곧 tenant 격리는 아니다

OpenBot supervisor는 사람별 computer container를 만들고, Isolated로 표시한 Bot에는 전용 container를 줄 수 있다. 각 Bot은 별도 browser profile과 workspace를 가진다. browser와 shell은 filter proxy를 거쳐 egress policy를 적용받고 cloud metadata address는 거부된다. gVisor를 지원하는 host에서는 `runsc`도 선택할 수 있다.

그러나 배포 형태에 따라 보안 의미가 달라진다. all-in-one image에는 supervisor가 없으므로 모든 Bot이 하나의 computer를 공유한다. profile과 folder가 나뉘어도 같은 container의 filesystem·process·network 경계 안에 있다. 공식 deployment 문서도 이를 서로 신뢰하는 한 팀에는 쓸 수 있지만 tenant 경계로는 부적합하다고 밝힌다. 서버리스 플랫폼이 Docker socket을 허용하지 않아 supervisor를 쓸 수 없다면, “self-hosted이므로 격리됐다”는 결론을 내려서는 안 된다.

proxy 기반 egress에도 한계가 있다. 공식 문서는 proxy 변수를 무시하고 raw socket을 여는 process는 computer 자체가 막지 못하며 Kubernetes NetworkPolicy 같은 하부 통제가 필요하다고 설명한다. 따라서 격리는 다음처럼 중첩해야 한다.

- Bot별 browser profile·workspace 분리
- 고위험 Bot의 dedicated container
- container runtime 또는 gVisor 경계
- Kubernetes NetworkPolicy·방화벽으로 direct egress 차단
- 외부 SaaS의 최소 권한 OAuth scope와 API-side authorization
- 짧은 수명 credential, 목적지 제한, 회전·폐기 절차

[Macro 권한 그래프 글](/posts/macro-unified-workspace-permission-graph/)에서 채널 멤버십이 AI 메모리와 외부 도구 권한으로 수렴해야 한다고 본 것처럼, AI 동료의 browser profile만 분리해서는 부족하다. 채널에서 볼 수 있는 정보, Bot memory, 연결 앱, shared account, 생성 파일과 handoff 대상이 같은 권한 그래프를 따라야 한다.

## 감사 로그는 화면 녹화보다 먼저 확정돼야 한다

OpenBot gateway는 대상과 정책을 판정한 뒤 computer를 호출하기 전에 audit row를 쓴다. 전달된 작업이 실패하면 두 번째 행을 남긴다. 이 순서는 “화면에서는 실행된 것처럼 보이지만 승인 기록이 없다”는 상태를 줄인다. handover도 help requested, control taken, control released로 기록하며 사람이 browser를 조작하는 동안 Bot 행동은 queue에 쌓지 않고 거부한다.

다만 audit trail이 완전한 event-sourced runtime이라는 뜻은 아니다. Activity tab은 브라우저가 열려 있는 동안의 편의 화면이며 reload 후 사라진다. CSV export는 최대 5,000행이고 cap에 닿으면 truncated header를 반환한다. export 자체도 감사 이벤트가 되지만, 장기 보존·SIEM 연계·무결성 증명·법적 보존 요구는 배포자가 설계해야 한다.

[Apache Maka 감사 로그 글](/posts/apache-maka-agent-runtime-event-log/)에서 강조했듯 사람이 읽기 좋은 transcript와 canonical execution fact는 다르다. OpenBot을 운영한다면 audit event ID, Bot·actor·initiator, policy revision, target snapshot, approval ID, external request ID, result status를 함께 보존해야 한다. 외부 SaaS가 성공 응답을 보냈지만 로컬 result 기록 전에 process가 죽는 경우에는 성공·실패를 추측하지 않고 `unknown` 또는 reconciliation 필요 상태로 남겨야 중복 환불·중복 발송을 피할 수 있다.

## 예약 업무는 기능이 아니라 별도 가용성 시스템이다

Routine은 자연어로 만든 cron 작업이며 생성자의 권한으로 실행된다. 15분보다 짧은 주기는 허용하지 않고, 사용자당 활성 routine은 20개로 제한한다. 열 번 연속 실패하면 자동으로 끄고, 오랫동안 worker가 중단됐을 때 누락된 모든 실행을 한꺼번에 재생하지 않는다. 모델이 쉽게 만들어 내는 무제한 반복 작업과 비용 폭증을 제품 차원에서 제한한 설계다.

운영 함정은 routine을 저장하는 API server와 실제로 실행 시각을 확인하는 worker가 분리돼 있다는 점이다. one-container image만 배포하면 routine은 UI에 next run을 표시하면서도 외부 cron이나 별도 worker가 없으면 실행되지 않는다. staged attachment 정리도 별도 sweep이 필요해, 이를 빼면 사용자당 32개 unsent file 한도에 영구적으로 막힐 수 있다. 기능 화면이 정상이라는 사실이 background control plane의 건강을 보증하지 않는다.

따라서 routine 운영에는 다음 지표가 필요하다.

- 마지막 sweep 시각과 expected interval
- due-to-start 지연, queue claim·lease 연장 실패
- routine별 연속 실패와 자동 비활성화 수
- unattended run의 승인 대기 시간
- 외부 부작용의 idempotency key와 reconciliation 상태
- worker 중단 뒤 skipped occurrence와 실제 실행 건수
- Bot별·사용자별·배포 전체 동시 실행량과 모델 비용

예약 업무를 허용하는 순간 플랫폼팀은 단순 채팅 서비스가 아니라 scheduler, queue, worker, lease, retry, alert를 운영한다. 사람이 없는 시간에 실행되는 만큼 interactive 요청보다 더 강한 rate limit과 change budget을 적용해야 한다.

## 2주 PoC는 답변 품질보다 거부·복구·분리를 측정한다

OpenBot은 README에서 beta이자 template이라고 명시한다. 즉 기능 목록을 그대로 프로덕션 약속으로 읽기보다, 실제 조직의 identity provider·SaaS·네트워크·감사 체계에 맞게 경계를 검증해야 한다. 첫 PoC는 고객 데이터나 결제 권한이 없는 합성 계정과 전용 workspace에서 시작하는 편이 안전하다.

![AI 동료를 관찰 전용에서 제한된 쓰기와 예약 실행으로 승격하는 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/openbot-ai-coworker-governance/decision-gates.svg)

| 검증 축 | 실제 측정값 | 중단 조건 예시 |
|---|---|---|
| 주체·계기 | actor·initiator·Bot·channel attribution 완전성 | routine·handoff가 interactive action으로 기록됨 |
| 승인 | read/write 분류, always allow 범위, 승인 우회·피로 | write가 영구 승인되거나 승인 전 부작용 발생 |
| 정책 | deny 우선, malformed rule, policy revision·rollback | 정책 오류가 allow-all로 전환되거나 이전 규칙 복원 불가 |
| 격리 | Bot 간 cookie·file·process·memory canary 유출 | 다른 Bot·사용자의 session이나 파일이 한 건이라도 노출 |
| 네트워크 | proxy 우회, private IP·metadata·미승인 host 접근 | raw socket으로 egress policy를 우회 |
| 감사 | decision-before-action, 결과 correlation, export 완전성 | 외부 write를 승인·정책·결과와 연결할 수 없음 |
| routine | sweep freshness, 지연, 중복 실행, fatigue rule | worker 중단을 UI·alert에서 탐지하지 못하거나 중복 부작용 발생 |
| 복구·비용 | DB·browser volume RPO/RTO, concurrent browser memory, 모델 비용 | 복원 후 audit·credential·profile 관계가 깨지거나 비용 상한 부재 |

실험 순서는 단계적으로 잡는다. 첫째, 외부 쓰기가 없는 research Bot 하나로 identity, audit, browser profile 분리를 확인한다. 둘째, 합성 파일을 읽고 정해진 output folder에만 쓰도록 정책을 좁힌다. 셋째, mock SaaS connector에 read와 write tool을 분리해 write마다 승인과 idempotency를 시험한다. 넷째, 같은 업무를 interactive와 routine으로 각각 실행해 initiator 기반 정책 차이가 실제로 적용되는지 본다. 마지막에 supervisor 장애, worker 중단, DB restart, credential revoke를 주입하고 복구 후 중복 실행과 감사 누락을 조사한다.

도입 대안도 목적에 따라 다르다. 결정론적 browser 업무 몇 개라면 Playwright나 기존 RPA가 더 단순하다. 코드 변경 agent를 강하게 가두는 것이 우선이면 OpenShell 같은 하부 정책 런타임이 중심이 될 수 있다. 여러 agent framework를 공통 UI에 붙이고 조직 계정·승인·routine·handoff를 운영해야 할 때 OpenBot류의 제어면 가치가 커진다. 이 계층들을 대체 관계로 보기보다, 업무 제어면과 실행 sandbox, 외부 서비스의 IAM을 겹쳐 배치해야 한다.

OpenBot이 보여 주는 중요한 흐름은 AI 에이전트가 채팅 기능에서 **지속적인 조직 행위자**로 이동하고 있다는 점이다. 이때 장기 기억이나 화면 조작 능력보다 먼저 설계할 것은 권한의 수명, unattended 실행의 식별, 승인 범위, 컴퓨터와 계정의 격리, 감사와 복구다. AI 동료를 도입할 기준은 “사람처럼 일했다”가 아니다. **사람이 없을 때 더 좁은 권한으로 움직이고, 멈춰야 할 곳에서 멈추며, 실행 뒤 누가 왜 무엇을 허용했는지 제한 시간 안에 설명할 수 있는가**다.

> 1차 자료: [CopilotKit/OpenBot 저장소와 README](https://github.com/CopilotKit/OpenBot), [Architecture](https://github.com/CopilotKit/OpenBot/blob/main/docs/architecture.md), [Deployment](https://github.com/CopilotKit/OpenBot/blob/main/docs/deployment.md), [Configuration](https://github.com/CopilotKit/OpenBot/blob/main/docs/configuration.md), [Routines](https://github.com/CopilotKit/OpenBot/blob/main/docs/routines.md), [`v0.2.0` 릴리스](https://github.com/CopilotKit/OpenBot/releases/tag/v0.2.0), [최근 commits](https://github.com/CopilotKit/OpenBot/commits/main/), [공개 issues](https://github.com/CopilotKit/OpenBot/issues), [공개 pull requests](https://github.com/CopilotKit/OpenBot/pulls), [MIT LICENSE](https://github.com/CopilotKit/OpenBot/blob/main/LICENSE). Trending·저장소 수치는 2026년 10월 31일 08시 35분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
