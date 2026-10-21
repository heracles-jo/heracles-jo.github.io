---
title: "Supabase 셀프호스팅: 관리형 전환 비용과 운영 기준"
description: "Supabase의 Postgres·Auth·Realtime·Storage 구성을 분해하고, 셀프호스팅에서 백업·키 회전·업그레이드·RLS를 책임질 수 있는지 판단하는 기준을 제시한다."
author: heracles-jo
date: 2026-10-22 07:50:00 +0900
categories: [Platform Engineering, Database]
tags: [supabase, self-hosting, postgres, backend-as-a-service, row-level-security, platform-engineering]
image:
  path: https://heracles-jo.github.io/assets/img/posts/supabase-self-hosting-operations/cover.svg
  alt: "Supabase 셀프호스팅에서 관리형 편의와 운영 책임을 비교하는 개념도"
---

Supabase 셀프호스팅을 검토할 때 흔히 하는 계산은 관리형 서비스의 월 요금과 가상 서버 비용을 비교하는 것이다. 이 계산에는 핵심 항목이 빠져 있다. **Supabase를 직접 운영한다는 것은 Postgres 한 대를 띄우는 일이 아니라 인증, API, 실시간 전송, 파일 저장, 함수 실행, 연결 풀, 게이트웨이의 장애와 보안 경계를 함께 소유하는 일**이다. 서버 비용이 낮아져도 키 회전, 백업 복원, 데이터베이스 마이그레이션, 이미지 호환성, 긴급 패치를 담당할 사람이 없다면 총비용은 오히려 커진다.

[Supabase 공식 저장소](https://github.com/supabase/supabase)는 2026년 10월 22일 08시 KST 전후 GitHub Trending daily에 표시됐다. GitHub 공개 API 확인 시점에는 112,961 stars, 16,917 forks, 열린 issue와 PR을 합친 1,183개, Apache-2.0 라이선스, 10월 21일까지 이어진 커밋 활동을 보였다. 공식 README는 Supabase를 Postgres 개발 플랫폼으로 정의하고 Database, Auth, REST·GraphQL API, Realtime, Storage, Edge Functions, AI·Vector 도구와 Dashboard를 결합한다. 이 수치와 Trending 신호는 해당 시점의 스냅샷이며 이후 달라질 수 있다. 이번 실행에서는 Search Console·Analytics의 실제 데이터에 접근하지 못해 주제 선정에 사용하지 않았다.

## 후보 비교: 새 도구보다 운영 책임이 오래 남는 주제를 택했다

오늘 daily·weekly 후보 중 상당수는 최근 글의 검색 의도와 겹쳤다. 저장소 이름만 다른지보다 독자가 해결하려는 문제가 같은지를 우선 비교했다.

| 후보 | 확인 시점 신호 | 기존 글 중복과 장기 가치 판단 |
|---|---|---|
| [Supabase](https://github.com/supabase/supabase) | daily 509 stars, 112,961 stars, Apache-2.0, 당일 커밋 | Postgres 기반 BaaS를 **관리형에서 셀프호스팅으로 옮길 때 생기는 운영 책임**은 기존 글에 없는 독립 검색 의도다. |
| [vLLM](https://github.com/vllm-project/vllm) | daily 439 stars, 94,840 stars, Apache-2.0, v0.32.0 | LLM 서빙은 LMCache, KTransformers, Model Optimizer 글에서 KV cache·이기종 추론·배포 검증을 이미 깊게 다뤘다. |
| [Graphify](https://github.com/Graphify-Labs/graphify) | daily 1,434 stars, 131,566 stars, Apache-2.0, v0.9.93 | 코드 지식 그래프와 검색 계층은 XERJ와 codebase-memory 계열 글의 중심 논지와 충돌한다. |
| [Headroom](https://github.com/headroomlabs-ai/headroom) | daily 477 stars, 77,227 stars, Apache-2.0, v0.41.0 | 도구 출력 압축은 Context Mode의 토큰·세션 I/O 최적화와 같은 검색 의도에 가깝다. |
| [AI Memory](https://github.com/akitaonrails/ai-memory) | daily 303 stars, 12,295 stars, MIT, v3.1.2 | 코딩 에이전트 장기 기억은 claude-mem과 세션 메모리 글에서 이미 운영 경계를 설명했다. |

Supabase는 오래된 대형 프로젝트라서 새 기능 소개만으로는 글의 가치가 약하다. 대신 셀프호스팅 문서가 최근 `self-hosted/v0.8.3` 구성, 자동 키 생성, 월 단위 안정 스냅샷, 3-way merge 기반 업데이트 절차를 구체화한 점에 주목했다. 검색자의 실제 질문도 “Supabase가 무엇인가”보다 “클라우드 요금과 데이터 통제 때문에 직접 운영해도 되는가”에 가깝다.

## 하나의 제품처럼 보이지만 장애 도메인은 여러 개다

Supabase의 개발 경험은 단순하다. 클라이언트 SDK에 URL과 publishable key를 넣고, Postgres 테이블을 만든 뒤 Auth와 Storage를 연결하면 빠르게 제품을 시작할 수 있다. 하지만 공식 Docker 구성의 내부를 보면 Studio, Envoy, Auth, PostgREST, Realtime, Storage, imgproxy, postgres-meta, Postgres, Edge Runtime, Supavisor가 연결된다. 선택적으로 Logflare와 Vector도 추가된다.

![Supabase 셀프호스팅에서 요청이 게이트웨이, 인증, API, 실시간, 저장소를 거쳐 Postgres와 객체 저장소로 흐르는 구조](https://heracles-jo.github.io/assets/img/posts/supabase-self-hosting-operations/architecture.svg)

이 구조가 제공하는 가치는 구성요소 수를 숨기는 데 있다. PostgREST는 스키마를 REST API로 노출하고, Auth는 사용자와 JWT 수명주기를 맡으며, Realtime은 Postgres 변경을 WebSocket 구독자에게 전달한다. Storage는 객체 데이터와 권한 메타데이터를 연결하고, Supavisor는 연결 수를 조절한다. 관리형 환경에서는 공급자가 이 결합을 시험하고 관측하며 업그레이드한다. 셀프호스팅에서는 그 계약이 운영팀으로 이동한다.

따라서 고가용성 설계도 서비스별로 달라진다. API gateway를 여러 개 띄우는 것만으로 Postgres 장애가 해결되지 않고, Postgres 복제본을 만든다고 Auth 서명 키와 Storage 객체가 복구되는 것도 아니다. Realtime의 logical replication 지연, 연결 풀 고갈, Edge Function의 외부 호출 실패, 이미지 처리의 CPU·메모리 급증은 서로 다른 알람과 용량 계획이 필요하다. “Compose가 healthy다”는 시작 조건이지 서비스 신뢰성의 증거가 아니다.

[Postgres 내장형 durable execution](/posts/github-trending-postgres-durable-execution/)에서 데이터베이스에 책임을 모을 때 장애 영향 반경을 함께 봐야 한다고 설명했다. Supabase도 같은 판단이 필요하다. Postgres가 데이터, 인증 정책, Storage 권한, Realtime 변경 스트림의 중심이 되면 개발은 단순해지지만 데이터베이스 성능 저하가 제품 전체의 기능 저하로 번질 가능성도 커진다.

## RLS는 기능이 아니라 최종 권한 경계다

Supabase의 중요한 설계 선택은 브라우저나 모바일 앱이 PostgREST를 통해 데이터베이스 API에 직접 접근할 수 있다는 점이다. 이 구조는 별도 CRUD 서버를 줄이지만, Row Level Security가 올바르다는 전제에 크게 의존한다. publishable key는 공개돼도 되는 식별자이고 실제 데이터 접근은 JWT claim과 RLS policy가 제한해야 한다. 반대로 secret key나 높은 권한의 service role을 클라이언트에 노출하면 RLS를 우회할 수 있다.

RLS의 위험은 정책이 없을 때만 생기지 않는다. 다음과 같은 조합이 더 찾기 어렵다.

- `SELECT` 정책은 테넌트를 제한하지만 `UPDATE`의 `WITH CHECK`가 빠져 다른 테넌트로 행을 이동할 수 있다.
- Storage 객체 경로와 데이터베이스의 소유권 기준이 달라 파일 메타데이터만 보호되고 원본 접근 경로는 열린다.
- SECURITY DEFINER 함수가 호출자보다 넓은 권한으로 실행되는데 `search_path`와 입력 검증이 약하다.
- 관리자용 Edge Function이 secret key를 사용하면서 사용자·테넌트 범위를 서버 코드에서 다시 검사하지 않는다.
- Realtime publication에 민감 테이블이 포함돼 읽기 API와 다른 경로로 변경 정보가 노출된다.

[Logto와 ID 운영 평면](/posts/github-trending-logto-identity-infrastructure/)에서 인증과 제품 권한은 같은 문제가 아니라고 구분했다. Supabase Auth가 사용자를 확인해도 “이 사용자가 이 조직의 이 행을 수정할 수 있는가”는 RLS와 애플리케이션 정책이 결정한다. 셀프호스팅 전환 전에는 테넌트 간 읽기·쓰기, 탈퇴 사용자, 권한 변경 직후의 기존 JWT, 백그라운드 작업의 service role 사용을 자동 테스트해야 한다.

## 백업은 Postgres 덤프 하나로 끝나지 않는다

셀프호스팅의 가장 비싼 실패는 설치 실패가 아니라 복구 실패다. 공식 구성은 Postgres 데이터와 Storage 데이터를 별도 볼륨에 둔다. 운영 환경에서 S3 호환 객체 저장소를 쓰더라도 데이터베이스의 객체 메타데이터, bucket 정책, 사용자·조직 상태와 실제 객체의 시점이 맞아야 한다. 데이터베이스를 오전 2시로 복원하고 객체 저장소를 오전 3시 상태로 남기면 참조되지 않는 객체와 존재하지 않는 객체 메타데이터가 동시에 생길 수 있다.

복구 설계에는 최소 네 묶음이 필요하다.

1. **Postgres**: base backup, WAL 보관, point-in-time recovery, 확장과 role 정의, 복원 후 무결성 검사.
2. **객체 데이터**: versioning 또는 snapshot, 삭제 복구, 데이터베이스 시점과의 조정 절차.
3. **비밀과 키**: JWT signing key, publishable·secret key, DB 비밀번호, SMTP·OAuth provider secret의 암호화된 백업과 회전 이력.
4. **구성**: Compose 파일, 이미지 digest, 환경변수 스키마, 프록시·DNS·TLS 설정, 데이터베이스 migration commit.

백업 파일이 있다는 사실보다 빈 환경에서 복원해 로그인, 토큰 갱신, API 읽기·쓰기, Storage 업로드·다운로드, Realtime 구독을 통과하는지가 중요하다. 복원 훈련에는 RTO와 RPO뿐 아니라 키가 유실됐을 때 모든 세션을 폐기할지, 기존 JWT 검증을 잠시 유지할지, OAuth callback URL과 SMTP 설정을 어떻게 재구성할지도 포함해야 한다.

[OpenBao 시크릿 관리 전환](/posts/openbao-secrets-management-migration/)에서 정책과 복구를 분리할 수 없다고 다뤘듯, `.env` 파일을 서버 디스크와 같은 백업에 그대로 넣는 것은 편하지만 침해 시 데이터와 복호화 수단을 함께 넘긴다. 운영 비밀은 별도 시크릿 저장소와 접근 감사 체계에 두고, 복원 절차가 사람 한 명의 로컬 파일에 의존하지 않게 해야 한다.

## 업그레이드는 이미지 교체가 아니라 분산 마이그레이션이다

Supabase 셀프호스팅 문서는 함께 시험된 Docker Compose 스냅샷을 대략 월 단위로 제공하며 개별 서비스 이미지를 임의로 바꾸면 호환성을 보장하지 않는다고 밝힌다. `update.sh`는 설치 버전을 기록하고 새 구성과 3-way merge를 수행한다. 이 방식은 단순 `docker compose pull`보다 안전하지만 자동 무중단 업그레이드를 뜻하지는 않는다.

변경은 적어도 네 층에서 일어난다. Postgres extension과 schema migration, Auth·Storage API의 데이터 모델, Gateway route와 환경변수, Studio·클라이언트 SDK의 기대 동작이다. 한 서비스만 되돌렸을 때 이미 적용된 DB migration이 구버전 코드와 호환되지 않을 수도 있다. rollback은 컨테이너 tag를 낮추는 작업이 아니라 데이터와 구성의 이전 계약으로 돌아갈 수 있는지 검증하는 작업이다.

실무에서는 production과 같은 데이터 규모를 가진 staging snapshot에서 다음 순서로 검증하는 편이 낫다.

- 현재 Compose와 이미지 digest, DB schema version, extension version을 기록한다.
- `update.sh --dry-run` 결과와 충돌 파일을 코드 리뷰한다.
- DB와 객체 저장소를 복제한 격리 환경에서 migration과 smoke test를 실행한다.
- 로그인·refresh token·OAuth callback·RLS·Storage signed URL·Realtime reconnect를 자동 검증한다.
- 연결 풀, WAL 증가량, replication lag, p95 API latency, 오류율을 비교한다.
- 되돌림 가능한 마지막 지점과 복원 예상 시간을 승인 기록에 남긴다.

HTTPS도 같은 운영 계약의 일부다. 공식 문서는 production에서 API gateway 앞에 Caddy나 Nginx 같은 reverse proxy를 두도록 안내한다. [Caddy 자동 HTTPS 운영](/posts/caddy-automatic-https-operations/)에서 다뤘듯 인증서 발급 성공만 볼 것이 아니라 갱신 실패, 다중 인스턴스의 인증서 storage, 설정 reload, WebSocket과 streaming 동작을 함께 시험해야 한다. Realtime 연결이 있는 환경에서는 일반 REST smoke test만으로 프록시 변경을 승인하면 안 된다.

## 관리형과 셀프호스팅 사이에는 세 번째 선택지가 있다

의사결정을 “Supabase Cloud 또는 Docker Compose”의 양자택일로 만들 필요는 없다. 팀의 통제 요구와 운영 능력에 따라 서비스 경계를 나눌 수 있다.

| 운영 모델 | 얻는 것 | 직접 책임질 것 | 적합한 조건 |
|---|---|---|---|
| Supabase 관리형 | 통합 업그레이드, 백업·관측성, 지원 경로, 빠른 시작 | 비용·플랜 제약, 공급자 장애와 기능 경계 | 작은 플랫폼팀, 빠른 제품 검증, 전담 DBA 부재 |
| 전체 셀프호스팅 | 배포 위치와 네트워크 통제, 구성 수정, 데이터 경계 | 모든 구성요소의 패치·백업·복구·용량·당직 | 규제·데이터 주권 요구와 24×7 운영 역량 보유 |
| 관리형 Postgres + 일부 서비스 | DB 내구성과 백업은 전문 서비스에 위임 | Auth·Realtime·Storage와 버전 호환성 | 특정 계층만 통제해야 하고 통합 시험 능력이 있는 팀 |
| 순수 Postgres + 개별 대안 | 필요한 기능만 선택, 장애 도메인 명시 | 통합 개발과 SDK 경험을 직접 설계 | 이미 IAM·객체 저장소·API 플랫폼이 표준화된 조직 |

![Supabase 관리형, 전체 셀프호스팅, 혼합형을 통제 요구와 운영 역량으로 선택하는 판단 흐름](https://heracles-jo.github.io/assets/img/posts/supabase-self-hosting-operations/decision.svg)

혼합형이 항상 더 쉽지는 않다. Supabase가 제공하는 장점은 각 구성요소의 결합이므로 일부를 교체하면 인증 claim, RLS, Storage policy, webhook, observability를 다시 연결해야 한다. 하지만 이미 조직 표준 IAM과 S3, 관리형 Postgres, 중앙 로그가 있다면 모든 것을 Compose 안에 복제하는 것보다 기존 플랫폼에 Supabase의 필요한 부분만 붙이는 편이 장기적으로 단순할 수 있다.

## PoC는 기능 데모가 아니라 당직 시뮬레이션이어야 한다

셀프호스팅 PoC에서 회원가입과 파일 업로드가 성공하는 것은 큰 의미가 없다. 정상 경로는 관리형과 로컬 모두 잘 동작한다. 차이는 새벽 장애, 패치, 복구, 권한 사고에서 나타난다. 2~4주 평가라면 실제 팀이 감당할 운영 작업을 일부러 발생시켜야 한다.

1. **부하 기준선**: 예상 동시 사용자, DB connection, Realtime socket, Storage 대역폭에서 p50·p95·p99 지연과 CPU·메모리·WAL을 측정한다.
2. **권한 공격 테스트**: 다른 테넌트 ID, 만료 직전 JWT, 탈퇴 계정, service key 오용, signed URL 재사용으로 데이터 경계를 검증한다.
3. **장애 주입**: Postgres 재시작, Gateway 한 대 종료, 객체 저장소 지연, SMTP 실패, OAuth provider 장애, 디스크 부족을 재현한다.
4. **복원 훈련**: 빈 인프라에 백업을 복원하고 전체 smoke test가 통과할 때까지 시간을 잰다.
5. **업그레이드 리허설**: self-hosted tag를 한 단계 올린 뒤 schema·API·Realtime·SDK 회귀를 확인하고 실제 rollback 또는 복원을 수행한다.
6. **키 회전**: JWT signing key와 secret key를 바꾸고 기존 세션, 서버 작업, Edge Function, 외부 webhook이 어떻게 실패하는지 기록한다.
7. **운영 인계**: 설치자가 없는 상태에서 다른 당직자가 대시보드, 로그, runbook만으로 장애를 분류하고 복구할 수 있는지 본다.

중단 기준도 비용과 함께 정해야 한다. 월 인프라 비용이 줄더라도 복원 시간이 목표를 넘거나, RLS 회귀 테스트를 자동화할 수 없거나, 업그레이드가 매번 수작업 충돌을 만들거나, 단일 운영자에게 키와 지식이 집중되면 셀프호스팅 승격을 멈추는 편이 맞다. 반대로 관리형 환경에서 데이터 위치, 사설 네트워크, 확장 설치, 규제 통제가 사업의 필수 조건이고 이를 책임질 플랫폼팀이 있다면 직접 운영의 가치가 분명해진다.

Supabase 셀프호스팅의 핵심 질문은 오픈소스 여부나 월 요금이 아니다. **Auth·API·Realtime·Storage가 공유하는 Postgres 중심 계약을 우리 팀이 장애 상황에서도 유지할 수 있는가**다. 공식 Compose는 훌륭한 출발점이고 Apache-2.0 코드는 통제 가능성을 제공한다. 그러나 통제권은 곧 패치, 백업, 키, 정책, 용량, 업그레이드의 책임이다.

도입 판단은 세 가지 증거로 끝내는 것이 좋다. 테넌트 경계를 깨지 못하는 자동 보안 테스트, 정해진 시간 안에 완료한 독립 복원 훈련, staging에서 재현된 업그레이드와 rollback 기록이다. 이 증거가 없다면 관리형 비용은 단순한 프리미엄이 아니라 운영 위험을 이전하는 비용이다. 세 증거를 반복해서 만들 수 있을 때 셀프호스팅은 비용 절감 구호가 아니라 플랫폼 전략이 된다.

> 1차 자료: [Supabase 저장소와 README](https://github.com/supabase/supabase), [공식 Self-Hosting with Docker 문서](https://supabase.com/docs/guides/self-hosting/docker), [공식 Docker 구성](https://github.com/supabase/supabase/tree/master/docker), [Docker Compose 파일](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml), [self-hosted 변경 이력](https://github.com/supabase/supabase/blob/master/docker/CHANGELOG.md), [Apache-2.0 라이선스](https://github.com/supabase/supabase/blob/master/LICENSE). 저장소와 Trending 수치는 2026년 10월 22일 08시 KST 전후의 공개 스냅샷이다.
