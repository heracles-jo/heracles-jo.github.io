---
title: "NVKE GPU Kubernetes 관리 평면: 베어메탈 도입 검증 기준"
description: "NVKE의 관리 클러스터·NICo·Cluster API·TPM 신뢰 구조를 해부하고, GPU 베어메탈 Kubernetes를 운영하기 전 보안·복구·업그레이드 기준을 정리한다."
author: heracles-jo
date: 2026-11-09 08:45:00 +0900
categories: [Platform Engineering, Cloud]
tags: [nvke, kubernetes, gpu-infrastructure, bare-metal, cluster-api, platform-engineering]
image:
  path: https://heracles-jo.github.io/assets/img/posts/nvke-gpu-kubernetes-control-plane/cover.svg
  alt: "NVKE로 GPU 베어메탈 Kubernetes 관리 평면을 설계할 때 확인할 제어면과 운영 경계"
---

GPU 서버가 몇 대일 때는 운영자가 노드에 드라이버와 컨테이너 런타임을 설치하고 하나의 Kubernetes 클러스터로 묶어도 버틸 수 있다. 서버가 여러 랙과 고객, 프로젝트로 늘어나면 문제가 달라진다. 어떤 장비를 어느 클러스터에 할당했는지, 제어 평면과 워커를 어떻게 교체할지, 노드 이미지와 Kubernetes 버전을 어떤 조합으로 승인할지, 장애 난 GPU 서버를 고객 워크로드를 해치지 않고 회수할지를 별도 시스템이 맡아야 한다. 이때 필요한 것은 GPU 스케줄러 하나가 아니라 **클러스터를 반복 생산하고 수명주기를 통제하는 관리 평면**이다.

[dsx-ai-factory/nvke](https://github.com/dsx-ai-factory/nvke)는 자체 NVIDIA GPU 인프라 위에 관리형 Kubernetes와 비슷한 운영 모델을 만들기 위한 오픈소스 관리 평면이다. 임시 seed cluster로 전용 management cluster를 세우고, 그 위의 NVKE가 NICo와 Cluster API를 통해 서로 독립된 workload cluster를 만든다. 각 고객 클러스터는 자체 Kubernetes control plane, etcd, node pool을 가진다. 다만 공식 문서가 분명히 밝히듯 현재는 **preview이며 production workload에 권장되지 않는다.** 따라서 지금의 핵심 질문은 “설치할 수 있는가”가 아니라 **어떤 운영 공백을 직접 메울 수 있을 때 평가 가치가 있는가**다.

2026년 11월 9일 08시 53분 KST 전후 GitHub Trending daily에서 NVKE는 **345 stars today**로 표시됐다. GitHub API 조회 시점에는 831 stars, 110 forks, issue와 pull request를 합친 open item 188개, Apache-2.0 라이선스였고 11월 7일 KST까지 main 변경이 이어졌다. 최신 제품 릴리스 `v0.23.1`은 11월 4일 KST 공개됐으며 tenant kubeconfig 파싱을 allowlist 방식으로 제한하는 수정이 포함됐다. 이 수치는 공개 페이지의 시점별 스냅샷이며 성숙도나 도입 적합성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어·노출·클릭 데이터에 접근하지 못했으므로 주제 선정 근거로 사용하지 않았다.

## 후보 비교: 에이전트 도구보다 GPU 플랫폼의 클러스터 수명주기를 골랐다

오늘 상위 후보에는 OSINT, 브라우저 자동화, 에이전트 스킬과 로봇 시뮬레이터가 함께 있었다. 저장소 이름뿐 아니라 독자가 해결하려는 문제를 기존 글과 비교했다. NVKE는 기존 GPU 추론 최적화 글과 달리 모델 실행 성능이 아니라 **베어메탈 GPU 자원을 여러 Kubernetes 클러스터로 공급하는 플랫폼 운영**이라는 별도 검색 의도를 가진다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [dsx-ai-factory/nvke](https://github.com/dsx-ai-factory/nvke) | daily 345, 831 stars, `v0.23.1`, Apache-2.0 | GPU 베어메탈의 클러스터 생성·교체·신뢰·복구를 묶는 플랫폼 엔지니어링 질문이 선명해 선택했다. |
| [sherlock-project/sherlock](https://github.com/sherlock-project/sherlock) | daily 2,372, 103,397 stars, `v0.16.2`, MIT | 사용자명 기반 OSINT는 Flowsint·브라우저 OSINT 거버넌스 글과 중심 의도가 가깝다. |
| [milind-soni/OpenMausBot](https://github.com/milind-soni/OpenMausBot) | daily 1,437, 18,210 stars, `v0.1.149`, Apache-2.0 | VM을 쓰는 범용 봇은 컴퓨터 사용 에이전트·격리·승인 워크플로 클러스터와 경쟁한다. |
| [meta/astryx](https://github.com/meta/astryx) | daily 863, 16,647 stars, `v0.7.11`, MIT | agent-ready design system은 기존 디자인 시스템·에이전트 산출물 검증 의도와 인접한다. |
| [google-deepmind/mujoco](https://github.com/google-deepmind/mujoco) | daily 26, 16,386 stars, `4.0.0`, Apache-2.0 | 시뮬레이터 업그레이드는 장기 가치가 있지만 최근 로봇 정책 배포 글과 연결하려면 별도 재현 실험이 더 필요하다. |

NVKE를 선택한 이유는 “NVIDIA가 Kubernetes를 새로 만들었다”는 신기함이 아니다. 공식 문서는 NVKE를 Kubernetes 배포판이나 Cluster API flavor가 아니라 **여러 독립 클러스터를 생산하는 self-hosting factory**라고 정의한다. 이 구분은 도입 범위를 결정한다. NVKE가 GPU workload의 성능, MIG 분할, 모델 큐, 분산 학습 통신까지 자동 해결한다고 기대하면 평가가 처음부터 어긋난다.

## 관리 클러스터와 고객 클러스터를 분리하는 공장 구조

NVKE 설치에는 management cluster와 workload cluster라는 두 종류의 Kubernetes가 있다. 임시 seed cluster는 management cluster를 세우고 사라진다. management cluster에는 NVKE controller, PostgreSQL, Temporal, Cluster API provider, SPIRE와 telemetry 구성 요소가 올라간다. 이후 고객의 cluster 생성 요청은 이 관리 평면을 거쳐 NICo가 보유한 물리 장비를 할당하고 kubeadm으로 새로운 workload cluster를 구성한다.

![NVKE가 API 요청을 영속화하고 NICo·Cluster API·노드 에이전트를 통해 독립 GPU Kubernetes 클러스터를 만드는 구조](https://heracles-jo.github.io/assets/img/posts/nvke-gpu-kubernetes-control-plane/architecture.svg)

cluster 생성 요청은 API handler가 Temporal을 직접 호출하는 방식이 아니다. 공식 architecture 문서에 따르면 REST API가 PostgreSQL transaction 안에서 cluster record와 workflow outbox row를 함께 기록하고, 별도 outbox processor가 이를 읽어 Temporal workflow를 시작한다. 그 workflow가 Cluster API resource를 만들고, 인프라 provider가 장비를 준비하며, controller가 각 노드의 `nvke-agent`에 gRPC로 접속해 kubeadm과 node bootstrap을 진행한다.

이 설계의 장점은 API 응답과 비동기 provisioning 작업 사이의 유실을 줄이는 데 있다. 데이터베이스에 cluster만 기록되고 workflow가 시작되지 않는 상태를 transactional outbox로 방지한다. 반면 운영자가 추적해야 할 상태는 늘어난다. 한 요청의 실패 원인이 API validation, PostgreSQL, outbox backlog, Temporal activity, Cluster API reconciliation, NICo allocation, SPIRE attestation, node agent, kubeadm 중 어디에 있는지 연결할 수 있어야 한다.

[Prometheus 3.16 업그레이드 글](/posts/prometheus-316-query-cost-upgrade/)에서 수집 프로세스가 살아 있다는 사실과 관측 기능이 정상이라는 사실을 구분했듯, NVKE도 controller Pod가 Running이라는 신호만으로 준비됐다고 볼 수 없다. `/readyz`의 database·Temporal 상태, node provisioning duration, pending count, give-up counter, CAPI Machine condition, NICo allocation과 workload cluster 내부의 실제 Node Ready를 하나의 incident timeline으로 묶어야 한다.

## 가장 큰 위험은 workload cluster보다 management cluster에 집중된다

여러 고객 클러스터를 자동화하면 관리 평면의 편의도 커지지만 실패 반경도 집중된다. preview 문서는 management cluster가 자기 자신을 upgrade, scale, replace하지 않으며, management-plane upgrade 절차와 backup·restore 절차도 제공하지 않는다고 명시한다. 즉 workload node 교체를 자동화하는 시스템이 정작 자신을 운영하는 기반 클러스터에는 같은 수명주기 제어를 적용하지 못한다.

이 제약은 단순한 “아직 기능이 없다”가 아니다. production 판단을 막는 핵심 운영 공백이다.

- management cluster node 수는 bootstrap 시점에 정하고 이후 늘리거나 교체할 수 없다.
- management API, PostgreSQL, Temporal, SPIRE, Cluster API object와 encryption material을 일관되게 복구하는 공식 절차가 없다.
- management cluster의 etcd encryption key 파일은 노드 밖에 남는 유일한 사본이므로 별도 보관이 필요하다.
- management-plane release를 올리는 표준 절차가 없어 component별 호환성과 rollback을 운영자가 설계해야 한다.
- 기본 telemetry backend는 메모리에 데이터를 두고 anonymous Grafana admin을 허용하므로 평가 외 용도에는 맞지 않는다.

이 상태에서 “세 노드 HA”만 보고 production에 올리면 장애 시 사용할 복구 계약이 없다. [OpenBao 전환 글](/posts/openbao-secrets-management-migration/)에서 Raft replica 수보다 snapshot 복원, seal key, KMS와 client 재연결을 함께 검증해야 했던 것처럼, NVKE도 빈 환경에서 management state를 재구성할 수 있는지 증명하지 못하면 HA는 재시작 내성에 그친다.

실무 PoC에서는 공식 backup 기능이 생길 때까지 무엇을 외부 시스템의 source of truth로 둘지 먼저 정해야 한다. node image와 release manifest, site spec, Helm values, NICo identifier, SPIRE CA, encryption key, database credential, cluster inventory와 고객 인계 기록을 Git·secret manager·artifact registry에 분리 보존하고, management cluster 상실 시 “복원”이 아니라 “재구축 후 고객 클러스터를 재발견하거나 이관”할 수 있는지 검토해야 한다. 이 경로가 설명되지 않으면 preview 범위를 벗어나지 않는 편이 맞다.

## TPM과 SPIFFE가 있어도 API 권한 모델은 별도 문제다

NVKE의 node identity는 강한 편이다. management plane이 workload node의 agent에 접속하고, node는 TPM을 이용해 SPIRE에 attest한 뒤 SPIFFE identity와 join credential을 받는다. 머신 metadata에는 agent connection mode와 attestation method가 기록되고 operator가 임의로 덮어쓰지 못하도록 제한한다. 이는 IP 주소나 초기 비밀번호만으로 노드 신원을 판단하는 구조보다 낫다.

그러나 node identity가 management API 보안을 대신하지는 않는다. preview 기본값에서 API authentication은 꺼져 있고 NodePort 30080의 plain HTTP로 제공된다. OIDC JWT 검증을 켜더라도 NVKE는 authorization을 하지 않는다. admit된 caller는 cluster 생성과 삭제를 포함한 모든 endpoint를 호출할 수 있다. bearer token을 직접 HTTP endpoint로 보내면 네트워크에서 평문으로 노출된다.

따라서 평가 환경에서도 최소한 다음 경계가 필요하다.

1. API NodePort를 일반 사내망에 직접 노출하지 않고 TLS reverse proxy 또는 격리된 관리 네트워크 뒤에 둔다.
2. OIDC를 permissive mode로 먼저 켜 `would_reject` metric과 log로 기존 caller를 찾은 뒤 enforcing으로 전환한다.
3. NVKE 전용 group에는 모든 customer cluster를 관리해도 되는 소수의 플랫폼 운영자와 automation만 넣는다.
4. management cluster admin kubeconfig와 고객에게 전달하는 workload cluster admin kubeconfig를 secret manager에서 별도 수명주기로 관리한다.
5. API authentication values가 재설치 때 빠지면 인증이 다시 꺼질 수 있으므로 배포 gate에서 `nvke_auth_enabled{mode="enforcing"}`를 확인한다.

고객에게 전달한 admin kubeconfig를 NVKE가 즉시 revoke하지 못하고, workload cluster CA도 회전하지 않는다는 제한도 중요하다. 고객 인계가 끝난 뒤에는 각 workload cluster 내부에서 OIDC·RBAC·break-glass credential을 별도로 구성하고 초기 admin credential의 보관과 만료를 통제해야 한다. [Cilium 네트워킹 전환 글](/posts/cilium-ebpf-networking-migration/)에서 정책 객체와 실제 packet verdict를 구분했듯, 여기서도 OIDC 설정 파일의 존재와 unauthorized caller가 실제로 거부되는지를 negative test로 확인해야 한다.

## node pool 자동화는 교체 실행이 아니라 교체 후보 표시까지다

NVKE는 node pool 생성·확장·삭제, Kubernetes control plane upgrade와 node replacement 흐름을 제공한다. 하지만 preview의 자동화 경계는 이름보다 좁다. `recycleBudget`을 설정하면 오래된 configuration의 node를 `NeedsRecycle`로 표시하지만, NVKE가 자동으로 cordon·drain·delete하지는 않는다. 운영자나 별도 break-fix system이 표시된 node를 삭제해야 현재 release로 replacement가 만들어진다.

또한 `desiredNodeCount`를 낮춰도 이미 실행 중이거나 NICo machine을 기다리는 node를 자동 제거하지 않는다. node label과 taint는 생성 시 고정되며 나중에 cluster 밖에서 제거돼도 다시 reconcile되지 않는다. `nvkectl`의 node pool patch는 desired count만 다루므로 Kubernetes version이나 recycle 설정 변경에는 직접 API 호출이 필요하다. control plane upgrade와 worker 교체가 서로 다른 도구·절차로 갈리는 셈이다.

GPU node에서는 이 간극이 더 크다. drain 전에 분산 학습 job, local checkpoint, RDMA·InfiniBand 연결, MIG partition과 device plugin 상태를 확인해야 한다. 문서상 NVKE는 물리 장비와 Kubernetes node 수명주기를 다루지만 GPU Operator, scheduler extension, workload queue, model serving runtime과 고객별 quota를 완성된 한 묶음으로 제공하지 않는다. 최근 공개 issue에서 cluster add-on 관리 방식을 별도로 논의하는 점을 고려하면, **GPU workload platform의 상위 계층은 운영자가 선택하고 통합해야 한다는 해석**이 타당하다.

이 때문에 PoC의 핵심은 새 node가 Ready가 되는 시간이 아니다. 오래된 node 하나를 의도적으로 교체하면서 PodDisruptionBudget, long-running GPU job, local data, network fabric, device health, telemetry label과 quota가 어떤 순서로 안전하게 이동하는지 측정해야 한다. NVKE가 eviction을 시작한 뒤 100초가 지나거나 오류가 나면 남은 Pod를 grace period 없이 삭제할 수 있다는 문서상 동작도 workload 유형별로 검증해야 한다.

## release manifest와 node image를 하나의 공급망으로 본다

NVKE는 controller와 node agent만 배포하는 프로젝트가 아니다. Kubernetes, containerd, runc, CNI, SPIRE, Temporal, PostgreSQL, Helm chart와 node OS image의 조합이 cluster 결과를 결정한다. `v0.23.1` release 자료는 component version과 image digest를 기록하고, 보안 정책은 GHCR image의 GitHub build-provenance attestation을 repository에 묶어 검증하라고 안내한다. NVKR은 고정된 입력에서 node image와 NVKE component artifact를 만드는 companion project로 설명된다.

여기서 release 이름만 기록하면 부족하다. cluster와 node pool에 실제 적용한 MachineImage, ClusterRelease, NodePoolRelease, source commit, image digest, attestation 검증 결과, NICo instance type, firmware·driver 상태를 함께 남겨야 한다. local image build와 smoke test는 실제 NICo boot, disk selection, first-boot 전체를 보증하지 않는다고 공식 limitation이 명시한다. 특히 FDE 평가 image는 같은 image에서 만든 node가 동일 volume key를 상속하고 공개 bootstrap passphrase로 key를 복구할 수 있어 data-at-rest confidentiality에 의존하면 안 된다.

[Terraform 거버넌스 글](/posts/github-trending-terraform-iac-governance/)에서 선언 파일과 실제 infrastructure state의 차이를 승인 대상으로 삼았듯, NVKE에서도 release resource와 물리 장비의 실상 사이 drift를 관리해야 한다. node가 Ready여도 GPU 수, ECC 상태, firmware, NIC topology, NVLink·InfiniBand 상태가 기대와 다를 수 있다. cluster 승격 gate에 Kubernetes conformance뿐 아니라 GPU burn-in, device inventory, network bandwidth와 collective communication test를 넣어야 한다.

## 어떤 대안과 비교해야 하는가

NVKE의 경쟁 상대를 다른 Kubernetes 배포판 하나로만 잡으면 판단이 좁아진다. 실제 선택지는 책임 모델에 따라 나뉜다.

| 선택지 | 얻는 것 | 직접 책임질 것 | 잘 맞는 조건 |
|---|---|---|---|
| NVKE preview 평가 | NICo·Cluster API·TPM identity를 연결한 다중 workload cluster factory | management plane 복구·업그레이드, API authorization, add-on·GPU workload stack | 자체 NVIDIA 베어메탈과 플랫폼 엔지니어링 팀이 있고 preview 공동 검증이 목적일 때 |
| 관리형 Kubernetes + GPU node | control plane HA·upgrade·backup의 상당 부분 이전 | cloud GPU 비용, quota, network·data locality, provider 제약 | 빠른 production과 작은 플랫폼팀이 우선일 때 |
| 기존 Cluster API + 자체 provider | 표준 CAPI 생태계와 인프라별 조합 자유 | bare-metal provisioning, node image, identity, lifecycle controller 통합 | 이미 CAPI 운영 경험과 자체 하드웨어 API가 있을 때 |
| 단일 온프레미스 Kubernetes | 구성 요소와 장애 도메인이 적음 | multi-tenancy, cluster별 upgrade·blast radius, 자원 배분 | 고객별 독립 cluster보다 하나의 내부 GPU pool이 충분할 때 |

[Coolify 셀프호스팅 PaaS 글](/posts/coolify-self-hosted-paas-operations/)에서 관리형 서비스를 떠날 때 서버 비용뿐 아니라 당직과 복구 책임이 돌아온다고 봤다. GPU Kubernetes도 같다. 자체 장비 감가상각과 cloud GPU 단가만 비교하면 management cluster, BGP·VIP, image factory, NICo, SPIRE CA, artifact registry, telemetry backend, 보안 패치와 24×7 장애 대응 비용을 빠뜨리게 된다.

## PoC는 cluster 생성 성공보다 제어면 상실과 node 교체를 시험한다

![NVKE를 로컬 평가에서 제한된 비프로덕션 GPU 클러스터로 승격하기 위한 검증 게이트](https://heracles-jo.github.io/assets/img/posts/nvke-gpu-kubernetes-control-plane/decision.svg)

첫 단계는 GPU 없이 local quickstart와 simulated NICo로 API, outbox, Temporal, CAPI, agent 상태 전이를 익히는 것이다. 다음 단계에서 실제 장비 3~5대를 사용해 비프로덕션 management cluster와 workload cluster 하나를 만든다. production 검토 전에 아래 중단 조건을 실제 장애 주입으로 확인해야 한다.

| 검증 영역 | 측정할 증거 | 중단 조건 예시 |
|---|---|---|
| provisioning | API 요청부터 NICo allocation, agent bootstrap, Node Ready까지 단계별 p50·p95 | 실패가 어느 계층인지 식별하지 못하거나 orphan machine이 남음 |
| 관리 평면 | DB·Temporal·controller·SPIRE 재시작, quorum·storage 장애 | 공식 절차 없이 state를 잃거나 고객 cluster 관리가 장기 중단 |
| 보안 | 무토큰·잘못된 group·평문 endpoint·agent spoofing negative test | 인증이 꺼진 채 재설치되거나 admit된 caller 범위를 제한하지 못함 |
| node 교체 | drain, PDB, GPU job checkpoint, device·fabric 재검증 | 강제 Pod 삭제가 데이터 손실을 만들거나 replacement 품질을 확인하지 못함 |
| artifact | source SHA, digest, attestation, node image·firmware inventory | 실행 중인 node의 provenance를 release record와 연결하지 못함 |
| 관측성 | readyz, workflow, CAPI, NICo, node·GPU metric 상관관계 | on-call이 제한 시간 안에 병목 계층을 설명하지 못함 |
| 복구 | secret·CA·encryption key·config inventory와 빈 환경 재구축 | management cluster 상실 뒤 RTO·RPO 또는 고객 이관 경로가 없음 |

합격선도 preview 상태에 맞게 제한해야 한다. 연구·개발용 GPU cluster 생성 시간을 줄이고 node image와 hardware qualification 절차를 표준화하는 목적이라면 NVKE는 유의미한 실험 대상이다. 반대로 고객 production을 즉시 호스팅하거나, 관리 평면의 공식 backup·upgrade·authorization이 필수이거나, 플랫폼팀이 NICo·BGP·SPIRE·Temporal·CAPI를 함께 운영할 수 없다면 현재 버전은 맞지 않는다.

NVKE가 보여 주는 중요한 방향은 GPU 서버를 단순한 Kubernetes worker가 아니라 **검증된 image와 hardware identity를 가진 교체 가능한 cluster 자원**으로 다룬다는 점이다. 그러나 factory가 workload cluster를 잘 만든다고 factory 자체가 자동으로 안전해지는 것은 아니다. 도입 판단은 세 질문으로 압축된다. **management cluster를 잃었을 때 무엇으로 재구축할 것인가, API와 고객 credential의 실제 권한을 어디서 제한할 것인가, GPU workload를 중단하지 않고 node를 교체했다는 증거를 어떻게 남길 것인가.** 이 세 답이 없으면 preview는 좋은 실험실이지만 production 관리 평면은 아니다.

> 1차 자료: [dsx-ai-factory/nvke 저장소와 README](https://github.com/dsx-ai-factory/nvke), [Architecture overview](https://github.com/dsx-ai-factory/nvke/blob/main/docs/architecture.md), [Preview status and known limitations](https://github.com/dsx-ai-factory/nvke/blob/main/docs/overview/preview-status.md), [Plan your installation](https://github.com/dsx-ai-factory/nvke/blob/main/docs/operate/plan-installation.md), [Secure the NVKE API](https://github.com/dsx-ai-factory/nvke/blob/main/docs/operate/api-authentication.md), [Observe NVKE and its clusters](https://github.com/dsx-ai-factory/nvke/blob/main/docs/operate/observe.md), [Manage node pools](https://github.com/dsx-ai-factory/nvke/blob/main/docs/workload-clusters/node-pools.md), [v0.23.1 release](https://github.com/dsx-ai-factory/nvke/releases/tag/v0.23.1), [Security policy](https://github.com/dsx-ai-factory/nvke/blob/main/SECURITY.md), [Apache-2.0 LICENSE](https://github.com/dsx-ai-factory/nvke/blob/main/LICENSE), [최근 commits](https://github.com/dsx-ai-factory/nvke/commits/main/), [공개 issues와 pull requests](https://github.com/dsx-ai-factory/nvke/issues). Trending·저장소 수치는 2026년 11월 9일 08시 53분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
