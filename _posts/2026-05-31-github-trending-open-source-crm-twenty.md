---
title: "오픈소스 CRM Twenty와 AI 시대 고객 데이터 플랫폼"
description: "GitHub Trending에 오른 Twenty를 중심으로 오픈소스 CRM, AI 에이전트 확장, 셀프호스팅 운영 리스크와 도입 판단 기준을 분석합니다."
author: heracles-jo
date: 2026-05-31 09:21:11 +0900
categories: [Open Source, GitHub Trending]
tags: [github-trending, open-source, twenty, crm, customer-data-platform, self-hosting, typescript, ai-agent, platform-engineering]
slug: "github-trending-open-source-crm-twenty"
draft: false
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-open-source-crm-twenty/cover.svg
  alt: "GitHub Trending 오픈소스 CRM Twenty 기술 분석 커버"
---

## 오늘 눈에 띈 저장소와 신호

2026년 5월 31일 오전 KST 기준 GitHub Trending daily와 weekly를 보면서 후보를 다시 비교했다. 이 글은 단순히 `twentyhq/twenty`를 소개하려는 글이 아니라, CRM이 고객 데이터 플랫폼과 AI 에이전트의 업무 컨텍스트로 재해석되는 흐름을 읽기 위한 분석이다.

| 후보 | 확인한 신호 | 제외/선택 이유 |
| --- | --- | --- |
| [twentyhq/twenty](https://github.com/twentyhq/twenty) | GitHub API 기준 약 48,708 stars, 6,911 forks, TypeScript, 최근 push 확인 | 기존 글과 중복이 적고, 오픈소스 CRM·데이터 주권·AI 에이전트 확장이라는 실무 주제가 선명해 선택 |
| microsoft/markitdown | 약 132,344 stars, MIT, 문서 Markdown 변환 | LiteParse 글과 검색 의도와 기술 각도가 가까워 제외 |
| EveryInc/compound-engineering-plugin | 약 18,415 stars, TypeScript, AI 개발 플러그인 흐름 | Cursor Plugins 글과 직접 중복되어 제외 |
| OpenMOSS/MOSS-TTS | Apache-2.0, 음성 생성 모델 계열 | VoxCPM 글과 주제 중복으로 제외 |
| meilisearch/meilisearch | 성숙한 오픈소스 검색 엔진 | 좋은 인프라 주제지만 오늘의 급부상 신호보다는 별도 심층 글에 적합 |

## CRM이 다시 개발자 도구처럼 보이기 시작한 날

2026년 5월 31일 오전 KST 기준으로 GitHub Trending daily와 weekly를 확인했다. daily 상위권에는 `microsoft/markitdown`, `anthropics/claude-code`, `cursor/plugins`, `revfactory/harness`, `EveryInc/compound-engineering-plugin`, `OpenBMB/VoxCPM`처럼 문서 변환, 코딩 에이전트, 플러그인, 음성 AI 계열 프로젝트가 계속 보였다. TypeScript daily에서는 `cursor/plugins`, `EveryInc/compound-engineering-plugin`, `Crosstalk-Solutions/project-nomad`, `microsoft/playwright`, `twentyhq/twenty`, `anomalyco/opencode`가 눈에 들어왔다.

최근 이 블로그에서는 Cursor Plugins, LiteParse, VoxCPM, Paperless-ngx, Frigate, Jellyfin처럼 에이전트 워크플로, 문서 파이프라인, 음성 AI, 셀프호스팅 인프라를 이미 다뤘다. 그래서 오늘은 또 다른 AI 플러그인이나 문서 파서를 고르면 흐름이 너무 겹친다. `twentyhq/twenty`는 다르다. 표면적으로는 CRM이지만, README가 강조하는 방향은 “고객 관리 화면”보다 “기술 팀이 비즈니스 객체, 뷰, 워크플로, 에이전트를 코드처럼 확장하는 CRM”에 가깝다. 이 지점이 흥미롭다. CRM은 대개 영업 조직의 SaaS 구매 의사결정으로 취급되지만, Twenty는 그 영역을 다시 애플리케이션 플랫폼의 문제로 끌고 온다.

후보는 최소 다섯 개 이상 비교했다. `microsoft/markitdown`은 132,344 stars, MIT, Python 기반 문서 Markdown 변환 도구로 여전히 강하지만 LiteParse 글과 검색 의도가 가깝다. `EveryInc/compound-engineering-plugin`은 18,415 stars, MIT, TypeScript 프로젝트로 Claude Code·Codex·Cursor 플러그인 흐름에 맞지만 전날 Cursor Plugins 분석과 겹친다. `Lum1104/Understand-Anything`은 45,915 stars, MIT, 코드 지식 그래프라는 좋은 주제지만 5월 20일 글에서 codegraph와 토큰 절감형 개발 도구를 이미 다뤘다. `OpenMOSS/MOSS-TTS`는 2,627 stars, Apache-2.0, Python 음성 생성 모델 계열이라 VoxCPM 글과 유사하다. `meilisearch/meilisearch`는 57,856 stars의 검색 엔진으로 훌륭한 인프라 주제지만 오래된 성숙 프로젝트라 오늘의 “급부상 신호”보다는 상시 평가 글에 더 어울린다. 반면 `twentyhq/twenty`는 TypeScript daily에 보였고, GitHub API 기준 48,708 stars, 6,911 forks, 최근 push가 2026-05-30 23:11:56 UTC에 있었다. 기존 글과 중복되지 않으면서도 개발자, 플랫폼 엔지니어, 데이터 거버넌스 담당자가 함께 읽을 만한 실무 주제다.

## 저장소에서 확인한 사실

- Repository: [https://github.com/twentyhq/twenty](https://github.com/twentyhq/twenty)
- GitHub API 확인 시점 기준 stars: 48,708
- 주요 언어: TypeScript
- Forks: 6,911
- 라이선스: GitHub API는 `NOASSERTION`으로 표시한다. LICENSE 파일 첫머리에는 “대부분 GNU Affero General Public License, 단 일부 파일은 `/* @license Enterprise */` 주석으로 표시된 별도 상용 라이선스”라고 적혀 있다. 실제 도입 전에는 라이선스와 유지보수 상태를 확인해야 한다.
- 최근 활동: `pushed_at`은 2026-05-30T23:11:56Z, `updated_at`은 2026-05-31T00:01:07Z로 확인됐다.
- Release/Tag: GitHub Releases에는 `v2.8.0`, tags에는 `v2.8.3`, `v2.8.2`, `v2.8.1` 등이 보였다.
- Issue/PR 활동: open issues count는 140으로 확인됐고, 공개 PR 목록에는 필터된 뷰 초기화 버그 수정, optimistic input sanitizing, workflow select field 수정 같은 변경이 올라와 있었다.
- 공식 문서: README에서 [https://docs.twenty.com](https://docs.twenty.com) 문서를 직접 연결한다. Cloud, app development guide, self-hosting Docker Compose, local setup guide도 README에 노출되어 있다.

현재 공개된 README 기준으로 Twenty는 “The #1 Open-Source CRM”이라고 자신을 설명한다. 조금 더 실무적인 표현으로 옮기면, 고정된 CRM 화면을 제공하는 제품이라기보다 고객 데이터와 업무 객체를 직접 모델링하고, 그 위에 뷰·워크플로·에이전트·logic function을 올릴 수 있는 CRM 개발 플랫폼에 가깝다. README의 예제도 일반 사용자 기능보다 `npx create-twenty-app my-app`, `defineObject`, `FieldType`, `twenty app:publish --private` 같은 개발자 확장 흐름을 먼저 보여준다.

기술 스택도 CRM SaaS 소개 페이지와는 결이 다르다. README의 Stack 섹션에는 TypeScript, Nx, NestJS, BullMQ, PostgreSQL, Redis, React, Jotai, Linaria, Lingui가 명시되어 있다. 이 조합은 “영업 도구 하나 설치”가 아니라 프론트엔드, API 서버, 작업 큐, 관계형 데이터베이스, 캐시/큐 상태, 다국어 UI, 모노레포 운영을 함께 봐야 한다는 뜻이다.

## 왜 CRM을 오픈소스로 운영하려는가

CRM은 조직에서 생각보다 깊은 시스템이다. 영업 기회, 고객사, 담당자, 계약, 지원 이력, 캠페인 반응, 내부 메모, 견적, 파트너 관계가 모두 CRM 주변에 붙는다. 시간이 지나면 CRM은 단순한 주소록이 아니라 회사의 고객 지식 그래프가 된다. 문제는 이 데이터가 대부분 특정 SaaS의 객체 모델과 권한 모델에 갇힌다는 점이다.

대형 SaaS CRM은 안정적이고 생태계가 넓다. Salesforce, HubSpot, Dynamics 같은 도구는 관리자 기능, 마켓플레이스, 감사, 권한, 리포팅, 자동화, 외부 연동이 이미 잘 갖춰져 있다. 많은 조직에서는 이 안정성이 곧 비용 절감이다. 다만 제품이 정한 방식과 조직의 실제 업무 흐름이 어긋나기 시작하면, CRM은 빠르게 “아무도 좋아하지 않지만 모두가 입력해야 하는 시스템”이 된다. 커스텀 필드가 늘어나고, 워크플로가 겹치고, 데이터 정합성은 점점 운영자의 손에 의존한다.

Twenty가 겨냥하는 지점은 이 틈이다. 기술 팀이 CRM 객체를 코드로 정의하고, 비즈니스 요구가 바뀔 때 애플리케이션 릴리스처럼 변경하고, 필요하면 자체 인프라에 올려 데이터 주권을 가져갈 수 있게 한다. 이것은 모든 회사에 좋은 방향은 아니다. 오히려 CRM 운영을 소프트웨어 운영 문제로 바꾸기 때문에, 플랫폼 역량이 없는 팀에는 부담이 커질 수 있다. 그러나 이미 내부 어드민, 백오피스, 데이터 파이프라인, AI 에이전트 실험을 운영하는 팀이라면 이야기가 달라진다. CRM이 더 이상 닫힌 업무 화면이 아니라 고객 데이터 플랫폼의 한 레이어가 될 수 있다.

## 화면보다 먼저 봐야 할 아키텍처 경계

Twenty를 검토할 때 데모 화면부터 보면 판단이 흐려진다. CRM은 UI가 예쁘다고 성공하지 않는다. 입력 경로, 데이터 모델, 권한, 백업, 배치 작업, 외부 연동, 감사, 실패 복구가 맞아야 한다. GitHub 저장소 활동을 기준으로 보면 Twenty는 활발히 개발되고 있지만, 활발하다는 말은 동시에 변경이 자주 들어온다는 뜻이기도 하다. 프로덕션에서 운영하려면 어느 컴포넌트를 누가 책임질지 먼저 나눠야 한다.

![Twenty 도입 시 아키텍처와 운영 책임 경계](https://heracles-jo.github.io/assets/img/posts/github-trending-open-source-crm-twenty/architecture.svg)

입력 계층은 영업·마케팅·지원 담당자가 직접 입력하는 화면, 외부 폼, CSV/스프레드시트 import, 내부 API 연동으로 나뉜다. CRM 데이터 품질은 여기서 거의 결정된다. “회사명” 하나만 봐도 법인명, 브랜드명, 지점명, 계열사명이 뒤섞이기 쉽다. Twenty를 도입한다면 객체와 필드를 코드로 정의할 수 있다는 장점을 데이터 표준화 규칙과 함께 써야 한다. 자유 입력 필드만 늘리면 오픈소스 CRM을 쓰는 의미가 줄어든다.

처리 계층은 README가 말하는 objects, views, workflows, agents, logic functions의 영역이다. 여기서는 기능 동작보다 실패 모드를 더 먼저 봐야 한다. 워크플로가 중복 실행되면 고객에게 이메일이 두 번 나가는가. 에이전트가 잘못된 레코드를 찾으면 누가 승인하는가. 특정 view가 권한 없는 데이터를 노출할 가능성은 없는가. 내부 정책상 AI 연동이 고객 메모를 외부 모델로 보낼 수 있는가. CRM 자동화는 생산성을 올리지만, 잘못된 자동화는 고객 신뢰를 직접 훼손한다.

저장 계층은 PostgreSQL과 Redis/BullMQ 계열 작업 상태를 함께 봐야 한다. PostgreSQL 백업만 잘해도 충분하다고 생각하기 쉽지만, 실제 업무 자동화에서는 큐에 쌓인 작업, 재시도 중인 job, 실패한 workflow, 외부 API 호출 상태가 중요하다. 장애 복구 시 “DB는 복구됐는데 어제 오후의 후속 연락 워크플로가 어디까지 실행됐는지 모른다”는 상황이 생기면 운영자가 수동으로 고객 대응을 정리해야 한다. PoC 때부터 큐 지연, 실패 작업 재처리, idempotency, 재시도 정책을 확인해야 한다.

배포 계층은 Cloud와 self-hosting을 분리해서 판단해야 한다. Twenty Cloud는 인프라 운영 부담을 줄일 수 있다. 반대로 Docker Compose 기반 셀프호스팅은 데이터 주권과 커스터마이징 여지를 준다. 하지만 셀프호스팅은 “무료로 CRM을 쓴다”가 아니라 “CRM 운영 책임을 내부로 가져온다”에 가깝다. 백업, 보안 패치, 버전 업그레이드, 모니터링, 장애 대응, 라이선스 검토가 모두 비용이다.

관측성과 보안 경계는 처음부터 설계에 넣는 편이 낫다. CRM은 개인정보와 영업 기밀이 모이는 시스템이다. 로그인 성공률, API 오류율, workflow 실패율, queue latency, DB connection saturation, slow query, release version, migration duration 정도는 기본 지표로 잡아야 한다. 보안 쪽에서는 역할 기반 권한, 감사 로그, 데이터 export 권한, 외부 AI 연동 경로, SSO/SCIM 필요성, 백업 파일 암호화, 삭제 요청 처리 방식을 확인해야 한다. 특히 AGPL과 Enterprise 라이선스가 함께 언급되는 저장소이므로, 내부 수정·네트워크 서비스 제공·상용 기능 사용 범위를 법무/컴플라이언스와 함께 검토하는 절차가 필요하다.

## Salesforce 대체재인가, 내부 고객 운영 플랫폼인가

Twenty를 “Salesforce 대체재”라고만 보면 평가가 거칠어진다. Salesforce를 이미 깊게 쓰는 엔터프라이즈가 모든 영업 프로세스, 파트너 앱, 리포트, 권한, 감사 체계를 한 번에 Twenty로 옮기는 것은 현실적인 첫 단계가 아니다. 반대로 아직 CRM이 스프레드시트와 Notion, Airtable, 내부 어드민에 흩어져 있는 팀이라면 Twenty는 꽤 현실적인 선택지가 될 수 있다.

선택 기준은 기능 목록보다 조직의 변경 속도다. 고객 객체가 자주 바뀌고, 제품 주도 성장(PLG), 세일즈 어시스트, 고객 성공, 인보이스, 지원 이력을 한 데이터 모델로 묶고 싶다면 Twenty의 “build an app” 접근이 맞을 수 있다. CRM을 업무 앱처럼 버전 관리하고, 개발자가 객체·필드·뷰를 코드 리뷰로 바꾸며, 운영팀이 실제 현장의 입력 품질을 개선하는 구조다. 이 경우 Twenty는 CRM 제품이면서 동시에 내부 플랫폼이다.

반대로 표준적인 리드 관리, 파이프라인, 견적, 이메일 캠페인, 관리자 리포트만 필요하고 조직에 CRM 운영 전담자가 없다면 기존 SaaS가 낫다. 구매 비용은 더 들 수 있지만 장애 대응, 보안 인증, 생태계 통합, 사용자 교육 자료가 이미 제공된다. CRM은 다운타임보다 데이터 혼란이 더 무섭다. 내부 팀이 그 혼란을 감당할 수 없다면 오픈소스라는 이유만으로 옮기면 안 된다.

![Twenty 도입 판단표](https://heracles-jo.github.io/assets/img/posts/github-trending-open-source-crm-twenty/decision-matrix.svg)

Airtable, NocoDB, Baserow 같은 도구와 비교하면 Twenty는 더 CRM 지향적이다. 범용 테이블 앱은 빠르게 업무 데이터를 만들고 공유하기 좋지만, 고객 관계 관리의 권한·활동 이력·업무 자동화·영업 뷰가 깊어질수록 직접 만들어야 할 것이 많아진다. 반대로 Twenty는 CRM이라는 도메인을 기본값으로 가져가면서 개발 확장을 열어둔다. Supabase나 Appsmith, Retool과도 다르다. 그 도구들은 내부 앱과 백엔드 구성요소를 만드는 데 강하지만, CRM 도메인 모델을 제품 레벨로 제공하지는 않는다.

따라서 Twenty를 선택할 때의 질문은 “이것이 Salesforce보다 기능이 많은가”가 아니다. “우리 팀은 고객 데이터 운영을 코드와 플랫폼 운영 방식으로 가져올 준비가 되어 있는가”에 가깝다.

## 팀 규모별로 보는 현실적인 도입 경로

개인 개발자나 작은 사이드 프로젝트라면 Twenty는 CRM 학습과 내부 도구 실험에 좋다. Docker Compose로 셀프호스팅을 해 보고, 객체 정의와 view 구성을 만져 보며, 고객 데이터 모델링 감각을 익힐 수 있다. 다만 개인 프로젝트에서도 실제 고객 개인정보를 넣는 순간 이야기가 달라진다. 백업과 삭제 요청, 접근 제어를 갖추지 못했다면 테스트 데이터나 익명화된 데이터로 제한하는 편이 안전하다.

스타트업이나 소규모 B2B 팀에는 더 흥미롭다. 초기에는 HubSpot 무료 플랜, 스프레드시트, Notion CRM으로 버티다가 어느 순간 제품 사용 데이터와 영업 활동, 고객 성공 메모가 갈라진다. 이때 Twenty를 내부 고객 운영 플랫폼으로 두고, 제품 DB나 이벤트 파이프라인과 연동하는 PoC를 해볼 수 있다. 바로 전체 영업팀에 배포하기보다는 특정 세그먼트, 예를 들어 엔터프라이즈 리드 관리나 온보딩 고객 성공 흐름부터 시작하는 편이 낫다. 실패해도 되돌릴 수 있는 범위에서 데이터 모델과 workflow를 검증해야 한다.

엔터프라이즈나 플랫폼 팀은 더 보수적으로 접근해야 한다. Twenty가 GitHub Trending에 올랐고 releases/tags가 활발하다는 사실은 긍정적인 신호지만, 엔터프라이즈 도입의 충분조건은 아니다. SSO, 감사, 데이터 보존 정책, 백업 암호화, 네트워크 분리, 취약점 대응 프로세스, 라이선스 검토, 장애 대응 SLA, 운영자 교육까지 확인해야 한다. 이미 Salesforce나 Dynamics가 중심인 조직이라면 Twenty를 대체재로 바로 놓기보다 특정 내부 CRM성 앱, 파트너 관리, 연구개발 고객 인터뷰 DB, 사내 AI 에이전트용 고객 지식 베이스 같은 주변 영역에서 시작하는 편이 현실적이다.

플랫폼 팀 관점에서는 Twenty의 장점이 더 분명하다. CRM 변경을 티켓, 코드 리뷰, 배포, 마이그레이션, 관측성의 흐름 안에 넣을 수 있기 때문이다. 하지만 이것은 동시에 플랫폼 팀이 영업 운영의 병목이 될 수 있다는 뜻이다. 모든 필드 추가와 뷰 변경이 개발 배포를 기다리게 되면 현업은 다시 스프레드시트로 빠져나간다. 좋은 도입 모델은 “핵심 객체와 보안 경계는 코드로 관리하고, 현업이 안전하게 조정할 수 있는 영역은 제품 설정으로 남기는 것”이다.

## PoC에서 꼭 망가뜨려 봐야 할 것들

Twenty PoC는 예쁜 화면 확인으로 끝내면 안 된다. 최소한 실제 고객 데이터 흐름과 비슷한 더미 데이터를 넣고, 일부러 실패를 만들어 봐야 한다.

첫 번째는 데이터 모델 변경이다. 회사, 담당자, 거래, 활동 같은 기본 객체 외에 조직 고유 객체를 정의하고, 필드 타입을 바꾸거나 삭제할 때 기존 데이터와 view가 어떻게 반응하는지 봐야 한다. CRM에서는 “필드 하나 변경”이 리포트, 자동화, 외부 연동을 동시에 깨뜨릴 수 있다.

두 번째는 성능과 검색이다. 고객 레코드가 수천 건일 때와 수십만 건일 때 사용자가 느끼는 지연은 다르다. 목록 view, 필터, 정렬, 검색, import, bulk update, API pagination을 확인해야 한다. PostgreSQL slow query와 인덱스 전략도 봐야 한다. CRM 사용자는 몇 초만 느려져도 데이터를 다른 곳에 적기 시작한다.

세 번째는 workflow 실패 복구다. 외부 이메일 API, Slack, billing system, 제품 DB와 연결된 자동화가 실패했을 때 재시도와 중복 실행이 어떻게 처리되는지 확인해야 한다. 고객에게 가는 메시지는 idempotency가 없으면 위험하다. 같은 알림이 두 번 발송되거나, 반대로 실패했는데 성공으로 표시되면 신뢰가 깨진다.

네 번째는 권한과 감사다. 영업 담당자가 다른 팀의 고객을 볼 수 있는지, 관리자 권한이 어디까지인지, export 권한을 제한할 수 있는지, 삭제된 레코드를 복구하거나 추적할 수 있는지 확인해야 한다. AI agent 기능을 검토한다면 에이전트가 접근 가능한 데이터 범위, 프롬프트/응답 로그 보존, 외부 모델 전송 여부를 별도로 점검해야 한다.

다섯 번째는 롤백이다. Twenty 버전을 올렸는데 migration이 실패하거나 UI가 깨졌을 때 어느 시점으로 되돌릴 수 있는지 실제로 연습해야 한다. DB 백업, 파일/환경 변수, queue 상태, 배포 이미지 버전을 함께 묶어 복구해야 한다. 릴리스 노트와 tags가 존재한다는 사실은 출발점일 뿐이고, 우리 환경에서 안전하게 되돌릴 수 있는지는 별개의 문제다.

마지막으로 유지보수 가능성이다. GitHub 저장소 활동을 기준으로 보면 Twenty는 활발하지만, 활발한 프로젝트는 이슈와 PR도 빠르게 변한다. 내부에서 누가 upstream 변경을 추적할지, 보안 패치를 얼마나 빨리 적용할지, 커스텀 앱이 버전 업그레이드와 충돌할 때 누가 고칠지 정해야 한다. 오픈소스 도입 실패의 상당수는 기능 부족이 아니라 주인 없는 운영에서 온다.

## 장점과 리스크를 같은 문장 안에서 봐야 한다

Twenty의 가장 큰 매력은 CRM을 개발 가능한 표면으로 열어둔다는 점이다. 객체와 필드를 코드로 정의하고, 앱을 publish하며, workflow와 agent를 얹는 모델은 기술 조직에 익숙하다. 고객 운영을 제품 개발의 일부로 다루는 팀에는 큰 장점이다. 데이터 주권이 중요한 조직에서는 self-hosting 가능성도 매력적이다. PostgreSQL 기반이라는 점은 데이터 엔지니어링과 백업 전략을 세우기 비교적 친숙하게 만든다.

하지만 같은 이유로 리스크도 생긴다. CRM을 코드로 확장할 수 있으면 개발팀이 CRM 변경의 책임자가 된다. 영업 운영, 고객 성공, 보안, 법무, 데이터 팀 사이의 조율 없이 기능만 붙이면 내부 플랫폼이 빠르게 복잡해진다. AGPL과 Enterprise 파일이 함께 언급되는 라이선스 구조도 가볍게 넘길 수 없다. 특히 네트워크를 통해 제공하는 소프트웨어를 수정해 운영하는 경우 AGPL 의무가 어떤 범위로 적용되는지 검토가 필요하다. GitHub API가 라이선스를 `NOASSERTION`으로 표시한다는 점도 자동화된 컴플라이언스 도구에서 별도 처리가 필요하다는 뜻이다.

운영 리스크는 세 가지가 크다. 첫째, 데이터 품질 리스크다. CRM은 잘못된 데이터가 누적되면 나중에 고치기 어렵다. 둘째, 자동화 리스크다. workflow와 agent가 고객 커뮤니케이션에 직접 영향을 주면 실패 비용이 커진다. 셋째, 업그레이드 리스크다. 활발한 저장소는 좋은 신호지만, 커스텀 확장이 많을수록 upstream 변화와 충돌할 가능성이 높다.

그래서 내 판단은 이렇다. Twenty는 “당장 전사 CRM을 갈아엎는 도구”라기보다, 고객 데이터 운영을 제품처럼 다루려는 팀의 PoC 후보로 적합하다. 특히 내부 배치 작업, 고객 성공 운영, 파트너 관리, AI 에이전트가 읽을 수 있는 고객 지식 베이스처럼 핵심 매출 프로세스보다 한 단계 주변에 있는 영역부터 보는 편이 안전하다. 여기서 데이터 모델과 운영 경계가 맞는지 확인한 뒤, 점진적으로 더 중요한 CRM 업무로 확장하는 방식이 현실적이다.

## 운영 설계 관점에서 추가로 봐야 할 경계

Twenty를 고객 데이터 플랫폼 후보로 본다면, 가장 먼저 정해야 할 것은 “무엇을 Twenty 안에 넣고, 무엇을 밖에 남길 것인가”다. CRM은 조직 안의 거의 모든 고객 관련 데이터가 모일 수 있는 유혹적인 장소다. 하지만 모든 데이터를 CRM에 넣는 순간 CRM은 느려지고, 권한 모델은 복잡해지며, 데이터 품질 책임도 흐려진다. 제품 이벤트 원본, billing 원장, 지원 티켓 원본, 마케팅 캠페인 로그까지 전부 Twenty가 직접 소유하게 만들기보다는, Twenty는 업무자가 판단하고 행동해야 하는 고객 운영 레이어로 두는 편이 안전하다.

데이터 동기화 방향도 명확해야 한다. 고객 회사와 담당자 같은 마스터 데이터는 어디가 기준 시스템인지 정해야 한다. Twenty에서 수정한 회사명이 제품 DB로 흘러가야 하는지, 제품 DB의 account 정보가 Twenty를 덮어써야 하는지, 충돌이 생기면 누가 승인하는지 정하지 않으면 오픈소스 CRM은 곧 또 하나의 데이터 사일로가 된다. 특히 기존 CRM이나 billing system과 병행하는 단계에서는 양방향 동기화를 쉽게 열지 않는 편이 좋다. 처음에는 단방향 복제와 수동 승인 흐름으로 시작하고, 데이터 품질이 안정된 뒤 자동화를 늘리는 방식이 더 현실적이다.

AI agent 기능을 검토한다면 보안 경계는 더 중요해진다. 고객 메모, 계약 조건, 영업 기회, 지원 이력은 모두 민감 정보다. 에이전트가 이 데이터를 읽고 요약하거나 다음 액션을 추천할 수 있다면 생산성은 올라간다. 그러나 같은 기능이 잘못 설계되면 권한 없는 사용자가 고객 정보를 간접적으로 조회하는 경로가 될 수 있다. 에이전트는 사용자의 권한을 그대로 상속해야 하고, 외부 모델 호출 여부, 프롬프트 로그 보존, 응답 저장 위치를 명확히 해야 한다. “AI가 추천한 내용”과 “사람이 승인한 고객 커뮤니케이션”도 구분되어야 한다.

릴리스 운영도 PoC 단계에서 확인해야 한다. Twenty는 활발히 개발되는 프로젝트이고 tags/releases가 존재한다. 이것은 긍정적이지만, self-hosting 환경에서는 업그레이드 책임이 내부로 온다는 뜻이다. CRM은 업무 시간이 긴 시스템이다. 영업팀이 월말 마감 중일 때 migration이 실패하면 기술 장애가 아니라 매출 운영 장애가 된다. 따라서 스테이징 환경, 데이터 마이그레이션 dry-run, 백업 복구 리허설, 버전 고정, 변경 공지 절차가 필요하다. 오픈소스 제품을 운영할 때 가장 위험한 선택은 `latest` 이미지를 습관적으로 따라가는 것이다.

## Twenty PoC를 4주로 설계한다면

첫 주는 데이터 모델링에 써야 한다. 회사, 담당자, 거래, 활동 같은 기본 객체 외에 우리 조직만의 고객 운영 객체를 정의한다. 예를 들어 B2B SaaS라면 workspace, subscription, onboarding milestone, health score, renewal risk 같은 객체가 필요할 수 있다. 이 객체를 Twenty 안에 모두 만들지, 일부는 외부 시스템에서 참조만 할지 결정한다. 이 단계의 산출물은 화면이 아니라 데이터 사전과 ownership matrix여야 한다.

둘째 주는 동기화와 권한이다. 더미 데이터로 import와 update를 반복하고, 중복 회사명, 잘못된 이메일, 퇴사한 담당자, 병합된 고객사를 일부러 넣어 본다. 권한 그룹을 만들고 영업, 고객 성공, 관리자, 읽기 전용 사용자로 나누어 실제로 볼 수 있는 레코드가 기대와 맞는지 확인한다. CRM은 기능보다 권한 오류가 더 비싼 시스템이다. 한 팀의 고객 정보가 다른 팀에 노출되면 신뢰 회복이 어렵다.

셋째 주는 workflow와 실패 복구다. 고객 온보딩 알림, renewal risk 알림, Slack 알림, 외부 API 업데이트 같은 간단한 자동화를 만들고 일부러 실패시킨다. 외부 API가 500을 반환하면 재시도하는지, 같은 알림이 두 번 나가지 않는지, 실패 job을 운영자가 다시 실행할 수 있는지 확인한다. 이 단계에서 BullMQ/Redis 계열 작업 상태와 PostgreSQL 데이터 상태가 어떻게 맞물리는지 봐야 한다.

넷째 주는 운영 전환 판단이다. 백업을 만들고 실제로 복구해 본다. 버전을 올렸다가 되돌려 본다. audit log와 export 권한을 점검한다. 보안팀이나 법무팀과 라이선스 검토를 진행한다. 이때 “Twenty를 도입한다/안 한다”보다 더 중요한 결론은 “어떤 범위까지 Twenty가 책임질 수 있는가”다. 핵심 전사 CRM은 아직 이르지만 파트너 관리나 고객 성공 실험에는 적합하다는 식의 단계적 결론이 더 좋은 PoC 결과다.

## 운영 체크리스트

- 고객 데이터의 기준 시스템을 정하고 Twenty와 외부 시스템의 동기화 방향을 명시한다.
- 핵심 객체와 필드의 ownership을 영업·고객성공·플랫폼·데이터 팀 사이에서 나눈다.
- workflow는 idempotency와 재시도, 실패 job 재처리 방법을 확인한 뒤 운영에 넣는다.
- AI agent가 읽을 수 있는 데이터 범위와 외부 모델 전송 여부를 권한 모델에 포함한다.
- self-hosting은 백업, 복구, migration dry-run, 버전 고정, 보안 패치 절차를 갖춘 뒤 검토한다.
- AGPL 및 Enterprise 라이선스 범위를 법무와 함께 확인한다.
- 기존 CRM과 병행할 경우 양방향 자동 동기화보다 단방향 복제와 승인 흐름부터 시작한다.
- 도입 성공 기준을 “기능 수”가 아니라 데이터 품질, 업무 채택률, 자동화 실패율, 복구 가능성으로 잡는다.

## 개인적인 결론: CRM을 구매할지, 운영할지의 질문

Twenty가 오늘 흥미로웠던 이유는 CRM이라는 오래된 범주를 다시 개발자와 플랫폼 엔지니어의 언어로 번역하고 있기 때문이다. 고객 객체를 코드로 정의하고, workflow와 agent를 붙이며, self-hosting까지 열어두면 CRM은 더 이상 영업팀만의 도구가 아니다. 고객 데이터 플랫폼, 내부 운영 앱, AI 에이전트의 업무 컨텍스트가 만나는 지점이 된다.

다만 그만큼 책임도 커진다. Twenty를 고르는 팀은 CRM을 “구매”하는 대신 일부를 “운영”하기로 선택하는 셈이다. 이 선택이 맞는 조직도 있고, 그렇지 않은 조직도 있다. 개발자 친화적인 확장성과 데이터 주권이 SaaS의 안정성보다 중요하다면 PoC를 해볼 만하다. 표준 프로세스, 검증된 생태계, 낮은 운영 부담이 더 중요하다면 기존 CRM을 쓰는 편이 낫다.

오늘 기준 GitHub Trending 신호와 저장소 활동만 놓고 보면 Twenty는 충분히 분석할 가치가 있는 프로젝트다. 하지만 고객 데이터는 실험 비용이 비싸다. 화면 데모보다 백업, 권한, workflow 실패, 라이선스, 업그레이드부터 검증하자. 그 과정을 통과하면 Twenty는 단순한 CRM 대체재가 아니라, AI 시대 고객 운영 플랫폼을 직접 설계하려는 팀의 좋은 출발점이 될 수 있다.
