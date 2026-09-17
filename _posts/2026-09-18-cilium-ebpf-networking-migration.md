---
title: "Cilium eBPF 네트워킹 전환: kube-proxy 대체와 업그레이드 기준"
description: "Cilium의 eBPF 데이터패스와 ID 기반 정책을 해부하고, kube-proxy 대체 범위·관측성·장애 위험·단계별 전환 기준을 운영 관점에서 정리한다."
author: heracles-jo
date: 2026-09-18 08:40:00 +0900
categories: [Cloud, Security]
tags: [cilium, ebpf, kubernetes-networking, network-policy, kube-proxy, platform-engineering]
image:
  path: https://heracles-jo.github.io/assets/img/posts/cilium-ebpf-networking-migration/cover.svg
  alt: "Cilium eBPF 데이터패스로 Kubernetes 네트워킹과 보안 정책을 전환하는 운영 기준"
---

Kubernetes 네트워크 장애를 조사하다 보면 애플리케이션보다 먼저 여러 계층을 건드리게 된다. Pod의 veth, CNI, 노드 라우팅, `iptables` 또는 IPVS 규칙, kube-proxy, 클라우드 로드밸런서, NetworkPolicy, 서비스 메시, DNS와 MTU가 차례로 등장한다. 각각은 합리적인 역할을 맡지만, 패킷 한 개가 어디서 변환되고 거부됐는지 설명하려면 여러 도구의 상태를 맞춰야 한다. **Cilium 전환의 핵심은 eBPF가 빠르다는 구호가 아니라, 네트워킹·정책·관측의 책임을 어디까지 하나의 데이터패스에 모을 것인지 결정하는 일**이다.

[cilium/cilium](https://github.com/cilium/cilium)은 eBPF 기반 네트워킹, 보안, 관측성 솔루션이다. Pod IP 대신 Kubernetes identity와 label을 정책 판단에 활용하고, 커널 hook과 BPF map으로 서비스 로드밸런싱과 정책 집행을 수행한다. Hubble은 같은 데이터패스에서 flow를 관찰한다. 선택에 따라 kube-proxy를 대체하고 Gateway API, ingress, egress gateway, Cluster Mesh까지 맡길 수도 있다. 기능 목록만 보면 매력적이지만, 이 범위를 한 번에 활성화하면 CNI 교체가 아니라 클러스터 네트워크 운영 모델 전체를 바꾸는 프로젝트가 된다.

2026년 9월 18일 08시 50분 KST 전후 GitHub Trending daily에서 Cilium은 **153 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 **25,258 stars**, 4,073 forks, Apache-2.0 라이선스, 열린 이슈와 PR을 합친 1,089개였고, 9월 17일까지 커밋이 이어졌다. 최신 안정 패치 릴리스는 9월 16일 공개된 `v1.20.2`였다. 이 수치와 상태는 확인 시점의 공개 스냅샷이며 성능이나 특정 클러스터의 적합성을 보증하지 않는다. Search Console과 Analytics의 실제 검색어 데이터에는 이번 실행 환경에서 접근할 수 없어 주제 선택에 사용하지 않았다.

## 후보 비교에서 Cilium을 남긴 이유

오늘 daily 상위에는 전날 다룬 Open Code Review와 Cloudflare Security Audit Skill이 다시 있었고, 에이전트 스킬·RAG·로컬 추론 저장소도 많았다. 저장소명이 달라도 기존 글과 같은 검색 의도를 반복하는 후보는 제외했다.

| 후보 | 확인 시점 신호 | 검색 의도·장기 가치 판단 |
|---|---|---|
| [Cilium](https://github.com/cilium/cilium) | daily 153, 25,258 stars, Apache-2.0, v1.20.2 | kube-proxy 대체와 NetworkPolicy 운영을 함께 판단하려는 플랫폼 팀의 독립적인 의도가 있고, 클라우드·보안 클러스터를 연결한다. |
| [BrowserSkill](https://github.com/Tencent/BrowserSkill) | daily 1,350, 4,092 stars, MIT, CLI v0.3.0 | 로그인 세션을 에이전트에 빌려주는 권한 경계는 중요하지만 기존 브라우저 자동화·에이전트 보안 글과 가깝다. |
| [Ghidra](https://github.com/NationalSecurityAgency/ghidra) | daily 912, 78,461 stars, Apache-2.0, 12.1.3 | 장기 가치는 높지만 최근 후보 검토와 마찬가지로 좁은 실무 문제를 정하지 않으면 범용 소개에 머문다. |
| [Coder](https://github.com/coder/coder) | daily 204, 14,818 stars, AGPL-3.0, v2.34.11 | 원격 개발 환경과 에이전트 workspace는 mise·Omarchy·샌드박스 글의 도입 의도와 인접한다. |
| [tinycast](https://github.com/abue-ammar/tinycast) | daily 738, 6,133 stars, beta 릴리스 | macOS 런처·클립보드 권한은 별도 의도지만 최근 BrewUI 글 직후라 주제 권위를 분산시킨다. |

Cilium은 새 프로젝트가 아니다. 오히려 성숙한 프로젝트가 새 패치 릴리스 직후 Trending에 오른 점이 중요하다. 네트워크 플러그인을 고르는 입문형 질문보다, 이미 Kubernetes를 운영하는 팀이 **어느 기능까지 넘기고 어떤 실패를 감당할지** 답할 자료가 충분하다. 이는 [Trivy로 이미지와 클러스터의 공급망 신호를 연결한 글](/posts/github-trending-trivy-supply-chain-security/)에서 다룬 shift-right 보안과도 이어지지만, 이번 글의 대상은 스캔이 아니라 런타임 패킷 경로다.

## 패킷 경로를 바꾸는 네 개의 결정

Cilium 데이터패스를 이해할 때 “eBPF로 구현됐다”에서 멈추면 운영 판단을 할 수 없다. 실제로는 네 가지 결정을 분리해야 한다.

![Cilium 데이터패스에서 identity, 정책, 서비스 변환, 관측이 만나는 구조](https://heracles-jo.github.io/assets/img/posts/cilium-ebpf-networking-migration/architecture.svg)

첫째는 **라우팅 방식**이다. 노드 간 Pod 트래픽을 VXLAN·Geneve overlay로 전달할지, 네이티브 라우팅과 클라우드 VPC 경로를 사용할지 결정한다. overlay는 기반 네트워크 요구를 줄이는 대신 캡슐화 overhead와 MTU 계산을 추가한다. native routing은 경로가 직접적이지만 노드와 상위 라우터가 Pod CIDR을 알아야 하고, 클라우드별 IPAM과 route limit를 함께 봐야 한다. 동일한 Cilium이라도 이 선택에 따라 장애 양상이 완전히 달라진다.

둘째는 **서비스 변환 위치**다. kube-proxy를 유지하면 Cilium은 CNI와 정책에 집중한다. kube-proxy replacement를 켜면 ClusterIP·NodePort·LoadBalancer 처리와 NAT가 BPF map 중심으로 이동한다. 규칙 수가 커질 때 긴 `iptables` chain을 순회하지 않는 장점이 있지만, 그 대가로 운영자가 `iptables-save` 대신 `cilium-dbg service list`, BPF map, agent 상태를 읽을 수 있어야 한다. 교체는 구성 요소 하나를 지우는 일이 아니라 진단 언어를 바꾸는 일이다.

셋째는 **보안 identity**다. Cilium은 label에서 도출한 identity로 endpoint policy를 적용한다. Pod IP가 재할당돼도 역할이 같은 workload는 같은 정책 의미를 유지할 수 있다. 하지만 label governance가 약하면 문제가 커진다. 배포 도구가 label을 바꾸거나, namespace·service account selector가 의도보다 넓거나, 정책 selector가 아무 endpoint도 선택하지 않으면 네트워크는 동작해도 보안 의도는 사라진다. IP 주소의 불안정성을 없애는 대신 메타데이터 정확성을 신뢰 경계로 올리는 셈이다.

넷째는 **L7과 proxy 경계**다. L3/L4 정책은 커널 데이터패스에서 처리할 수 있지만 HTTP method·path 같은 L7 규칙은 Envoy redirect와 연결된다. 이때 인증서, proxy readiness, redirect 누락, 자원 사용량, protocol compatibility가 새 실패 지점이 된다. Cilium의 공식 eBPF 문서도 L7 policy object가 트래픽을 userspace Envoy로 보낸다고 설명한다. “모든 정책을 eBPF가 커널에서 처리한다”는 식의 단순화는 정확하지 않다.

## kube-proxy를 없애기 전에 진단 능력을 먼저 옮겨야 한다

kube-proxy replacement의 장점은 분명하다. 서비스 조회와 backend 선택을 BPF map으로 처리하고, socket hook을 이용해 노드 내부 연결을 더 이른 지점에서 전달할 수 있다. Source IP 보존, DSR, Maglev 같은 선택지도 있다. 그러나 기능을 켜는 순간 기존 runbook이 자동으로 따라오지는 않는다.

플랫폼 팀은 최소한 세 종류의 상태를 연결할 수 있어야 한다.

1. Kubernetes가 기대하는 Service, EndpointSlice, NetworkPolicy 상태
2. Cilium agent와 operator가 계산한 endpoint, identity, policy revision
3. 노드에 실제 적재된 BPF program과 map, 그리고 Hubble이 관찰한 flow verdict

예를 들어 Service 객체와 EndpointSlice가 정상이어도 BPF backend map 갱신이 늦거나 agent가 비정상이라면 트래픽은 실패한다. 반대로 Hubble에 `DROPPED`가 보인다고 모두 policy 문제는 아니다. MTU, reverse NAT, conntrack pressure, 잘못된 device auto-detection도 같은 사용자 증상을 만들 수 있다. 따라서 “Hubble UI가 있으니 관측성이 해결된다”가 아니라, control-plane 의도와 datapath 현실을 동일한 incident timeline에 놓을 수 있는지가 기준이다.

이 차이는 [Linux 서버 하드닝 기준](/posts/github-trending-linux-server-hardening-baseline/)에서 언급한 커널·네트워크 설정과 직접 만난다. 노드 이미지의 kernel version, BPF config, cgroup mode, bpffs mount, JIT hardening, lockdown·LSM 정책이 달라지면 클러스터별 결과도 달라진다. 보안팀이 eBPF를 공격면이라는 이유로 일괄 비활성화하거나, 플랫폼 팀이 성능을 이유로 무조건 허용해서는 안 된다. 서명된 노드 이미지와 kernel baseline, Cilium이 요구하는 capability, BPF program 관측 권한을 함께 합의해야 한다.

## v1.20.2 변경 목록은 성숙도보다 blast radius를 보여 준다

`v1.20.2` 릴리스에는 ENI IPAM, BPF map event, policy revision, Cluster Mesh, DSR, ICMP checksum, L2 announcement, Gateway API, Hubble, Envoy, IPv6와 agent crash 관련 수정이 함께 들어 있다. 패치가 많다는 사실만으로 품질이 낮다고 볼 수는 없다. 다양한 커널·클라우드·CNI·정책 조합을 지원하는 프로젝트에서 활발한 backport는 유지보수 신호다. 동시에 Cilium이 이미 네트워크의 여러 핵심 경로를 소유한다는 뜻이기도 하다.

특히 다음 세 항목은 운영 설계와 연결된다.

- 새 Pod가 policy 변경 직후 최대 2분 동안 stale policy revision을 보고하던 문제
- named-port policy와 Pod churn이 겹칠 때 동시 map 변경으로 agent가 crash할 수 있던 문제
- 잘못된 ExternalAuth backend reference에서 fail closed가 되도록 고친 문제

첫 두 항목은 배포 churn과 policy rollout을 동시에 부하 테스트해야 하는 이유다. 세 번째는 보안 기능의 실패 기본값이 버전과 구현 세부에 달려 있음을 보여 준다. release note를 “버그 수정됨”으로만 읽지 말고, 우리 구성에서 동일한 경로를 사용하는지와 이전 버전에서 어떤 보상 통제가 필요했는지 확인해야 한다.

v1.20 upgrade note에는 더 직접적인 action required도 있다. Kafka-aware와 일부 generic L7 policy rule 제거, `CiliumNodeConfig`의 `v2alpha1` 제거, CNI spec 기본값 변경, Gateway API 최소 버전과 `TLSRoute` CRD 조건이 포함된다. 특히 잘못된 Gateway API CRD 조합에서는 기존 `TLSRoute` 객체가 API server에서 읽히지 않아 사실상 사라진 것처럼 보일 수 있다고 문서가 경고한다. 네트워크 업그레이드를 Helm chart 버전 변경으로 취급하면 안 되는 이유다.

## NetworkPolicy가 있다고 격리가 보장되지는 않는다

Cilium 도입의 흔한 목표는 default deny와 identity 기반 microsegmentation이다. 여기서 가장 위험한 실패는 트래픽이 모두 끊기는 경우보다 **허용 범위가 조용히 넓어지는 경우**다. 정책이 workload를 선택하지 못하거나, DNS·health check·node-local service 예외를 넓게 추가하거나, namespace label이 자동화 과정에서 달라지면 서비스는 정상처럼 보이면서 격리는 약해진다.

정책 운영에는 네 가지 계약이 필요하다.

- 모든 namespace와 workload가 어떤 default posture를 갖는지 선언한다.
- selector가 현재 선택하는 endpoint 수와 예상 범위를 CI에서 비교한다.
- 허용 flow뿐 아니라 반드시 거부돼야 하는 canary flow를 계속 실행한다.
- 정책 변경, identity 변경, workload rollout의 순서를 정하고 revision 수렴을 확인한다.

L7 정책은 더 신중해야 한다. HTTP path 규칙은 세밀하지만 proxy 경로와 애플리케이션 protocol 해석을 추가한다. 암호화된 트래픽을 어디서 종료할지, gRPC·WebSocket·upgrade 요청을 어떻게 처리할지, Envoy가 비정상일 때 fail open인지 fail closed인지 서비스별로 검증해야 한다. 보안 정책의 정밀도가 높아질수록 가용성 의존성도 커진다.

[CubeSandbox의 eBPF 기반 egress 격리](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)에서도 강조했듯, 정책 파일이 존재한다는 사실과 실제 패킷이 차단된다는 사실은 다르다. 샌드박스와 Kubernetes cluster 모두 DNS 우회, node-local endpoint, metadata service, host networking, privileged workload가 경계를 가로지를 수 있다. Hubble flow와 능동적인 거부 테스트를 함께 써야 한다.

## 한 번에 CNI·kube-proxy·ingress를 바꾸지 않는다

Cilium의 기능 통합은 장점이지만 migration에서는 coupling이 된다. 기존 CNI에서 Cilium으로 옮기는 날 kube-proxy replacement, L7 policy, ingress controller, encryption까지 동시에 켜면 장애가 났을 때 원인을 분리할 수 없다. 전환은 기능이 아니라 **패킷 경로의 변화량**을 기준으로 나누는 편이 안전하다.

![Cilium 전환 단계와 각 단계에서 확인해야 할 중단 게이트](https://heracles-jo.github.io/assets/img/posts/cilium-ebpf-networking-migration/decision.svg)

첫 단계는 별도 비프로덕션 클러스터에서 현재 네트워크의 기준선을 만드는 것이다. Pod 간·Service·NodePort·external traffic, DNS, 대용량 응답, 장기 TCP, UDP, hairpin, hostNetwork, dual stack 여부를 실제 workload로 재현한다. 평균 지연보다 p95/p99, connection reset, retransmit, MTU 관련 drop, policy convergence를 기록한다.

둘째 단계에서는 Cilium을 CNI와 L3/L4 policy 범위로 제한한다. cloud IPAM, node reboot, autoscaling, drain, disruption budget, observability pipeline을 검증한다. 이 시점에 on-call이 endpoint와 BPF 상태를 조회하고 flow를 따라갈 수 있어야 한다.

셋째 단계에서만 kube-proxy replacement를 canary node pool 또는 별도 cluster에 적용한다. 서비스 종류와 traffic policy별로 기존 경로와 결과를 비교하고, map pressure와 conntrack, agent CPU·memory, failover 시간을 측정한다. 플랫폼에 따라 in-place migration보다 새 cluster를 만들고 workload를 옮기는 blue/green 방식이 rollback을 단순하게 할 수 있다.

마지막으로 L7 policy, Gateway API, egress gateway, encryption, Cluster Mesh를 각각 독립된 프로젝트로 연다. 기능마다 소유 팀, SLO, 장애 시 우회 경로가 다르다. CNI가 성공했다고 ingress와 multi-cluster도 자동으로 안전한 것은 아니다.

## PoC 합격선은 처리량 하나가 아니다

벤치마크에서 packets per second가 높아도 운영 전환이 성공한 것은 아니다. 다음 항목을 기존 CNI·kube-proxy 조합과 같은 조건에서 비교해야 한다.

| 측정 영역 | 최소 질문 | 중단 조건 예시 |
|---|---|---|
| 연결 정확성 | TCP·UDP·ICMP, IPv4·IPv6, hairpin, externalTrafficPolicy가 예상대로 동작하는가 | 정상 경로의 간헐적 reset 또는 source IP 의미 변경 |
| 정책 수렴 | label·policy·Pod churn 뒤 allow/deny가 몇 초 안에 일치하는가 | 허용 범위가 넓어지는 stale revision 재현 |
| 장애 복구 | agent·operator·node·Envoy 재시작 중 기존 연결과 신규 연결은 어떻게 되는가 | runbook 없는 blackhole 또는 장기 fail-open |
| 관측 가능성 | Kubernetes 객체에서 BPF map과 Hubble flow까지 한 사건으로 추적 가능한가 | drop 이유를 운영자가 제한 시간 내 설명하지 못함 |
| 자원 비용 | map pressure, agent CPU·memory, Hubble 저장·label cardinality 비용은 얼마인가 | peak에서 map 포화 또는 관측 비용 예산 초과 |
| 업그레이드 | CRD·Helm value·deprecated API를 사전 검사하고 rollback할 수 있는가 | downgrade 불가 상태를 백업 없이 통과 |

보안 검증은 positive test보다 negative test가 중요하다. 허용돼야 할 API 호출만 확인하지 말고, 다른 namespace·service account·cluster에서 같은 port로 접근했을 때 실제로 거부되는지 본다. Gateway API와 ExternalAuth를 쓴다면 잘못된 backend reference, 인증 서비스 timeout, certificate rotation도 넣는다. 패치 릴리스에서 수정된 named-port churn과 policy revision 경로는 회귀 fixture로 보존할 가치가 있다.

전환 후 비용도 계산해야 한다. Hubble metric label을 세밀하게 늘리면 Prometheus cardinality와 저장 비용이 커지고, flow log 보존은 개인정보·내부 서비스 이름 노출 문제를 만든다. L7 가시성은 payload 전체를 저장하지 않더라도 URL path와 header가 민감 정보를 포함할 수 있다. 관측 데이터의 접근 권한과 retention을 CNI 설정의 부수 항목으로 두지 말아야 한다.

## Cilium을 선택하지 않는 것도 정상적인 결론이다

작은 클러스터에서 현재 CNI와 kube-proxy가 안정적이고, NetworkPolicy 요구가 단순하며, 팀이 커널·BPF 진단 역량을 갖추지 못했다면 전환 이익이 비용보다 작을 수 있다. 관리형 Kubernetes가 제공하는 vendor CNI 통합과 지원 계약이 더 중요한 조직도 있다. 서비스 메시를 이미 표준화했고 네트워크·L7 책임을 다시 합칠 이유가 없다면 Cilium의 모든 기능을 쓸 필요도 없다.

반대로 node 수와 service 수가 늘어 `iptables` 운영이 부담이고, identity 기반 정책과 flow visibility가 필요하며, 플랫폼 팀이 커널과 클라우드 네트워크까지 책임질 수 있다면 Cilium은 강한 후보가 된다. [Apple Container의 VM별 격리 판단](/posts/github-trending-apple-container-mac-linux-containers/)과 마찬가지로 “더 현대적인 기술인가”보다 “어떤 경계를 누가 운영할 것인가”가 선택 기준이다.

Cilium 전환은 네트워크 구성 요소를 줄일 수 있지만 책임까지 줄여 주지는 않는다. kube-proxy를 제거하면 서비스 변환 책임이 BPF 데이터패스로 이동하고, IP 기반 정책을 줄이면 label과 identity 거버넌스가 중요해지며, Hubble을 켜면 flow 데이터의 비용과 접근 통제가 생긴다. 따라서 도입 순서는 기능 목록이 아니라 **기준선 측정, L3/L4 경로 검증, 진단 역량 이전, kube-proxy canary, 고급 기능 분리**여야 한다. 이 순서를 지킬 수 없다면 현재 네트워크를 유지하면서 관측성과 정책 테스트부터 개선하는 편이 더 안전하다.

> 1차 자료: [Cilium 저장소와 README](https://github.com/cilium/cilium), [Apache-2.0 LICENSE](https://github.com/cilium/cilium/blob/main/LICENSE), [eBPF 데이터패스 소개](https://docs.cilium.io/en/stable/network/ebpf/intro/), [Network Policy 문서](https://docs.cilium.io/en/stable/security/policy/), [v1.20 Upgrade Guide](https://docs.cilium.io/en/stable/operations/upgrade/), [v1.20.2 release note](https://github.com/cilium/cilium/releases/tag/v1.20.2), [최근 commits](https://github.com/cilium/cilium/commits/main/), [공개 issues](https://github.com/cilium/cilium/issues), [공개 pull requests](https://github.com/cilium/cilium/pulls). Trending·저장소 수치는 2026년 9월 18일 08시 50분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
