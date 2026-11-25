---
title: "OLake Iceberg CDC: 데이터 복제 정확도·복구 검증 기준"
description: "OLake Go의 Postgres CDC와 Iceberg 쓰기 구조를 해부하고, 체크포인트·스키마 진화·카탈로그·보안·롤백을 도입 전에 검증하는 기준을 정리한다."
author: heracles-jo
date: 2026-11-26 08:05:00 +0900
categories: [Data Engineering, Database]
tags: [olake, apache-iceberg, change-data-capture, data-replication, lakehouse]
image:
  path: https://heracles-jo.github.io/assets/img/posts/olake-iceberg-cdc-replication/cover.svg
  alt: "OLake가 Postgres 변경 데이터를 Apache Iceberg 테이블로 복제하는 파이프라인과 검증 지점"
---

운영 데이터베이스를 분석 플랫폼으로 복제할 때 가장 위험한 실패는 파이프라인이 멈추는 것이 아니다. 대시보드는 계속 갱신되지만 일부 업데이트가 빠지고, 삭제된 고객이 분석 테이블에 남으며, 재시작 뒤 같은 주문이 두 번 집계되는 **조용한 불일치**가 더 비싸다. 처리량이 높은 CDC 도구라도 source WAL, 체크포인트, 객체 스토리지 파일, Iceberg snapshot, catalog commit이 하나의 복구 계약으로 연결되지 않으면 신뢰할 수 없다.

[datazip-inc/olake-go](https://github.com/datazip-inc/olake-go)는 PostgreSQL·MySQL·MongoDB·MSSQL 등의 full load와 CDC 데이터를 Apache Iceberg 또는 Parquet로 옮기는 Go 기반 데이터 수집 엔진이다. README는 별도 Spark·Flink·Kafka·Debezium 없이 경량 구성을 지향하며, Iceberg의 여러 catalog와 S3 계열 저장소를 지원한다고 설명한다. 이 방향은 매력적이지만, 운영 판단의 핵심은 컴포넌트 수가 아니라 **장애 후 source 변경 순서와 destination table 상태를 얼마나 정확히 재구성할 수 있는가**다.

2026년 11월 26일 08시 18분 KST 전후 GitHub Trending의 Go daily 목록에서 OLake Go는 `20 stars today`로 표시됐다. [GitHub 저장소 메타데이터](https://github.com/datazip-inc/olake-go) 확인 시점에는 **2,352 stars, 349 forks, 245 open issues**, Apache-2.0 라이선스였고 11월 25일까지 push가 이어졌다. 최신 정식 릴리스는 11월 20일의 `v1.2.2`다. 이 수치는 관심도와 활동을 보여 주는 시점별 스냅샷일 뿐 데이터 정확도나 운영 성숙도를 보증하지 않는다. Search Console·Analytics의 실제 검색어와 유입 데이터에는 이번 실행에서 접근하지 못했으므로 선정 근거로 사용하지 않았다.

## 후보 비교: 에이전트 스킬보다 데이터 정합성 질문이 덜 포화돼 있었다

오늘 global·weekly 상위권은 보안 스킬, 에이전트 개발 방법론, GUI용 CLI, 개인 에이전트, 디자인 시스템에 집중됐다. 저장소 이름만 다를 뿐 이 블로그가 이미 다룬 승인·격리·에이전트 스킬·디자인 검증 의도와 경쟁하는 후보가 많았다. OLake는 기존 글에서 직접 다루지 않은 **OLTP 변경을 열린 테이블 포맷으로 복제할 때의 정확도와 복구**라는 독립적인 운영 질문이 남았다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [OLake Go](https://github.com/datazip-inc/olake-go) | Go daily 20, API 2,352 stars, Apache-2.0, `v1.2.2` | CDC 체크포인트, Iceberg delete, schema evolution, catalog commit을 묶는 데이터 정합성 의도가 선명해 선택했다. |
| [Claude-BugHunter](https://github.com/elementalsouls/Claude-BugHunter) | daily 1,644, API 22,924 stars, MIT | 승인된 레드팀 자동화는 Security Audit Skill·Codex Security 글의 권한과 증거 검증 문제와 겹친다. |
| [CLI-Anything](https://github.com/HKUDS/CLI-Anything) | daily 1,094, API 65,642 stars, Apache-2.0 | GUI 기능을 agent-native CLI로 노출하는 중심 논지를 에이전트 네이티브 소프트웨어 글에서 이미 분석했다. |
| [Nod](https://github.com/n8n-io/nod) | weekly 1,011, API 3,558 stars, Apache-2.0 | 개인 에이전트의 승인·예약·소유자 데이터는 중요하지만 OpenBot·agent-desktop의 지속 권한과 실행 검증 의도에 인접한다. |
| [Astryx](https://github.com/meta/astryx) | weekly 2,890, API 33,108 stars, MIT | agent-ready 디자인 시스템은 DESIGN.md와 Modern Web Guidance 글의 토큰·접근성·에이전트 산출물 검증 의도와 경쟁한다. |

## 실제 파이프라인은 하나의 Go 바이너리로 끝나지 않는다

OLake의 source driver는 `spec`, `check`, `discover`, `sync` 명령을 공통 계약으로 사용한다. PostgreSQL 기준으로는 full refresh, 기존 데이터를 먼저 적재한 뒤 WAL 변경을 따라가는 CDC, 현재 WAL 위치부터 새 변경만 읽는 strict CDC, cursor 기반 incremental 모드를 제공한다. `discover` 결과에서 대상 stream, filter, chunk column, partition 규칙과 sync mode를 정하고, 완료된 batch나 sync 끝에서 state를 남긴다.

Iceberg destination은 현재 Go 코드가 Java writer process를 띄우고 gRPC로 record batch를 전달하는 구조다. 저장소 문서는 Go용 Iceberg 구현이 equality delete 쓰기를 지원하지 않아 Java를 사용하며, backfill은 append, CDC는 delete file을 만드는 upsert 방식으로 동작한다고 설명한다. 전송 batch는 실제 Parquet 크기가 아니라 메모리 객체 기준 최대 256MB로 기술돼 있다.

<img src="https://heracles-jo.github.io/assets/img/posts/olake-iceberg-cdc-replication/architecture.svg" alt="OLake의 source CDC, state, Go 처리 계층, Java Iceberg writer와 catalog commit 구조" width="1200" height="760" loading="lazy">
_OLake를 단일 프로세스로 보지 말고 source log, state artifact, Go driver, gRPC·Java writer, object storage와 catalog를 서로 다른 장애 도메인으로 나눠야 한다._

이 구조에서 관측해야 할 경계는 다섯 개다.

1. **source position**: PostgreSQL LSN, replication slot, publication과 WAL 보존 상태
2. **ingestion state**: stream별 chunk, cursor, resume token과 state format version
3. **writer process**: Go→gRPC 전달, Java process 생존, batch flush와 오류 전파
4. **table state**: data file, equality·position delete, schema와 partition spec
5. **catalog commit**: 새 Iceberg snapshot이 원자적으로 공개됐는지, query engine이 같은 snapshot을 보는지

[PostgreSQL을 durable execution 기반으로 사용할 때의 상태 경계](/posts/github-trending-postgres-durable-execution/)와 마찬가지로, DB 로그를 읽는 것 자체보다 그 위치가 외부 artifact의 commit과 어떻게 연결되는지가 중요하다. source offset만 전진하고 catalog commit이 실패하면 누락이 생길 수 있고, destination commit 뒤 state 저장이 실패하면 재시작 때 중복 적용 가능성을 검토해야 한다.

## `exactly once`는 제품 문구가 아니라 장애 행렬로 검증해야 한다

README는 exactly-once delivery를 장점으로 내세운다. 그러나 CDC에서 이 표현은 한 번도 재처리하지 않는다는 뜻이 아니다. 실무적으로는 재시도와 중복 입력이 있어도 최종 테이블 상태가 source의 논리적 상태와 같아지는지, 그리고 그 결과를 증명할 수 있는지가 중요하다.

최소한 다음 지점에 장애를 주입해야 한다.

| 장애 시점 | 재시작 뒤 확인할 증거 | 실패 판정 |
|---|---|---|
| WAL batch를 읽은 직후 | 저장된 LSN과 아직 commit되지 않은 record 범위 | state만 전진해 행이 누락됨 |
| data·delete file 업로드 중 | orphan file, multipart upload, 재시도된 file hash | 같은 논리 변경이 중복 반영되거나 쓰레기 파일이 누적됨 |
| Iceberg snapshot commit 직전·직후 | 이전·신규 snapshot ID, manifest, state 기록 순서 | commit됐지만 재처리하거나 commit 전인데 건너뜀 |
| Java writer 종료·gRPC 단절 | Go process가 실패를 성공으로 오인하지 않는지 | partial batch를 성공 처리하거나 writer가 고아 process로 남음 |
| state artifact 저장 실패 | 마지막 durable checkpoint와 destination snapshot 대응 | 임의의 최신 파일을 state로 사용해 복구 지점이 불명확함 |

비교 데이터셋은 단순 row count로 부족하다. primary key별 최신 값, 삭제 집합, 중복 key, null과 decimal, timestamp precision, large TOAST column, schema version을 source snapshot과 destination query 결과에서 대조해야 한다. 최근 `v1.2.0`이 PostgreSQL CDC 중 사용할 수 없던 TOAST column 해석과 decimal 지원을 추가한 사실은 타입·부분 row image가 실제 정합성 경계임을 보여 준다.

재현 테스트에는 고정된 transaction sequence가 유용하다. insert 1만 건, 일부 update, primary key 경계값, delete, 같은 transaction 안의 다중 table 변경, DDL, 장문·JSON·decimal·timestamp 데이터를 순서대로 적용한다. 각 단계에서 source transaction ID·LSN, OLake state, Iceberg snapshot ID를 한 행으로 묶은 검증 ledger를 만들면 “최종 건수는 같다”보다 훨씬 빨리 차이를 찾을 수 있다.

## state는 작은 JSON이지만 사실상 복구 프로토콜이다

Postgres driver 문서는 batch 완료나 sync 종료 때 state file을 생성하고, 재실행 시 `--state`로 checkpoint를 넘길 수 있다고 설명한다. 예시에는 global LSN과 대상 stream, stream별 chunk 상태가 들어간다. 이 파일을 임시 출력물로 취급하면 안 된다. 데이터 복제의 RPO를 결정하는 핵심 artifact이기 때문이다.

`v1.2.2` 릴리스는 MongoDB resume token 지원과 함께 **한 번 해당 버전으로 CDC를 실행하면 state와 destination metadata가 새 형식으로 바뀌므로 v1.2.1 이하로 downgrade할 수 없다**고 명시한다. 즉 binary rollback과 data-plane rollback이 분리된다. 배포가 실패했을 때 이전 container image를 다시 띄우는 일반적인 절차가 state migration 뒤에는 안전하지 않을 수 있다.

업그레이드 전에는 다음을 함께 보존해야 한다.

- 실행 binary·container digest와 connector version
- source config·catalog·stream selection의 비밀 제거 사본
- state file 원본과 schema version
- 마지막 성공 Iceberg snapshot ID와 catalog metadata 위치
- destination table의 schema·partition spec·identifier field
- downgrade 가능 여부와 지원되는 복구 경로

[DrawDB로 데이터베이스 스키마 변경을 검토하는 기준](/posts/github-trending-drawdb-database-schema-design-governance/)에서 migration 문법보다 도메인 관계와 운영 위험을 함께 봐야 했듯, CDC schema evolution도 column 추가 성공만 확인해서는 부족하다. rename을 drop+add로 해석하는지, type widening·narrowing을 어떻게 처리하는지, primary key 변경과 nullable 전환이 delete semantics에 어떤 영향을 주는지 시험해야 한다.

## Iceberg의 열린 형식도 table maintenance 책임을 없애지 않는다

OLake는 Glue, Hive, JDBC, REST catalog와 여러 객체 스토리지를 지원한다. 열린 catalog와 table format을 사용하면 query engine 선택권은 커지지만, 작은 data file과 delete file, orphan file, snapshot retention, manifest 증가, compaction은 운영자의 책임으로 남는다. OLake가 table maintenance를 별도 `olake-fusion` 프로젝트로 분리한 것도 ingestion과 maintenance가 다른 수명주기를 가진다는 신호다.

CDC가 빈번한 table에서는 equality delete가 누적될수록 읽기 비용이 커질 수 있다. 반대로 너무 자주 rewrite하면 객체 스토리지 요청, catalog commit 충돌, compaction 중 읽기 변동과 비용이 늘어난다. 따라서 ingestion throughput만 측정하지 말고 아래 지표를 같이 봐야 한다.

- source commit부터 query engine 가시성까지의 p50·p95 freshness lag
- snapshot당 data file·delete file 수와 평균 크기
- scan bytes 대비 실제 반환 bytes, delete 적용 비용
- catalog commit latency와 충돌·재시도율
- compaction 전후 쿼리 시간과 객체 스토리지 요청량
- orphan file·만료 snapshot 정리 시간과 복구 가능 기간

[LZ4와 Zstd를 선택할 때 codec 단독 속도보다 실제 Parquet·Kafka 경로를 측정해야 한다는 기준](/posts/lz4-compression-selection/)도 그대로 적용된다. OLake README의 처리량 수치는 프로젝트가 공개한 특정 benchmark 환경의 값이다. source disk, WAL 설정, network, row width, key 분포, object storage, catalog와 partition 수가 다른 조직에서는 full load RPS보다 end-to-end freshness와 query cost가 더 중요한 기준이 될 수 있다.

## 보안 경계는 DB 계정에서 catalog·state·UI까지 이어진다

복제 서비스는 source의 광범위한 읽기 권한, replication slot, destination bucket write, catalog commit 권한을 동시에 가진다. 침해되면 운영 DB를 읽고 분석 table을 변조할 수 있으므로 일반 ETL worker보다 blast radius가 크다.

공개 issue에는 SSH tunnel이 host key를 검증하지 않는 문제, source·destination config의 secret masking 필요, malformed JSONL에서 parser가 무한 대기할 수 있는 문제, 실패한 Iceberg check 뒤 Java writer가 남는 문제가 열려 있었다. 열린 issue는 확정된 모든 배포의 취약점 목록은 아니지만, 현재 도입자가 직접 확인해야 할 구체적인 실패 모드다.

운영 환경에서는 다음 통제를 기본값으로 두는 편이 안전하다.

- source 계정은 필요한 schema와 replication 권한만 부여하고 DDL·write 권한을 제거한다.
- SSH host key를 pin하고 중간자 공격을 허용하는 fallback을 금지한다.
- S3·catalog credential은 job별·환경별로 분리하고 짧은 수명 또는 workload identity를 사용한다.
- state·config·log에서 password, token, private key와 connection string을 비밀 스캔한다.
- OLake UI의 기본 `admin`/`password` 자격증명을 시작 전에 폐기하고 외부 노출을 막는다.
- Java child process, memory·disk, gRPC port와 object storage egress를 제한한다.

자격증명 수명과 복구를 별도 시스템으로 관리하려면 [OpenBao 시크릿 관리 전환 기준](/posts/openbao-secrets-management-migration/)처럼 발급·회전·폐기와 감사 경로를 함께 설계해야 한다. config 파일에서 문자열을 가리는 것만으로는 이미 복제된 로그, state backup, CI artifact와 container 환경 변수의 노출을 해결하지 못한다.

<img src="https://heracles-jo.github.io/assets/img/posts/olake-iceberg-cdc-replication/verification-workflow.svg" alt="OLake CDC 파이프라인을 관찰·대조·장애 주입·업그레이드·승격 단계로 검증하는 의사결정 흐름" width="1200" height="760" loading="lazy">
_처리량 데모에서 바로 운영으로 가지 말고, source와 Iceberg 상태 대조·장애 주입·state migration·table maintenance를 통과한 stream만 단계적으로 승격한다._

## PoC는 빠른 적재보다 불일치를 얼마나 빨리 발견하는지 본다

2~3주 PoC는 대표 table 3~5개로 제한한다. 하나는 append 중심 event table, 하나는 update·delete가 많은 업무 table, 하나는 wide JSON·decimal·timestamp를 가진 table로 구성한다. 첫 주에는 full load와 CDC 결과를 source query와 매 batch 대조하고, 둘째 주에는 process kill, network timeout, catalog 장애, credential revoke, schema 변경을 주입한다. 마지막에만 version upgrade와 state 복구를 시험한다.

| 검증 축 | 최소 측정값 | 중단 조건 |
|---|---|---|
| 정합성 | key별 값·삭제·중복·null·decimal·timestamp 대조 | row count는 같지만 값이나 삭제 집합이 다름 |
| 체크포인트 | LSN·state version·snapshot ID correlation | state와 destination commit 순서를 설명할 수 없음 |
| 복구 | process·network·catalog 장애 후 RPO/RTO, 재처리 범위 | 수동으로 임의 LSN을 골라야만 복구 가능 |
| schema evolution | add·rename·type·nullability·key 변경 결과 | 무손실이라고 보고했지만 query 결과가 조용히 변형됨 |
| 성능·비용 | freshness lag, CPU·memory, file 수, scan bytes, compaction | ingestion은 빠르지만 delete·small file로 쿼리 비용이 계속 증가 |
| 보안 | 최소 권한, host key, secret masking, UI·gRPC 노출 | source write나 bucket 전체 삭제 권한이 필요하거나 secret이 로그에 남음 |
| 업그레이드 | state migration, mixed version, rollback·restore rehearsal | release note의 비가역 변경을 배포 뒤에 발견함 |

downstream 의미 계층도 별도 검증 대상이다. CDC가 정확해도 `revenue`, `active_user`, `cancelled_order`의 정의가 팀마다 다르면 분석 결과는 일치하지 않는다. [Apache Ossie의 시맨틱 계층 표준화](/posts/apache-ossie-semantic-model-interchange/)처럼 ingestion의 물리적 정확성과 BI·AI가 소비하는 지표 의미를 다른 계약으로 관리해야 한다.

OLake의 장점은 source driver와 Iceberg·Parquet writer를 하나의 비교적 가벼운 실행 경로로 제공하고, 열린 catalog와 query engine 생태계로 연결한다는 데 있다. 반면 Go와 Java writer의 이중 런타임, state format migration, equality delete와 table maintenance, catalog·object storage의 복구 책임은 사라지지 않는다.

도입 기준은 “Fivetran보다 몇 배 빠른가”가 아니다. **source transaction, durable state, Iceberg snapshot을 같은 증거 사슬로 연결할 수 있는가. 장애 뒤 누락·중복·삭제 불일치를 자동으로 탐지할 수 있는가. binary와 state가 함께 바뀌는 업그레이드에서 실제 rollback·restore 경로를 연습했는가.** 이 세 질문에 실행 결과로 답할 수 있을 때 OLake는 빠른 데모용 복제기가 아니라 운영 가능한 lakehouse ingestion 계층이 된다.

## 1차 자료

- [OLake Go 저장소와 README](https://github.com/datazip-inc/olake-go)
- [PostgreSQL driver 문서](https://github.com/datazip-inc/olake-go/blob/master/drivers/postgres/README.md)
- [Iceberg writer 구조와 catalog 설정](https://github.com/datazip-inc/olake-go/blob/master/destination/iceberg/README.md)
- [`v1.2.2` 릴리스와 downgrade 경고](https://github.com/datazip-inc/olake-go/releases/tag/v1.2.2)
- [`v1.2.0` 릴리스](https://github.com/datazip-inc/olake-go/releases/tag/v1.2.0), [`v1.1.0` 릴리스](https://github.com/datazip-inc/olake-go/releases/tag/v1.1.0)
- [최근 commits](https://github.com/datazip-inc/olake-go/commits/master/), [공개 issues와 pull requests](https://github.com/datazip-inc/olake-go/issues)
- [Apache-2.0 LICENCE](https://github.com/datazip-inc/olake-go/blob/master/LICENCE)

Trending·저장소 수치는 2026년 11월 26일 08시 18분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
