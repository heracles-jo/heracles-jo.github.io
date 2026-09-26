---
title: "OpenBao 시크릿 관리 전환: Vault 호환성보다 중요한 운영 기준"
description: "OpenBao의 동적 시크릿·PKI·Raft HA 구조를 바탕으로 Vault 계열 시크릿 관리 전환에서 호환성, 복구, 감사, 업그레이드를 검증하는 기준을 제시한다."
author: heracles-jo
date: 2026-09-27 07:55:00 +0900
categories: [Security, Platform Engineering]
tags: [openbao, secret-management, dynamic-secrets, pki, high-availability, platform-engineering]
image:
  path: https://heracles-jo.github.io/assets/img/posts/openbao-secrets-management-migration/cover.svg
  alt: "OpenBao 시크릿 관리 전환에서 신뢰 경계와 운영 검증 항목을 보여주는 표지"
---

API 키를 Kubernetes Secret과 CI 변수, 애플리케이션 설정 파일에 나눠 저장하면 처음에는 단순하다. 시간이 지나면 같은 자격 증명이 여러 환경에 복제되고, 누가 읽었는지 설명하기 어려워지며, 유출 사고 때 어떤 사본을 폐기해야 하는지도 불분명해진다. 시크릿 관리 시스템이 필요한 이유는 비밀번호를 한곳에 모으기 위해서가 아니다. **인증된 주체에게 최소 권한의 비밀을 짧게 발급하고, 사용 이력을 남기며, 필요할 때 일괄 폐기하는 수명주기**를 만들기 위해서다.

[OpenBao](https://github.com/openbao/openbao)는 비밀, 인증서, 암호화 키를 저장·발급·배포하는 오픈소스 시스템이다. 정적 키·값 저장소뿐 아니라 데이터베이스와 Kubernetes 같은 대상에 동적 자격 증명을 발급하고, lease가 끝나면 회수하며, Transit 엔진으로 애플리케이션 데이터를 직접 보관하지 않고 암복호화할 수 있다. 그러나 기능이 익숙해 보인다고 기존 Vault 계열 배포를 바이너리만 바꾸는 프로젝트로 취급해서는 안 된다. 저장소 형식, 플러그인, 인증 방식, 정책, 클라이언트 헤더, 업그레이드 경로와 장애 대응이 함께 움직이는 보안 제어면이기 때문이다.

Search Console과 Analytics의 실제 쿼리 데이터에는 이번 실행 환경에서 접근할 수 없었다. 노출·순위·클릭률을 확인했다고 가정하지 않았다. 대신 기존 글의 제목, 설명, 태그, 저장소 링크, `_data/written_topics.yml`과 최근 검색 의도를 비교했다. [Vaultwarden 글](/posts/vaultwarden-self-hosted-password-manager/)은 사람이 사용하는 비밀번호 금고의 셀프호스팅 책임을 다뤘다. 이번 글은 애플리케이션과 플랫폼이 사용하는 동적 시크릿, PKI, 암호화 서비스의 운영 제어면을 다루므로 독자 질문과 실패 반경이 다르다.

## 후보 네 개 중 OpenBao를 선택한 이유

2026년 9월 27일 08시 01분 KST 전후 GitHub Trending daily·weekly와 각 저장소의 공개 API를 확인했다. 순위는 주제가 아니라 후보 발굴 신호로만 사용했다. 아래 별 수와 릴리스 상태는 조회 시점의 스냅샷이며 이후 달라질 수 있다.

| 후보 | 공개 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---:|---|
| [Paperclip](https://github.com/paperclipai/paperclip) | daily 2,589, 87,180 stars, MIT, v2026.916.1 | 에이전트 업무 관리 제어면은 강한 신호지만 Google AX·Orca의 오케스트레이션 및 병렬 운영 의도와 가깝다. |
| [Hindsight](https://github.com/vectorize-io/hindsight) | daily 2,152, 32,096 stars, MIT, v0.10.1 | 학습형 에이전트 메모리는 기존 Supermemory·코드베이스 메모리 글과 직접 경쟁한다. |
| [Univer](https://github.com/dream-num/univer) | daily 845, 19,182 stars, Apache-2.0, v1.0.2 | 오피스 문서를 에이전트 runtime으로 묶지만 OfficeCLI 문서 자동화 글과 중심 질문이 인접한다. |
| [OpenBao](https://github.com/openbao/openbao) | daily 360, 7,989 stars, MPL-2.0, v2.7.0 | 동적 시크릿·PKI·암호화 서비스의 오픈 거버넌스와 전환 검증이라는 독립된 장기 검색 의도가 선명하다. |

OpenBao는 2026년 9월 23일 `v2.7.0`을 공개했고 9월 24일까지 main 브랜치 커밋이 이어졌다. 최신 릴리스에는 외부 KMS/HSM 키를 PKI·Transit에서 사용하는 External Keys, ML-DSA와 PQC TLS, PostgreSQL 읽기 확장, 강한 일관성 제어, control group이 포함됐다. 동시에 file storage 제거, 일부 내장 auth·secret engine의 외부 플러그인 이동, Go module v2 전환과 여러 보안 수정도 들어 있다. 기능 추가보다 **변경 폭과 보안 패치가 함께 나온 릴리스**라는 점이 전환·업그레이드 운영을 분석하기에 더 중요한 신호다.

## OpenBao의 가치는 저장소가 아니라 수명주기 제어에 있다

OpenBao의 기본 흐름은 인증, 검증, 인가, 접근 네 단계로 설명할 수 있다. 사용자·워크로드·애플리케이션이 auth method로 신원을 증명하면 토큰과 정책이 연결되고, path 기반 ACL이 허용한 secret engine 또는 system API에만 접근한다. 기본 거부가 출발점이며, 정책이 허용하지 않은 작업은 실행되지 않는다.

![OpenBao에서 인증 주체가 정책을 거쳐 동적 시크릿과 PKI·Transit 기능에 접근하는 구조](https://heracles-jo.github.io/assets/img/posts/openbao-secrets-management-migration/architecture.svg)

이 구조에서 가장 먼저 구분할 것은 세 종류의 데이터다.

1. **정적 시크릿**은 운영자가 저장한 API 키나 설정 값이다. 중앙화와 감사에는 도움이 되지만 원본 시스템에서 키를 자동 회전하지는 않는다.
2. **동적 시크릿**은 요청 시점에 대상 시스템에서 새 자격 증명을 만들고 lease 종료 때 폐기한다. 유출된 자격 증명의 유효 시간을 줄이지만 대상 DB·클라우드·Kubernetes 권한과 폐기 API가 정상이어야 한다.
3. **암호화·PKI 서비스**는 키 자체를 애플리케이션에 넘기는 대신 서명·암복호화·인증서 발급 연산을 제공한다. 키 노출을 줄이는 대신 OpenBao 가용성과 지연이 애플리케이션 경로에 들어온다.

따라서 “시크릿을 모두 OpenBao로 옮긴다”는 목표는 모호하다. 정적 KV를 먼저 중앙화할지, 데이터베이스 계정을 동적으로 바꿀지, 내부 CA를 이전할지, Transit을 온라인 암호화 의존성으로 둘지에 따라 장애 반경이 달라진다. 특히 동적 시크릿은 짧은 TTL만 설정한다고 안전해지지 않는다. 애플리케이션이 갱신 실패를 처리하지 못하면 만료 시점이 곧 장애 시점이 된다. lease 갱신, 재인증, 연결 풀 교체, 폐기 지연을 하나의 시나리오로 시험해야 한다.

## 저장소가 암호화돼도 운영자가 전능하면 경계는 무너진다

공식 보안 모델은 저장소 backend를 신뢰하지 않는 대상으로 본다. OpenBao는 backend로 나가는 데이터를 security barrier에서 AES-GCM으로 암호화하고 변조를 검증한다. 클러스터 노드 사이의 트래픽도 상호 인증 TLS를 사용한다. 원시 디스크나 데이터베이스 덤프를 얻었다고 평문 시크릿이 바로 노출되는 구조는 아니다.

그러나 이 설명을 “스토리지 침해를 걱정하지 않아도 된다”로 읽으면 안 된다. 공식 threat model은 저장소를 임의로 조작하는 공격자가 데이터를 삭제·손상하거나 이전 상태로 롤백하는 상황, 실행 중인 프로세스 메모리 분석, 호스트 코드 실행, 악성 플러그인, 외부 IdP와 secret engine 대상 시스템의 결함을 보호 범위 밖으로 둔다. 암호화는 기밀성을 높이지만 가용성·정합성·운영자 권한까지 자동으로 해결하지 않는다.

이 점은 [Terraform의 state·권한 분리](/posts/github-trending-terraform-iac-governance/)와 닮았다. IaC 코드가 Git에 있다고 실제 인프라가 안전한 것이 아니듯, 시크릿이 OpenBao에 있다고 접근 정책과 root 권한이 자동으로 안전해지는 것은 아니다. 최소한 다음 경계를 따로 설계해야 한다.

- **초기화·unseal 경계**: Shamir share 또는 auto-unseal KMS 권한을 일상 관리자 권한과 분리한다.
- **정책 경계**: 플랫폼 운영자, 보안 운영자, 애플리케이션 배포 주체, 감사자의 권한을 서로 다른 path와 capability로 제한한다.
- **플러그인 경계**: 외부 플러그인 바이너리·OCI image의 출처, digest, 실행 권한과 업그레이드 절차를 통제한다.
- **감사 경계**: audit device가 기록하는 path·메타데이터·오류에 민감 정보가 포함될 가능성과 로그 접근 권한을 검토한다.
- **복구 경계**: snapshot, seal key, KMS, DNS, TLS 인증서와 배포 구성을 같은 장애 도메인에 두지 않는다.

`v2.7.0`에서 잘못된 요청 데이터가 audit log에 평문으로 남을 수 있던 문제, plugin command 경로와 namespace policy 처리 관련 보안 문제가 수정된 사실도 이 경계를 보여 준다. 감사 로그와 플러그인은 보안 기능의 부속물이 아니라 그 자체로 민감한 공격면이다.

## HA라는 이름보다 읽기 일관성과 복구 절차를 본다

새 배포에서 공식 문서는 Integrated Storage(Raft)를 기본 HA backend로 권장한다. 각 노드가 데이터를 복제하고 한 노드가 active가 되며, standby는 요청을 active로 전달하거나 redirect한다. `v2.5.0` 이후 Raft는 읽기 요청의 수평 확장을 지원하고, `v2.7.0`에서는 PostgreSQL backend도 조건부 읽기 확장을 지원한다.

여기서 “노드가 세 대니 HA”라는 판단은 부족하다. active 선출, client redirect, cluster address, load balancer health check, seal 상태, snapshot, Raft quorum이 동시에 맞아야 한다. API 주소를 load balancer로만 설정하면 redirect loop가 생길 수 있고, follower가 오래 뒤처지면 읽기 결과의 일관성을 별도로 다뤄야 한다. `v2.7.0`이 `X-Vault-Index`와 `X-Vault-Inconsistent` 헤더로 fail, active 전달, 상태 대기 동작을 추가한 것도 standby read가 단순한 성능 옵션이 아님을 보여 준다.

운영 검증은 최소 다섯 가지 장애를 포함해야 한다.

- active 노드를 종료했을 때 신규 로그인과 기존 token 요청이 회복되는 시간
- Raft follower가 지연된 상태에서 읽기 요청이 실패·전달·대기 중 어떤 동작을 하는지
- load balancer가 sealed·standby·active 상태를 올바르게 구분하는지
- snapshot을 빈 클러스터에 복원한 뒤 policy, lease, auth mount, PKI 데이터가 일관되게 돌아오는지
- KMS 또는 HSM이 일시적으로 불가할 때 재시작, unseal, 서명 경로가 어떻게 실패하는지

[Cilium 전환 글](/posts/cilium-ebpf-networking-migration/)에서 control plane의 의도와 실제 datapath 상태를 함께 보아야 했듯, OpenBao도 서버 health 하나로는 부족하다. storage index, active identity, seal 상태, audit 전송, token·lease 오류, 외부 DB·KMS 응답을 같은 incident timeline에서 연결해야 한다.

## Vault 호환성은 출발점이지 마이그레이션 보증이 아니다

OpenBao의 API와 구성에는 `X-Vault-*` 헤더와 Vault 계열의 개념이 많이 남아 있다. 기존 클라이언트와 자동화가 그대로 동작할 가능성은 중요한 장점이다. 하지만 호환성을 제품 이름이나 CLI 모양으로 추정해서는 안 된다. 실제 계약은 사용하는 auth method, secret engine, API path, plugin version, storage backend, namespace, seal 방식과 client library 버전의 조합이다.

특히 `v2.7.0`은 file storage를 server backend에서 제거했고, Kerberos·LDAP·RADIUS auth와 LDAP secret engine을 주 배포물 밖의 플러그인으로 옮겼다. 기존 환경이 해당 기능을 사용한다면 “OpenBao 설치 성공”과 “운영 기능 동등성” 사이에 큰 간격이 생긴다. Go API·SDK를 사용하는 내부 도구도 module v2 경로와 internal package 이동의 영향을 받을 수 있다.

공식 `bao operator migrate`는 storage backend 사이의 데이터를 복호화하지 않고 복사하지만 온라인 무중단 전환 도구는 아니다. 문서는 일관성을 위해 OpenBao를 중지한 오프라인 작업으로 규정하고, destination의 기존 key를 덮어쓰며, 완료 후 추가 Raft 노드를 다시 join하도록 안내한다. 따라서 전환 계획에는 다음이 필요하다.

1. 현재 mount, auth method, policy, plugin, seal, namespace, client library 목록을 추출한다.
2. 각 항목을 OpenBao 목표 버전의 지원 형태와 대조하고 동등성·대체·제거로 분류한다.
3. 실제 데이터 사본으로 offline migration 시간과 rollback 시간을 측정한다.
4. 애플리케이션별 login, read, renew, revoke, dynamic credential, PKI issuance 회귀 테스트를 실행한다.
5. 신규 발급을 중단하는 cutover 시점과 구 시스템으로 돌아갈 수 있는 최종 시점을 정한다.

데이터 복사가 끝났다는 사실은 클라이언트가 안전하게 전환됐다는 뜻이 아니다. 장기 실행 프로세스가 오래된 token을 들고 있는지, agent cache가 어느 endpoint를 바라보는지, CI runner와 Kubernetes injector가 새 CA를 신뢰하는지까지 확인해야 한다.

## 대안 비교는 기능표보다 책임 모델로 한다

| 선택지 | 강점 | 운영 부담과 경계 | 맞는 환경 |
|---|---|---|---|
| OpenBao | MPL-2.0, 공개 거버넌스, 동적 시크릿·PKI·Transit, Raft·PostgreSQL 선택 | 직접 HA·복구·업그레이드·플러그인 검증, 호환성 회귀 책임 | 오픈소스 통제권과 플랫폼 운영 역량이 모두 필요한 조직 |
| HashiCorp Vault 계열 | 넓은 생태계와 축적된 운영 경험, 상용 지원 선택지 | 에디션·라이선스·제품 정책 검토, 기능별 비용과 지원 경계 | 기존 투자가 크고 공식 지원·생태계 예측성이 중요한 조직 |
| 클라우드 secret manager | 관리형 가용성, IAM·KMS·감사 서비스와 긴밀한 통합 | 멀티클라우드 이식성, 동적 엔진 범위, 비용·벤더 종속 | 단일 클라우드 중심이며 운영 인력을 줄이는 것이 우선인 팀 |
| External Secrets Operator + 기존 backend | Kubernetes 선언형 동기화와 GitOps 결합 | 동기화된 Kubernetes Secret의 복제·회전 지연·RBAC 경계 | 이미 신뢰할 backend가 있고 cluster 전달 계층만 필요한 경우 |
| SOPS·Git 암호화 | 변경 리뷰와 GitOps 친화성, 작은 구성 | 온라인 동적 발급·lease·즉시 폐기·중앙 감사에는 부적합 | 배포 시점의 정적 설정과 작은 팀의 단순성이 중요한 경우 |

[Trivy 공급망 보안 글](/posts/github-trending-trivy-supply-chain-security/)에서 범용 스캐너와 전문 플랫폼의 역할을 분리했듯, secret manager도 하나로 모든 문제를 해결하려 해서는 안 된다. SOPS는 Git에 둘 정적 설정에 적합하고, cloud secret manager는 관리형 운영에 강하며, OpenBao는 다수 플랫폼에 일관된 동적 발급·PKI·암호화 정책을 제공할 때 가치가 커진다. 반대로 Kubernetes Secret 몇 개를 관리하는 작은 팀이 OpenBao cluster부터 만들면 보안보다 운영 복잡도가 먼저 늘 수 있다.

## PoC는 발급 성공보다 실패와 폐기를 측정한다

![OpenBao 도입 결정을 위한 호환성·가용성·보안·복구 검증 게이트](https://heracles-jo.github.io/assets/img/posts/openbao-secrets-management-migration/decision.svg)

PoC에서 `bao kv put`과 `get`이 성공하는 것은 시작 조건일 뿐이다. 합격선은 다음 측정값으로 정하는 편이 낫다.

- **인증**: Kubernetes·OIDC·AppRole 로그인 성공률, IdP 장애 시 실패 방식, token 발급 p95 지연
- **수명주기**: 동적 자격 증명 TTL, 갱신 실패 후 애플리케이션 회복 시간, revoke 완료까지 걸린 시간
- **정책**: 허용·거부 canary 요청, 정책 변경 전파 시간, root·sudo 사용 빈도와 승인 기록
- **가용성**: active failover 동안 오류율, standby read의 일관성, quorum 손실 뒤 복구 시간
- **복구**: 빈 환경에서 snapshot 복원 RTO·RPO, seal/KMS·TLS·DNS를 포함한 전체 복구 완전성
- **감사**: audit 누락률, 로그 전송 실패 감지 시간, 민감 필드 노출 여부, 보존 비용
- **운영 비용**: 월별 업그레이드·인증서·플러그인·정책 리뷰 시간, on-call이 원인을 분리하는 데 걸린 시간

가장 가치 있는 실험은 의도적으로 자격 증명을 만료시키는 것이다. DB 계정의 TTL을 짧게 두고 연결 풀이 새 계정을 받는지, revoke 후 기존 세션이 얼마나 남는지, OpenBao가 잠시 중단됐을 때 애플리케이션이 무한 재시도로 장애를 확대하지 않는지 본다. PKI를 평가한다면 발급 성공뿐 아니라 CA rotation, CRL·OCSP, 만료 직전 갱신 폭주, 잘못된 SAN 거부를 시험한다. 외부 KMS 키를 쓴다면 provider 장애와 rate limit이 서명 경로의 SLO를 어떻게 바꾸는지도 측정해야 한다.

OpenBao가 맞는 조직은 이미 플랫폼 팀이 인증·네트워크·스토리지·백업을 운영하고, 정적 시크릿 복제와 장기 자격 증명이 실제 위험이며, 여러 환경에 공통 정책을 제공해야 하는 곳이다. 반대로 전담 운영자가 없고 단일 클라우드의 관리형 서비스로 요구를 충족할 수 있으며, 복구 훈련과 정책 리뷰를 수행할 수 없다면 직접 운영은 통제권이 아니라 새로운 단일 장애점이 된다.

결정 기준은 “Vault와 얼마나 비슷한가”가 아니다. **시크릿 발급·갱신·폐기·감사·복구의 전체 계약을 우리 팀이 측정하고 지킬 수 있는가**다. 그 계약을 실제 장애 시험으로 증명한 뒤에야 OpenBao의 오픈 거버넌스와 기능 폭이 운영 자산이 된다.

> 1차 자료: [OpenBao 저장소와 README](https://github.com/openbao/openbao), [MPL-2.0 LICENSE](https://github.com/openbao/openbao/blob/main/LICENSE), [What is OpenBao](https://openbao.org/docs/what-is-openbao/), [Security model](https://openbao.org/docs/internals/security/), [Integrated Storage](https://openbao.org/docs/configuration/storage/raft/), [High Availability](https://openbao.org/docs/concepts/ha/), [`operator migrate`](https://openbao.org/docs/commands/operator/migrate/), [v2.7.0 release](https://github.com/openbao/openbao/releases/tag/v2.7.0), [최근 commits](https://github.com/openbao/openbao/commits/main/). Trending·저장소 수치는 2026년 9월 27일 08시 01분 KST 전후 확인한 공개 스냅샷이다.
