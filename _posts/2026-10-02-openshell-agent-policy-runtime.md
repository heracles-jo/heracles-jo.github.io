---
title: "AI 에이전트 정책 런타임: OpenShell 격리·자격증명 기준"
description: "OpenShell의 커널 강제 격리, 네트워크 요청 검사, 자격증명 주입, 정책 증명을 분해해 자율 에이전트를 운영할 때의 도입 경계와 PoC 기준을 제시한다."
author: heracles-jo
date: 2026-10-02 08:25:00 +0900
categories: [AI Infrastructure, Security]
tags: [openshell, ai-agent-security, sandbox, policy-as-code, credential-broker, network-egress]
image:
  path: https://heracles-jo.github.io/assets/img/posts/openshell-agent-policy-runtime/cover.svg
  alt: "OpenShell이 AI 에이전트의 파일·프로세스·네트워크·자격증명 접근을 정책으로 통제하는 구조"
---

자율 AI 에이전트가 유용해지려면 파일을 읽고, 패키지를 설치하고, GitHub나 클라우드 API를 호출하며, 때로는 자격증명을 사용해야 한다. 문제는 이 권한을 에이전트 프로세스에 그대로 넘기는 순간 프롬프트 인젝션과 잘못된 계획, 공급망 스크립트가 같은 권한을 공유한다는 점이다. 컨테이너 하나를 띄우거나 위험 명령을 문자열로 차단하는 것만으로는 파일 접근, 우회 네트워크, API 쓰기 요청, 비밀정보 반출을 하나의 경계에서 설명하기 어렵다.

[NVIDIA/OpenShell](https://github.com/NVIDIA/OpenShell)은 이 간극을 **에이전트 정책 런타임**으로 다룬다. 에이전트는 격리된 sandbox 안에서 실행하고, 신뢰된 supervisor가 파일·프로세스·네트워크 정책을 집행한다. 실제 자격증명은 sandbox에 전달하지 않고 승인된 목적지로 나가는 요청에만 주입한다. 여기에 SMT solver 기반 policy prover를 붙여 새 정책이 허용 경계를 넓히는지 적용 전에 검사한다. 핵심은 “안전한 에이전트”를 약속하는 것이 아니라 **에이전트가 틀려도 가능한 행위를 런타임이 제한하고 검증하게 만드는 것**이다.

2026년 10월 2일 08시 35분 KST 전후 GitHub Trending daily에서 OpenShell은 **2,503 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 **13,991 stars**, 1,622 forks, 열린 이슈와 PR을 합친 515개, Apache-2.0 라이선스였고 최신 안정 릴리스는 9월 28일의 `v0.1.2`였다. 10월 2일 KST 새벽까지 sandbox 로그, policy proposal 갱신, supervisor 입력 제한 관련 커밋이 이어졌다. 수치와 활동 상태는 확인 시점의 공개 스냅샷이며 보안성이나 프로덕션 적합성을 보증하지 않는다. 이번 실행 환경에서는 Search Console과 Analytics의 실제 검색어·노출·CTR 데이터에 접근할 수 없어 주제 선택에 사용하지 않았다.

## 후보를 걸러 내고 남은 질문은 “권한을 어디서 강제할 것인가”였다

오늘 후보는 에이전트 도구에 크게 치우쳐 있었다. 저장소명뿐 아니라 기존 글의 중심 논지와 검색 의도를 비교하면 스킬 작성법, 병렬 에이전트, 범용 sandbox 소개를 다시 쓰기 쉬운 목록이었다. OpenShell도 sandbox를 제공하지만, 이번 글의 초점은 실행 환경 자체보다 **process identity와 API 요청 단위로 정책을 집행하고 자격증명을 분리하는 방법**이다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [NVIDIA/OpenShell](https://github.com/NVIDIA/OpenShell) | daily 2,503, 13,991 stars, Apache-2.0, v0.1.2 | kernel 경계, L7 egress, credential broker, policy proof를 연결한 최소 권한 런타임 의도가 분명해 선택했다. |
| [mvschwarz/openrig](https://github.com/mvschwarz/openrig) | daily 640, 3,695 stars, Apache-2.0 | 지속형 에이전트 팀은 Orca·Google AX의 병렬 실행과 오케스트레이션 의도에 가깝다. |
| [tile-ai/tilelang](https://github.com/tile-ai/tilelang) | daily 157, 8,092 stars, 라이선스 API `NOASSERTION` | GPU kernel DSL은 가치가 크지만 기존 추론 최적화 글과 구분하려면 성능 실측이 더 필요하다. |
| [mattpocock/skills](https://github.com/mattpocock/skills) | daily 888, 273,868 stars, MIT | 에이전트 스킬·개발 절차는 이미 스킬 엔지니어링과 공급망 보안 글에서 다뤘다. |
| [firebase/firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk) | daily 112, 6,855 stars, Apache-2.0 | Apple 앱 SDK 운영은 독립 주제지만 오늘 신호만으로 좁고 지속적인 검색 문제를 정의하기 어렵다. |

[CubeSandbox의 MicroVM 실행 격리](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)가 비신뢰 코드를 어떤 인프라 경계에 가둘지 물었다면, OpenShell은 그 안에서 **어떤 binary가 어느 host와 API path에 접근하고 어떤 credential을 받을지**를 묻는다. [Google AX의 에이전트 오케스트레이션](/posts/google-ax-agent-orchestration/)이 sandbox 생성·중단·재개를 상위 제어면에서 다뤘다면, OpenShell은 한 실행의 권한 집행과 정책 변경 승인에 더 가깝다.

## 신뢰 경계는 sandbox 안과 supervisor 밖으로 갈린다

공식 architecture는 gateway, supervisor, sandbox를 분리한다. Gateway는 sandbox 수명주기, 정책, provider, 사용자 권한을 관리하는 제어면이다. Agent process는 sandbox boundary 안의 비신뢰 workload다. Supervisor는 boundary 밖에서 요청을 판정하고 DNS를 해석하며 승인된 upstream 연결을 열고 자격증명을 주입한다.

![OpenShell에서 에이전트 요청이 커널 경계와 supervisor 정책 검사를 거치는 아키텍처](https://heracles-jo.github.io/assets/img/posts/openshell-agent-policy-runtime/architecture.svg)

Linux backend에서 workload는 non-root identity와 capability 없이 실행되고, Landlock이 filesystem 접근을 제한한다. TCP open과 DNS query는 seccomp user notification으로 가로채 supervisor로 보낸다. Docker·Podman은 workload network를 끄고 Unix socket으로 연결하며, Kubernetes는 NetworkPolicy와 mTLS private service, MicroVM은 network device가 없는 guest와 vsock을 사용한다. runtime마다 도구는 달라도 **workload가 supervisor를 우회해 직접 egress하지 못해야 한다**는 계약은 같다.

일반 sidecar proxy보다 눈에 띄는 부분은 process identity를 kernel 관찰에서 얻는다는 점이다. 규칙은 sandbox 전체가 `api.github.com`에 갈 수 있다고 쓰는 대신 실제 executable path와 host·port를 묶는다. REST method와 path, WebSocket message, GraphQL operation, MCP tool, JSON-RPC method도 검사할 수 있다. `curl`의 GitHub `GET /repos/**`는 허용하면서 `POST`와 `DELETE`는 막는 식이다.

정밀한 규칙이 곧 정확한 경계를 뜻하지는 않는다. `pip`가 실제로는 Python interpreter에서 연결을 열고, agent가 시작한 child process가 부모 binary 규칙을 상속할 수 있다. 같은 host·port에 겹치는 규칙은 허용 범위를 합친다. inspected endpoint의 기본 enforcement가 `audit`라면 위반을 기록할 뿐 차단하지 않는다. binary 식별, rule overlap, `audit`와 `enforce`를 잘못 이해하면 정책 파일보다 실제 권한이 넓어진다.

## 자격증명을 숨겨도 upstream 권한은 다시 좁혀야 한다

OpenShell provider는 API key나 cloud token을 gateway 쪽에 저장하고, supervisor가 provider profile과 policy가 모두 허용한 요청에만 credential을 추가한다. Sandbox runtime에는 gateway signing key와 provider credential을 두지 않는다. AWS STS나 OAuth refresh처럼 짧은 수명 credential을 gateway가 갱신하는 흐름도 제공한다.

환경 변수에 키를 넣고 agent가 자유롭게 읽게 하는 것보다 낫지만 credential broker가 least privilege를 자동 완성하지는 않는다. GitHub API가 허용돼 있으면 agent가 private repository 내용을 새 issue나 gist로 보낼 가능성을 method·path 정책으로 막아야 한다. Git, SSH, custom binary protocol처럼 내용을 검사하기 어려운 경로는 destination allowlist 이상의 통제가 약하다. Provider readiness도 새 process가 새 revision을 적용했다는 뜻이지 upstream 권한이 최소화됐다는 뜻은 아니다.

따라서 provider에는 read-only scope, repository·bucket·role 단위 제한, 짧은 TTL을 적용해야 한다. OpenShell은 “어디로 보낼 수 있는가”를 좁히고 upstream IAM은 “도착한 뒤 무엇을 할 수 있는가”를 다시 제한해야 한다. Broker가 compromise될 때의 blast radius도 별도 threat model에 포함해야 한다.

## Policy prover의 핵심은 통과가 아니라 coverage다

Policy prover는 candidate가 조직의 boundary policy보다 넓은 filesystem, process, Landlock, L4 network, REST 접근을 허용하는지 검사하고 경계를 넘으면 counterexample을 돌려준다. Agent가 blocked request 뒤 새 rule을 제안할 때도 cloud metadata, 새 credential destination, L7 우회 같은 위험을 찾는다.

“Formal verification”을 정책 전체의 안전성 증명으로 읽으면 안 된다. 공식 문서는 GraphQL·MCP·WebSocket·JSON-RPC rule, 서로 다른 filesystem 하위 path와 symlink 의미, 일부 wildcard 조합을 `unsupported`로 반환한다고 명시한다. 정책이 너무 크거나 시간이 부족하면 `inconclusive`가 될 수 있다. 통과 결과도 **모델링된 범위에서 boundary를 넘지 않는다**는 뜻이지 task에 꼭 필요한 최소 정책이거나 runtime이 올바르게 집행한다는 뜻은 아니다.

CI에서는 `coverage.domains`와 `reason_code`를 함께 확인하고 `within_boundary` 외의 결과를 실패로 취급해야 한다. 실제 sandbox에서는 허용 요청뿐 아니라 반드시 막혀야 할 요청을 실행한다. 정책 증명은 배포 전 정적 보증이고, denial canary와 egress log는 실행 중 동적 보증이다.

## 자동 policy proposal은 권한 팽창 경로가 될 수 있다

Policy advisor를 켜면 blocked request를 본 agent가 host, port, binary, method, path로 좁힌 network rule을 제안할 수 있다. 기본값은 사람이 승인하는 manual mode이며, filesystem·Landlock·process identity는 proposal로 바꿀 수 없다. 승인된 network rule은 재시작 없이 반영된다.

주의할 부분은 `auto` approval이다. Prover가 알려진 위험을 찾지 않고 destination heuristic이 flag하지 않으면 public host 접근이 사람 검토 없이 열릴 수 있다. Credential이 붙지 않아도 source code, prompt, build artifact는 유출될 수 있다. 운영에서는 manual을 기본으로 두고, 자동 승인이 필요하다면 조직 mirror나 고정 artifact host처럼 상위 destination 집합부터 제한하는 편이 낫다. 반복 proposal, wildcard 확대, 거부 뒤 재제안, provider가 붙은 destination 증가는 감사 이벤트로 남겨야 한다.

## 실패 모드는 정책보다 통제면 의존성에서 먼저 보인다

OpenShell은 supervisor 연결이 끊기면 agent를 freeze하고 boundary를 확인하기 전에는 workload를 시작하지 않는 fail-closed 설계를 설명한다. 보안에는 유리하지만 supervisor, gateway, policy store, DNS와 proxy가 availability 경로에 들어온다. 대규모 fleet에서는 정책 정확성만큼 queue, reconnect, freeze·resume, orphan cleanup을 측정해야 한다.

Kubernetes에서는 CNI가 `NetworkPolicy`를 실제로 집행해야 한다. [Cilium 전환 글](/posts/cilium-ebpf-networking-migration/)에서 다뤘듯 정책 객체와 packet verdict는 다르다. Supervisor service만 허용한 canary workload에서 public DNS, metadata endpoint, node-local service, 다른 sandbox로의 직접 연결이 모두 차단되는지 시험해야 한다.

커널 요구사항도 가볍지 않다. 공식 support matrix는 Landlock ABI 3, seccomp user notification과 `SECCOMP_IOCTL_NOTIF_ADDFD`, workload memory mediation을 요구한다. 일부 오래된 kernel은 reduced legacy read-only mode로 동작한다. Kubernetes 버전만 확인하고 node kernel, LSM 활성화, runtime seccomp profile을 보지 않으면 sandbox가 시작되지 않거나 기능이 줄어든다.

릴리스는 stable patch를 대체로 주 단위로 내고 최신 minor와 직전 minor를 지원한다. 빠른 수정은 긍정적이지만 `v0.1.x` 단계에서는 gateway, supervisor, sandbox runtime, CLI, SDK, prover 버전을 한 묶음으로 고정하고 conformance 없이 부분 업그레이드하지 않는 편이 안전하다.

## 기존 방어선과 겹치지 않게 배치해야 한다

OpenShell은 [위험 명령 차단 훅](/posts/ai-agent-destructive-command-guard/)의 대체품이 아니다. 명령 guard는 개발자 workspace에서 복구 불가능한 CLI 실수를 막고, OpenShell은 agent를 별도 boundary에 넣어 파일·process·network 권한을 강제한다. Branch protection, cloud IAM, API-side authorization, artifact signing도 그대로 남는다.

[Cloudflare Security Audit Skill의 검증 구조](/posts/cloudflare-security-audit-skill-validation-pipeline/)처럼 비신뢰 repository를 build·test하는 workload라면 OpenShell은 감사 대상이 감사 실행기를 공격하는 것을 막는 하부 경계가 될 수 있다. 그러나 finding의 진위, source trace, coverage는 별도 evidence pipeline이 맡아야 한다. 격리는 잘못된 실행의 영향 범위를 줄일 뿐 잘못된 결론을 고쳐 주지 않는다.

![OpenShell 도입 전 런타임 경계와 운영 준비도를 함께 판단하는 의사결정표](https://heracles-jo.github.io/assets/img/posts/openshell-agent-policy-runtime/decision.svg)

## 2주 PoC는 “차단됨”보다 우회와 복구를 측정한다

외부 부작용이 제한되고 결과를 Git diff로 판정할 수 있는 코드 수정 agent로 시작하는 편이 좋다. Production cloud 계정이나 고객 데이터 대신 합성 credential과 전용 repository·role을 사용한다.

| 측정 영역 | 확인할 값 | 중단 조건 예시 |
|---|---|---|
| 파일·프로세스 | read/write denial, symlink·child process·binary 교체 | 허용하지 않은 path 접근 또는 identity 우회 |
| 네트워크 | direct egress, DNS, private IP, metadata, L7 차단 | supervisor를 우회한 연결 또는 audit 오인 |
| 자격증명 | 평문 노출, destination binding, TTL·revocation | credential이 env·file·log에 남거나 다른 host에 재사용됨 |
| 정책 증명 | coverage, unsupported·timeout, counterexample | 미지원 정책을 성공으로 처리하거나 boundary 초과를 놓침 |
| 제안 운영 | proposal 수, 승인 시간, 반복·확대 제안 | prompt injection이 새 host 접근을 자동 획득 |
| 가용성 | gateway·supervisor 장애 시 freeze·resume | fail-open 또는 장시간 orphan workload |
| 업그레이드 | patch 간 policy·SDK·runtime 호환성 | rollback 없이 차단 결과가 바뀜 |

먼저 provider 없이 default deny를 확인하고, 다음으로 read-only endpoint 하나만 연다. 그 뒤 합성 credential을 특정 method·path에만 주입하고 다른 binary·host·path에서 탈취를 시도한다. Policy advisor는 manual mode에서 reviewer 시간을 잰 뒤 마지막에 제한된 자동화를 검토한다. Gateway와 supervisor를 강제 종료해 freeze와 복구가 실제로 일어나는지도 확인한다.

OpenShell이 잘 맞는 조직은 agent workload를 여러 팀이나 tenant에 제공하고, 파일·네트워크·credential 경계를 중앙 정책으로 표준화하며, 플랫폼팀과 보안팀이 gateway와 runtime을 지속 운영할 수 있는 곳이다. 신뢰된 내부 script 몇 개를 단일 CI runner에서 실행하거나 외부 API와 비밀정보 접근이 거의 없다면 기존 ephemeral runner와 IAM, egress firewall이 더 단순할 수 있다.

OpenShell의 가치는 sandbox 기능 수가 아니라 통제점을 연결하는 방식에 있다. Kernel boundary가 direct access를 막고, supervisor가 process와 request를 판정하며, provider가 credential을 destination에 묶고, prover가 정책 확대를 배포 전에 검사한다. 동시에 kernel 지원, proxy 호환성, CNI enforcement, solver coverage, reviewer 운영이라는 새 의존성을 만든다. 도입 여부는 “에이전트가 안전해 보이는가”가 아니라 **거부돼야 할 행위가 실제로 거부되고, 정책 확대가 설명 가능하며, 통제면 장애 때 workload가 안전하게 멈추는가**로 결정해야 한다.

> 1차 자료: [NVIDIA/OpenShell 저장소와 README](https://github.com/NVIDIA/OpenShell), [Apache-2.0 LICENSE](https://github.com/NVIDIA/OpenShell/blob/main/LICENSE), [공식 Architecture](https://docs.nvidia.com/openshell/latest/about/architecture), [Sandbox Policies](https://docs.nvidia.com/openshell/latest/how-it-works/policies/overview), [Network Rules](https://docs.nvidia.com/openshell/latest/how-it-works/policies/network-rules), [Policy Prover](https://docs.nvidia.com/openshell/latest/how-it-works/policies/prover), [Policy Advisor](https://docs.nvidia.com/openshell/latest/how-it-works/policies/advisor), [Providers](https://docs.nvidia.com/openshell/latest/how-it-works/providers/overview), [Support Matrix](https://docs.nvidia.com/openshell/latest/about/support-matrix), [v0.1.2 release](https://github.com/NVIDIA/OpenShell/releases/tag/v0.1.2), [최근 commits](https://github.com/NVIDIA/OpenShell/commits/main/), [공개 issues](https://github.com/NVIDIA/OpenShell/issues), [공개 pull requests](https://github.com/NVIDIA/OpenShell/pulls). Trending·저장소 수치는 2026년 10월 2일 08시 35분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
