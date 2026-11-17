---
title: "임베디드 스프레드시트 엔진: Univer 도입·검증 기준"
description: "Univer의 수식 엔진·명령 모델·Headless 처리를 분석하고, SaaS에 스프레드시트를 내장할 때 계산 정확도·권한·협업·라이선스를 검증하는 기준을 정리한다."
author: heracles-jo
date: 2026-11-18 08:12:00 +0900
categories: [Developer Tools, Data Engineering]
tags: [univer, spreadsheet-engine, formula-engine, embedded-office, data-governance]
image:
  path: https://heracles-jo.github.io/assets/img/posts/univer-embedded-spreadsheet-engine/cover.svg
  alt: "Univer 임베디드 스프레드시트 엔진의 계산·편집·검증 경계"
---

SaaS 제품에 표 형태의 입력 화면을 넣는 일은 어렵지 않다. 진짜 난도는 사용자가 Excel처럼 수식을 쓰고, 행과 열을 삽입하고, 필터와 정렬을 적용하며, 여러 사람이 동시에 편집한 결과를 서버 계산과 파일 내보내기까지 일관되게 유지해야 할 때 올라간다. 데이터 그리드에 기능을 하나씩 붙이다 보면 어느 순간 제품팀은 UI 컴포넌트가 아니라 **스프레드시트 계산·편집 엔진**을 직접 만들고 있다는 사실을 깨닫는다.

[dream-num/univer](https://github.com/dream-num/univer)는 Sheets와 Docs를 제품 안에 조립할 수 있는 Office SDK다. 공개 저장소에는 콘텐츠 모델, 수식·렌더링 엔진, 명령과 undo/redo, 플러그인·의존성 관리, Facade API, Sheets·Docs 편집 기능이 Apache-2.0으로 제공된다. 실시간 협업과 Office 파일 변환, 일부 고급 기능, AI SDK는 별도 Server SDK·상용 모듈 영역이다. 따라서 도입 질문은 “웹에서 Excel처럼 보이는가”가 아니다. **우리 제품의 계산 규칙과 권한, 변경 이력, 파일 호환성을 어느 계층까지 Univer에 맡기고 어떤 부분을 직접 소유할 것인가**가 핵심이다.

2026년 11월 18일 08시 19분 KST 전후 [GitHub Trending daily](https://github.com/trending?since=daily)에서 Univer는 `1,776 stars today`로 표시됐다. [GitHub 저장소 API와 공개 메타데이터](https://github.com/dream-num/univer) 확인 시점에는 28,880 stars, 2,616 forks, Apache-2.0 라이선스였고 11월 17일까지 수식 wildcard, 혼합 셀 정렬, 접근성 focus 처리 관련 커밋이 이어졌다. 최신 정식 릴리스 `v1.5.2`는 11월 16일 공개됐다. 수치는 공개 페이지의 시점별 스냅샷이며 제품 적합성이나 계산 정확도를 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색 유입 데이터에 접근하지 못했으므로 선정 근거로 사용하지 않았다.

## 후보 비교: 문서 생성보다 “제품 안의 계산 표면”이라는 질문을 분리했다

최근 글에서 Univer를 여러 번 후보로 검토했지만 기존 [OfficeCLI 문서 자동화 글](/posts/github-trending-officecli-office-document-automation/)과 가깝다는 이유로 보류했다. 이번에는 중심 질문을 오피스 파일 생성에서 분리했다. OfficeCLI가 `.xlsx`를 만들고 렌더링하고 고치는 자동화 런타임이라면, Univer의 별도 검색 의도는 **사용자가 머무는 SaaS 화면 안에 편집·수식·계산·undo를 가진 스프레드시트 엔진을 내장하는 방법**이다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Univer](https://github.com/dream-num/univer) | daily 1,776, API 28,880 stars, Apache-2.0, v1.5.2 | 문서 생성기가 아니라 임베디드 수식·편집 엔진의 정확도와 제품 경계를 다루는 독립 검색 의도로 선택했다. |
| [Claude-BugHunter](https://github.com/elementalsouls/Claude-BugHunter) | daily 1,007, API 9,179 stars, 코드 MIT·콘텐츠 CC BY 4.0 | 승인된 보안 연구 도구지만 Cloudflare Security Audit Skill과 Codex Security 글의 검증·권한 질문에 가깝다. |
| [Plannotator](https://github.com/backnotprop/plannotator) | daily 691, API 13,051 stars, Apache-2.0 | 비동기 주석과 사람 검토 UX는 유효하지만 설계 리뷰·AI 코드 리뷰 클러스터와 직접 경쟁한다. |
| [LoopForge](https://github.com/Tencent/LoopForge) | daily 590, API 3,091 stars, README상 MIT | 코딩 에이전트 SOP·sandbox·human gate는 Orca·OpenBot·승인 워크플로의 중심 논지와 겹친다. |
| [Arcane](https://github.com/getarcaneapp/arcane) | daily 654, API 9,302 stars | Docker 관리 UI는 실용적이지만 Coolify·셀프호스팅 운영 글과 검색 의도를 분리하기 어렵다. |

Univer를 다시 선택할 수 있었던 이유는 프로젝트 범위도 달라졌기 때문이다. 현재 README는 Web SDK의 공개 영역과 Server·AI SDK의 별도 라이선스 영역을 명시하고, 브라우저 편집뿐 아니라 Node.js Headless 처리, command composition, Facade API와 이벤트를 강조한다. 최신 커밋도 `XLOOKUP`·`XMATCH`·`SEARCH` wildcard와 혼합 셀 정렬처럼 “표가 보인다”보다 “Excel 사용자가 기대하는 의미가 맞는가”에 가까운 문제를 고친다. 장기 가치는 AI 오피스라는 이름보다 이 호환성 작업에 있다.

## 그리드와 스프레드시트 엔진의 경계는 계산 상태에서 갈린다

일반 데이터 그리드는 행과 열을 표시하고 편집 이벤트를 애플리케이션에 넘기는 데 강하다. 정렬, 필터, 가상 스크롤, 셀 에디터, 서버 페이지네이션이면 많은 관리 화면을 만들 수 있다. 반면 스프레드시트는 셀 값만 저장하지 않는다. 수식 참조, 이름 정의, 병합, 조건부 서식, 데이터 검증, 숨김 행·열, 필터 범위, 부동 이미지, 선택 상태, undo stack이 서로 영향을 준다.

예를 들어 필터 범위 안에 행을 삽입하면 원본 셀 모델뿐 아니라 필터 범위와 수식 참조, 조건부 서식, 차트 source가 함께 이동해야 한다. undo는 방금 삽입한 행만 지우는 것이 아니라 각 기능이 만든 변경을 역순으로 복원해야 한다. Univer의 command system은 기능별 mutation과 undo 데이터를 하나의 명령으로 조합한다. 이 구조는 플러그인 확장성을 주지만, 커스텀 기능도 같은 변경 계약을 따라야 한다는 뜻이다.

![Univer를 제품에 내장할 때 UI·명령·계산·저장 책임을 나누는 아키텍처](https://heracles-jo.github.io/assets/img/posts/univer-embedded-spreadsheet-engine/architecture.svg)

제품 아키텍처에서는 네 계층을 분리하는 편이 안전하다.

1. **표현 계층**은 캔버스 렌더링, selection, 키보드·IME, 접근성, 모바일 입력을 담당한다.
2. **편집 계층**은 command, mutation, undo/redo, plugin 간 변경 조합을 소유한다.
3. **계산 계층**은 수식 파싱, dependency graph, 재계산 순서, 오류 값과 Excel 호환 의미를 책임진다.
4. **애플리케이션 계층**은 사용자 권한, 업무 데이터, 승인 상태, 저장 API와 감사 로그를 소유한다.

가장 흔한 실패는 네 번째 계층을 스프레드시트 UI에 맡기는 것이다. 셀을 편집할 수 있다는 사실이 해당 업무 객체를 변경할 권한이 있다는 뜻은 아니다. 가격표의 `B12`가 실제로는 계약 할인율이라면 저장 전 도메인 권한과 유효성 검사를 다시 거쳐야 한다. Univer snapshot은 편집 상태의 표현이지, 애플리케이션의 권위 있는 권한 모델을 대체하지 않는다.

## 수식 호환성은 함수 개수보다 의미 회귀로 검증해야 한다

스프레드시트 엔진 비교표에는 보통 지원 함수 수가 먼저 나온다. 그러나 운영에서 더 위험한 것은 미지원 함수보다 **지원한다고 생각한 함수가 다른 의미로 계산되는 경우**다. 최근 Univer 커밋에서 `XLOOKUP`과 `XMATCH`의 match mode에 따라 `?`와 `*`를 literal 또는 wildcard로 읽는 동작을 수정한 사례가 이를 보여 준다. 같은 문자열과 수식이 버전 전후에 다른 행을 반환할 수 있다.

따라서 PoC에는 업무 샘플을 복사한 workbook보다 의도적으로 작은 formula corpus가 필요하다.

- exact·approximate·wildcard lookup과 중복 키
- 빈 셀, 빈 문자열, `0`, `FALSE`, 오류 값의 구분
- 날짜 serial, 시간대, locale별 숫자·날짜 입력
- 절대·상대·혼합 참조와 행·열 삽입 후 참조 이동
- 범위 교차, spill, 이름 정의, 순환 참조
- 혼합 타입 정렬과 필터, 대소문자·Unicode 문자열
- 대량 dependency graph에서 부분 재계산과 전체 재계산 결과 동등성

각 fixture는 Excel 또는 조직이 기준으로 삼는 엔진의 기대 결과와 오류 코드를 고정해야 한다. UI screenshot 비교만으로는 부족하다. 셀 값, 타입, formula AST 또는 정규화된 수식, dependency, recalc 결과를 구조적으로 대조해야 한다. [NL-to-SQL 정확도 검증 글](/posts/nvidia-auto-ontology-nl-to-sql-validation/)에서 실행 성공과 의미 정확도를 나눴듯, 스프레드시트도 “수식이 오류 없이 계산됐다”와 “업무상 같은 답이 나왔다”를 분리해야 한다.

버전 업그레이드 gate도 동일하다. 최신 버전이 메모리를 줄이고 함수를 고쳤다는 release note만 보고 올리지 않는다. golden workbook을 구버전과 신버전에서 계산하고, 달라진 셀을 함수·타입·의존성별로 분류한다. 의도된 수정이라도 기존 사용자가 그 동작에 의존했다면 데이터 migration 또는 재승인이 필요할 수 있다.

## Headless 처리는 서버 권위 계산이 아니라 또 하나의 런타임이다

Univer는 브라우저 UI 없이 Node.js에서 콘텐츠 모델, command, calculation을 재사용하는 Headless 경로를 제공한다. 견적서 생성, 대량 workbook 변환, 저장 전 검증, 백그라운드 재계산에는 매력적이다. 브라우저와 서버가 같은 모델을 공유하면 “클라이언트에서 보인 값”과 “서버가 저장한 값”의 차이를 줄일 수 있다.

하지만 같은 패키지를 쓴다고 자동으로 동일한 결과가 보장되지는 않는다. 브라우저와 Node 런타임 버전, locale, timezone, plugin 목록, Worker 구성, workbook snapshot version이 다르면 결과가 갈릴 수 있다. 공개 README 기준 Headless Univer는 Node.js 18.17 이상을 지원하지만, 저장소 자체 개발 환경은 Node.js 22.18 이상을 요구한다. 운영 이미지는 SDK 버전뿐 아니라 runtime과 plugin manifest까지 고정해야 한다.

또한 서버 Headless 엔진에 최종 권위를 줄지 결정해야 한다. 재무·계약처럼 결과 책임이 큰 영역에서는 다음 세 가지 중 하나를 명시적으로 택해야 한다.

| 계산 모델 | 장점 | 주요 위험 | 적합한 경우 |
|---|---|---|---|
| 브라우저 계산 우선 | 빠른 상호작용, 서버 비용 감소 | 조작된 client 결과, 버전·locale drift | 초안·시뮬레이션, 저장 전 서버 검증이 있는 경우 |
| 서버 재계산 우선 | 권위 있는 결과와 감사 경계가 명확 | 지연, 동시성, 대형 workbook 비용 | 견적·정산·승인처럼 저장 결과가 중요할 때 |
| 도메인 서비스 계산 | 업무 규칙을 코드·DB에서 독립 관리 | 스프레드시트 수식과 이중 구현 | 세금·가격·권한 등 핵심 규칙을 셀 수식에 맡기면 안 될 때 |

대부분의 제품은 세 번째를 중심에 두고 첫째와 둘째를 보조로 쓰는 편이 낫다. 스프레드시트는 사용자가 가정과 계산을 탐색하는 강력한 표면이지만, 모든 업무 규칙의 단일 진실 원천이 되면 셀 위치와 수식이 API 계약처럼 굳어진다.

## 협업·파일 변환·AI는 공개 코어와 같은 구매 단위가 아니다

Univer의 공개 저장소는 Web SDK 코어를 Apache-2.0으로 제공한다. 그러나 README는 Server SDK의 실시간 협업·편집 이력·Office import/export와 AI SDK 확장을 별도 배포·라이선스로 설명한다. 공개 demo가 보여 주는 기능 전체를 오픈소스 기본 구성으로 가정하면 견적과 아키텍처가 틀어진다.

도입 전에는 기능 목록을 세 열로 다시 작성해야 한다.

- 공개 패키지만으로 가능한 기능
- 별도 상용 plugin 또는 native binding이 필요한 기능
- 서버·운영 서비스를 직접 구현해야 하는 기능

특히 `.xlsx` round-trip과 협업은 “나중에 붙이는 옵션”으로 보기 어렵다. 기존 Excel 파일을 가져와 편집하고 다시 내보내야 한다면 pivot, chart, external link, custom metadata, OLE, formula compatibility가 제품 계약에 포함된다. 실시간 공동 편집이 필요하면 충돌 해결뿐 아니라 사용자 identity, 문서 ACL, presence, version history, selective undo, offline reconnect를 함께 운영해야 한다.

AI 연결도 같은 원칙을 따른다. 에이전트가 Facade API로 셀을 수정할 수 있다는 것은 편리하지만, 사용자와 같은 권한으로 모든 workbook을 읽고 쓰게 해서는 안 된다. [통합 워크스페이스 권한 그래프 글](/posts/macro-unified-workspace-permission-graph/)에서 다룬 것처럼 문서·사용자·채널·도구의 권한을 교차 계산해야 한다. 에이전트에는 workbook 전체보다 허용된 range와 operation을 주고, formula·data validation·외부 링크 변경은 별도 승인을 거치는 편이 안전하다.

## 제품 통합에서 먼저 드러나는 실패 모드

첫째는 **snapshot을 데이터베이스처럼 쓰는 것**이다. workbook 전체 JSON만 저장하면 시작은 빠르지만 부분 조회, 권한 필터, schema migration, 감사 diff가 어려워진다. snapshot은 편집 재개와 호환성용으로 보존하되, 업무 엔티티는 별도 구조화 모델과 stable ID를 가져야 한다.

둘째는 **cell address를 업무 식별자로 쓰는 것**이다. `B12`는 행 삽입과 정렬로 의미가 바뀐다. 주문 ID, 항목 ID, metric ID를 별도로 보존하고 화면 위치는 projection으로 다뤄야 한다. 셀 주석이나 숨은 열에 ID를 넣는 우회는 export·copy/paste에서 쉽게 손실된다.

셋째는 **undo를 승인 취소로 오해하는 것**이다. 편집기의 undo stack은 로컬 사용성 기능이다. 이미 서버에 승인·전송·결제된 업무 이벤트를 되돌리는 보상 트랜잭션과는 다르다. command history와 도메인 event log를 분리해야 한다.

넷째는 **대형 workbook 성능을 첫 화면 렌더링만으로 평가하는 것**이다. 실제 병목은 대량 paste, dependency invalidation, volatile formula, sort/filter, undo memory, collaboration patch, import/export에서 나타난다. p50만 보지 말고 최악 fixture의 p95와 메모리 peak, main-thread blocking을 측정해야 한다.

다섯째는 **접근성과 IME를 마지막에 붙이는 것**이다. 스프레드시트는 키보드 탐색과 편집 모드 전환이 복잡하다. 최신 커밋에 focus-visible 수정이 들어간 사실도 이 영역이 지속적인 호환성 작업임을 보여 준다. 한국어 조합 중 Enter·Tab·blur, screen reader의 셀 좌표·값 읽기, 고대비·축소 동작을 초기에 시험해야 한다.

## PoC는 데모 workbook이 아니라 경계 계약을 측정한다

2~3주 PoC라면 제품의 가장 복잡한 Excel 파일부터 가져오지 않는다. 먼저 계산·편집·저장·권한을 분리해 작은 fixture를 만들고, 그 다음 실제 업무 workbook 10~20개를 추가한다.

![Univer 도입 PoC에서 계산·편집·권한·운영을 함께 판정하는 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/univer-embedded-spreadsheet-engine/decision-gate.svg)

| 검증 영역 | 최소 측정값 | 중단 또는 보완 조건 |
|---|---|---|
| 수식 정확도 | golden formula corpus, 오류 값, 버전 전후 diff | 핵심 계산의 차이를 함수·타입·버전으로 설명하지 못함 |
| 구조 변경 | 행·열 삽입, sort/filter, merge, undo 후 참조 무결성 | 화면은 정상이나 formula·validation·chart 범위가 어긋남 |
| 저장·복구 | snapshot round-trip, schema migration, crash recovery | 저장 성공 후 다시 열었을 때 의미 또는 undo 기준점이 손실됨 |
| 성능 | 초기 렌더, paste, recalc, sort, export의 p50·p95와 memory | 실제 fixture에서 main thread 장기 정지 또는 메모리 폭증 |
| 권한 | range·operation별 허용, server 재검증, agent dry-run | 숨은 셀·Facade API·Headless 경로로 UI 권한을 우회함 |
| 협업 | 동시 편집, reconnect, selective undo, version history | 충돌 후 누가 무엇을 바꿨는지 재구성할 수 없음 |
| 파일 호환 | 대표 XLSX import/export와 실제 Office 대조 | 계산은 맞아도 chart·pivot·metadata가 조용히 손실됨 |
| 라이선스·비용 | 공개·상용 기능 매핑, 서버·native 구성, upgrade 비용 | PoC 핵심 기능이 별도 모듈임을 배포 직전에 발견함 |

테스트 순서는 정적 fixture, 브라우저 편집, Headless 재계산, 파일 round-trip, 협업 순이 좋다. 앞 단계의 의미가 안정되지 않은 상태에서 협업을 붙이면 결과 차이가 계산 엔진인지 동기화인지 구분하기 어렵다. [컴퓨터 사용 에이전트 평가 글](/posts/cua-computer-use-agent-evaluation/)에서 시작 상태와 evaluator를 먼저 고정했듯, 여기서도 workbook snapshot, plugin manifest, runtime, locale, 기대 결과를 고정해야 한다.

Univer가 적합한 팀은 제품 자체가 편집 가능한 표와 계산을 핵심 경험으로 제공하는 경우다. 예산·견적·계획·재고·모델링·교육·데이터 앱처럼 사용자가 셀을 통해 가정을 바꾸고 결과를 즉시 확인해야 한다면 그리드보다 높은 수준의 엔진이 필요하다. 반대로 단순 CRUD 표, 서버가 계산한 결과 조회, 제한된 inline edit라면 데이터 그리드와 도메인 API가 더 단순하고 안전하다.

Univer의 강점은 스프레드시트 UI 한 장이 아니라 콘텐츠 모델, command·undo, 수식 계산, rendering, Facade API를 조립 가능한 엔진으로 제공한다는 데 있다. 동시에 그 범위가 넓기 때문에 공개 코어와 상용 계층, 편집 상태와 업무 데이터, client 계산과 서버 권위, AI 도구와 사용자 권한을 분리해야 한다. 도입 성공은 Excel처럼 보이는 데모가 아니라 **버전이 바뀌어도 같은 업무 계산을 설명할 수 있고, 사용자의 편집 자유가 제품의 데이터·권한 계약을 깨뜨리지 않는 상태**로 판단하는 편이 맞다.

## 1차 자료와 확인 범위

- [Univer 저장소와 README](https://github.com/dream-num/univer)
- [Univer v1.5.2](https://github.com/dream-num/univer/releases/tag/v1.5.2)
- [Univer v1.5.0 release notes](https://github.com/dream-num/univer/releases/tag/v1.5.0)
- [공개 패키지와 상용 SDK 범위](https://github.com/dream-num/univer#open-source-and-commercial-extensions)
- [Headless 시작 가이드](https://docs.univer.ai/guides/sheets/getting-started/node)
- [Facade API reference](https://docs.univer.ai/reference/classes/univer)
- [Security Policy](https://github.com/dream-num/univer/blob/dev/SECURITY.md)
- [Apache-2.0 LICENSE](https://github.com/dream-num/univer/blob/dev/LICENSE)
- [최근 commits](https://github.com/dream-num/univer/commits/dev/)
- [공개 issues](https://github.com/dream-num/univer/issues)

Trending·저장소 수치는 2026년 11월 18일 08시 19분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
