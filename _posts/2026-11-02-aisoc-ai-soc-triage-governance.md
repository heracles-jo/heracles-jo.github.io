---
title: "AI SOC 자동화: AiSOC 트리아지·대응 승인 검증 기준"
description: "AiSOC의 탐지·상관분석·AI 조사·승인 대응 구조를 분해해 SIEM 연동, 증거 원장, 프롬프트 인젝션, 오탐과 운영 비용의 검증 기준을 제시한다."
author: heracles-jo
date: 2026-11-02 08:05:00 +0900
categories: [Security, AI Infrastructure]
tags: [aisoc, ai-soc, security-operations, incident-triage, soar, mitre-attack]
image:
  path: https://heracles-jo.github.io/assets/img/posts/aisoc-ai-soc-triage-governance/cover.svg
  alt: "AI SOC의 탐지부터 사람 승인 대응까지 검증하는 운영 구조 표지"
---

보안 관제의 병목은 경보를 더 많이 만드는 데 있지 않다. EDR, 클라우드 감사 로그, IAM, Kubernetes, 이메일 보안 도구가 이미 수많은 신호를 낸다. 문제는 서로 다른 형식의 이벤트를 같은 사건으로 묶고, 조사 근거를 잃지 않은 채 우선순위를 정하며, 실제 차단 조치 앞에서 사람의 권한과 책임을 확인하는 일이다. 이 구간에 LLM을 넣으면 요약 속도는 빨라지지만, 공격자가 남긴 로그 문장이 모델의 지시문으로 읽히거나 근거 없는 확신이 자동 대응으로 번질 수 있다.

[beenuar/AiSOC](https://github.com/beenuar/AiSOC)는 이 문제를 오픈소스 AI Security Operations Center로 풀려는 프로젝트다. 텔레메트리를 공통 형식으로 정규화하고, 탐지·상관분석 뒤 AI 에이전트가 사건을 조사하며, 프롬프트와 도구 호출·인용·판정을 Investigation Ledger에 기록한다. 대응은 기본적으로 미리보기이고, 정책과 사람 승인을 통과한 동작만 벤더 시스템으로 전달한다.

2026년 11월 2일 08시 10분 KST 전후 공개 스냅샷에서 AiSOC는 GitHub Trending daily에 **436 stars today**로 표시됐다. GitHub API 기준 6,182 stars, 643 forks, MIT 라이선스였고, 최신 정식 릴리스 `v21.0.0`은 11월 1일 공개됐다. 같은 날까지 identity context, 네트워크 탐지, 대응 verb 확장 관련 변경과 PR 활동이 이어졌다. 저장소는 2026년 5월 생성돼 짧은 기간에 큰 기능 표면과 빠른 메이저 버전 변화를 보였다. 관심도와 기능 수는 성숙도 보증이 아니며, 아래 수치는 확인 시점의 스냅샷이다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근할 수 없어 주제 선정에 사용하지 않았다.

## 후보를 비교하면 남는 질문은 “AI가 경보를 어떻게 안전하게 닫는가”다

오늘 daily·weekly 목록은 코딩 에이전트와 디자인 스킬에 집중됐다. 최근 글의 제목·태그뿐 아니라 독자가 해결하려는 문제를 대조하면 t3code와 ThinkRail은 코딩 에이전트 운영, Hallmark는 디자인 산출물 품질, Handy는 로컬 음성 입력으로 각각 기존 클러스터와 가까웠다. AiSOC도 단순히 “보안 에이전트”로 소개하면 기존 AI 보안 감사 글과 겹친다. 차이는 **코드 취약점을 찾는 감사**가 아니라, 운영 중 들어오는 경보를 사건으로 묶고 대응 권한까지 통제하는 **SOC 트리아지·SOAR 경계**에 있다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [AiSOC](https://github.com/beenuar/AiSOC) | daily 436, 6,182 stars, MIT, `v21.0.0` | SIEM을 대체하는 소개보다 **AI 트리아지의 근거·승인·사후 검증**이라는 독립 운영 질문이 선명해 선택했다. |
| [T3 Code](https://github.com/pingdotgg/t3code) | daily 3,100, 37,822 stars, MIT, `v0.1.6` | 원격 코딩 에이전트 제어는 Orca·Google AX·OpenBot과 검색 의도 중복 폭이 크다. |
| [Handy](https://github.com/cjpais/Handy) | daily 383, 36,492 stars, MIT, `v0.9.8` | 오프라인 음성 인식은 별도 수요가 있지만 기존 음성 AI·로컬 AI 글과 인접한다. |
| [ThinkRail](https://github.com/JetBrains/thinkrail) | weekly 5,738, 6,961 stars, Apache-2.0, `v0.3.0` | IDE 안의 에이전트·spec·workspace는 기존 병렬 코딩 및 컨텍스트 운영 의도와 경쟁한다. |
| [Hallmark](https://github.com/Nutlope/hallmark) | weekly 12,062, 44,817 stars, MIT, 정식 release 없음 | AI 생성 UI 품질은 유효하지만 디자인 시스템·에이전트 스킬 글에서 반복된 독자 문제다. |

[Cloudflare Security Audit Skill 글](/posts/cloudflare-security-audit-skill-validation-pipeline/)은 저장소의 취약점 후보를 독립 검증과 커버리지 원장으로 좁히는 AppSec 절차를 다뤘다. AiSOC의 입력은 소스 코드가 아니라 이미 운영 중인 시스템이 내보낸 경보다. 질문도 “취약점이 진짜인가”에서 “지금 이 경보가 어떤 사건이며, 누구에게 어떤 조치를 허용할 것인가”로 바뀐다.

## AiSOC의 핵심은 LLM보다 이벤트·권한 경계를 분리한 데 있다

공식 아키텍처를 따라 이벤트 하나를 추적하면 구조가 선명하다. Connector나 ingest API가 받은 텔레메트리는 OCSF 형태의 공통 envelope로 정규화된다. Kafka가 이벤트 spine을 만들고 fusion service가 탐지 규칙, 임계값·순서 기반 window rule, tenant별 tuning을 적용한다. 이후 `{tenant}:{entity}:{tactic}` 계열 키로 관련 경보를 incident에 묶고 Postgres와 fused-alert topic에 기록한다.

그다음에야 agent가 등장한다. 모델은 경보, 연관 사건, entity context, 과거 verdict를 읽고 typed tool을 호출한다. 모델이 임의 SQL을 쓰는 구조가 아니라 lake query나 graph traversal처럼 닫힌 도구 표면을 사용한다. 결과는 verdict·confidence·근거 인용과 함께 Investigation Ledger에 남고, 대응 playbook은 기본 preview 상태에서 계획만 보여 준다.

![AiSOC에서 텔레메트리 수집부터 AI 조사와 승인 대응까지 분리한 아키텍처](https://heracles-jo.github.io/assets/img/posts/aisoc-ai-soc-triage-governance/architecture.svg)

이 구조에서 중요한 경계는 다섯 가지다.

1. **수집과 정규화**: 원본 필드가 actor·resource·outcome으로 어떻게 매핑됐는지 추적할 수 있어야 한다.
2. **탐지와 사건화**: 규칙이 실제 이벤트에서 실행 가능한지, suppression 때문에 사라진 신호가 무엇인지 구분해야 한다.
3. **AI 조사**: 모델이 읽은 증거와 도구 호출이 판정 뒤에도 재현 가능해야 한다.
4. **승인과 실행**: playbook 승인과 개별 고위험 action 권한을 같은 것으로 취급하지 않아야 한다.
5. **사후 확인**: 벤더 API의 HTTP 200을 성공으로 간주하지 않고 실제 격리·차단·해제 상태를 다시 조회해야 한다.

[Apache Maka의 에이전트 감사 로그 글](/posts/apache-maka-agent-runtime-event-log/)에서 실행 사실과 사람이 읽기 좋은 transcript를 분리했듯, SOC에서도 요약문은 canonical evidence가 아니다. 원본 event ref, 정규화 버전, 적용 rule·tuning revision, tool input/output digest, 승인자와 실행 결과가 연결돼야 “왜 이 경보를 닫았는가”를 나중에 다시 묻을 수 있다.

## 탐지 규칙 수보다 “실제로 발화 가능한가”가 중요하다

AiSOC README는 확인 시점 기준 디스크에 7,015개 규칙이 있고 그중 2,534개를 executable로 집계한다. 이 차이는 기능 부족을 숨기는 숫자가 아니라, 오히려 운영자가 봐야 할 핵심이다. SPL·YARA-L처럼 evaluator가 없는 형식, 현재 connector가 내지 않는 필드, 단일 이벤트 엔진으로 표현할 수 없는 상관 규칙은 파일이 존재해도 실행 가능한 탐지가 아니다.

프로젝트는 vendor-shaped event를 실제 connector와 engine에 replay해 rule이 발화한 경우에만 executable 집합에 넣는다고 설명한다. 번역할 수 없는 Splunk SPL을 억지로 근사하지 않고 거부하며, windowed rule도 stateless rule과 따로 센다. 방향은 타당하다. 하지만 도입 조직은 upstream의 “발화 가능”과 우리 환경의 “탐지 유효”를 구분해야 한다.

- Connector가 필요한 필드를 보내도 자사 로그 설정에서 그 필드가 실제로 수집되는가.
- 규칙이 synthetic fixture에서 발화하는 것과 실제 공격·정상 업무를 분리하는 것은 같은가.
- tenant tuning, severity floor, suppression이 queue를 줄이는 동시에 blind spot을 만들지 않는가.
- 규칙 업데이트가 과거 incident 분류와 재현 결과를 바꾸는가.

따라서 PoC에서는 전체 rule count보다 **source별 field coverage, 발화율, 정상 데이터 오탐, suppression 근거, replay 재현성**을 측정해야 한다. [공개 PoC 아카이브 운영 글](/posts/github-trending-exploitarium-poc-governance/)에서 빠른 취약점 신호를 내부 자산·탐지 근거와 연결했듯, AiSOC의 CISA KEV와 retro-hunt도 “새 IOC가 들어왔다”보다 어떤 보존 데이터에 어떤 시간 경계로 다시 적용됐는지를 기록해야 한다.

## 프롬프트 인젝션은 채팅창이 아니라 공격자가 만든 로그에서 온다

SOC 에이전트가 읽는 데이터는 본질적으로 공격자 영향권에 있다. command line, DNS 이름, 이메일 본문, user-agent, 파일명, Kubernetes annotation, Slack 메시지에 `ignore previous instructions` 같은 문장을 넣는 것은 어렵지 않다. 이 문자열이 조사 prompt에 그대로 들어가면 공격자는 탐지 대상이면서 동시에 조사자의 입력을 작성하는 셈이다.

AiSOC의 공식 threat model은 nonce 기반 evidence fence, role-marker 탐지, raw log·secret을 거부하는 LLM input contract, structured output 재검증을 제시한다. 의심 신호가 높으면 autonomy tier를 L0 수동 검토로 내리고, tool argument가 사건 evidence graph에 존재하는 entity인지 확인한다. 중요한 태도는 문서가 “prompt는 hard trust boundary가 아니다”라고 잔여 위험을 남긴다는 점이다.

이 방어는 유효하지만 세 가지를 별도로 시험해야 한다.

**첫째, 탐지되지 않는 인젝션이다.** 알려진 role marker를 피하고 정상 보안 문맥처럼 보이는 문자열이 verdict를 흔들 수 있다. 정적 pattern test뿐 아니라 다국어, encoding, 분절된 필드, enrichment 결과를 섞은 adversarial corpus가 필요하다.

**둘째, 인젝션 없이도 생기는 근거 왜곡이다.** 정규화 과정에서 actor가 `unknown`으로 사라지거나 서로 다른 경보가 같은 correlation key에 합쳐지면 모델은 잘못된 사건 묶음을 매우 그럴듯하게 설명한다. 모델 안전과 데이터 품질은 다른 실패 축이다.

**셋째, 읽기 권한에서 쓰기 권한으로 넘어가는 순간이다.** 조사 agent가 잘못 판단하더라도 read-only query에 머물면 영향은 제한적이다. 반면 host isolation, credential revoke, IP block은 업무 중단과 증거 손실을 만든다. tool name allowlist만 두지 말고 대상 entity, asset criticality, 요청자·승인자 분리, idempotency key, rollback 가능성을 dispatch 시점에 다시 검증해야 한다.

## 사람 승인은 버튼이 아니라 권한 판정이어야 한다

“human in the loop”는 자주 안전장치처럼 쓰이지만, 누가 어떤 정보로 승인했는지 확인하지 않으면 단순한 클릭 단계다. AiSOC의 action approval 문서는 과거 Slack·Teams 사용자를 audit log에는 남겼지만 실제 permission tier와 separation of duties에 연결하지 못했던 결함을 공개한다. 현재 설계는 bot이 권한을 주장하지 않고 identity만 전달하며, actions service가 operator-defined principal map을 통해 권한을 판정한다. 매핑되지 않은 사용자는 fail-closed로 거부된다.

운영에서 확인할 항목은 다음과 같다.

- 요청자와 승인자가 다른가.
- `low`, `medium`, `high` action tier가 실제 blast radius와 맞는가.
- ChatOps identity와 사내 IdP principal의 수명·퇴사·직무 변경이 동기화되는가.
- 승인 시점의 action plan과 실행 시점의 target state가 달라지면 재승인을 요구하는가.
- timeout이 승인으로 해석되지 않고 안전한 거절로 끝나는가.
- 실행 후 원격 시스템의 상태를 재조회하고, 불명확하면 `unknown`으로 남기는가.

여기에는 아직 운영 리스크도 있다. 프로젝트 문서는 action service의 pending approval이 메모리에 있어 restart와 다중 replica에서 유실될 수 있고, 모든 대기 action이 ChatOps 카드로 능동 전송되는 것은 아니라고 명시한다. 반면 alert-triggered playbook의 approval pause는 Postgres에 저장돼 restart 후 이어지는 구조다. 이름이 모두 “approval”이어도 지속성 모델이 다르므로, HA 환경에서는 승인 객체별 저장 위치와 복구 의미를 직접 검증해야 한다.

## SIEM 대체로 시작하면 실패할 가능성이 높다

AiSOC 자체도 drop-in SIEM replacement가 아니라고 선을 긋는다. Core profile은 16개 장기 실행 service와 약 8GB RAM, full profile은 22개 service와 약 12GB RAM을 제시한다. Postgres, Redis, Kafka, Qdrant에 더해 full profile은 ClickHouse, Neo4j, OpenSearch를 사용한다. 설치가 된다는 것과 보안 운영 플랫폼을 책임질 수 있다는 것은 다른 문제다.

기존 SIEM을 즉시 걷어내기보다 다음 역할로 나누는 편이 현실적이다.

| 계층 | 기존 시스템의 역할 | AiSOC에 먼저 맡길 범위 |
|---|---|---|
| 원본 보존·컴플라이언스 검색 | 장기 로그 보존, 법적 보존, 규제 쿼리 | 대체하지 않고 event ref와 조회 경로 연결 |
| 탐지 | 검증된 SIEM/EDR rule, 기존 on-call | 일부 source의 shadow detection과 replay 비교 |
| 사건 상관분석 | analyst queue, case management | 중복 grouping과 priority 추천을 병렬 평가 |
| AI 조사 | 사람의 수동 pivot·요약 | read-only tool, 근거 인용, verdict 제안 |
| 대응 | SOAR·EDR·IAM 변경 | preview와 저위험 action부터, 고위험은 승인 유지 |

[OpenBot의 승인·감사·격리 글](/posts/openbot-ai-coworker-governance/)이 지속형 업무 에이전트의 사람 통제를 다뤘다면, AiSOC는 공격자 영향 데이터와 고위험 보안 동작이 같은 파이프라인 안에 있다는 점에서 더 엄격한 증거 계약이 필요하다. “자율 대응”을 목표로 시작하지 말고 analyst의 조사 시간을 줄이면서 잘못된 종료·차단을 늘리지 않는지를 먼저 봐야 한다.

## 4주 PoC는 정확도보다 운영 경계를 측정한다

처음부터 모든 connector와 rule을 켜면 어느 계층에서 품질이 무너졌는지 알기 어렵다. EDR 한 종류와 cloud audit 한 종류, 과거에 사람이 판정한 incident corpus를 선택해 shadow mode로 시작하는 편이 낫다. 원본 시스템의 case ID와 AiSOC incident를 연결하되 자동 close와 vendor mutation은 끈다.

![AiSOC를 관제 운영에 승격하기 전 통과해야 할 데이터·판정·승인·복구 게이트](https://heracles-jo.github.io/assets/img/posts/aisoc-ai-soc-triage-governance/decision-gates.svg)

| 검증 영역 | 측정값 | 중단 조건 예시 |
|---|---|---|
| 수집·정규화 | source별 필드 보존, actor/entity 누락률, cursor gap, 중복률 | 중요 source의 actor·time·event id가 조용히 사라짐 |
| 탐지·상관 | 과거 incident 재발견, 오탐, 잘못 합쳐진 incident, suppression 영향 | unrelated alert가 하나로 묶여 조사 범위가 왜곡됨 |
| AI 판정 | analyst agreement보다 근거 재현률, unsupported claim, abstain·error 비율 | evidence에 없는 indicator를 인용한 verdict가 자동 종료 후보가 됨 |
| 프롬프트 안전 | adversarial corpus의 tier demotion, secret·raw log egress | 공격자 문자열이 tool target이나 action tier를 바꿈 |
| 승인·실행 | 승인자 권한, separation of duties, idempotency, post-action verification | restart 후 승인 상태 유실 또는 HTTP 성공만으로 완료 처리 |
| 운영 비용 | alert당 token·CPU·storage, p50/p95 triage, backlog 복구 시간 | queue 증가 시 LLM·Kafka·DB 병목을 분리하지 못함 |
| 복구·업그레이드 | backup restore, schema migration, replay 결과 차이, rollback | 릴리스 변경으로 과거 incident 판정이 달라져도 설명 불가 |

첫 주에는 connector field와 원본 참조의 완전성을 본다. 둘째 주에는 과거 incident를 replay해 grouping과 verdict 근거를 사람이 다시 판정한다. 셋째 주에는 prompt injection, 누락 field, delayed event, duplicate delivery, 모델 timeout, datastore 장애를 주입한다. 넷째 주에만 preview playbook과 저위험 action을 테스트 계정에 연결하고 승인·재시도·rollback을 확인한다.

합격 기준은 “AI 정확도 90%” 하나로 두지 않는다. 예를 들어 critical/high 사건의 원본 evidence 재현률 100%, unsupported claim이 있는 verdict의 자동 종료 0건, tenant 간 데이터 혼입 0건, 고위험 action의 요청자·승인자 동일 사례 0건, 실행 결과 미확인 상태의 성공 처리 0건처럼 경계별 조건을 둬야 한다. 작은 로컬 모델의 JSON 형식 성공률이나 자체 synthetic benchmark는 구성 요소 검증에는 유용하지만 실제 SOC의 base rate, 조직별 정상 행위, 조사 품질을 대신하지 못한다.

AiSOC에서 장기적으로 볼 가치는 “LLM이 분석가를 대체하는가”가 아니다. **탐지 가능한 규칙만 집계하고, AI가 읽은 증거를 원장에 남기며, 응답 권한을 action마다 다시 판정하고, 측정하지 못한 값을 0으로 꾸미지 않으려는 운영 규율**에 있다. 동시에 빠른 메이저 릴리스, 넓은 서비스 표면, 서로 다른 approval persistence, 짧은 실운영 역사 때문에 전체 교체보다 제한된 shadow deployment가 맞다. 도입 결정은 demo의 화려함이 아니라, 잘못된 경보 묶음과 근거 없는 판정, 승인 유실, 실행 실패를 조직이 발견하고 되돌릴 수 있는지로 내려야 한다.

> 1차 자료: [AiSOC 저장소와 README](https://github.com/beenuar/AiSOC), [공식 아키텍처](https://github.com/beenuar/AiSOC/blob/main/docs/architecture/README.md), [Repository Reality audit](https://github.com/beenuar/AiSOC/blob/main/docs/audit/REPOSITORY_REALITY.md), [Agent threat model](https://github.com/beenuar/AiSOC/blob/main/docs/security/agent-threat-model.md), [Action approvals](https://github.com/beenuar/AiSOC/blob/main/apps/docs/docs/operations/action-approvals.md), [v21.0.0 release](https://github.com/beenuar/AiSOC/releases/tag/v21.0.0), [MIT LICENSE](https://github.com/beenuar/AiSOC/blob/main/LICENSE), [최근 commits](https://github.com/beenuar/AiSOC/commits/main/), [공개 issues와 pull requests](https://github.com/beenuar/AiSOC/issues). Trending·저장소 수치는 2026년 11월 2일 08시 10분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
