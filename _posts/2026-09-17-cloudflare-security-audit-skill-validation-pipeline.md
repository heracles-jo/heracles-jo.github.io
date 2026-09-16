---
title: "AI 보안 감사 자동화: Cloudflare Security Audit Skill 검증 구조"
description: "Cloudflare Security Audit Skill의 정찰·커버리지·독립 검증 구조를 분석하고, AI 보안 감사를 신뢰 가능한 증거 파이프라인으로 도입하는 기준을 제시한다."
author: heracles-jo
date: 2026-09-17 08:15:00 +0900
categories: [Security, AI Infrastructure]
tags: [cloudflare-security-audit, ai-security-audit, vulnerability-research, agent-skills, devsecops, sandbox]
image:
  path: https://heracles-jo.github.io/assets/img/posts/cloudflare-security-audit-skill-validation-pipeline/cover.svg
  alt: "AI 보안 감사에서 탐색 결과를 독립 검증과 구조화된 증거로 좁혀 가는 파이프라인"
---

AI 코딩 에이전트에게 “이 저장소의 보안 취약점을 찾아라”라고 요청하면 결과는 빨리 나온다. 더 어려운 일은 그다음이다. 에이전트가 지적한 코드가 실제 실행 경로에 있는지, 낮은 신뢰도의 입력이 어떤 경계를 넘는지, 재현 과정에서 에이전트가 원본을 바꾸지는 않았는지, 한 번도 살펴보지 않은 영역을 “문제없음”으로 오해하지 않았는지 확인해야 한다. 이 증거 계약이 없으면 보고서가 길어질수록 보안팀의 분류 비용도 커진다.

[cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill)은 더 좋은 취약점 프롬프트보다 **발견과 반증을 분리하는 감사 절차**를 제안한다. 정찰로 신뢰 경계와 입력 표면을 그린 뒤 커버리지 원장을 만들고, 격리된 hunter가 후보를 찾으면 다른 verifier가 이를 깨뜨리려 한다. 살아남은 결과만 JSON 스키마로 고정하고, 다시 독립적인 source verification을 거쳐 사람용 보고서를 만든다. 핵심은 AI가 취약점을 많이 말하게 하는 것이 아니라, 어떤 주장을 누가 어떤 증거로 확인했는지 추적 가능하게 만드는 데 있다.

2026년 9월 17일 08시 20분 KST 전후 GitHub Trending daily에서 이 저장소는 **1,249 stars today**로 표시됐다. 같은 시점 GitHub API에서는 **7,075 stars**, 414 forks, MIT 라이선스, 열린 이슈와 PR을 합친 14개, 9월 15일 KST 전후의 최근 push를 확인했다. 정식 GitHub release는 없었다. 관심도와 저장소 수치는 확인 시점의 스냅샷이며 감사 정확도나 프로덕션 적합성을 보증하지 않는다. Search Console과 Analytics의 실제 검색어 데이터에는 이번 실행 환경에서 접근할 수 없어 주제 선정에 사용하지 않았다.

## 오늘 후보에서 남은 질문은 “누가 발견을 검증하는가”였다

최근 글의 저장소명뿐 아니라 검색 의도와 중심 판단을 대조했다. 저사양 추론, macOS 생산성 도구, 역공학, 생성형 음악도 장기 후보가 될 수 있지만 이번 신호에서는 AI 보안 감사 결과를 운영 가능한 증거로 바꾸는 문제가 가장 선명했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도 판단 |
|---|---|---|
| [Security Audit Skill](https://github.com/cloudflare/security-audit-skill) | daily 1,249, 7,075 stars, MIT, 정식 release 없음 | 코드베이스 보안 감사의 커버리지·독립 검증·증거 계약이라는 별도 의도가 있다. |
| [colibri](https://github.com/JustVugg/colibri) | daily 1,532, 약 35.0k stars, Apache-2.0, v1.11.0 | MoE expert의 디스크 스트리밍은 AirLLM·KTransformers의 저VRAM 추론 의도와 가깝다. |
| [tinycast](https://github.com/abue-ammar/tinycast) | daily 1,136, 약 5.6k stars, v0.10.23 | 경량 macOS 런처와 클립보드 권한은 독립적이지만 전날 Homebrew GUI 글과 독자 맥락이 연속된다. |
| [Ghidra](https://github.com/NationalSecurityAgency/ghidra) | daily 1,059, 약 77.7k stars, Apache-2.0, 12.1.3 | 장기 가치는 높지만 Trending 신호만으로는 범용 역공학 입문을 넘어설 좁은 문제 정의가 부족했다. |
| [YuE](https://github.com/multimodal-art-projection/YuE) | daily 370, 약 9.4k stars, Apache-2.0, v0.1.6 | 음악 생성·편집은 별도 의도지만 기존 음성·미디어 파이프라인과 연결할 운영 자료를 더 축적할 필요가 있다. |

이 주제는 [SkillSpector의 에이전트 스킬 공급망 검사](/posts/github-trending-skillspector-agent-skill-security/)와 이름이 비슷해 보인다. 그러나 SkillSpector는 설치하려는 스킬 자체가 악성 지침이나 과도한 권한을 품었는지 묻는다. Security Audit Skill은 에이전트 스킬을 이용해 **대상 코드베이스의 취약점을 어떻게 조사하고 검증할지**를 다룬다. 검사 대상과 증거 생산자가 반대편에 있으므로 같은 검색 의도가 아니다.

## 여섯 단계의 본질은 역할 분리보다 상태 분리다

공식 README는 전체 감사를 여섯 단계로 정리한다. reconnaissance, coverage-led hunting, candidate validation, structured output, independent record verification, target-neutral reporting이다. 겉으로는 여러 에이전트를 병렬로 부르는 구성처럼 보이지만, 운영 관점의 핵심은 각 단계가 서로 다른 상태를 소유한다는 점이다.

![정찰에서 독립 검증과 보고서까지 이어지는 AI 보안 감사 아키텍처](https://heracles-jo.github.io/assets/img/posts/cloudflare-security-audit-skill-validation-pipeline/architecture.svg)

정찰 단계는 `architecture.md`와 `coverage-ledger.json`을 만든다. 원장에는 공격 표면, 서브시스템, 신뢰 경계와 attack class의 조합이 작업 단위로 남는다. hunter의 자유로운 탐색이 “흥미로운 파일 몇 개를 읽었다”로 끝나지 않도록, 무엇을 계획했고 무엇이 covered·blocked·deferred·out_of_scope인지 외부 상태로 기록한다. 여러 실행의 원장을 비교하면 이전에 확인한 소스와 바뀐 소스를 구분해 재검증할 수도 있다.

후보가 나오면 발견한 에이전트가 스스로 확정하지 않는다. fresh verifier가 source trace와 재현 조건을 따라가며 틀렸음을 증명하려고 한다. 최종 판정은 세 가지다.

- `confirmed`: 구체적인 신뢰 경계 위반, 완전한 소스 추적, 제한된 관찰 결과가 있다.
- `needs_validation`: 소스에 근거한 가설은 있지만 배포 설정이나 안전한 실행 환경처럼 결정적인 사실이 없다. severity를 붙이지 않는다.
- `rejected`: 반증된 후보도 버리지 않고 기록해 같은 오탐이 반복되는 것을 줄인다.

`findings.json`은 `report-schema.json`으로 검사하고, coverage 원장도 별도 JavaScript validator로 확인한다. 스키마 검증은 취약점이 진짜임을 증명하지 않는다. 다만 파일 경로·라인·경계·영향·판정 같은 필수 필드가 사라진 채 그럴듯한 산문으로 변하는 것을 막는다. [Open Code Review의 결정론적 외곽 구조](/posts/open-code-review-hybrid-ai-code-review/)가 리뷰 대상과 코멘트 위치를 고정했듯, 여기서 코드가 맡는 역할은 모델의 보안 판단이 아니라 **판단을 검토할 수 있는 형식의 보존**이다.

## 커버리지 원장은 “취약점 0건”을 안전한 문장으로 바꾼다

자동 보안 감사에서 가장 위험한 출력은 틀린 취약점 하나만이 아니다. 제한된 시간에 일부 경로만 읽은 결과를 전체 저장소의 무결성 보증처럼 표현하는 것도 위험하다. Security Audit Skill은 한 번의 실행이 완전하지 않다고 명시하고, quick·standard·deep profile에 따라 조사 단위와 critic 횟수, 검증 예산을 달리한다.

이 구조에서 “confirmed 0건”은 “취약점이 없다”가 아니다. 현재 source ref, 선택한 scope, 실행 profile과 예산 안에서 완료된 ledger unit에서 확정된 결과가 없다는 뜻이다. 예산 부족으로 verifier를 배정하지 못한 후보는 억지로 `needs_validation`에 넣어 실행을 성공 처리하지 않고 run 자체를 `incomplete`로 남긴다. 보안 대시보드에서는 이 차이를 다음처럼 분리해야 한다.

| 운영 지표 | 의미 | 잘못된 해석 |
|---|---|---|
| confirmed 수 | 증거 계약을 통과한 경계 위반 | 적을수록 제품이 안전함 |
| rejected 수·비율 | 검증 단계가 제거한 후보와 오탐 비용 | 모델 품질이 나쁘므로 모두 폐기 |
| ledger coverage | 계획한 감사 단위 중 상태가 설명된 범위 | 코드 라인 커버리지와 동일 |
| blocked·deferred | 샌드박스, 설정, 예산 때문에 남은 공백 | 취약점이 아닌 영역 |
| 반복 실행의 신규 root cause | 추가 실행이 발견한 순증가 신호 | 총 취약점 recall의 직접 추정치 |

Cloudflare의 공식 기술 글도 단일 실행이 반복 실행 전체에서 발견한 취약점의 대략 절반만 찾았다고 밝힌다. 이는 통제된 전체 recall 보장이 아니라 프로젝트의 자체 test run 관찰이다. 실제 코드베이스에는 정답 집합이 없으므로 “95%의 취약점을 찾는다” 같은 수치를 만들 수 없다. 대신 재실행에서 새 root cause가 계속 나오는지, coverage gap이 줄어드는지, 사람 triage가 accepted finding을 재현할 수 있는지를 본다.

## 가장 중요한 보안 경계는 감사 대상과 감사 실행기 사이에 있다

취약점을 찾기 위해 build, test, parser fixture, 브라우저나 fuzzer를 실행하는 순간 대상 저장소는 더 이상 수동적인 입력이 아니다. 악성 `package.json` script, build hook, test fixture, compiler plugin이 감사 호스트의 토큰과 네트워크에 접근할 수 있다. “보안 감사이므로 실행해도 안전하다”는 가정이 오히려 공급망 공격 통로를 만든다.

공식 skill은 target-controlled 실행에 운영체제 수준 샌드박스를 요구한다. 외부 네트워크를 끄고, 환경 변수는 빈 상태에서 명시적 allowlist만 채우며, target과 toolchain은 read-only로 두고, agent별 scratch 경로에만 쓰게 한다. CPU·메모리·프로세스·파일 크기·디스크·실행 시간도 제한해야 한다. 하나라도 강제할 수 없다면 target code를 실행하지 않고 해당 후보를 `needs_validation`으로 남긴다.

이 요구는 [CubeSandbox의 MicroVM 코드 실행 격리](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)에서 다룬 실행 경계와 이어진다. 컨테이너 하나를 띄웠다는 사실만으로 충분하지 않다. host socket, 홈 디렉터리, credential helper, package cache, Docker daemon, cloud metadata endpoint가 보이면 감사 대상이 감사자를 공격할 수 있다. 로컬 loopback이 필요한 테스트도 외부 egress와 분리해야 한다.

아티팩트 반출 절차가 유난히 엄격한 이유도 같다. skill은 scratch에서 retained artifact로 옮길 때 절대 경로·`..`·symlink를 거부하고, no-follow open과 `fstat`, regular file·link count·크기 제한을 확인하도록 한다. 재귀 복사나 archive 일괄 해제를 금지한다. 대상 프로세스가 symlink race, FIFO, device file, 거대한 결과물로 상위 실행기를 공격할 수 있기 때문이다. 보안 감사의 PoC도 신뢰되지 않은 출력이라는 원칙이다.

## 독립 verifier가 있다고 독립적인 판단이 자동으로 생기지는 않는다

발견자와 검증자를 다른 sub-agent로 나누는 것은 필요한 출발점이지만 충분조건은 아니다. 둘이 같은 모델, 같은 system prompt, 같은 압축된 정찰 요약을 공유하면 같은 오해를 반복할 수 있다. Cloudflare의 확장형 harness는 discovery와 validation에 서로 다른 모델을 사용한다고 설명하지만, 공개 저장소는 단일 저장소용 skill이며 그 fleet-wide 시스템 전체 구현은 아니다.

PoC에서는 독립성을 네 층으로 측정하는 편이 낫다.

1. **상태 독립성**: verifier에게 hunter의 추론 전체가 아니라 최소 후보·source trace·재현 계약만 전달한다.
2. **권한 독립성**: verifier는 finding을 새로 만들 수 없고 confirm·reject·block만 하게 한다.
3. **실행 독립성**: 별도 scratch와 깨끗한 checkout에서 원본 source ref를 다시 확인한다.
4. **모델 독립성**: 고위험 finding은 가능하면 다른 모델 계열 또는 사람 reviewer가 재검증한다.

동시에 사람 승인도 “마지막에 보고서를 읽는다”로 끝내면 안 된다. 인증 우회, cross-tenant 접근, 원격 코드 실행처럼 영향이 큰 항목은 threat model, 최소 재현, 원본 코드에서의 결과, 패치 후 회귀 테스트를 사람이 다시 확인해야 한다. 에이전트가 만든 severity는 triage 우선순위의 입력이지 CVE나 배포 차단을 자동 결정하는 판결이 아니다.

## 기존 AppSec 도구를 대체하지 말고 증거를 연결한다

이 skill의 attack class에는 메모리 안전성, AI·LLM, 웹 프로토콜·인증, 공급망·release, cloud·deployment, RPC·messaging, 자원 고갈, 데이터 격리 등이 포함된다. 범위가 넓다고 해서 SAST, SCA, secret scanning, fuzzing, IaC policy를 제거할 근거는 되지 않는다.

[Trivy 기반 공급망 보안](/posts/github-trending-trivy-supply-chain-security/)처럼 결정론적 스캐너는 알려진 package·image·misconfiguration 신호를 반복 가능하게 찾는다. AI 감사는 여러 함수와 설정을 걸친 의미적 경계, 저장소 특화 attack class, 기존 rule로 표현하기 어려운 비즈니스 로직을 탐색하는 데 배치한다. 양쪽 결과를 같은 finding schema나 SARIF로 연결할 수는 있지만 출처와 확실성은 구분해야 한다.

또한 [위험 명령 차단 훅](/posts/ai-agent-destructive-command-guard/)은 감사 에이전트가 host에서 파괴적 명령을 실행하는 실수를 줄일 수 있으나 OS 샌드박스를 대신하지 않는다. 문자열 기반 guard가 허용한 build script도 악성일 수 있다. 설치 전 skill scanning, 실행 전 명령 guard, 실행 중 sandbox, 결과 후 독립 검증은 서로 다른 실패를 막는 방어선이다.

## PoC는 발견 건수보다 반증 비용을 측정해야 한다

처음부터 전사 저장소를 계속 스캔하면 토큰 비용과 중복 후보가 먼저 쌓인다. 최근 1년 안에 실제로 수정한 보안 결함이 있고, test fixture를 로컬에서 재현할 수 있으며, 배포 설정 없이도 경계를 설명할 수 있는 저장소 한두 개로 시작한다. 수정 전 commit과 수정 후 commit을 분리해 blind evaluation corpus를 만든다.

![AI 보안 감사를 CI와 취약점 관리 체계에 넣기 전 확인할 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/cloudflare-security-audit-skill-validation-pipeline/decision.svg)

측정 항목은 다음 다섯 묶음이면 된다.

- **탐지와 반증**: 알려진 결함 재발견률, unique candidate 중 confirmed 비율, verifier가 제거한 root cause 중복과 vacuous finding 비율
- **증거 품질**: source ref·파일·함수·trust boundary·관찰 결과의 재현률, 원본 미변경 검증, 사람 reviewer의 재현 시간
- **커버리지**: profile별 planned·covered·blocked·deferred unit, 반복 실행에서 새로 채운 gap, 변경 source의 재검증 누락
- **운영 비용**: 저장소당 agent 호출·token·wall time, p50/p95 triage 시간, 중단 후 resume 성공률, 모델·도구 버전별 변동
- **격리 안전성**: egress 차단, credential 비노출, write 범위, 자원 제한, symlink·대용량 artifact fixture의 차단 결과

합격선은 “취약점 10개 발견”처럼 쓰지 않는다. 예를 들어 critical/high 과거 결함은 전부 후보로 올리고, confirmed finding의 사람 재현률 100%, target-controlled 실행의 외부 egress 0건, blocked unit을 성공으로 집계한 사례 0건, source ref 없는 보고 0건처럼 증거와 경계를 기준으로 둔다. 오탐이 많아도 verifier가 싸게 제거하면 탐색 단계에서는 허용할 수 있지만, 사람에게 전달되는 confirmed의 재현성이 낮으면 중단해야 한다.

CI 적용도 단계적으로 한다. 처음에는 예약 실행에서 보고서만 만들고 merge를 막지 않는다. 다음에는 변경된 고위험 경계만 scoped run으로 검사하고, schema·ledger validator 실패와 sandbox 정책 위반만 기계적으로 차단한다. AI가 붙인 severity로 merge를 막는 것은 과거 결함 corpus와 사람 재현성이 축적된 뒤의 일이다. private source와 finding이 외부 모델로 전송되는 경우 provider의 보존·학습·리전·incident 조건도 별도 승인해야 한다.

## skill에서 harness로 넘어갈 시점

공개 skill은 단일 저장소에서 절차를 검증하기 좋은 출발점이다. 그러나 실행이 길어지고 저장소가 늘면 context와 파일만으로는 버티기 어렵다. Cloudflare의 기술 글은 초기 skill에서 fleet-wide harness로 옮길 때 context exhaustion, 중단 복구, cross-repo reasoning이 한계였다고 설명한다. 각 stage를 stateless worker로 만들고, run·repo·stage별 상태를 데이터베이스에 보존하며, dependency graph와 dedup queue를 추가한 이유다.

조직이 다음 신호를 보면 orchestration 투자를 검토할 수 있다.

- 같은 저장소를 여러 번 실행하고 사람이 원장과 finding을 수동으로 diff한다.
- rate limit이나 worker 실패 한 번에 수 시간의 조사가 사라진다.
- 공통 library의 경계 위반을 consumer 저장소까지 추적해야 한다.
- 같은 root cause가 여러 모델·branch·저장소에서 반복돼 triage queue가 막힌다.
- 모델 교체 때 과거 결과의 재현성과 비용을 비교할 실행 메타데이터가 없다.

그 전에는 복잡한 플랫폼부터 만들 필요가 없다. 정찰·탐색·독립 검증, immutable source ref, 외부 상태 원장, OS 샌드박스라는 최소 계약을 한 저장소에서 지키는 편이 낫다. 반대로 이 계약 없이 병렬 agent 수만 늘리면 발견량이 아니라 중복과 확신만 증가한다.

Cloudflare Security Audit Skill의 실무 가치는 “AI가 보안 전문가를 대체한다”는 데 있지 않다. 불완전한 탐색을 coverage ledger에 남기고, 후보와 확정 finding을 분리하며, target code를 비신뢰 실행물로 취급하고, 사람이 재현할 수 있는 구조화된 증거만 보고서로 승격하는 데 있다. 채택 여부는 stars나 발견 건수보다 세 질문으로 결정해야 한다. **감사하지 않은 범위를 설명할 수 있는가, 발견자와 독립된 주체가 원본에서 결과를 반증했는가, 감사 대상이 감사 인프라를 공격해도 영향이 격리되는가.** 셋 중 하나라도 답이 없다면 아직 취약점 자동화가 아니라 취약점 후보 생성기다.

> 1차 자료: [Security Audit Skill 저장소와 README](https://github.com/cloudflare/security-audit-skill), [공식 SKILL.md](https://github.com/cloudflare/security-audit-skill/blob/main/skills/security-audit/SKILL.md), [검증·보고 규약](https://github.com/cloudflare/security-audit-skill/blob/main/skills/security-audit/VALIDATION-AND-REPORTING.md), [coverage ledger validator](https://github.com/cloudflare/security-audit-skill/blob/main/skills/security-audit/validate-coverage-ledger.cjs), [findings schema](https://github.com/cloudflare/security-audit-skill/blob/main/skills/security-audit/report-schema.json), [Cloudflare의 vulnerability harness 설계 글](https://blog.cloudflare.com/build-your-own-vulnerability-harness/), [MIT LICENSE](https://github.com/cloudflare/security-audit-skill/blob/main/LICENSE), [commit 기록](https://github.com/cloudflare/security-audit-skill/commits/main/), [공개 Pull Requests](https://github.com/cloudflare/security-audit-skill/pulls). Trending·저장소 수치는 2026년 9월 17일 08시 20분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
