---
title: "celld와 셀프호스팅 Durable Objects: 상태ful 서버리스가 다시 인프라 선택지가 되는 이유"
description: "GitHub Trending에 오른 denoland/celld를 중심으로 Cloudflare Durable Objects 모델을 자체 인프라와 S3 호환 스토리지 위에서 운영하려는 흐름, 아키텍처, 도입 판단, 보안·운영 리스크를 분석한다."
author: heracles-jo
date: 2026-08-09 07:12:00 +0900
categories: [Cloud Infrastructure, Serverless]
tags: [github-trending, celld, durable-objects, serverless, cloudflare-workers, deno, rust, sqlite, s3, self-hosted]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-celld-self-hosted-durable-objects/cover.svg
  alt: "celld가 S3 호환 버킷과 셀 단위 SQLite를 이용해 셀프호스팅 Durable Objects를 구성하는 상태ful 서버리스 흐름"
---

GitHub Trending daily에서 [denoland/celld](https://github.com/denoland/celld)가 눈에 띄었다. 2026년 8월 9일 07:15 KST 전후 확인한 공개 스냅샷 기준으로 celld 저장소는 약 2.5k stars, 71 forks, 13 open issues를 보였고, 2026년 8월 5일 [v0.1.0 릴리스](https://github.com/denoland/celld/releases/tag/v0.1.0)와 같은 시점의 최근 커밋이 확인됐다. 같은 Trending 화면에는 `PrimeIntellect-ai/prime-agent`, `addyosmani/agent-skills`, `google/skills`, `goauthentik/authentik`, `LadybirdBrowser/ladybird`, `google/guava` 같은 저장소도 함께 보였다. 이 글의 수치와 순위는 확인 시점의 스냅샷이며, GitHub Trending 순위와 저장소 지표는 언제든 바뀔 수 있다.

오늘의 기술 흐름을 한 문장으로 정리하면 이렇다. **서버리스가 “무상태 함수”의 동의어였던 시기를 지나, 작고 명확한 상태 단위를 애플리케이션 아키텍처의 1급 객체로 끌어올리는 방향으로 이동하고 있다.** celld는 Cloudflare Workers와 Durable Objects의 프로그래밍 모델을 자체 머신과 S3 호환 오브젝트 스토리지 위에서 실행하려는 프로젝트다. 단순히 Cloudflare를 복제하려는 시도라기보다, 상태ful 서버리스가 왜 매력적인지, 그리고 그 매력을 자체 운영 환경으로 가져올 때 어떤 비용과 리스크가 생기는지를 보여주는 사례로 보는 편이 정확하다.

![celld runtime flow](https://heracles-jo.github.io/assets/img/posts/github-trending-celld-self-hosted-durable-objects/runtime-flow.svg)

## 오늘의 GitHub Trending 후보와 선택 이유

최근 글에서 AI 에이전트 스킬, 로컬 AI 실행, 개발 환경 컨트롤 플레인, 협업·프로젝트 관리, 브라우저 테스트, 문서 인입 파이프라인을 이미 다뤘기 때문에 이번에는 같은 에이전트 도구 소개를 반복하지 않는 방향으로 후보를 비교했다.

| 후보 저장소 | 확인 시점 신호 | 주목할 점 | 이번 글의 판단 |
|---|---:|---|---|
| [denoland/celld](https://github.com/denoland/celld) | 약 2.5k stars, v0.1.0, Rust | S3 호환 버킷을 조정자와 내구성 계층으로 쓰는 셀프호스팅 Durable Objects | 오늘의 핵심 주제로 선택 |
| [LadybirdBrowser/ladybird](https://github.com/LadybirdBrowser/ladybird) | 약 65k stars, 최근 커밋 활발 | 독립 브라우저 엔진과 웹 플랫폼 구현 | 의미는 크지만 장기 프로젝트라 오늘의 신호보다 지속 관찰 주제에 가까움 |
| [goauthentik/authentik](https://github.com/goauthentik/authentik) | 약 24k stars, 2026.5.6 릴리스 | 셀프호스팅 IAM/SSO | 기존 identity infrastructure 글과 각도가 가까움 |
| [PrimeIntellect-ai/prime-agent](https://github.com/PrimeIntellect-ai/prime-agent) | 약 8.7k stars, v0.7.1 | 장시간 자율 코딩 에이전트 | 최근 에이전트 네이티브 소프트웨어·스킬·CLI 각도와 중복 가능성이 큼 |
| [google/guava](https://github.com/google/guava) | 약 52k stars, Java 핵심 라이브러리 | 성숙한 라이브러리의 꾸준한 유지보수 | 실무적으로 중요하지만 Trending의 새 흐름을 설명하기에는 신선도가 낮음 |

celld를 선택한 이유는 “상태를 어디에 둘 것인가”라는 오래된 문제가 다시 애플리케이션 런타임의 중심으로 돌아오고 있기 때문이다. 전통적 서버리스는 빠른 배포와 자동 확장을 제공했지만, 상태는 보통 외부 DB, 큐, 캐시, 오브젝트 스토리지에 흩어졌다. 반대로 모놀리식 서버나 장수 프로세스는 상태와 연결을 다루기 쉽지만, 장애 격리와 확장 단위가 거칠어지기 쉽다. Durable Objects 모델은 이 둘 사이에서 “이름을 가진 작은 상태ful 객체”를 단위로 삼는다. celld는 이 모델을 특정 클라우드 계정 밖으로 꺼내 자체 인프라 선택지로 만들겠다는 점에서 흥미롭다.

## celld는 무엇인가: Cloudflare Workers 모델을 자체 버킷 위로 옮기는 실험

[celld README](https://github.com/denoland/celld)는 프로젝트를 “Self-hosted, distributed Durable Objects”라고 설명한다. 핵심은 `celld` 노드가 V8을 내장해 Wrangler 번들을 실행하고, fleet 전체가 S3 호환 버킷 하나를 공유한다는 점이다. 이 버킷에는 배포물, cell 상태, 소유권 기록, 노드 lease, peer 인증 비밀 등이 저장된다. 각 Durable Object에 해당하는 cell은 자기만의 SQLite 데이터베이스를 갖고, 이름으로 주소 지정되며, 한 시점에는 하나의 노드만 그 cell을 소유한다.

이 설계는 익숙한 분산 시스템 패턴과 다르게 보인다. 보통 여러 노드가 상태를 공유하려면 etcd, Consul, ZooKeeper, Raft 기반 저장소, 중앙 스케줄러, 멤버십 프로토콜 중 하나가 등장한다. celld의 문서는 “no control plane or consensus”를 강조한다. 노드들은 공유 버킷의 오브젝트 스토리지 compare-and-swap 성격을 이용해 cell 소유권을 획득하고, SQLite 상태를 버킷에 복제한다. 노드가 사라져도 버킷이 내구성의 기준점이므로 다른 노드가 cell을 깨워 이어받을 수 있다는 것이 기본 아이디어다.

문서상으로는 RPO=0도 강조된다. [docs README](https://github.com/denoland/celld/blob/main/docs/README.md)는 celld가 cell의 SQLite 데이터를 버킷에 보낸 뒤에야 write를 acknowledge하므로, 노드 손실이 이미 확인된 write를 잃지 않는다고 설명한다. 물론 이는 오브젝트 스토리지 지연, 네트워크 품질, 구현 성숙도, 장애 시나리오 검증이 함께 따라와야 의미가 있다. 그래도 설계 의도는 분명하다. 애플리케이션 개발자는 거대한 공유 DB 테이블을 직접 샤딩하는 대신, 사용자·문서·채팅방·AI 에이전트 같은 단위마다 cell을 만들고 그 cell의 지역적 상태를 작은 SQLite DB로 다루게 된다.

## 왜 지금 이 흐름이 중요한가: 서버리스의 빈칸은 “상태”였다

서버리스의 첫 번째 약속은 인프라 추상화였다. 함수 단위 배포, 이벤트 기반 실행, 사용량 기반 과금, 자동 확장. 하지만 실무에서는 곧 상태 관리가 병목이 됐다. 사용자 세션, WebSocket 연결, 문서 동시 편집, 채팅방, 워크플로 상태, 장시간 에이전트 작업, 게임 룸, IoT 디바이스 상태처럼 “작지만 오래 사는 상태”가 필요한 워크로드는 많다. 이를 순수 무상태 함수로만 구현하면 Redis, Postgres, DynamoDB, Queue, Pub/Sub, cache invalidation, optimistic locking이 빠르게 얽힌다.

Cloudflare Durable Objects가 흥미로웠던 이유도 여기에 있다. 객체 하나에 요청을 직렬화하고, 객체 내부 저장소를 가까이에 두고, 이름 기반 라우팅으로 특정 상태 단위를 찾아간다. 개발자는 “이 문서의 동시 편집 상태는 이 객체가 관리한다”처럼 사고할 수 있다. celld는 이 모델을 자체 머신에서 실행하게 해준다. 클라우드 사업자의 글로벌 엣지 네트워크와 관리형 운영을 그대로 가져오는 것은 아니지만, 프로그래밍 모델과 상태 단위의 장점을 온프레미스, private cloud, 특정 리전, 비용 통제 환경에서 실험할 수 있게 한다.

이는 AI 시대의 애플리케이션 구조와도 맞닿아 있다. 장시간 동작하는 에이전트, 사용자별 메모리, 세션별 도구 상태, 스트리밍 UI, 협업형 캔버스는 모두 “한 번 요청하고 끝나는 함수”보다 “상태를 가진 작은 actor”에 가깝다. 다만 오늘 글의 초점은 AI 도구가 아니라 그 밑의 런타임 선택지다. 에이전트든 협업 앱이든, 결국 운영자는 상태의 소유권, 복제, 장애 복구, 비용 모델을 결정해야 한다.

## 핵심 아키텍처: cell, SQLite, object storage, peer network

celld의 아키텍처를 실무 의사결정 관점에서 나누면 네 가지 계층으로 볼 수 있다.

### 1. 실행 계층: V8과 Workers 호환 API

각 celld 노드는 V8을 내장하고 Wrangler 번들을 실행한다. 문서의 [Cloudflare compatibility](https://github.com/denoland/celld/blob/main/docs/cloudflare-compat.md)에 따르면 module Workers, `fetch`, JS RPC, service bindings, Durable Object bindings, static assets 등의 일부 Workers 표면을 지원한다. 반면 KV, R2 제공 자체, Cache API, Workers AI, Vectorize, Hyperdrive, Browser Rendering, Email, cron triggers, custom domains, TLS termination 등은 제공 범위 밖이거나 별도 ingress/proxy가 필요하다. 즉 “Cloudflare 전체 플랫폼의 셀프호스팅 버전”이 아니라 “Durable Objects 중심의 Workers 런타임”으로 이해해야 한다.

### 2. 상태 계층: cell마다 SQLite 데이터베이스

각 cell은 작은 서버이자 자기 SQLite DB를 가진다. 요청은 같은 cell 안에서 동시에 실행되지 않고, storage operation은 interleaving되지 않도록 설계된다. 이것은 개발 모델을 단순하게 만든다. 예를 들어 문서 단위 협업 서버라면 문서 하나를 cell 하나로 잡아 동시성 충돌 범위를 문서 내부로 제한할 수 있다. 여러 고객이 하나의 큰 DB 테이블을 놓고 경쟁하는 구조보다 contention과 장애 반경을 작게 만들 수 있다.

### 3. 조정 계층: S3 호환 버킷

celld에서 버킷은 단순 백업 저장소가 아니다. 배포물, cell state, ownership record, node lease, peer-auth secret이 들어가는 권위(authority)의 원천이다. 노드들은 버킷을 통해 소유권을 획득하고, 상태를 복제하고, 최신 배포를 발견한다. 이 설계의 장점은 별도 control plane을 줄인다는 점이고, 단점은 버킷 권한과 성능이 곧 전체 fleet의 신뢰 경계가 된다는 점이다. 문서도 bucket credential을 fleet administrator access로 취급하라고 명시한다.

### 4. 네트워크 계층: peer HTTP와 ingress의 책임 분리

[security 문서](https://github.com/denoland/celld/blob/main/docs/security.md)는 peer 요청에 HMAC, body signature, clock limit, replay protection이 있지만 peer protocol 자체가 TLS를 종료하지 않는다고 설명한다. 따라서 advertised address는 신뢰할 수 있는 private network나 WireGuard, Tailscale 같은 encrypted overlay 위에 둬야 한다. public TLS와 사용자 인증은 celld가 아니라 ingress, reverse proxy, 애플리케이션 계층의 책임이다. 이 지점은 PoC에서는 쉽게 넘어가지만 운영 도입에서는 가장 먼저 설계해야 하는 경계다.

## 기존 방식과 비교: Cloudflare, Fly Machines, Lambda, Actor 프레임워크

celld를 평가하려면 “무엇을 대체하는가”보다 “어떤 운영 모델을 선택하는가”로 비교해야 한다.

| 선택지 | 강점 | 한계 | celld와의 차이 |
|---|---|---|---|
| [Cloudflare Durable Objects](https://developers.cloudflare.com/durable-objects/) | 글로벌 엣지, 관리형 운영, Workers 생태계 | 플랫폼 종속, 계정/리전/과금 정책 의존 | celld는 자체 머신과 버킷을 쓰지만 관리형 글로벌 인프라는 직접 운영해야 함 |
| AWS Lambda + DynamoDB/ElastiCache | 성숙한 클라우드 운영, IAM, 관측성 | 상태 로직이 여러 관리형 서비스로 분산 | celld는 상태와 실행 단위를 cell로 묶어 애플리케이션 모델을 단순화하려 함 |
| Fly.io Machines/Apps | 장수 프로세스와 지역 배치에 강함 | 앱별 상태·복제 설계는 별도 | celld는 Durable Object API와 cell 단위 ownership을 전면에 둠 |
| Akka/Orleans 같은 actor 모델 | actor 사고방식과 분산 런타임 경험 | 언어/프레임워크 결합, 운영 난이도 | celld는 JavaScript Workers API와 SQLite·오브젝트 스토리지 조합으로 접근성을 높임 |
| 일반 Kubernetes + Postgres/Redis | 표준 도구와 인력 풀이 넓음 | 샤딩, hot key, WebSocket, 동시성 제어가 앱 책임 | celld는 작은 상태 단위의 기본 샤딩을 유도함 |

따라서 celld의 직접 경쟁자는 하나의 제품만이 아니다. “관리형 Cloudflare를 쓸 것인가, AWS 서비스 조합으로 갈 것인가, actor 프레임워크를 도입할 것인가, Kubernetes 위에 직접 만들 것인가”라는 아키텍처 결정의 한 축에 놓인다. celld가 유리한 영역은 Cloudflare Durable Objects 프로그래밍 모델이 마음에 들지만 데이터 위치, 비용 구조, 네트워크 폐쇄성, 자체 운영 통제 때문에 완전 관리형 플랫폼으로 가기 어려운 팀이다.

## 실무 도입 시 장점: 상태 단위가 설계의 중심이 된다

첫 번째 장점은 상태의 경계가 코드 구조에 드러난다는 점이다. Postgres 테이블과 Redis key space로 모든 상태를 흩뿌리면, 시간이 지날수록 어떤 요청이 어떤 상태를 독점적으로 변경하는지 추적하기 어렵다. cell 모델은 사용자, 문서, 채팅방, 작업 실행 단위처럼 자연스러운 업무 경계를 런타임 경계로 만들 수 있다. 이는 장애 격리와 성능 분석에도 도움이 된다.

두 번째 장점은 운영 단순화 가능성이다. 물론 celld 자체가 분산 시스템이므로 “간단하다”는 표현은 조심해야 한다. 그러나 etcd, 전용 스케줄러, 별도 membership service 없이 S3 호환 버킷을 조정자와 내구성 계층으로 쓰는 설계는 작은 팀에게 매력적이다. 이미 MinIO, AWS S3, Cloudflare R2 같은 오브젝트 스토리지를 운영·사용하는 조직이라면 PoC 진입 장벽이 낮다.

세 번째 장점은 비용과 배치 통제다. 문서상 idle cell은 버킷에 hibernate되어 거의 비용이 들지 않고, resident cell만 메모리를 사용한다. docs는 8GB 노드가 1,000 resident cells를 보유할 수 있다는 초기 수치를 제시한다. 이것은 벤치마크라기보다 설계 감각을 주는 숫자로 봐야 한다. 실제 비용은 cell당 메모리, 연결 수, SQLite 쓰기 빈도, 버킷 요청 비용, 네트워크 egress, ingress 계층 비용에 따라 달라진다.

## 한계와 리스크: alpha 프로젝트를 운영 시스템으로 착각하면 안 된다

celld의 [limitations 문서](https://github.com/denoland/celld/blob/main/docs/limitations.md)는 현재 경계를 꽤 명확하게 적고 있다. fleet은 하나의 application deployment를 실행하며, multi-tenant scheduler, account service, managed ingress, global placement layer가 없다. peer HTTP는 TLS를 종료하지 않는다. bucket credential은 fleet의 행정 권한이다. `~/.aws` profile이나 SSO login을 읽지 않는 등 credential 방식에도 제약이 있다. Windows prebuilt binary도 없고 Intel Mac prebuilt도 제공되지 않는다.

운영 리스크는 크게 다섯 가지다.

1. **보안 경계 오해**: peer request가 인증된다고 해서 네트워크가 안전한 것은 아니다. TLS는 별도 overlay나 private network로 해결해야 한다.
2. **버킷 권한 집중**: 버킷 credential 유출은 배포물, 상태, lease, peer secret 장악으로 이어진다. 최소 권한과 credential rotation이 필수다.
3. **오브젝트 스토리지 지연 의존**: write acknowledge가 버킷 복제와 결합되면 tail latency가 애플리케이션 체감 성능에 영향을 준다.
4. **호환성 착각**: Cloudflare 전체 플랫폼을 기대하면 실패한다. KV, cron, managed TLS, custom domain 같은 기능은 별도 설계가 필요하다.
5. **성숙도와 장애 사례 부족**: v0.1.0 단계의 alpha 프로젝트다. 보안 수정은 최신 릴리스 중심이며, 장기 운영 사례와 tooling은 아직 제한적이다.

이 때문에 celld는 지금 당장 핵심 결제 시스템이나 규제 대상 고객 데이터를 올릴 대상이라기보다, 상태ful edge/serverless 모델을 검증하는 PoC와 내부 도구, 제한된 트래픽의 협업 기능부터 접근하는 것이 합리적이다.

## PoC 체크리스트: “실행된다”보다 “운영할 수 있다”를 확인하라

celld PoC를 한다면 단순 counter 예제를 띄우는 데서 멈추면 안 된다. 다음 항목을 작은 실험 계획으로 만들어야 한다.

- **워크로드 모델링**: cell 경계를 사용자, 문서, 룸, agent session 중 어디로 잡을지 결정한다.
- **버킷 설계**: AWS S3, Cloudflare R2, MinIO 중 어떤 S3 호환 계층을 쓸지 정하고, 전용 bucket과 최소 권한 credential을 만든다.
- **네트워크 경계**: peer port는 private subnet 또는 WireGuard/Tailscale overlay에만 둔다. public ingress는 별도 TLS termination과 인증을 담당한다.
- **지연 측정**: p50뿐 아니라 p95/p99 write latency, cell wake-up latency, WebSocket reconnection behavior를 측정한다.
- **장애 주입**: owner node kill, bucket 일시 지연, 네트워크 partition, credential rotation, deploy rollback을 실험한다.
- **관측성**: `celld diagnose` 결과, 노드별 resident cell 수, RSS, CPU, file descriptor, pressure sample을 수집한다.
- **호환성 검증**: Cloudflare Workers API 중 실제 앱이 쓰는 API가 celld에서 지원되는지 문서와 테스트로 확인한다.
- **데이터 복구**: 버킷 객체 버전 관리, retention, 백업, 삭제 방지 정책을 정한다.

이 체크리스트는 “celld가 나쁘다”는 의미가 아니다. 오히려 alpha 단계의 분산 런타임을 진지하게 평가하려면 이 정도 질문이 기본이라는 뜻이다.

## 어떤 팀에 적합하고, 어떤 경우 피해야 하나

celld가 적합한 팀은 명확하다. Cloudflare Workers/Durable Objects 모델에 익숙하거나 관심이 있고, 자체 인프라·private network·S3 호환 스토리지를 운영할 수 있으며, 작은 상태 단위로 애플리케이션을 재설계할 의지가 있는 팀이다. 특히 협업 문서, 채팅방, 실시간 dashboard, 내부 control plane, 제한된 범위의 AI session runtime처럼 상태 경계가 자연스럽게 나뉘는 서비스에 잘 맞는다.

반대로 다음 상황에서는 피하는 편이 낫다. 첫째, Cloudflare의 글로벌 엣지, managed DDoS, TLS, custom domain, KV/R2/Queues/Workflows까지 한 번에 기대하는 경우다. celld는 그런 플랫폼 전체가 아니다. 둘째, 운영팀이 private networking, credential management, object storage 정책을 다룰 준비가 없는 경우다. 셋째, 강한 규제 준수와 장기 support policy가 필요한 업무다. alpha 프로젝트의 속도와 운영 조직의 안정성 요구가 충돌할 가능성이 높다.

## 향후 관찰해야 할 지표와 전망

앞으로 celld를 볼 때는 stars보다 더 중요한 지표가 있다. 첫째, 릴리스 주기와 breaking change 관리다. v0.1.0 이후 compatibility boundary가 얼마나 안정화되는지 봐야 한다. 둘째, Cloudflare compatibility 문서의 gap이 어떻게 줄어드는지, 특히 D1·Workflows·Queues 계획이 실제 구현으로 이어지는지 확인해야 한다. 셋째, 보안 문서가 threat model과 hardening guide로 확장되는지 봐야 한다. 넷째, 운영 사례와 benchmark가 등장하는지, cell wake-up, WebSocket migration, pressure shedding의 기본값이 어떻게 정해지는지 관찰해야 한다.

전망은 조심스럽게 긍정적이다. 모든 애플리케이션이 celld 같은 런타임으로 이동하지는 않을 것이다. 관계형 쿼리 중심의 백오피스, 데이터 웨어하우스, 단순 CRUD API는 기존 Postgres와 일반 웹 서버가 더 단순하다. 그러나 실시간 협업, 사용자별 장기 세션, agent runtime, edge-adjacent state처럼 “작은 상태 단위가 많고, 각 단위의 일관성이 중요하며, 전체 DB를 공유하기 싫은” 워크로드는 계속 늘고 있다. celld의 Trending 등장은 그 수요가 특정 플랫폼 안의 기능을 넘어 독립적인 아키텍처 선택지로 확장되고 있음을 보여준다.

## 결론: celld는 제품보다 질문이 중요하다

celld를 오늘 당장 표준 런타임으로 채택하라고 말하기는 이르다. 저장소는 빠르게 움직이고 있지만 alpha 경계가 분명하며, 보안·네트워크·버킷 권한·호환성 책임이 운영자에게 남아 있다. 그럼에도 celld가 던지는 질문은 매우 실무적이다. “우리 서비스의 상태 단위는 무엇인가?”, “상태의 소유권과 장애 반경을 코드 구조로 표현하고 있는가?”, “관리형 플랫폼 종속을 받아들일 것인가, 자체 운영 책임을 질 것인가?”

이 질문에 답할 수 있는 팀이라면 celld는 좋은 PoC 대상이다. 반대로 그 질문이 아직 정리되지 않았다면, celld를 도입하기 전에 현재 아키텍처의 hot key, 동시성 제어, WebSocket 운영, DB contention, 복구 절차부터 점검해야 한다. GitHub Trending은 답을 주지 않는다. 다만 오늘 celld가 보여준 신호는 분명하다. 상태ful 서버리스는 더 이상 변두리 아이디어가 아니라, 실무 아키텍처 회의에서 다시 꺼내볼 만한 선택지가 되고 있다.
