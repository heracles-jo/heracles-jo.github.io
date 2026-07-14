---
title: "Flowsint와 OSINT 그래프 조사 플랫폼"
description: "2026년 6월 3일 GitHub Trending에서 Flowsint가 보여준 오픈소스 OSINT 그래프 조사, 위협 인텔리전스, 윤리적 정찰 자동화와 운영 리스크를 IT 전문가 관점에서 분석합니다."
author: heracles-jo
date: 2026-06-03 07:25:00 +0900
categories: [Cybersecurity, Open Source]
tags: [github-trending, flowsint, osint, threat-intelligence, graph-database, cybersecurity, neo4j, privacy]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-osint-graph-flowsint/cover.svg
  alt: Flowsint를 중심으로 도메인, IP, ASN, 소셜 계정, 자동 enrichers, 검증 워크플로가 그래프로 연결되는 OSINT 조사 플랫폼 흐름을 설명하는 커버 이미지
---

## 오늘의 GitHub Trending 신호: OSINT가 스프레드시트에서 그래프 운영으로 이동한다

2026년 6월 3일 오전 KST 기준으로 GitHub Trending daily와 weekly를 확인하면 AI 에이전트, 문서 변환, 코드 이해 도구와 함께 보안 조사 자동화 도구가 눈에 띈다. daily 후보에는 [chopratejas/headroom](https://github.com/chopratejas/headroom), [microsoft/markitdown](https://github.com/microsoft/markitdown), [affaan-m/ECC](https://github.com/affaan-m/ECC), [D4Vinci/Scrapling](https://github.com/D4Vinci/Scrapling), [nesquena/hermes-webui](https://github.com/nesquena/hermes-webui), [reconurge/flowsint](https://github.com/reconurge/flowsint), [OpenBMB/VoxCPM](https://github.com/OpenBMB/VoxCPM) 등이 보였다. weekly에서는 [Lum1104/Understand-Anything](https://github.com/Lum1104/Understand-Anything), [hardikpandya/stop-slop](https://github.com/hardikpandya/stop-slop), [revfactory/harness](https://github.com/revfactory/harness)처럼 AI 개발 워크플로 주변 도구도 강하게 노출되었다.

이미 이 블로그에서는 에이전트 네이티브 소프트웨어, 토큰 절감형 AI 코딩 도구, 문서 파서, AI 메모리, 적응형 웹 스크래핑, 셀프호스팅 CRM과 미디어 서버를 다루었다. 그래서 오늘은 또 하나의 AI 도구를 요약하기보다, 보안·리스크 조직에서 실질적인 의사결정으로 이어지는 흐름을 선택했다. 오늘의 논지는 **OSINT(Open Source Intelligence)가 단순 검색과 링크 수집을 넘어, 그래프 기반 증거 관리와 자동 enrichers를 결합한 조사 운영 플랫폼으로 진화하고 있다**는 것이다. 그 신호를 잘 보여준 저장소가 [Flowsint](https://github.com/reconurge/flowsint)다.

GitHub API와 Trending 페이지 확인 시점 기준으로 `reconurge/flowsint`는 TypeScript 중심 프로젝트이며, 약 4,471개의 star와 580개의 fork를 가지고 있었다. daily Trending에서는 190 stars today로 노출되었고, 저장소는 2025년 1월 생성, 2026년 6월 2일까지 커밋이 이어진 것으로 확인되었다. 최신 릴리스는 2026년 5월 31일 공개된 `v1.2.9`이며, 릴리스 노트에는 Celery healthcheck 수정, enrichers 컬렉션 공개, security issues 수정이 포함되어 있었다. 최근 커밋에는 timezone-aware service timestamps와 social enricher output encoding 수정도 보였다. 이 수치와 활동 신호는 확인 시점의 스냅샷이며 GitHub 집계, 시간대, API 응답에 따라 변할 수 있다.

Flowsint README는 자신을 “ethical investigation, transparency, and verification”을 위한 오픈소스 OSINT graph exploration tool이라고 설명한다. 단순히 멋진 그래프 UI를 제공한다는 의미가 아니다. 도메인, IP, ASN, 조직, 소셜 계정, 웹사이트, WHOIS, DNS, 서브도메인, 과거 도메인 데이터 같은 조각난 공개 정보를 관계 중심으로 정리하고, 자동 enrichers로 새 단서를 확장하며, 분석가가 검증 가능한 조사 흐름을 만들 수 있게 하겠다는 방향이다.

![Flowsint형 OSINT 그래프 조사 파이프라인](https://heracles-jo.github.io/assets/img/posts/github-trending-osint-graph-flowsint/architecture.svg)

## 왜 지금 Flowsint 같은 도구가 주목받는가

보안 조직의 외부 공격 표면은 더 이상 고정된 자산 목록으로 설명되지 않는다. SaaS 도입, 클라우드 계정, 임시 서브도메인, 외주 개발, 인수합병, 소셜 미디어 계정, 유출된 개발자 이메일, 오래된 DNS 레코드가 모두 조사 대상이 된다. 전통적인 취약점 스캐너는 “알고 있는 자산”에는 강하지만, 조직이 잊어버린 외부 노출이나 관계성 추적에는 약하다. 반대로 수작업 OSINT는 유연하지만 재현성, 감사 가능성, 협업성이 떨어진다.

Flowsint가 Trending에 오른 배경은 바로 이 간극에 있다. README에 따르면 Flowsint는 reconnaissance와 OSINT를 위한 graph-based investigation tool이며, 시각적 그래프 인터페이스와 automated enrichers를 제공한다. 사용자는 Docker와 Make를 설치한 뒤 `make prod`로 실행할 수 있고, 기본 계정은 없으며 처음 접속해 계정을 생성하는 방식이다. 특히 README는 “OSINT investigations need a high level of privacy. Everything is stored on your machine.”이라고 강조한다. 이는 민감한 조사 데이터를 외부 SaaS에 올리기 어려운 보안팀, 언론 조사팀, 사기 조사팀, 내부 위협 인텔리전스 팀에 중요한 메시지다.

오늘 후보 중 MarkItDown은 문서 변환, Headroom은 LLM 컨텍스트 압축, Hermes WebUI와 ECC는 에이전트 사용 경험과 운영 체계, Understand-Anything은 코드·문서 지식 그래프에 가깝다. 반면 Flowsint는 공개 정보 조사와 사이버보안 의사결정이라는 명확한 도메인을 가진다. 최근 AI 도구 트렌드가 “더 많은 정보를 모델에 넣는 방법”에 집중했다면, Flowsint의 흐름은 “사람이 검증해야 하는 단서를 구조화하고 책임 있게 확장하는 방법”에 초점을 둔다. 이 차이가 중요하다. 보안 조사에서는 그럴듯한 요약보다 출처, 시점, 관계, 권한, 법적 범위가 더 중요하기 때문이다.

## 핵심 아키텍처: 그래프, enrichers, 로컬 저장, 분석가 루프

Flowsint의 루트 구조와 Docker Compose 구성을 보면 단순 프런트엔드 프로젝트가 아니다. 저장소에는 `flowsint-app`, `flowsint-api`, `flowsint-core`, `flowsint-enrichers`, `flowsint-types`, `neo4j-migrations`가 있고, docker-compose에는 PostgreSQL, Redis, Neo4j, 애플리케이션/API 계층이 포함된다. 개발 및 운영 환경에서는 PostgreSQL이 일반 데이터와 계정·작업 상태를, Redis가 Celery와 캐시를, Neo4j가 관계 그래프를 담당하는 형태로 이해할 수 있다.

이 구조는 OSINT 도구에 잘 맞는다. 도메인을 입력하면 DNS 해석으로 IP를 얻고, IP에서 ASN을 찾고, ASN에서 CIDR 범위를 확장하고, 조직명에서 관련 도메인을 찾고, 사용자명에서 소셜 플랫폼 계정을 탐색할 수 있다. Flowsint README가 나열한 available enrichers에는 Reverse DNS Resolution, DNS Resolution, Subdomain Discovery, WHOIS Lookup, Domain to Website, Domain to Root Domain, Domain to ASN, Domain History, IP Information, IP to ASN, ASN to CIDRs, CIDR to IPs, Maigret 기반 username search, Organization to ASN, Organization Information, Organization to Domains 등이 포함된다.

여기서 중요한 것은 “자동화” 자체가 아니라 자동화 결과가 그래프의 노드와 엣지로 남는다는 점이다. 조사자는 한 번의 검색 결과를 복사해 문서에 붙이는 것이 아니라, 도메인과 IP, 조직과 ASN, 사용자명과 플랫폼 계정의 관계를 축적한다. 이후 다른 조사자가 같은 그래프를 보면서 어떤 단서가 어떤 enricher에서 나왔는지, 어느 시점의 데이터인지, 어떤 판단을 추가했는지 확인할 수 있다. 보안 운영에서 이 재현성과 협업성은 기능 목록보다 더 큰 가치다.

또 하나의 핵심은 분석가 루프다. OSINT는 완전 자동화가 어려운 영역이다. 공개 데이터는 오래되었거나, 동명이인이 많거나, CDN과 클라우드 때문에 소유 관계가 모호하거나, 공격자가 의도적으로 오염시킨 정보일 수 있다. 따라서 좋은 OSINT 플랫폼은 “많이 찾아주는 도구”가 아니라 “분석가가 검증하고 배제하고 설명할 수 있게 해주는 도구”여야 한다. Flowsint가 transparency와 verification을 전면에 둔 점은 이 맥락에서 의미가 있다.

## 기존 방식과 대체 도구 비교

OSINT 및 위협 인텔리전스 도구는 이미 많다. [Maltego](https://www.maltego.com/)는 그래프 기반 조사 도구의 대표 사례이며, 다양한 transform 생태계를 갖고 있다. [SpiderFoot](https://github.com/smicallef/spiderfoot)는 자동화된 OSINT 수집과 스캔에 강점이 있고, [OpenCTI](https://github.com/OpenCTI-Platform/opencti)는 조직의 위협 인텔리전스 지식 관리와 STIX/TAXII 기반 연계에 초점을 둔다. [theHarvester](https://github.com/laramies/theHarvester)는 이메일, 서브도메인, 호스트 정보 수집에 널리 쓰이는 경량 도구다.

| 구분 | 강점 | 한계 | Flowsint 관점의 차별점 |
| --- | --- | --- | --- |
| 수작업 검색/스프레드시트 | 빠른 시작, 도구 의존 낮음 | 재현성·협업·감사 취약 | 그래프와 enrichers로 조사 흐름을 구조화 |
| Maltego | 성숙한 그래프 UI와 transform 생태계 | 라이선스·운영 방식 고려 필요 | 오픈소스 로컬 저장과 자체 확장 가능성 |
| SpiderFoot | 자동 수집 범위가 넓음 | 결과 검증과 관계 해석은 별도 작업 필요 | 그래프 중심 탐색과 분석가 워크스페이스에 초점 |
| OpenCTI | 위협 인텔리전스 지식 관리에 강함 | 초기 도입·모델링 비용이 큼 | 정찰·조사 단서 확장에 더 가벼운 진입점 |
| CLI 도구 모음 | 자동화와 파이프라인 연결 용이 | 비전문가 협업과 시각화가 어려움 | API·UI·그래프 DB로 팀 단위 운영 가능 |

Flowsint가 이 도구들을 대체한다고 단정할 수는 없다. 오히려 실무에서는 목적에 따라 조합될 가능성이 높다. 예를 들어 외부 공격 표면 초기 탐색은 Flowsint나 SpiderFoot로 수행하고, 고도화된 위협 인텔리전스 지식 관리는 OpenCTI로 연결하며, 특정 단서의 깊은 분석은 CLI 도구나 상용 데이터 소스를 함께 사용할 수 있다. 중요한 판단 기준은 “우리 팀이 어떤 데이터를 어떤 책임 범위 안에서 수집하고, 누가 검증하고, 어떤 시스템에 기록할 것인가”다.

## 실무 도입 시 얻을 수 있는 장점

첫째, 조사 속도와 일관성이 개선된다. 신입 분석가와 시니어 분석가가 같은 입력에서 완전히 다른 체크리스트를 수행하면 결과 품질이 들쭉날쭉해진다. Enricher 기반 워크플로는 반복적인 DNS, WHOIS, ASN, 소셜 계정 탐색을 표준화한다. 물론 자동 결과가 곧 사실은 아니지만, 최소한 빠뜨리기 쉬운 기본 탐색을 체계화할 수 있다.

둘째, 관계 중심의 설명이 가능해진다. 보안 리포트에서 “이 도메인이 의심스럽다”보다 강한 근거는 “이 도메인은 특정 ASN 범위, 과거 WHOIS 히스토리, 유사한 서브도메인 패턴, 소셜 계정 단서와 이렇게 연결된다”는 설명이다. 그래프는 이런 설명을 시각적으로 보조한다. 특히 임원 보고나 법무·컴플라이언스 협업에서는 관계를 눈으로 확인할 수 있는 구조가 의사결정 시간을 줄인다.

셋째, 로컬 저장의 장점이 있다. 조사 대상이 임직원, 고객, 협력사, 공격자 인프라와 관련될 경우 데이터 자체가 민감하다. Flowsint README의 “everything is stored on your machine” 메시지는 클라우드 SaaS 업로드가 부담스러운 팀에 유리하다. 다만 로컬 저장은 자동으로 안전하다는 뜻이 아니다. 백업, 접근권한, 로그 관리, 암호화, 운영자 계정 관리가 함께 설계되어야 한다.

넷째, 오픈소스 확장성이 있다. Flowsint는 enrichers와 core, API, app이 분리된 구조를 갖는다. 팀이 자체 데이터 소스, 내부 자산 DB, 티켓 시스템, SIEM, SOAR와 연결하려면 오픈소스 구조가 유리하다. 상용 도구의 제한된 커넥터에 갇히지 않고, 특정 산업이나 조직에 필요한 단서를 직접 모델링할 수 있다.

![OSINT 그래프 도구 도입 리스크 매트릭스](https://heracles-jo.github.io/assets/img/posts/github-trending-osint-graph-flowsint/risk-matrix.svg)

## 보안·운영·법적 리스크: OSINT 도구는 기능보다 통제가 먼저다

OSINT 도구의 가장 큰 리스크는 “공개 정보니까 마음대로 수집해도 된다”는 오해다. 공개적으로 접근 가능한 데이터라도 수집 목적, 규모, 보관 기간, 재식별 가능성, 관할 법률, 서비스 약관에 따라 문제가 될 수 있다. Flowsint의 [ETHICS.md](https://github.com/reconurge/flowsint/blob/main/ETHICS.md)는 인권 침해, 무단 감시, 괴롭힘, doxxing, 정치적 조작, 개인정보 침해를 금지하고, 합법적·윤리적 조사와 연구 목적을 강조한다. 이는 문서상의 선언에 그치지 않고 실제 운영 정책으로 내려와야 한다.

운영 관점에서는 네 가지를 봐야 한다. 첫째, API 키와 외부 데이터 소스 credential 관리다. Enricher가 늘어날수록 외부 서비스 토큰과 rate limit 관리가 중요해진다. 둘째, 그래프 데이터의 품질 관리다. 자동으로 확장된 관계가 오탐이면, 그래프는 빠르게 오염된다. 셋째, 큐와 작업 재시도 정책이다. Redis/Celery 계층이 포함된 구조에서는 대량 작업, 실패 재시도, 중복 실행, 시간 초과가 비용과 데이터 품질에 영향을 준다. 넷째, 백업과 삭제 정책이다. 조사 데이터는 나중에 증거로 필요할 수 있지만, 불필요한 개인정보를 오래 보관하는 것은 리스크다.

보안 관점에서는 로컬 호스팅이 외부 유출을 줄이는 동시에 내부 공격 표면을 만든다. Docker Compose에서 PostgreSQL, Redis, Neo4j, API, 프런트엔드가 함께 뜨면 포트 노출, 기본 비밀번호, 네트워크 분리, 관리자 계정, 로그 파일 위치를 점검해야 한다. 특히 Neo4j와 Redis가 외부에 노출되면 조사 데이터와 작업 상태가 위험해질 수 있다. PoC 단계에서도 내부망 접근 제한, 방화벽, 강한 secret, 정기 업데이트, 이미지 취약점 스캔을 적용하는 편이 안전하다.

또한 정확성 리스크가 있다. OSINT 그래프는 관계를 보여주지만 인과관계를 증명하지 않는다. 같은 IP를 공유한다고 같은 운영자라는 뜻은 아니며, 같은 사용자명이 동일 인물이라는 뜻도 아니다. CDN, 클라우드 호스팅, 프록시, 과거 소유권 변경, 자동 생성 계정은 모두 오탐을 만든다. 따라서 리포트에는 “확인된 사실”, “추정”, “추가 검증 필요”를 분리해야 한다.

## PoC 체크리스트: 도구 설치보다 조사 운영 모델을 먼저 정하라

Flowsint류 도구를 PoC할 때는 기능 시연보다 운영 모델을 먼저 정의해야 한다. 다음 체크리스트를 권한다.

1. **목적 범위 정의**: 외부 공격 표면 관리, 브랜드 사칭 탐지, 피싱 인프라 조사, 사기 계정 분석, 내부 위협 인텔리전스 중 무엇을 목표로 하는가.
2. **법무·보안 승인**: 수집 가능한 데이터 유형, 금지 대상, 보관 기간, 삭제 요청 대응 절차를 문서화했는가.
3. **데이터 모델링**: 도메인, IP, ASN, 조직, 계정, 이메일, 사건, 증거, 판단 노트를 어떤 노드와 엣지로 표현할 것인가.
4. **Enricher 검증**: 각 enricher의 데이터 출처, rate limit, 비용, 오탐률, 실패 시 동작을 확인했는가.
5. **접근 제어**: 분석가, 관리자, 감사자 역할을 분리하고 민감 조사 케이스를 격리할 수 있는가.
6. **증거 관리**: 결과가 나온 시간, 원본 URL, 요청 파라미터, 스크린샷 또는 원문 저장 정책을 정했는가.
7. **운영 안정성**: PostgreSQL, Redis, Neo4j의 백업, 모니터링, 패치, 용량 계획을 마련했는가.
8. **보고 템플릿**: 그래프 결과를 경영진·법무·IR·SOC에 맞는 언어로 바꾸는 템플릿을 만들었는가.
9. **오남용 방지**: 개인 대상 조사, 정치·노동·민감 집단 추적 등 금지 시나리오를 명확히 차단했는가.
10. **성과 지표**: 발견한 미관리 자산 수, 검증 완료 단서 비율, 오탐 제거 시간, 조사 리드타임을 측정하는가.

PoC의 성공 기준은 “그래프가 예쁘다”가 아니라 “같은 사건을 다시 조사했을 때 동일한 근거를 재현할 수 있고, 잘못된 단서를 통제하며, 의사결정자가 책임 있게 판단할 수 있다”여야 한다.

## 어떤 팀에 적합하고, 어떤 경우 피해야 하는가

Flowsint 같은 오픈소스 OSINT 그래프 도구는 외부 노출 자산이 빠르게 변하는 스타트업, 클라우드 전환 중인 기업, 브랜드 사칭·피싱 대응이 필요한 보안팀, 사기 조사팀, 위협 인텔리전스 기능을 막 구축하는 조직에 적합하다. 특히 상용 SaaS에 민감 조사 데이터를 올리기 어려운 조직, 자체 데이터 소스와 연결해야 하는 조직, 분석가가 그래프 기반 사고에 익숙한 조직이라면 PoC 가치가 크다.

반대로 피해야 할 경우도 분명하다. 첫째, 법적·윤리적 조사 범위를 정하지 않은 팀은 도구부터 설치하면 안 된다. 둘째, 운영 인력이 없어 Docker, 데이터베이스, 백업, 패치, 접근 제어를 관리할 수 없다면 상용 관리형 도구나 제한된 CLI 워크플로가 더 안전할 수 있다. 셋째, 결과를 검증할 분석가 없이 자동 수집 결과만으로 결론을 내리려는 조직에는 맞지 않는다. 넷째, 이미 OpenCTI나 상용 위협 인텔리전스 플랫폼이 성숙하게 운영되고 있고, 정찰 단계의 공백이 크지 않다면 Flowsint는 중복 도구가 될 수 있다.

## 앞으로 관찰할 지표와 전망

Flowsint의 향후 가치는 몇 가지 지표로 판단할 수 있다. 첫째, enrichers 생태계가 얼마나 빠르게 늘고, 각 enricher의 품질과 문서화가 개선되는가. 둘째, 권한 관리, 감사 로그, 케이스 관리, 증거 보존 같은 엔터프라이즈 기능이 성숙하는가. 셋째, Neo4j 기반 그래프 모델이 대량 조사에서도 성능과 유지보수성을 유지하는가. 넷째, ETHICS 문서의 원칙이 실제 기능, 예를 들어 금지 대상 제한, 민감 데이터 표시, 삭제 워크플로, 접근 통제로 연결되는가. 다섯째, 커뮤니티가 단순 스타 증가를 넘어 실제 이슈, PR, 릴리스로 이어지는가.

운영 성숙도를 판단할 때는 기능 추가 속도만 보면 안 된다. 보안팀이 실제로 의존할 수 있는 도구가 되려면 장애가 났을 때 어떤 작업이 중단되는지, 잘못된 enrichment 결과를 어떻게 되돌리는지, 조사 케이스별 권한을 어떻게 나누는지, 외부 데이터 제공자의 약관 변경을 어떻게 반영하는지까지 문서와 코드에 녹아야 한다. 특히 OSINT 그래프는 시간이 지날수록 과거 데이터와 현재 데이터가 섞이기 쉽다. 어제 유효했던 DNS 관계가 오늘은 사라질 수 있고, 과거 WHOIS 정보가 현재 소유자를 설명하지 못할 수 있다. 따라서 시간축을 가진 엣지, 신뢰도 점수, 수동 검증 상태, 만료 정책이 제품의 핵심 품질 기준이 된다.

또한 AI 기능과의 결합도 관찰할 만하다. 앞으로 많은 OSINT 도구는 자연어 요약, 이상 관계 추천, 조사 경로 제안, 보고서 초안 작성 기능을 붙일 것이다. 그러나 이 영역에서 AI는 결론을 대신 내려주는 역할보다, 분석가가 놓친 단서를 알려주고 근거를 정리하는 보조자에 머물러야 한다. 확인되지 않은 추론을 사실처럼 출력하면 법적·윤리적 리스크가 커진다. 따라서 AI가 추가되더라도 원본 링크, 수집 시각, 데이터 출처, 사람이 승인한 판단을 분리해 보여주는 설계가 중요하다.

오늘 GitHub Trending의 더 넓은 흐름은 흥미롭다. AI 에이전트 도구들은 컨텍스트를 압축하고, 문서를 Markdown으로 바꾸고, 코드를 지식 그래프로 만들고, 작업을 자동화한다. 보안 조사 도구들은 공개 정보를 그래프로 묶고, 자동 enrichers로 단서를 확장하고, 분석가가 검증 가능한 결론을 만들게 한다. 두 흐름의 공통점은 “정보를 많이 모으는 것”에서 “정보의 관계와 책임 있는 사용을 운영하는 것”으로 이동하고 있다는 점이다.

따라서 Flowsint를 단순한 OSINT UI로만 보면 흐름을 놓친다. 더 중요한 변화는 보안팀이 외부 세계의 불확실한 단서를 데이터 구조, 그래프, 큐, 저장소, 윤리 원칙, 운영 정책으로 다루기 시작했다는 점이다. 실무 의사결정자에게 오늘의 교훈은 명확하다. OSINT 자동화는 경쟁력이 될 수 있지만, 통제되지 않은 자동화는 새로운 리스크다. Flowsint 같은 도구를 검토한다면 기능 목록보다 먼저 조사 목적, 데이터 거버넌스, 검증 절차, 운영 책임자를 정해야 한다. 그 기반 위에서만 그래프 기반 OSINT는 보안 조직의 판단 속도와 품질을 동시에 높이는 인프라가 될 수 있다.
