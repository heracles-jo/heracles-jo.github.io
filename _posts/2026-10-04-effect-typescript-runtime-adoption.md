---
title: "Effect TypeScript 도입: 예외·동시성·의존성 관리 기준"
description: "Effect 4의 타입 오류 채널·Fiber·Scope·Layer를 Promise 기반 TypeScript와 비교하고, 전면 재작성 없이 프로덕션에 도입할 경계와 PoC 측정 기준을 정리한다."
author: heracles-jo
date: 2026-10-04 08:28:00 +0900
categories: [Developer Tools, Software Engineering]
tags: [effect-ts, typescript, error-handling, structured-concurrency, dependency-injection, observability]
image:
  path: https://heracles-jo.github.io/assets/img/posts/effect-typescript-runtime-adoption/cover.svg
  alt: "Effect가 TypeScript 애플리케이션의 오류, 동시성, 자원과 의존성을 하나의 실행 모델로 묶는 구조"
---

TypeScript 서비스가 커지면 타입보다 실행 흐름이 먼저 무너지기 쉽다. 함수 반환형은 정확해도 `Promise` rejection에 어떤 오류가 들어오는지 알기 어렵고, `Promise.all`로 시작한 작업은 한 갈래가 실패했을 때 나머지를 어떻게 취소할지 애매하다. 데이터베이스 연결과 파일 handle은 `try/finally`가 흩어진 곳마다 누수 가능성을 만들며, 의존성 주입 container와 retry library, queue, logger, tracing SDK는 서로 다른 생명주기 규칙을 가진다.

[Effect-TS/effect](https://github.com/Effect-TS/effect)는 이 문제를 개별 utility가 아니라 하나의 TypeScript 실행 모델로 다룬다. `Effect<Success, Error, Requirements>` 타입에 성공 값, 예상 가능한 오류, 필요한 service를 함께 표현하고, Fiber로 동시 작업을 실행하며, Scope와 finalizer로 자원 수명을 묶는다. Layer는 service construction graph를 만들고 tracing·metrics·logging은 Effect 실행 문맥과 연결한다. 핵심 질문은 “함수형 프로그래밍을 도입할 것인가”가 아니다. **현재 코드에서 암묵적인 실패·취소·자원·의존성 계약을 명시적으로 만들었을 때 운영 복잡도가 실제로 줄어드는가**다.

2026년 10월 4일 08시 36분 KST 전후 GitHub Trending에서 Effect는 daily **302 stars today**, weekly **466 stars this week**로 표시됐다. GitHub API 기준 저장소는 16,806 stars, 813 forks, 열린 이슈와 PR을 합친 313개였고 MIT 라이선스를 명시했다. `effect@4.0.0`은 10월 1일 공개됐으며 README는 4.x를 LTS로 설명한다. 10월 4일 KST 아침까지 HTTP range 검증, MSSQL connection recovery, Stream rate 제한, tracing context 관련 수정이 main에 반영됐다. 수치와 활동은 확인 시점의 공개 스냅샷이며 프레임워크의 적합성이나 안정성을 보증하지 않는다. 이번 실행 환경에서는 Search Console과 Analytics의 실제 검색어·노출·CTR 데이터에 접근할 수 없어 선정 근거로 사용하지 않았다.

## 후보 비교에서 남은 질문은 TypeScript 실행 계약이었다

오늘 daily·weekly 목록은 에이전트 skill, context 절감, 웹 수집 도구에 크게 치우쳤다. 기존 121개 글의 제목·description·저장소 링크와 중심 논지를 대조하면 이 후보들은 최근 에이전트 운영 클러스터와 직접 경쟁했다. Effect는 TypeScript라는 기존 주제와 접점이 있지만, [SWC 글](/posts/github-trending-swc-rust-web-toolchain/)이 빌드 변환을, [scriptc 글](/posts/scriptc-typescript-native-compiler/)이 네이티브 artifact를 다뤘다면 이번 검색 의도는 **서비스가 실행 중 실패하고 취소되며 자원을 정리하는 규칙을 어떻게 설계할 것인가**다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Effect-TS/effect](https://github.com/Effect-TS/effect) | daily 302·weekly 466, 16,806 stars, MIT, Effect 4.0.0 | 타입 오류·구조적 동시성·자원 수명·의존성 graph를 하나의 runtime 계약으로 묶는 독립 질문이 있어 선택했다. |
| [Panniantong/Agent-Reach](https://github.com/Panniantong/Agent-Reach) | daily 1,683·weekly 3,959, 89,773 stars, MIT | 에이전트 웹 수집은 기존 scraping·OSINT·Agent-Reach 후보 검토와 반복되고 플랫폼 약관·credential 경계가 크다. |
| [cloudflare/cloudflare-os](https://github.com/cloudflare/cloudflare-os) | daily 84, 10,558 stars, Apache-2.0 | 기업 문맥을 쓰는 agent workspace는 Google AX·DeerFlow·에이전트 실행 환경 글과 독자 문제가 가깝다. |
| [getsentry/sentry](https://github.com/getsentry/sentry) | daily 211, 45,201 stars, 라이선스 API `NOASSERTION` | 오류·성능 관측성은 장기 가치가 크지만 PostHog 통합 관측성 글과 겹치며 fair-source 배포 경계를 별도 검토해야 한다. |
| [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) | daily 505, 109,521 stars, Apache-2.0 | 토큰 절감 proxy는 context 최적화·에이전트 skill 클러스터와 경쟁하고, 65% 절감 주장을 일반화하려면 workload 실측이 필요하다. |

Effect를 고른 직접 계기는 Trending 순위보다 4.0 전환이었다. 공식 migration guide에 따르면 core programming model은 유지되지만 패키지 version을 통일하고 platform·RPC·cluster·workflow 등 여러 기능을 `effect` package로 합쳤다. 동시에 `ai`, `http`, `rpc`, `sql`, `workflow`, `observability` 같은 module은 import 경로가 단순해져도 `unstable` 상태를 유지한다. 즉 진입 표면은 넓어졌지만 안정성 등급을 읽지 않으면 minor update가 예상보다 큰 변경을 가져올 수 있다.

## `Effect<A, E, R>`는 반환형보다 운영 계약에 가깝다

일반적인 `Promise<User>`는 성공 값만 설명한다. 함수가 404, timeout, validation, 권한 오류 중 무엇으로 실패하는지, 실행에 database나 logger가 필요한지 타입에서 알기 어렵다. Effect의 세 type parameter는 이를 분리한다.

- `A`: 성공했을 때 얻는 값
- `E`: 호출자가 예상하고 복구할 수 있는 오류
- `R`: 실행에 제공돼야 하는 service 요구사항

예상 오류와 defect를 나누는 것이 첫 번째 변화다. 공식 문서는 domain flow에 포함되는 failure를 error channel에 추적하고, programmer bug나 불변식 위반 같은 unexpected error는 defect로 별도 보존한다. 모든 `throw`를 union type으로 옮기는 것이 아니라 **호출자가 retry·fallback·사용자 응답으로 처리할 수 있는 실패만 모델링하는 것**이 중요하다.

예를 들어 결제 승인 실패, 재고 부족, 외부 API rate limit은 예상 오류가 될 수 있다. 반면 `undefined` 접근이나 잘못된 SQL mapper처럼 정상 흐름에서 일어나면 안 되는 문제까지 업무 오류로 포장하면 오히려 장애를 숨긴다. Error taxonomy가 정리되지 않은 팀이 Effect 문법부터 적용하면 `UnknownError`, `Error`, 거대한 union만 늘고 복구 정책은 여전히 암묵적이다.

![Effect 타입 계약이 Layer·Fiber·Scope를 거쳐 runtime과 관측성으로 이어지는 구조](https://heracles-jo.github.io/assets/img/posts/effect-typescript-runtime-adoption/architecture.svg)

이 모델의 가치는 compiler가 모든 운영 문제를 해결해서가 아니다. API 경계에서 `E`와 `R`이 바뀌면 review diff에 드러나고, retry 가능한 실패와 즉시 중단해야 할 defect를 다른 경로로 보낼 수 있기 때문이다. 반대로 Effect를 library 내부에만 숨겨 외부에서는 무조건 `Promise<any>`로 바꾸면 가장 중요한 계약 정보가 adapter에서 사라진다.

## Fiber의 장점은 병렬 실행보다 취소와 수명이다

JavaScript에는 event loop와 Promise가 이미 있다. 따라서 Effect Fiber를 “더 빠른 thread”로 이해하면 판단을 잘못한다. Fiber는 경량 실행 단위이면서 parent-child 수명, interruption, 결과 합성, concurrency limit을 표현하는 도구다. 공식 concurrency 문서는 기본 순차 실행, 숫자로 제한한 병렬성, `unbounded`, 주변 설정을 따르는 `inherit`를 구분한다.

이 차이는 fan-out 호출에서 드러난다. 사용자 1명의 화면을 만들기 위해 profile, permission, recommendation, billing API를 동시에 부를 때 무제한 `Promise.all`은 구현이 짧지만 다음 질문을 남긴다.

1. 한 요청이 timeout되면 아직 진행 중인 다른 요청을 중단하는가.
2. HTTP client가 실제 `AbortSignal`을 받아 interruption을 전달하는가.
3. 1,000개 item을 처리할 때 동시성 상한은 어디서 결정되는가.
4. 실패 원인이 여러 개면 어떤 cause를 보존하는가.
5. parent request가 끝난 뒤 orphan 작업이 남지 않는가.

Effect를 써도 adapter가 cancellation을 무시하면 network·database 작업은 계속될 수 있다. Fiber가 interrupted됐다는 runtime 상태와 외부 부작용이 중단됐다는 사실을 같게 보면 안 된다. HTTP, SQL, queue, child process adapter마다 취소 전달과 idempotency를 검증해야 한다.

동시성 기본값도 주의한다. API마다 sequential, inherited, unbounded 의미가 다를 수 있고 `unbounded`는 편리한 최적화가 아니라 부하 정책이다. PoC에서는 처리량만 보지 말고 upstream connection 수, queue depth, memory high-water mark, cancellation latency와 timeout 후 남은 작업 수를 함께 측정해야 한다.

## Scope는 `try/finally`를 없애는 대신 수명 경계를 제품화한다

데이터베이스 connection, file handle, lock, temporary directory, telemetry exporter는 성공·실패·취소 어느 경로에서도 정리돼야 한다. Effect의 Scope는 자원 lifetime을 나타내며 scope가 닫힐 때 finalizer를 역순으로 실행한다. `acquireUseRelease`, `Effect.scoped`, `Effect.addFinalizer` 같은 API는 acquisition과 cleanup을 같은 구성 단위에 둔다.

이 구조는 중첩 자원에 특히 유리하다. TLS connection 위에 stream을 열었다면 stream이 connection보다 먼저 닫혀야 한다. 수동 `finally`가 여러 함수에 흩어지면 release 순서와 누락을 review하기 어렵지만 scope graph에서는 획득 순서와 종료 경계를 한곳에서 볼 수 있다.

그러나 finalizer가 등록됐다는 사실만으로 안전하지는 않다.

- cleanup이 영원히 기다리면 graceful shutdown이 멈춘다.
- release 자체가 실패했을 때 원래 업무 오류와 어떻게 함께 보존할지 정해야 한다.
- interruption 불가능한 cleanup 구간이 길면 종료 시간이 늘어난다.
- 외부 API의 이미 발생한 부작용은 local resource finalizer로 되돌릴 수 없다.
- shared Layer resource의 scope를 request 단위로 닫으면 connection pool이 반복 생성될 수 있다.

따라서 scope 설계는 함수 문법 문제가 아니라 ownership 문제다. Process, application, worker, request, transaction 중 누가 자원을 만들고 언제 닫는지 먼저 정해야 한다. [pg_durable의 durable execution 글](/posts/github-trending-postgres-durable-execution/)에서 작업 상태와 부작용 경계를 분리했듯, Effect Scope도 process 내부 자원 수명은 관리하지만 외부 workflow의 exactly-once를 자동으로 제공하지 않는다.

## Layer는 DI container보다 construction graph에 가깝다

Effect의 service와 Layer를 NestJS나 Inversify의 decorator 기반 DI와 같은 기능으로만 보면 절반만 보게 된다. Service interface는 실제 작업에서 다른 dependency를 노출하지 않도록 단순하게 유지하고, Layer가 config·logger·database 같은 construction dependency를 조합한다. `Layer<RequirementsOut, Error, RequirementsIn>`에는 무엇을 만들고, 생성 중 어떤 오류가 나며, 무엇이 필요한지가 들어간다.

장점은 production과 test graph를 같은 type system에서 교체할 수 있다는 점이다. Database service가 query마다 Config와 Logger를 요구하지 않고, `DatabaseLive`를 만들 때만 그 dependency를 제공하면 unit test는 `DatabaseTest`만 넣을 수 있다. Startup failure도 Layer error로 다뤄 config 누락, migration 실패, credential 문제를 request 처리 전에 분리할 수 있다.

실패 모드는 memoization과 scope에서 생긴다. 같은 Layer definition을 여러 번 제공했을 때 service가 한 번 생성되는지, request마다 새로 만들어지는지, test isolation을 위해 cache를 끊어야 하는지 이해하지 못하면 connection pool과 background Fiber가 중복된다. Graph가 커질수록 type error도 길어지고 팀원이 construction path를 찾기 어려워질 수 있다. Layer diagram, naming convention, application composition root를 정하지 않으면 기존 DI container보다 더 추상적인 wiring이 된다.

## 관측성은 자동이 아니라 실행 문맥을 잃지 않는 능력이다

Effect는 logging, metrics, tracing API와 OpenTelemetry integration을 제공한다. `Effect.withSpan`으로 span을 붙여도 `Effect<A, E, R>` type은 바뀌지 않고, Layer로 exporter를 production과 test 환경에 제공할 수 있다. Fiber와 structured execution을 사용하면 parent-child span과 interruption cause를 같은 실행 문맥에 연결할 여지가 생긴다.

하지만 SDK를 설치했다고 관측성이 완성되지는 않는다. Span name과 attribute cardinality, error cause 변환, retry attempt, queue wait, concurrency permit, finalizer duration을 어떤 규칙으로 기록할지 정해야 한다. `@effect/opentelemetry`처럼 third-party type을 노출하는 integration은 v4 migration guide에서 unstable 범주로 설명되므로 minor upgrade도 adapter contract를 검증해야 한다.

[PostHog 통합 관측성 글](/posts/posthog-unified-product-observability/)에서 도구 수보다 공통 식별자와 데이터 경계를 먼저 봤듯, Effect도 trace를 많이 만드는 것이 목적이 아니다. 기존 request ID, release SHA, tenant, sampling policy와 연결되고, expected failure와 defect, interruption이 운영 화면에서 구분돼야 한다. Otherwise 모든 실패가 같은 빨간 span으로 보이면 type-level 구분이 production diagnosis까지 이어지지 않는다.

## Effect 4 전환은 package 정리보다 안정성 지도를 먼저 본다

Effect 4는 모든 ecosystem package의 version을 동기화하고 platform·RPC·cluster·workflow 등 많은 module을 core `effect` 아래로 합쳤다. 호환 version을 찾는 부담은 줄지만 upgrade blast radius는 넓어질 수 있다. 공식 README는 TypeScript 5.9 이상, strict mode, Node.js 18 이상을 일반 요구사항으로 두며 일부 integration은 더 새 runtime을 요구한다.

Migration에서 특히 확인할 항목은 다음과 같다.

- `effect`와 `@effect/*` package version을 정확히 맞추는가.
- `effect/unstable/...` import path를 옮긴 뒤 해당 API가 여전히 unstable임을 추적하는가.
- Context, Cause, FiberRef, Scope와 forking API 변경이 error·lifecycle 의미를 바꾸지 않는가.
- v3와 v4를 동시에 쓰는 transitive dependency가 bundle과 runtime identity를 갈라놓지 않는가.
- TypeScript compiler와 language service 성능이 대형 codebase에서 수용 가능한가.
- tree-shaking 결과와 source map, test runner, ESM/CJS boundary가 기존 build와 같은가.

공식 README는 4.x에 최소 3년 지원과 후속 major 이후 bug·security fix 기간을 명시하지만 stable API와 unstable·experimental API의 보증 범위는 다르다. “LTS”라는 label 하나로 모든 module을 같은 위험도로 승인하면 안 된다.

## 전면 재작성보다 한 개의 실패 많은 경계에서 시작한다

Effect는 전파성이 강하다. 한 함수가 `Effect`를 반환하면 caller도 error와 requirement를 다루게 되고, service·Layer·Scope가 application composition까지 이어진다. 이 특성 때문에 작은 library처럼 넣었다가 경계가 애매해지거나, 반대로 전사 표준으로 선언해 대규모 rewrite를 시작하기 쉽다. 둘 다 피하는 편이 좋다.

첫 PoC는 외부 I/O가 있고 retry·timeout·resource cleanup이 실제로 필요한 bounded workflow 하나가 적합하다. 예를 들면 webhook 처리, 세 개 API를 조합하는 backend-for-frontend endpoint, 파일 import worker다. 핵심 domain 전체나 UI state를 첫 대상으로 잡지 않는다.

![Effect 도입을 확대하거나 경계에 머물게 하는 2주 PoC 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/effect-typescript-runtime-adoption/decision.svg)

| 검증 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 오류 모델 | expected error 분류율, defect 누락, HTTP·queue mapping | 오류 union만 커지고 caller의 복구 결정은 더 불명확함 |
| 취소·동시성 | timeout 후 잔여 작업, 취소 전달 시간, peak in-flight, upstream 부하 | Fiber interruption 뒤에도 I/O와 부작용이 계속되거나 부하가 증가함 |
| 자원 수명 | connection·handle 누수, finalizer 시간·실패, shutdown p95 | 정상·오류·취소 경로 중 하나에서 누수 또는 종료 정체가 재현됨 |
| 의존성 graph | Layer startup 시간, 중복 instance, test setup line 수 | composition이 기존 DI보다 이해하기 어렵고 shared resource가 중복 생성됨 |
| 관측성 | trace 연결률, expected/defect/interruption 구분, attribute cardinality | 오류 원인이 더 풍부해지지 않거나 telemetry 비용만 증가함 |
| 개발 경험 | typecheck·IDE 지연, stack trace 이해 시간, 신규 작업 lead time | 핵심 reviewer 몇 명만 코드를 수정할 수 있고 feedback loop가 느려짐 |
| 업그레이드 | stable·unstable import inventory, v4 patch 회귀, rollback | minor update 영향 범위를 자동 검출하지 못하거나 package version이 갈림 |

기준선은 현재 Promise·DI 구현으로 남겨 같은 장애 시나리오를 비교한다. Upstream timeout, partial failure, process shutdown, connection acquisition 실패, finalizer 실패를 의도적으로 주입한다. 성공률과 latency뿐 아니라 코드 review에서 error·dependency·lifetime 변화가 얼마나 잘 보이는지, on-call이 cause tree와 span을 읽는 데 얼마나 걸리는지도 기록한다.

도입을 확대하기 좋은 팀은 TypeScript backend와 worker가 많고, 복잡한 비동기 흐름·재시도·자원 누수·DI wiring이 반복 문제이며, strict typing과 공통 runtime convention에 투자할 수 있는 조직이다. 반대로 CRUD가 단순하고 framework의 request lifecycle과 DI로 충분하며, 팀 교체가 잦고 함수형 abstraction 경험이 거의 없다면 작은 adapter나 기존 표준 library가 총비용이 낮을 수 있다.

Effect의 장기 가치는 `Promise`를 다른 문법으로 감싸는 데 있지 않다. 성공 값만 타입으로 적던 TypeScript 코드에 **실패 종류, 필요한 service, 자원 수명, 취소와 병렬성, 관측 문맥을 함께 설계하도록 압력을 주는 것**에 있다. 그 압력이 현재 장애를 줄이고 review 가능성을 높인다면 runtime 표준이 될 수 있다. 반대로 팀이 error taxonomy와 ownership을 정하지 않은 채 API만 옮기면 더 정교한 타입 아래에 같은 운영 혼란이 남는다.

> 1차 자료: [Effect 저장소와 README](https://github.com/Effect-TS/effect), [MIT LICENSE](https://github.com/Effect-TS/effect/blob/main/LICENSE), [Effect 4 migration guide](https://github.com/Effect-TS/effect/blob/main/MIGRATION.md), [Error Management](https://effect.website/docs/error-management/two-error-types/), [Managing Layers](https://effect.website/docs/requirements-management/layers/), [Resource Management](https://effect.website/docs/resource-management/introduction/), [Scope](https://effect.website/docs/resource-management/scope/), [Concurrency](https://effect.website/docs/concurrency/basic-concurrency/), [Tracing](https://effect.website/docs/observability/tracing/), [`effect@4.0.0` release](https://github.com/Effect-TS/effect/releases/tag/effect%404.0.0), [최근 commits](https://github.com/Effect-TS/effect/commits/main/), [공개 issues](https://github.com/Effect-TS/effect/issues), [공개 pull requests](https://github.com/Effect-TS/effect/pulls). Trending·저장소 수치는 2026년 10월 4일 08시 36분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
