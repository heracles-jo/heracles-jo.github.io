---
title: "AFFiNE 로컬 퍼스트 지식 베이스: CRDT 동기화·복구 기준"
description: "AFFiNE의 CRDT·로컬 저장·실시간 협업·셀프호스팅 구조를 분해해 동기화 충돌, 데이터 소유권, 백업·복구와 실무 도입 판단 기준을 정리한다."
author: heracles-jo
date: 2026-11-23 08:39:00 +0900
categories: [Platform Engineering, Productivity]
tags: [affine, local-first, crdt, knowledge-management, self-hosting]
image:
  path: https://heracles-jo.github.io/assets/img/posts/affine-local-first-knowledge-base/cover.svg
  alt: "AFFiNE 로컬 퍼스트 지식 베이스의 장치 저장 CRDT 동기화 셀프호스팅 복구 계층"
---

로컬 퍼스트 지식 베이스를 고르는 이유는 인터넷이 끊겨도 노트를 쓰기 위해서만이 아니다. 사용자가 먼저 가진 복사본에서 편집하고, 여러 장치와 동료의 변경을 나중에 합치며, 서비스 장애나 요금 정책이 바뀌어도 원본 데이터에 접근할 수 있어야 한다는 운영 요구가 핵심이다. 문제는 `local-first`라는 라벨만으로 이 계약이 완성되지 않는다는 데 있다. 로컬 변경이 서버와 충돌했을 때 무엇이 남는지, 삭제가 다른 장치에 어떻게 전파되는지, 파일과 문서 데이터가 같은 시점으로 복구되는지까지 확인해야 실제 통제권이 생긴다.

[toeverything/AFFiNE](https://github.com/toeverything/AFFiNE)는 문서, 데이터베이스와 무한 캔버스를 한 워크스페이스에 결합하고 로컬 저장과 실시간 협업을 함께 제공하는 오픈소스 프로젝트다. 2026년 11월 23일 08시 47분 KST 전후 GitHub Trending daily에는 `537 stars today`로 표시됐다. GitHub API 확인 시점에는 76,804 stars, 5,622 forks였고 기본 개발 브랜치 `canary`에는 11월 22일까지 동기화 안정성, 서버 blob 접근 경계와 모바일 빌드 변경이 반영됐다. 최신 안정 릴리스는 GitHub 페이지 기준 `0.27.4`, 보안 정책은 현재 `0.27.x`만 지원 대상으로 명시한다. 수치와 저장소 상태는 확인 시점의 공개 스냅샷이며 제품 안정성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근하지 못했다.

## 후보 비교: 기능 목록보다 독립적인 운영 질문을 골랐다

오늘 상위권에는 에이전트 스킬, 보안 자동화, 웹 수집과 모델 학습 도구가 많았다. 그러나 저장소 이름이 달라도 이미 다룬 검색 의도와 중심 판단이 같으면 새 글의 장기 가치는 낮다. AFFiNE은 단순한 “Notion 대안 추천”보다 **로컬 원본과 협업 서버 사이의 동기화·복구 계약을 어떻게 검증할 것인가**라는 별도 질문을 만든다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [toeverything/AFFiNE](https://github.com/toeverything/AFFiNE) | daily 537, API 76,804 stars, 활발한 canary·stable 릴리스 | CRDT 기반 로컬 퍼스트 협업과 복구 검증이라는 독립적인 도입 의도가 있어 선택했다. |
| [Tracer-Cloud/opensre](https://github.com/Tracer-Cloud/opensre) | daily 395, API 14,395 stars, Apache-2.0 | CI/CD 장애 조사 에이전트는 관측성·배포 복구 글과 중심 질문이 가깝다. |
| [elementalsouls/Claude-BugHunter](https://github.com/elementalsouls/Claude-BugHunter) | daily 1,721, API 17,739 stars, MIT | 승인된 레드팀 자동화는 Security Audit Skill·Codex Security의 권한·증거 검증 의도와 겹친다. |
| [firecrawl/firecrawl](https://github.com/firecrawl/firecrawl) | daily 910, API 207,008 stars, AGPL-3.0 | 웹 수집과 에이전트 지식 인입은 기존 문서 파서·RAG·헤드리스 브라우저 클러스터와 경쟁한다. |
| [jingyaogong/minimind](https://github.com/jingyaogong/minimind) | daily 473, API 68,629 stars, Apache-2.0 | 소형 LLM 학습은 장기 가치가 있지만 모델 학습 재현성·로컬 LLM 글과 검색 의도가 인접한다. |

기존 [Macro 통합 워크스페이스 분석](/posts/macro-unified-workspace-permission-graph/)은 여러 협업 객체를 한 그래프에 모을 때 권한과 AI 메모리가 어떻게 확산되는지를 봤다. AFFiNE의 더 선명한 질문은 문서 편집 상태 자체다. 서버 연결이 끊긴 동안 두 장치에서 같은 문서를 수정했을 때, 다시 연결한 뒤 사용자가 기대한 내용과 첨부 파일이 보존되는가. [Meetily의 로컬 회의 지식 파이프라인](/posts/github-trending-meetily-local-meeting-knowledge-pipeline/)이 장치 안에 생성되는 민감한 기록의 수명주기를 다뤘다면, 여기서는 여러 장치와 협업자가 공유하는 편집 상태의 수렴을 본다.

## AFFiNE의 핵심은 캔버스보다 CRDT 데이터 흐름이다

AFFiNE README는 문서와 화이트보드, 데이터베이스를 하나의 블록 기반 워크스페이스에서 다루는 경험을 앞세운다. 내부적으로는 BlockSuite 편집기와 CRDT 계층이 더 중요하다. 공식 BlockSuite 동기화 문서는 문서 상태를 단순 JSON 파일이 아니라 CRDT의 바이너리 표현으로 유지하고, 로컬 IndexedDB나 WebSocket 같은 provider를 연결해 같은 문서를 여러 저장소와 동기화할 수 있다고 설명한다.

전통적인 클라우드 편집기는 서버 응답이 진실의 원본이고 클라이언트 상태가 이를 따라가는 구조가 많다. 로컬 퍼스트 설계에서는 장치가 오프라인이어도 유효한 변경을 만들 수 있어야 하므로 각 복사본이 일시적으로 원본 역할을 한다. CRDT는 변경 순서가 달라도 최종 상태가 수렴하도록 돕지만, 모든 의미 충돌을 사람 대신 해결하지는 않는다. 두 사용자가 같은 문단을 서로 다른 의도로 고쳤을 때 데이터 구조가 합쳐져도 문서의 뜻은 어색해질 수 있다.

![AFFiNE의 로컬 장치 CRDT provider 협업 서버 저장소를 분리한 동기화 아키텍처](https://heracles-jo.github.io/assets/img/posts/affine-local-first-knowledge-base/architecture.svg)
_그림 1. 로컬 편집이 먼저 가능하더라도 장치 저장, CRDT 변경, 원격 동기화, blob과 서버 데이터는 서로 다른 실패 지점을 가진다._

이 구조를 운영 관점에서 네 계층으로 나누면 검증 지점이 보인다.

1. **편집 계층**은 문서·캔버스·테이블의 블록과 사용자 의도를 다룬다.
2. **로컬 지속성 계층**은 브라우저 IndexedDB 또는 데스크톱 저장소에 장치 복사본을 남긴다.
3. **동기화 계층**은 CRDT update, awareness와 provider 연결을 통해 여러 복사본을 수렴시킨다.
4. **서버·파일 계층**은 계정, 협업 공간, metadata, blob과 장기 저장을 담당한다.

“오프라인에서 수정됐다”는 성공은 첫 두 계층만 증명한다. 다른 장치가 같은 변경을 받았는지, 첨부 이미지가 문서와 같은 권한으로 동기화됐는지, 서버 복원 뒤 문서 참조가 깨지지 않았는지는 별도 시험이 필요하다.

## CRDT가 해결하는 충돌과 해결하지 못하는 충돌

CRDT의 강점은 네트워크 지연과 재접속을 정상 상태로 취급한다는 점이다. 사용자가 비행기 모드에서 문서를 고치고 다른 사용자가 서버 연결 상태에서 별도 블록을 추가해도, 연결이 회복되면 양쪽 변경을 병합할 수 있다. 중앙 잠금이나 마지막 저장자의 전체 덮어쓰기에 의존하는 방식보다 협업 탄력성이 높다.

그러나 실무자는 `conflict-free`를 `mistake-free`로 읽으면 안 된다.

- 같은 문장을 한쪽은 승인, 다른 쪽은 보류로 수정하면 구조적으로 합쳐져도 의사결정은 모순될 수 있다.
- 한 장치가 문서를 삭제하고 다른 장치가 오래된 복사본을 편집하면 삭제 tombstone과 새 변경의 기대가 충돌한다.
- 문서 블록은 수렴했지만 첨부 blob 업로드가 실패하면 화면에는 깨진 참조가 남을 수 있다.
- 오래 오프라인이던 장치가 복귀할 때 schema migration과 CRDT version 호환성이 맞지 않을 수 있다.
- 실시간 presence가 끊겨 있으면 사용자는 같은 영역을 동시에 편집한다는 사실을 모르고 의미 충돌을 키울 수 있다.

최근 canary의 `improve sync stability` 변경은 불완전한 문서 등록 복구와 revision conflict 탐지를 다룬다. 이는 활발한 개선 신호이면서 동기화 경계가 계속 움직인다는 뜻이기도 하다. 팀 배포에서는 `stable`과 `canary`를 혼용하지 말고, 클라이언트·서버·모바일 버전 조합을 고정한 뒤 오프라인 재접속 시험을 반복해야 한다.

가장 중요한 관측값은 “sync 아이콘이 초록색인가”가 아니다. 장치별 last acknowledged revision, pending update 수, blob upload 실패, 재접속 시간, conflict·recovery 이벤트, 삭제 전파 지연을 확인할 수 있어야 한다. UI의 정상 표시와 데이터 수렴을 같은 것으로 취급하면 조용한 손실을 놓친다.

## 로컬 퍼스트는 백업이 아니라 복사본 우선권에 가깝다

로컬 퍼스트 앱을 쓰면 데이터가 장치에 있으니 백업이 끝났다고 생각하기 쉽다. 하지만 장치 복사본은 작업 지속성을 위한 상태이지 검증된 복구 지점이 아니다. 손상된 상태나 실수로 삭제한 내용도 다른 장치와 빠르게 동기화될 수 있고, 오랫동안 꺼져 있던 장치는 최신 첨부 파일과 계정 metadata가 없을 수 있다.

셀프호스팅용 Compose는 AFFiNE server, migration job, Redis와 PostgreSQL을 실행하고 `./data/storage`, `./data/postgres`, 설정 디렉터리를 영속화한다. 이 구성에서 PostgreSQL만 dump하면 충분하다고 가정해서는 안 된다. 문서 metadata와 계정 관계, 파일 storage, 설정, 실행 중인 image version과 migration 상태가 함께 맞아야 한다. Redis는 재구성 가능한 임시 상태인지, 특정 job이나 session을 잃었을 때 어떤 영향이 있는지도 배포 버전에서 확인해야 한다.

[Supabase 셀프호스팅 운영 글](/posts/supabase-self-hosting-operations/)에서 DB dump 보유와 실제 복원 성공을 구분했듯, AFFiNE도 빈 서버에서 다음 조건을 확인해야 한다.

- 당시 사용한 AFFiNE image digest와 설정으로 migration이 완료되는가.
- PostgreSQL과 storage를 같은 시점으로 복원했을 때 문서와 blob 참조가 일치하는가.
- 로컬에 pending update가 있는 장치가 복원 서버에 연결될 때 데이터가 중복되거나 사라지지 않는가.
- 삭제된 workspace, 사용자 제거와 공유 권한이 복원 뒤 되살아나지 않는가.
- 웹·데스크톱·모바일 클라이언트가 같은 문서 수와 revision을 관찰하는가.
- export한 Markdown·snapshot이 최후의 수동 복구 경로로 실제 열리는가.

백업 주기는 문서 작성량만으로 정하지 않는다. 협업자가 많고 첨부 파일이 크며 오프라인 장치가 자주 복귀하는 팀일수록 동기화 지연과 backup 시점 사이의 차이가 커진다. RPO는 서버 DB의 마지막 dump 시각이 아니라 **모든 장치에서 확인된 변경이 복원 가능한 형태로 보존된 시각**으로 정의하는 편이 정확하다.

## 셀프호스팅은 데이터 위치를 바꾸지만 신뢰 경계도 늘린다

AFFiNE의 공식 Compose는 시작하기 쉽지만 예시 설정을 그대로 운영 환경에 올리면 안 된다. 공개 파일은 PostgreSQL에 `POSTGRES_HOST_AUTH_METHOD: trust`를 사용하며 서비스 이름 기반 내부 연결을 전제로 한다. 인터넷에 데이터베이스 포트를 노출하지 않고 격리 네트워크 안에서만 사용해야 하며, 실제 운영에서는 인증, secret 관리, TLS 종료, 관리자 접근, 로그와 backup 권한을 별도로 설계해야 한다.

로컬 퍼스트와 셀프호스팅을 결합하면 외부 SaaS 의존은 줄어든다. 대신 다음 책임이 조직으로 이동한다.

- 서버·데스크톱·모바일의 버전 호환성과 단계적 업데이트
- PostgreSQL, storage, 설정과 암호화 키의 일관된 backup
- 초대, 공유 링크, workspace 제거와 퇴사자 권한 회수
- 클라이언트 캐시와 오프라인 복사본의 잔존 데이터 처리
- 취약점 공지 추적과 현재 지원 major version 유지
- AI·MCP·원격 이미지 같은 선택 기능의 외부 전송 경계

[Project NOMAD의 오프라인 지식 서버](/posts/project-nomad-offline-knowledge-server/)처럼 서버가 내 통제 안에 있다는 사실은 복구 가능성을 자동으로 만들지 않는다. 정전, disk full, 잘못된 migration, storage 권한 오류, 인증서 만료, 클라이언트 버전 분열을 실제로 재현해야 한다. 관리형 SaaS의 장애를 피하는 대신 작은 플랫폼 팀의 운영 능력이 가용성 상한이 된다.

## 라이선스는 “전체 MIT”라고 단순화하면 안 된다

GitHub 저장소 화면은 MIT license를 함께 표시하지만 루트 `LICENSE`는 디렉터리별 조건을 구분한다. 대부분의 외부 코드는 MIT로 제공되지만 `packages/backend`와 `packages/common/native` 아래에는 별도 backend license가 적용될 수 있다. backend license는 Community Edition에 포함되는 일부를 MPL-2.0으로 설명하면서, Enterprise Edition 부분의 production 사용에는 유효한 구독 조건을 요구한다.

따라서 “오픈소스이므로 모든 서버 기능을 수정해 상용 서비스로 자유롭게 재배포할 수 있다”고 가정해서는 안 된다. 실제 사용할 image와 source path가 CE인지 EE인지, 수정·배포·브랜딩·기업 기능의 조건이 무엇인지 canonical license text와 현재 제품 문서로 확인해야 한다. 이 글은 법률 자문이 아니며 조직 도입이나 재판매 전에는 법무 검토가 필요하다.

라이선스 경계는 기술 아키텍처에도 영향을 준다. 필요한 SSO, 감사, 관리 기능이 EE에만 있다면 CE를 선택한 팀이 직접 구현할 비용과 보안 책임이 커질 수 있다. 반대로 개인·소규모 팀이 기본 문서 협업과 로컬 편집만 필요하다면 복잡한 엔터프라이즈 기능 없이 CE 범위가 충분할 수 있다.

## 2주 PoC는 기능 만족도보다 수렴·복구 증거를 모은다

처음부터 전체 문서와 회의록을 이관하지 말고 독립된 테스트 workspace에서 장치·사용자·네트워크 실패를 의도적으로 만든다. 기존 Notion이나 파일 저장소를 즉시 폐기하지 않고, 일상 편집 가치와 운영 위험을 동시에 비교해야 한다.

![AFFiNE 도입을 로컬 편집 동기화 충돌 복구 보안 승격 순서로 검증하는 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/affine-local-first-knowledge-base/decision.svg)
_그림 2. 화면 기능보다 오프라인 변경의 수렴, 삭제·권한 전파와 빈 서버 복구를 먼저 통과한 뒤 중요 문서를 옮긴다._

첫 주에는 웹·데스크톱·모바일 중 실제 사용할 조합으로 같은 문서를 편집한다. 네트워크를 끊고 서로 다른 블록과 같은 문단을 수정하며, 첨부 이미지·데이터베이스 행·캔버스 객체를 함께 바꾼다. 재접속 뒤 각 장치의 내용, revision, 첨부 파일과 검색 결과를 대조한다. 단순한 문장 추가뿐 아니라 삭제, 되돌리기, workspace 탈퇴와 오래된 장치 복귀를 포함해야 한다.

둘째 주에는 stable image와 backup으로 빈 서버를 복원한다. 복원 전 오프라인 장치 하나에 pending change를 남겨 두고, 서버 복구 뒤 연결했을 때 기대한 상태가 되는지 본다. version upgrade 전후 export·import, database migration rollback, storage 누락과 disk full도 시험한다.

| 검증 영역 | 측정값 | 중단 조건 예시 |
|---|---|---|
| 오프라인 편집 | pending update, 재접속 시간, 사용자 수정 유실 | 재접속 후 내용이 조용히 덮어써지거나 중복됨 |
| 의미 충돌 | 같은 문단·행·캔버스 객체의 병합 결과와 사람 수정 시간 | 구조는 수렴하지만 중요 결정의 뜻이 반복적으로 훼손됨 |
| 파일 정합성 | 문서 참조 대비 blob 존재율, upload retry, 깨진 미리보기 | 문서는 정상인데 첨부 파일을 복구할 수 없음 |
| 권한·삭제 | 초대·탈퇴·삭제 후 장치·검색·공유 링크 접근 | 제거한 사용자의 오프라인 복사본이나 링크가 계속 유효함 |
| 백업·복구 | RPO·RTO, 문서 수, revision·blob 일치율 | 빈 서버 복원 뒤 일부 workspace나 파일이 누락됨 |
| 업그레이드 | stable 버전 간 migration, 구·신 클라이언트 호환성 | client version 차이로 편집·sync가 멈추거나 손상됨 |
| 운영 비용 | patch 시간, storage 증가, 사용자 지원 건수 | SaaS 절감보다 장애 대응·지원 비용이 지속적으로 큼 |

성과 지표에는 문서 작성 속도와 캔버스 만족도도 필요하지만, 그것만으로 도입을 결정하면 안 된다. 기존 도구 대비 오프라인 작업 성공률, 동기화 후 사람의 재조정 시간, 복원 성공률과 권한 회수 지연이 함께 개선돼야 한다.

## 도입 판단은 데이터가 어디에 있는가보다 언제 다시 믿을 수 있는가다

AFFiNE은 문서와 캔버스를 한 편집 모델에 결합하고, CRDT와 로컬 저장으로 네트워크 단절을 일반적인 상태로 취급한다. 개인 지식 관리와 소규모 협업에서 클라우드 연결을 기다리지 않고 작업할 수 있다는 장점은 분명하다. 셀프호스팅 경로와 활발한 개발도 데이터 통제권을 중시하는 팀에 매력적이다.

반대편에는 동기화와 복구의 복잡성이 있다. CRDT는 변경을 수렴시키지만 사람의 의도를 판정하지 않고, 로컬 복사본은 검증된 backup이 아니며, 서버를 직접 운영하면 PostgreSQL·storage·migration·클라이언트 호환성 책임이 생긴다. 라이선스도 저장소 전체를 한 문장으로 MIT라고 부르기 어려우므로 사용할 edition과 경로를 확인해야 한다.

도입 기준은 세 질문으로 압축할 수 있다. **오프라인에서 만든 변경이 여러 장치에서 손실 없이 수렴하는가, 삭제와 권한 회수가 로컬 복사본·검색·공유 링크까지 예측 가능하게 전파되는가, 빈 서버에 DB·파일·설정을 복원한 뒤 같은 문서를 다시 신뢰할 수 있는가.** 이 질문에 반복 가능한 시험 결과로 답할 수 있을 때 로컬 퍼스트는 마케팅 문구가 아니라 운영 가능한 데이터 소유 모델이 된다.

## 1차 자료와 확인 범위

- [AFFiNE 공식 저장소와 README](https://github.com/toeverything/AFFiNE)
- [BlockSuite Data Synchronization 문서](https://github.com/toeverything/AFFiNE/blob/canary/blocksuite/docs-site/guide/data-synchronization.md)
- [AFFiNE self-host Compose](https://github.com/toeverything/AFFiNE/blob/canary/.docker/selfhost/compose.yml)
- [AFFiNE Security Policy](https://github.com/toeverything/AFFiNE/blob/canary/SECURITY.md)
- [AFFiNE 루트 LICENSE](https://github.com/toeverything/AFFiNE/blob/canary/LICENSE)
- [AFFiNE backend LICENSE](https://github.com/toeverything/AFFiNE/blob/canary/packages/backend/server/LICENSE)
- [AFFiNE releases](https://github.com/toeverything/AFFiNE/releases)
- [AFFiNE commits](https://github.com/toeverything/AFFiNE/commits/canary/)
- [AFFiNE issues](https://github.com/toeverything/AFFiNE/issues)

Trending·GitHub 수치와 저장소 상태는 2026년 11월 23일 08시 47분 KST 전후 확인한 공개 페이지와 API 스냅샷이다. 설치·보안·라이선스 판단은 실제 배포 시점의 stable release, canonical 문서와 조직 정책을 다시 기준으로 삼아야 한다.
