---
title: "drawDB와 데이터베이스 스키마 설계 거버넌스: 브라우저 ERD 도구가 다시 주목받는 이유"
description: "GitHub Trending에 오른 drawdb-io/drawdb를 중심으로 브라우저 기반 ERD 편집, SQL import/export, 스키마 리뷰, 마이그레이션 거버넌스, 보안·운영 리스크를 실무 의사결정 관점에서 분석한다."
author: heracles-jo
date: 2026-08-13 07:24:00 +0900
categories: [Data Engineering, Database]
tags: [github-trending, drawdb, erd, database-design, schema-design, sql, migration, data-governance, chartdb, azimutt, schemaspy]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-drawdb-database-schema-design-governance/cover.svg
  alt: "drawDB가 브라우저 ERD 편집과 SQL 생성으로 데이터베이스 스키마 설계 거버넌스를 앞당기는 흐름"
---

GitHub Trending daily와 weekly를 확인하다 보면 AI 에이전트, 로컬 개발 도구, 문서 처리 파이프라인처럼 최근 반복적으로 부상하는 주제 사이에서 다소 전통적으로 보이는 저장소가 눈에 띌 때가 있다. 2026년 8월 13일 07:30 KST 전후 확인한 공개 스냅샷 기준으로 [drawdb-io/drawdb](https://github.com/drawdb-io/drawdb)는 weekly Trending에 올라 있었고, GitHub API 기준 약 **38.9k stars**, **3.1k forks**, **224 open issues**, JavaScript 중심 코드베이스, **AGPL-3.0** 라이선스, 2026년 8월 12일 최신 커밋 활동을 보였다. 같은 시점 daily 후보에는 [cloudflare/computer](https://github.com/cloudflare/computer), [semantica-agi/semantica](https://github.com/semantica-agi/semantica), [macro-inc/macro](https://github.com/macro-inc/macro), [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) 등이 있었고, weekly 후보에는 [chartdb/chartdb](https://github.com/chartdb/chartdb), `google/skills`, `vitali87/code-graph-rag` 같은 프로젝트도 함께 보였다. 이 글의 수치와 순위는 확인 시점의 스냅샷이며, GitHub Trending과 저장소 지표는 실시간으로 바뀐다.

오늘의 기술 흐름을 한 문장으로 정리하면 이렇다. **데이터베이스 스키마 설계는 더 이상 DBA나 백엔드 개발자 몇 명의 로컬 산출물이 아니라, 제품·데이터·보안·플랫폼 팀이 함께 검토해야 하는 운영 거버넌스 자산으로 이동하고 있다.** drawDB가 흥미로운 이유는 “예쁜 ERD를 그리는 무료 웹앱”이어서가 아니다. README는 drawDB를 브라우저에서 동작하는 데이터베이스 ERD 편집기이자 SQL import/export, migration 생성, 커스터마이징을 지원하는 도구로 설명한다. 코드 구조를 보면 React, Vite, Monaco Editor, Dexie, `node-sql-parser`, `@dbml/core`, Dagre 기반 자동 배치, MySQL·PostgreSQL·SQLite·MariaDB·MSSQL·Oracle SQL 처리 코드가 함께 보인다. 즉 drawDB는 데이터 모델을 사람이 이해하는 그림과 기계가 실행하는 SQL 사이에서 왕복시키려는 도구다.

![브라우저 ERD 기반 스키마 설계 워크플로](https://heracles-jo.github.io/assets/img/posts/github-trending-drawdb-database-schema-design-governance/workflow.svg)

## 오늘의 GitHub Trending 후보와 선택 이유

최근 글에서 에이전트 네이티브 소프트웨어, 스킬·CLI·로컬 AI, 문서 인입 라우팅, 셀프호스팅 협업, 운영형 AI 기상 데이터, 프로젝트 관리 도구 등을 이미 다뤘기 때문에 이번에는 같은 AI 에이전트 각도를 피했다. 후보를 비교하면 다음과 같다.

| 후보 저장소 | 확인 시점 신호 | 주목할 점 | 이번 글의 판단 |
|---|---:|---|---|
| [drawdb-io/drawdb](https://github.com/drawdb-io/drawdb) | 약 38.9k stars, 3.1k forks, 최근 커밋 | 브라우저 ERD, SQL import/export, 여러 DB 방언, optional server | 오늘의 핵심 주제로 선택 |
| [cloudflare/computer](https://github.com/cloudflare/computer) | 약 7.8k stars, MIT, preview 명시 | Durable Object 기반 가상 파일시스템과 실행 백엔드 | 흥미롭지만 최근 서버리스/에이전트 런타임 글과 일부 중복 |
| [semantica-agi/semantica](https://github.com/semantica-agi/semantica) | 약 5.6k stars, MIT, Python | accountable AI를 위한 그래프 네이티브 컨텍스트 인프라 | AI 거버넌스 주제로 적합하나 최근 AI 인프라 글과 가까움 |
| [chartdb/chartdb](https://github.com/chartdb/chartdb) | 약 22.7k stars, AGPL-3.0, v1.20.1 릴리스 | 단일 쿼리 기반 DB 다이어그램 생성 | drawDB와 함께 비교 대상으로 활용 |
| [azimuttapp/azimutt](https://github.com/azimuttapp/azimutt) | 약 2.1k stars, MIT | DB 탐색·문서화·최적화 지향 | 복잡한 기존 DB 탐색 비교 대상으로 활용 |

선택 기준은 단순 인기보다 “지금 조직에서 실제로 부딪히는 의사결정 문제를 설명할 수 있는가”였다. 많은 팀이 마이크로서비스, SaaS 연동, 이벤트 기반 아키텍처, 분석 파이프라인을 운영하면서 스키마 변경의 영향 범위를 빠르게 파악하지 못한다. ORM 모델은 애플리케이션 관점이고, migration 파일은 변경 이력 관점이며, 데이터 카탈로그는 소비 관점이다. 그 사이에서 “현재 도메인 모델이 어떻게 연결되어 있는가”를 공유하는 가벼운 시각 계층이 필요해졌다. drawDB의 Trending은 이 공백을 보여준다.

## 왜 지금 데이터베이스 스키마 설계 도구인가

스키마 설계는 오래된 주제다. 하지만 최근의 맥락은 과거의 ERwin, Visio, 수동 PowerPoint 다이어그램과 다르다. 첫째, 스키마 변경 속도가 빨라졌다. 제품 실험, feature flag, A/B 테스트, 결제·정산·권한 모델 변경이 모두 DB 구조를 건드린다. 변경은 작은 PR로 들어오지만, 누적되면 테이블 간 관계와 제약 조건이 빠르게 복잡해진다. 실제 장애는 SQL 문법 오류보다 “의도하지 않은 관계 파괴”, “락이 오래 잡히는 migration”, “인덱스 누락으로 인한 배포 후 성능 저하”에서 자주 발생한다.

둘째, 스키마를 이해해야 하는 사람이 늘었다. 백엔드 개발자만 DB를 보는 시대가 아니다. 데이터 엔지니어는 CDC와 warehouse 모델을 봐야 하고, 보안 담당자는 개인정보 컬럼과 보존 정책을 확인해야 하며, 제품 담당자는 주문·구독·권한 상태 전이를 이해해야 한다. 텍스트 migration만으로는 이들이 같은 맥락을 공유하기 어렵다. 브라우저 기반 ERD 도구가 중요한 이유는 설치 장벽을 낮추고, 리뷰 회의나 PR 설명에서 같은 그림을 빠르게 볼 수 있게 하기 때문이다.

셋째, AI 코딩과 자동 생성 SQL이 늘면서 오히려 검토 가능한 모델의 중요성이 커졌다. 모델이 migration 초안을 만들 수는 있지만, 도메인 의미와 운영 리스크까지 자동으로 보장하지는 않는다. generated SQL이 외래키를 잘못 해석하거나, nullable 컬럼을 무심코 추가하거나, 대용량 테이블에 위험한 DDL을 만들 수 있다. 이때 시각화된 모델은 “AI가 만든 변경이 도메인 구조에 맞는가”를 사람이 검토하는 보조 장치가 된다.

## drawDB의 핵심 구조: 그림 편집기가 아니라 SQL 왕복 계층

[drawDB README](https://github.com/drawdb-io/drawdb)는 계정 없이 브라우저에서 ERD를 만들고, SQL 스크립트를 가져오거나 내보내며, Docker로도 실행할 수 있다고 설명한다. 공유 기능이 필요하면 [drawdb-server](https://github.com/drawdb-io/drawdb-server)를 별도로 구성하고 환경 변수를 설정하라고 안내한다. 이 구조는 실무적으로 중요하다. 기본 편집 경험은 클라이언트 중심으로 가볍게 두고, 공유·폼 제출 같은 서버 기능은 선택 사항으로 분리했기 때문이다.

코드 의존성을 보면 drawDB의 역할이 더 분명해진다. React와 Vite는 웹 UI의 기반이고, Monaco Editor는 SQL 편집 경험을 담당한다. Dexie는 브라우저 로컬 저장소 계층으로 해석할 수 있다. `node-sql-parser`, `oracle-sql-parser`, `@dbml/core`는 SQL 또는 DBML과 내부 다이어그램 모델 사이의 변환에 관여한다. `@dagrejs/dagre`와 `src/utils/autoArrange.js`는 테이블과 관계를 그래프로 보고 자동 배치하는 데 쓰인다. 데이터베이스 목록에는 MySQL, PostgreSQL, SQLite, MariaDB, MSSQL, Oracle SQL, Generic 모델이 정의되어 있다.

이런 구조는 drawDB를 “ERD 캔버스”보다 “스키마 표현 변환기”에 가깝게 만든다. 사용자는 기존 DDL을 가져와 시각 모델로 바꾸고, 테이블과 관계를 조정한 뒤 다시 SQL로 내보낼 수 있다. 물론 완전한 왕복 변환은 매우 어렵다. 각 DBMS마다 constraint, index, generated column, partition, trigger, view, extension, collation, identity 전략이 다르다. 따라서 실무에서는 drawDB가 생성한 SQL을 곧바로 운영 DB에 적용하는 방식보다, 설계 초안과 리뷰 산출물로 사용하고 실제 배포는 별도의 migration 파이프라인에서 검증하는 방식이 안전하다.

## 기존 방식 및 대체 도구와의 비교

비교 대상은 세 가지 축으로 나눌 수 있다. 첫 번째는 [ChartDB](https://github.com/chartdb/chartdb)처럼 “기존 DB에서 다이어그램을 빠르게 생성”하는 도구다. ChartDB는 단일 쿼리로 DB 구조를 시각화하는 경험을 강조한다. 이미 큰 운영 DB가 있고, 현재 상태를 빠르게 파악해야 하는 팀에는 이 접근이 강하다. 반면 drawDB는 브라우저에서 직접 설계하고 SQL을 주고받는 편집 경험에 더 초점이 있다. 신규 서비스 설계, PR 설명, 도메인 모델 워크숍에는 drawDB 쪽이 가볍게 맞을 수 있다.

두 번째는 [Azimutt](https://github.com/azimuttapp/azimutt)처럼 복잡한 데이터베이스 탐색과 문서화를 지향하는 도구다. Azimutt는 “Explore, document and optimize any database”를 내세우며 큰 스키마에서 필요한 부분을 찾아 이해하는 문제에 가깝다. 엔터프라이즈 환경에서는 전체 ERD가 너무 커서 오히려 쓸모없어지는 경우가 많다. 이때 검색, 필터링, 부분 뷰, 문서화 기능이 중요하다. drawDB를 선택한다면 “복잡한 운영 DB 전체 탐색”이 아니라 “설계와 변경 논의의 앞단”에 배치하는 것이 자연스럽다.

세 번째는 [SchemaSpy](https://github.com/schemaspy/schemaspy), dbdocs, DataGrip 다이어그램, Prisma Studio, Rails schema, Liquibase/Flyway 문서화 같은 기존 생태계다. 이 도구들은 이미 CI, IDE, migration workflow와 연결되어 있는 경우가 많다. drawDB가 이들을 대체한다고 보는 것은 과장이다. 더 현실적인 해석은 drawDB가 빠른 시각 초안과 커뮤니케이션 계층을 제공하고, schema diff, migration 검증, 성능 영향 분석, 배포 승인 같은 통제는 기존 도구가 담당하는 구조다.

| 구분 | drawDB | ChartDB | Azimutt | SchemaSpy/IDE/마이그레이션 도구 |
|---|---|---|---|---|
| 주 사용 시점 | 설계·리뷰 초안 | 기존 DB 시각화 | 대규모 DB 탐색·문서화 | 운영 변경 관리·문서 생성 |
| 강점 | 브라우저 편집, SQL import/export, 낮은 진입 장벽 | DB에서 빠르게 다이어그램 생성 | 복잡한 스키마 이해 | CI·IDE·배포 파이프라인 연계 |
| 한계 | SQL 방언 완전성, source of truth 관리 필요 | 설계 편집보다 reverse engineering 중심 | 도구 학습 비용 | 비개발자 커뮤니케이션이 어려울 수 있음 |
| 적합한 팀 | 제품 초기 설계, PR 설명, 도메인 모델 합의 | 운영 DB 현황 파악 | 데이터 모델이 큰 조직 | 규제·운영 통제가 중요한 팀 |

## 실무 도입 장점: 회의 시간을 줄이고 변경 리스크를 앞당긴다

drawDB 같은 도구의 첫 번째 장점은 커뮤니케이션 비용 절감이다. 스키마 변경 PR에서 `ALTER TABLE`, ORM 모델, migration 파일만 보면 리뷰어는 머릿속으로 관계를 재구성해야 한다. 테이블이 5개를 넘어가고 관계가 다대다, nullable foreign key, 상태 테이블로 늘어나면 리뷰 품질은 빠르게 떨어진다. ERD가 있으면 “이 변경이 주문 상태 전이와 결제 정산에 어떤 영향을 주는가”를 더 빨리 논의할 수 있다.

두 번째 장점은 설계 결함을 배포 전에 드러낸다는 점이다. 예를 들어 `orders`, `payments`, `refunds`, `subscriptions`가 서로 어떤 기준키를 공유하는지 명확하지 않으면 나중에 분석 쿼리와 정산 로직이 계속 흔들린다. 그림으로 관계를 보면 잘못된 cardinality, 누락된 unique constraint, 애매한 ownership이 드러난다. 이것은 성능 튜닝보다 앞선 도메인 모델링 문제다.

세 번째 장점은 온보딩이다. 신규 개발자나 데이터 분석가는 “어떤 테이블부터 봐야 하는가”에서 막힌다. 스키마 다이어그램이 최신 상태로 유지된다면 첫 주의 이해 비용을 크게 줄일 수 있다. 특히 작은 팀에서는 별도의 데이터 카탈로그를 도입하기 부담스러울 수 있다. drawDB로 핵심 도메인만 가볍게 문서화하는 방식은 비용 대비 효과가 있다.

## 한계와 리스크: 그림이 진실이 되는 순간 위험해진다

![스키마 설계 도구 도입 리스크 매트릭스](https://heracles-jo.github.io/assets/img/posts/github-trending-drawdb-database-schema-design-governance/risk-matrix.svg)

가장 큰 리스크는 source of truth 충돌이다. 운영 DB의 실제 상태, migration repository, ORM 모델, drawDB 파일이 서로 다르면 무엇을 믿어야 하는가. 답은 명확해야 한다. 운영 변경의 진실은 version-controlled migration과 실제 DB introspection이어야 한다. drawDB는 설계·리뷰·커뮤니케이션 산출물로 두고, 배포 직전에는 migration diff와 DB별 테스트로 검증해야 한다.

두 번째는 SQL 방언 충실도다. drawDB는 여러 DB를 지원하지만, DBMS별 DDL의 모든 의미를 완벽히 처리하는 것은 매우 어렵다. PostgreSQL의 partial index, expression index, enum, extension, generated column, partitioning, RLS, MySQL의 charset/collation, InnoDB 옵션, MSSQL의 identity와 schema namespace, Oracle의 sequence와 tablespace 같은 세부 요소는 단순 ERD 모델로 축약되기 쉽다. 따라서 자동 생성 SQL은 초안으로 보고, DBA 또는 경험 있는 백엔드 개발자가 실제 적용 가능성을 검토해야 한다.

세 번째는 보안과 데이터 노출이다. 스키마 자체도 민감 정보다. 테이블명과 컬럼명만으로도 비즈니스 로직, 고객 세그먼트, 내부 정책, 보안 경계가 드러날 수 있다. 샘플 데이터가 포함되면 위험은 더 커진다. 브라우저 기반 도구를 쓸 때는 어떤 데이터가 로컬에 저장되는지, 공유 기능을 켰을 때 어떤 서버로 전송되는지, 외부 SaaS URL에 업로드하지 않는지, export 파일을 어디에 보관하는지 점검해야 한다. drawDB는 optional server를 분리하지만, 조직이 자체 배포를 하더라도 접근 제어와 로그, 백업, 삭제 정책은 별도로 설계해야 한다.

네 번째는 라이선스다. drawDB 본체는 AGPL-3.0으로 표시된다. 내부에서 독립 실행 도구로 사용하는 것과, 수정 후 네트워크 서비스로 제공하는 것, 제품에 통합해 고객에게 제공하는 것은 법적 의미가 다를 수 있다. 이 글은 법률 자문이 아니며, 상용 제품이나 사내 플랫폼에 깊게 통합하려는 팀은 반드시 오픈소스 컴플라이언스 담당자와 AGPL 의무를 검토해야 한다. 비교 대상으로 본 drawdb-server는 MIT로 표시되지만, 본체와 서버의 라이선스 경계도 함께 봐야 한다.

## PoC 체크리스트: 도구 평가보다 프로세스 검증이 먼저다

도입 PoC는 “예쁜 다이어그램을 만들 수 있는가”가 아니라 “우리 팀의 스키마 변경 프로세스가 개선되는가”를 검증해야 한다. 다음 순서를 권한다.

1. **대표 도메인 1개 선정**: 주문, 결제, 권한, 구독처럼 관계가 복잡하고 변경 빈도가 높은 영역을 고른다.
2. **현재 DDL import 테스트**: 실제 운영 DDL의 sanitized copy를 가져와 테이블, 관계, 타입, 제약 조건이 얼마나 보존되는지 확인한다.
3. **round-trip diff 확인**: import 후 export한 SQL을 원본과 비교해 손실되는 요소를 분류한다. 문법 차이, 의미 손실, 지원 불가 항목을 구분해야 한다.
4. **PR 리뷰에 첨부**: 다음 schema 변경 PR에 drawDB 다이어그램을 첨부하고 리뷰 시간이 줄었는지, 누락된 질문이 발견됐는지 확인한다.
5. **migration 도구와 역할 분리**: Flyway, Liquibase, Prisma, Rails migration, Alembic 등 실제 배포 경로와 drawDB 산출물의 관계를 문서화한다.
6. **보안 경계 검토**: 샘플 데이터 금지, 민감 컬럼 명명 규칙, export 파일 저장 위치, 공유 서버 접근 권한을 정한다.
7. **라이선스 검토**: 내부 사용, 수정 배포, 서비스 제공 여부에 따라 AGPL-3.0 의무를 검토한다.
8. **유지보수 책임자 지정**: 다이어그램이 낡지 않도록 누가 언제 업데이트하는지 정한다.

이 체크리스트에서 가장 중요한 항목은 3번과 5번이다. SQL round-trip에서 손실이 많다면 drawDB를 설계 초안으로 제한해야 한다. 반대로 단순한 도메인에서 충분히 안정적이라면 PR 설명과 온보딩 문서로 활용할 수 있다. 하지만 어떤 경우에도 운영 migration의 승인 게이트를 생략해서는 안 된다.

## 어떤 팀에 적합하고, 어떤 경우 피해야 하나

적합한 팀은 세 부류다. 첫째, 빠르게 성장하는 제품팀이다. 신규 기능이 자주 추가되고 도메인 모델이 아직 굳지 않은 팀은 스키마 설계 토론의 속도가 중요하다. drawDB는 초기 설계안을 빠르게 그리고 SQL 초안을 만들기 좋다. 둘째, 백엔드와 데이터 팀 사이의 커뮤니케이션 비용이 큰 조직이다. 분석 테이블과 운영 테이블의 의미가 자주 어긋나는 경우, 핵심 도메인 ERD를 공유하는 것만으로도 질문의 질이 좋아진다. 셋째, 별도 엔터프라이즈 데이터 모델링 도구를 도입하기 부담스러운 소규모 조직이다.

피해야 할 경우도 분명하다. 규제 산업에서 스키마 정보 반출 통제가 매우 엄격한데 브라우저 저장·공유 경계를 검증할 수 없다면 도입을 미뤄야 한다. 수천 개 테이블을 가진 레거시 DB 전체를 한 번에 이해하려는 목적이라면 drawDB만으로는 부족할 수 있다. SQL 방언 특화 기능을 많이 쓰는 대규모 PostgreSQL 또는 Oracle 환경에서 generated SQL을 신뢰하려는 접근도 위험하다. 이 경우에는 DB introspection, schema diff, migration testing, 성능 검증을 제공하는 전문 도구와 함께 제한적으로 써야 한다.

## 향후 관찰해야 할 지표와 전망

앞으로 볼 지표는 stars보다 운영 적합성에 가깝다. 첫째, 최근 커밋에서 보인 자동 배치, 다국어 UI, 의존성 보안 업데이트 같은 유지보수 흐름이 지속되는지 봐야 한다. drawDB 저장소는 2026년 8월 12일 기준 Traditional Chinese UI 문자열 추가, auto-arrange 관련 커밋, DOMPurify 업데이트가 확인됐다. 이는 사용자 경험과 보안 의존성 관리가 계속 다뤄지고 있다는 신호다. 둘째, release note 체계다. 확인 시점에는 GitHub Releases가 별도로 보이지 않았다. 조직에서 표준 도구로 쓰려면 버전 고정, 변경 로그, 회귀 테스트 전략이 필요하다.

셋째, DB 방언 지원의 깊이다. MySQL, PostgreSQL, SQLite, MariaDB, MSSQL, Oracle SQL을 모두 지원한다고 해도 실무에서는 “우리 팀이 쓰는 기능이 안전하게 표현되는가”가 더 중요하다. 넷째, 공유 서버와 협업 기능의 성숙도다. 스키마 리뷰는 혼자 그리는 도구에서 끝나지 않는다. 권한, 댓글, 변경 이력, export 정책, Git 연동이 강해질수록 팀 도입 가능성이 커진다. 다만 이 영역은 보안과 라이선스 검토도 함께 무거워진다.

결론적으로 drawDB의 Trending은 데이터베이스 모델링의 회귀가 아니라, 스키마 설계 거버넌스를 더 이른 단계로 당기려는 움직임으로 보는 편이 맞다. AI가 코드를 쓰고, 서비스가 빠르게 쪼개지고, 데이터 소비자가 늘수록 데이터 모델의 의미를 공유하는 비용은 커진다. 브라우저 ERD 도구는 이 문제를 완전히 해결하지 못하지만, 논의를 시작하는 표면을 낮춘다. 실무 의사결정자는 drawDB를 “운영 DB 변경 자동화 도구”로 과대평가하지 말고, “도메인 모델 합의와 리뷰 품질을 높이는 시각 계층”으로 평가해야 한다. 그 경계를 지킨다면, 작은 도구 하나가 스키마 변경 장애를 줄이고 팀 간 대화를 훨씬 구체적으로 만들 수 있다.
