---
title: "Penpot과 오픈소스 디자인 협업 플랫폼의 현실성"
description: "Penpot의 SVG·CSS 기반 파일 모델, 디자인 토큰, 셀프호스팅 구조와 운영 문서를 바탕으로 오픈소스 디자인 협업의 가치, 이전 비용과 도입 기준을 정리한다."
author: heracles-jo
date: 2026-06-23 07:32:00 +0900
categories: [Developer Tools, Collaboration]
tags: [penpot, self-hosting, open-source, governance, collaboration, design-system]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-penpot-open-source-design-collaboration/cover.svg
  alt: "오픈소스 디자인 협업 플랫폼 Penpot의 셀프호스팅, 웹 표준, 디자인-개발 협업 구조 분석"
---

GitHub Trending에서 [penpot/penpot](https://github.com/penpot/penpot)이 주목받는 현상을 “무료 Figma 대체재”로만 설명하면 핵심을 놓친다. Penpot은 화면 설계 기능뿐 아니라 **디자인 파일과 협업 기록을 누가 보유하고, 어떤 형식으로 개발 파이프라인에 넘기며, 서비스 장애와 업그레이드를 누가 책임질 것인가**라는 인프라 질문을 드러낸다. 디자인 시스템이 제품 코드와 릴리스 정책에 연결된 조직이라면 이 문제는 디자이너용 도구 구매를 넘어선다.

이 글은 2026년 6월의 Trending 관찰을 출발점으로 삼되, 2026년 11월 17일 기준 Penpot 공식 저장소와 사용자·기술·운영 문서를 다시 확인해 보강했다. 특정 SaaS의 최신 기능표나 시장 점유율처럼 계속 변하는 비교는 피하고, Penpot이 공식적으로 문서화한 SVG·CSS 기반 표현, 디자인 토큰, API와 plugin, Docker/Kubernetes 배포, 백업·업그레이드·인증 경계를 중심으로 판단한다.

![Penpot 협업 구조](https://heracles-jo.github.io/assets/img/posts/github-trending-penpot-open-source-design-collaboration/architecture.svg)

## Penpot의 차별점은 오픈소스보다 파일 모델에 있다

Penpot 공식 README는 플랫폼을 open-source web-based design tool로 소개하며, SVG·CSS·HTML 같은 open standards를 사용한다고 설명한다. 사용자 가이드도 개발자가 별도 “handoff 모드” 없이 디자인 파일을 inspect하고 CSS, HTML/SVG markup, 측정값과 에셋을 확인할 수 있다고 설명한다. 이는 개발자 경험에서 의미가 크다. 디자인 산출물을 독점 포맷의 최종 이미지로 받는 대신 브라우저가 이해하는 표현에 가까운 구조로 볼 수 있기 때문이다.

다만 “웹 표준을 쓴다”를 “디자인이 곧 production code다”로 해석해서는 안 된다. 디자인 편집기의 SVG 구조는 시각적 의도를 보존하기 위한 것이고, 실제 제품 코드는 의미 있는 DOM, 접근성, 상태 관리, 반응형 규칙, 성능, 국제화와 테스트를 만족해야 한다. 자동 생성한 CSS와 SVG를 그대로 복사하면 중복 style, 절대 좌표, 불필요한 wrapper와 접근성 누락이 남을 수 있다. Penpot의 장점은 코드를 없애는 것이 아니라 **디자인 의도를 개발자가 더 투명하게 검사하고 변환할 수 있게 하는 것**에 있다.

이 관점은 [DESIGN.md와 에이전트 친화적 디자인 시스템 글](/posts/github-trending-design-md-design-system-ai-agents/)과도 연결된다. 디자인 도구가 구조화된 token과 component property를 제공할수록 사람뿐 아니라 코드 생성 도구도 더 나은 입력을 받는다. 그러나 산출물 검증이 없다면 구조화된 입력은 구조화된 오류를 더 빠르게 퍼뜨릴 뿐이다.

## 화면 편집기 뒤에는 협업 백엔드가 있다

셀프호스팅 Penpot을 도입하면 브라우저 편집기 하나만 운영하는 것이 아니다. 공식 [Technical Guide](https://help.penpot.app/technical-guide/)와 저장소의 compose 구성을 보면 frontend, backend, exporter, PostgreSQL, Valkey, object storage와 mail provider 등 여러 구성 요소가 함께 움직인다. exporter는 PDF 같은 내보내기 작업을 담당하고, 데이터베이스는 핵심 객체를 보관하며, asset은 별도 storage에 놓일 수 있다. 캐시·세션·작업 조정을 위한 서비스와 이메일·인증 연동도 필요하다.

이 구조에서 운영 책임은 계층별로 달라진다.

| 계층 | 역할 | 운영 시 확인할 질문 |
|---|---|---|
| Frontend | 편집·리뷰·inspect UI | 브라우저 호환성, CSP, public URL과 proxy 설정이 맞는가 |
| Backend | 프로젝트·파일·권한·협업 API | 인증, rate limit, migration과 로그를 누가 관리하는가 |
| Exporter | PDF·렌더링 계열 비동기 작업 | queue 적체와 실패를 사용자가 확인할 수 있는가 |
| PostgreSQL | 핵심 영속 데이터 | snapshot뿐 아니라 복구 가능한 백업을 시험했는가 |
| Valkey/Redis 계열 | session·cache·작업 조정 | 재시작 시 유실 가능한 상태와 영속 상태를 구분했는가 |
| Asset storage | 이미지·폰트·첨부 asset | DB와 같은 시점으로 백업하고 권한·수명주기를 관리하는가 |
| Reverse proxy/TLS | 외부 진입점 | 업로드 크기, websocket, timeout, 보안 header가 맞는가 |
| Identity/mail | 사용자 수명주기와 초대 | 퇴사자 회수, domain policy, SMTP 장애 경로가 있는가 |

화면이 열리고 파일 하나를 저장했다고 PoC가 끝난 것이 아니다. 여러 사용자가 동시에 편집하고, 큰 asset을 올리고, exporter가 바쁠 때도 응답하며, 장애 뒤 DB와 asset이 같은 시점으로 복구돼야 협업 플랫폼이라고 부를 수 있다. [TeslaMate 셀프호스팅 운영 글](/posts/github-trending-teslamate-vehicle-data-observability/)에서 다룬 것처럼 “내 서버에 설치 가능”은 통제권을 주는 동시에 백업, 패치, 인증과 장애 대응 책임을 되돌려 준다.

## 디자인 토큰: 기능보다 원천 시스템을 먼저 정해야 한다

Penpot의 [Design Tokens 문서](https://help.penpot.app/user-guide/design-systems/design-tokens/)는 color, dimension, font family·weight, duration, cubic bezier, stroke thickness, opacity, rotation, shadow, typography 같은 token type과 set·theme 구성을 설명한다. DTCG 형식으로 token을 import/export할 수 있다는 점도 디자인과 코드 사이의 자동화 가능성을 높인다. 문제는 “token 기능이 있는가”가 아니라 어느 시스템이 권위 있는 원천인지다.

조직에는 보통 다음 후보가 이미 존재한다.

- Penpot 파일과 library
- 코드 저장소의 JSON 또는 CSS custom property
- Style Dictionary 같은 변환 파이프라인
- Storybook에 구현된 component와 theme
- 별도 token 관리 서비스
- 모바일 플랫폼의 Android/iOS resource

이 중 둘 이상을 동시에 source of truth로 두면 동기화 충돌이 생긴다. 디자이너가 Penpot에서 `color.action.primary`를 바꾸고 개발자가 Git에서 같은 token을 수정했을 때 어느 쪽이 이겨야 하는가. 단순 last-write-wins는 시각 회귀와 접근성 문제를 숨긴다. 현실적인 운영 패턴은 한 방향의 승인 흐름을 정하는 것이다.

예를 들어 Penpot을 작성 원천으로 쓴다면 token export를 CI가 읽어 schema, naming, 금지된 raw value, color contrast를 검사하고 pull request로 코드 변경을 만든다. 반대로 Git을 원천으로 쓴다면 승인된 token package를 Penpot으로 import하는 release 절차가 필요하다. 어느 방식이든 변경에는 version, owner, 영향 component, migration 기간이 있어야 한다. Penpot을 설치한다고 중복 색상과 임의 spacing이 자동으로 정리되지는 않는다. 오히려 기존 부채가 더 잘 보이게 된다.

## Component와 variant는 디자인 시스템 거버넌스의 문제다

Penpot은 component, variant, shared library를 통해 재사용을 지원한다. 그러나 component 수가 많다는 사실은 디자인 시스템의 성숙도를 뜻하지 않는다. 이름이 비슷한 button이 여러 library에 있고, variant property가 일관되지 않으며, deprecated component가 계속 복제되면 중앙 도구는 혼란을 더 빠르게 확산한다.

component 운영에는 최소한 다음 규칙이 필요하다.

1. library owner와 승인 경로를 정한다.
2. component 이름과 variant property vocabulary를 고정한다.
3. 디자인 component와 실제 코드 component의 mapping을 문서화한다.
4. breaking change와 deprecation 기간을 둔다.
5. 접근성 상태, focus, disabled, error, loading을 정상 상태와 같은 비중으로 설계한다.
6. 화면 하나가 아니라 theme·locale·viewport 조합으로 검증한다.

특히 개발자 inspect에서 얻는 markup과 style은 구현의 출발점이지 완료 판정이 아니다. [Modern Web Guidance 검증 글](/posts/modern-web-guidance-agent-web-validation/)에서 정리했듯, 실제 웹 품질은 semantic HTML, 키보드 동작, 브라우저 지원, CSP, hydration, visual regression을 함께 봐야 한다. 디자인 시스템 연결의 목표도 “코드를 빨리 복사한다”가 아니라 디자인 변경이 production UI에서 어떤 회귀를 만들지 더 빨리 발견하는 데 있어야 한다.

## Figma에서 옮기는 비용은 파일 변환보다 행동 변화에서 나온다

Penpot의 공식 [Migration Guide](https://help.penpot.app/user-guide/first-steps/migration-guide/)는 Figma에서 Penpot으로 이동할 때 Penpot Exporter plugin, 정적 SVG·PNG·JPG, token JSON을 상황에 따라 사용하고 대표 파일로 먼저 검증하라고 안내한다. 즉 Penpot이 `.fig` 원본을 완전하게 직접 해석한다고 가정할 것이 아니라, exporter가 만든 Penpot 호환 파일과 정적 asset을 통해 이전하는 흐름이다. exporter 역시 일회성 migration 도구이지 두 시스템의 지속적인 양방향 동기화 계층은 아니다. “파일이 열렸다”와 “업무가 이전됐다”가 다른 이유다. 실제 전환 비용은 네 영역에서 발생한다.

### 시각적 충실도

font availability, auto layout과 grid 규칙, mask, effect, text metrics, component property가 다르면 화면은 비슷해 보여도 구조가 달라질 수 있다. 대표 파일을 screenshot diff로 비교하고, component instance가 원본 library와 어떤 관계를 유지하는지 확인해야 한다.

### 프로토타입 의미

화면 전환, overlay, scroll behavior, interactive component 같은 기능은 도구마다 의미가 다르다. 중요한 사용자 흐름을 클릭해 보지 않고 frame 수만 세면 prototyping gap을 놓친다.

### 협업 기록

comment, version history, branch 관습, 외부 stakeholder link, plugin data는 디자인 객체와 별개의 운영 자산이다. 일부를 옮길 수 없으면 어떤 기록을 read-only archive로 남길지 결정해야 한다.

### 사람의 근육 기억

단축키, selection, layout 조작, text editing, library publish와 review 흐름의 작은 차이는 매일 누적된다. 도구 전환 ROI에서 가장 쉽게 빠지는 비용이 교육과 초기 생산성 저하다. 기능표 비교보다 디자이너가 실제 업무를 완료하는 시간을 측정해야 하는 이유다.

따라서 대규모 전환 전에는 대표 프로젝트를 난이도별로 골라야 한다. 단순 마케팅 페이지 하나만 성공시키면 복잡한 제품 UI, 다국어 text, 큰 library와 prototyping 문제를 가린다. 반대로 가장 복잡한 legacy 파일부터 시작하면 도구보다 기존 부채를 평가하게 된다.

## Self-hosting의 보안 경계

Penpot 공식 기술 문서는 Docker를 가장 간단한 self-hosting 경로로 제시하고, Kubernetes·Elestio·Cloudron 같은 경로도 안내한다. 하지만 공개 인터넷에 올리는 순간 reverse proxy, TLS, upload, storage, identity와 patch cadence를 직접 책임져야 한다. 기본 compose 예제는 학습과 시작을 위한 구성이지 조직의 production security baseline이 아니다.

운영자는 특히 다음을 확인해야 한다.

- registration을 열어 둘지, domain allowlist 또는 invite-only로 제한할지
- OIDC, LDAP, SAML 연동 중 무엇을 사용하고 account deprovisioning을 어떻게 할지
- service account와 사용자 credential을 분리했는지
- object storage가 public bucket이나 추측 가능한 URL로 노출되지 않는지
- SMTP와 webhook 실패가 초대·알림 흐름을 조용히 깨뜨리지 않는지
- exporter와 backend container의 egress와 secret 범위를 제한했는지
- 관리자 기능과 일반 편집 기능의 audit trail을 어디에 남길지
- plugin 또는 API integration이 파일 데이터를 외부로 보내는지

오픈소스는 코드를 감사할 수 있게 하지만 자동으로 안전한 배포를 만들어 주지는 않는다. 보안팀이 제품 코드를 모두 검토할 수 없더라도 threat model, image provenance, dependency update, secret rotation, restore drill과 vulnerability response owner는 정할 수 있다.

## 백업은 PostgreSQL dump 하나로 끝나지 않는다

Penpot의 공식 [Docker 운영 문서](https://help.penpot.app/technical-guide/getting-started/docker/#backup-penpot)는 기본 compose가 PostgreSQL과 사용자 asset용 volume을 사용하므로 두 영속 데이터 영역을 정기적으로 백업해야 한다고 설명한다. 이 지침의 핵심은 파일 메타데이터와 binary asset의 일관성이다. DB만 복구하면 참조 대상 이미지가 없을 수 있고, asset만 남으면 어느 프로젝트에 속하는지 잃을 수 있다.

운영 환경에서는 백업 설계를 다음 수준까지 내려야 한다.

1. 데이터베이스 dump 또는 volume snapshot의 주기와 보존 기간
2. filesystem 또는 S3 asset의 같은 시점 복제
3. encryption key와 configuration의 별도 보관
4. restore 환경에서의 실제 복구 시험
5. RPO·RTO와 책임자
6. 업그레이드 직전 snapshot과 rollback 조건
7. 백업 파일 접근 권한과 삭제 정책

“매일 백업한다”보다 “분리된 환경에서 지난주 백업을 몇 시간 안에 복구해 대표 파일과 asset을 열 수 있다”가 검증 가능한 기준이다. 디자인 파일은 코드처럼 Git history가 기본 제공되는 자산이 아니므로 복구 시험의 우선순위가 높다.

## 업그레이드는 migration과 rollback 프로젝트다

공식 [Docker update 절차](https://help.penpot.app/technical-guide/getting-started/docker/#update-penpot)는 compose와 image를 갱신하는 흐름을 제공한다. self-hosting 팀은 이를 단순 자동 업데이트가 아니라 maintenance window, DB migration, plugin/API compatibility와 rollback을 포함한 변경 관리로 다뤄야 한다. 특히 한 번 적용한 schema migration이 이전 application image와 호환되지 않을 수 있으므로 “container tag를 되돌린다”만으로 rollback이 끝난다고 가정하면 위험하다.

업그레이드 전에는 clone 환경에서 다음 smoke test를 실행하는 편이 좋다.

- 로그인, 초대, 권한 변경
- 대표 파일 열기와 저장
- 동시 편집과 comment
- library publish와 update 반영
- token import/export
- PDF·SVG·image export
- `.fig` 또는 `.penpot` import
- plugin과 API integration
- backup 복구와 이전 image로의 rollback 가능성

제품 팀이 매일 사용하는 협업 도구는 짧은 장애도 여러 팀을 동시에 멈춘다. 따라서 가용성 판단에는 서버 비용뿐 아니라 on-call, maintenance communication, rollback 시간과 사용자 우회 경로를 포함해야 한다.

![Penpot 도입 체크리스트](https://heracles-jo.github.io/assets/img/posts/github-trending-penpot-open-source-design-collaboration/checklist.svg)

## 비용 판단: 라이선스 좌석을 서버 비용과만 비교하지 말 것

Penpot Community self-hosting의 매력 중 하나는 사용자 수 증가에 따른 SaaS 좌석 압박을 다른 비용 구조로 바꿀 수 있다는 점이다. 그러나 비용 비교에서 compute와 storage만 넣으면 결론이 왜곡된다. 다음 항목을 함께 계산해야 한다.

- 플랫폼 엔지니어의 설치·업그레이드·장애 대응 시간
- identity, mail, observability, backup infrastructure
- 디자이너 교육과 초기 생산성 저하
- 파일·library·comment migration과 archive 비용
- 외부 파트너 onboarding과 지원
- plugin 대체 개발 또는 integration 유지보수
- 보안·법무·조달 검토
- 장애 시 전체 제품팀의 대기 비용

반대로 SaaS 비용도 좌석 가격만이 아니다. 데이터 위치, 계정 회수, export, 감사, vendor policy 변경과 장기 보존의 제약이 조직에 위험 비용을 만들 수 있다. Penpot의 경제성은 “무료냐 유료냐”가 아니라 **운영 책임을 내부화했을 때 얻는 통제 가치가 총소유비용보다 큰가**로 판단해야 한다.

## 현실적인 PoC: 신규 파일 하나가 아니라 업무 한 사이클을 검증한다

전면 전환보다 경계가 분명한 학습 프로젝트가 낫다. 내부 관리자 화면, 새 실험 제품, design system v2의 작은 component group처럼 실패해도 기존 production을 흔들지 않는 범위를 고른다. 그 안에서도 디자이너만 써 보는 것이 아니라 PM의 comment, 개발자의 inspect, token export, QA의 시각 비교, 운영자의 backup과 upgrade까지 한 사이클을 돌려야 한다.

PoC scorecard는 다음 네 축으로 나눌 수 있다.

### 디자인 생산성

- 대표 화면 제작 시간과 수정 횟수
- component·variant 작업의 오류율
- 대형 파일의 load·save·collaboration 체감
- 디자이너가 우회 작업을 위해 다른 도구를 쓰는 빈도

### 개발 handoff

- spec clarification 질문 수
- SVG·asset 재작업률
- token 변경이 코드에 반영되는 lead time
- design과 Storybook component 간 불일치 수

### 운영 신뢰성

- backup restore 성공 시간
- exporter queue와 대형 asset 처리
- upgrade와 rollback 소요 시간
- 인증·권한 회수와 audit 확인

### 전환 가능성

- 대표 `.fig` 파일의 시각·구조 차이
- comment·history·plugin data 보존 경계
- 외부 파트너와 stakeholder의 접근 마찰
- archive와 exit plan의 현실성

측정 기간은 최소한 하나의 feature가 설계, 리뷰, 구현, QA를 통과할 정도여야 한다. 이 주기 전에 만족도 설문만 받으면 새 도구의 신기함이나 초기 불편만 측정하게 된다.

## 어떤 팀에 적합하고, 어떤 팀은 관리형 서비스를 유지해야 하나

Penpot은 데이터 위치와 배포 통제가 중요한 조직, 오픈 표준 기반 handoff와 token automation을 강화하려는 팀, 자체 플랫폼 운영 역량이 있는 조직에 잘 맞는다. 공공·금융·국방·헬스케어처럼 조달과 접근 감사 요구가 강한 환경, 폐쇄망이나 private cloud가 필요한 환경도 검토 가치가 크다. 또한 기존 SaaS를 즉시 대체하지 않더라도 내부 제품 또는 보안 민감 프로젝트에 별도 디자인 workspace가 필요한 경우 현실적인 선택지가 될 수 있다.

반대로 작은 디자인 팀이 이미 관리형 도구에서 빠르게 협업하고 있고, identity·backup·upgrade를 맡을 플랫폼 팀이 없다면 self-hosting은 문제보다 책임을 더 많이 만들 수 있다. plugin과 외부 파트너 생태계가 업무의 핵심인 팀도 전환 비용이 높다. 이 경우 Penpot SaaS를 시험하거나 기존 도구를 유지하면서 open token pipeline과 export 정책부터 개선하는 편이 낫다.

[SWC와 프런트엔드 도구 전환 글](/posts/github-trending-swc-rust-web-toolchain/)에서처럼 도구의 기술적 우수성과 조직 전체의 migration ROI는 별개다. 디자인 도구도 benchmark 하나나 기능 개수로 교체하지 않는다. 현재 병목이 vendor governance인지, handoff인지, 비용인지, 운영 통제인지 먼저 밝혀야 한다.

## 도입 판단: 핵심은 주권이 아니라 감당 가능한 주권이다

Penpot이 던지는 가장 중요한 질문은 디자인 파일이 제품 개발의 핵심 자산이라면 그 자산의 형식, 저장 위치와 운영 규칙을 조직이 얼마나 직접 통제해야 하는가다. SVG·CSS 기반 표현, token, component, API와 self-hosting은 이 통제권을 넓힌다. 동시에 데이터베이스, asset, 인증, exporter, 백업, upgrade와 사용자 지원 책임도 함께 가져온다.

그래서 Penpot을 “무료 Figma”라고 부르는 것은 두 방향 모두에서 부정확하다. 가격만 기대한 팀은 운영 비용에 실망하고, 대체재라는 말만 들은 팀은 생태계와 행동 변화의 비용을 놓친다. 더 정확한 평가는 **오픈 디자인 협업 인프라를 직접 운영할 선택권**이다.

좋은 도입은 도구를 전사에 배포하는 것으로 끝나지 않는다. token의 원천을 정하고, component와 code mapping을 관리하며, import 차이를 검증하고, backup을 실제 복구하고, upgrade 실패를 되돌릴 수 있어야 한다. 그 책임을 감당할 수 있고 데이터 통제·자동화·개발 협업에서 분명한 이익이 있다면 Penpot은 현실적인 플랫폼이다. 그렇지 않다면 관리형 도구를 유지하는 결정도 충분히 기술적이고 합리적이다.

## 공식 자료

- [Penpot GitHub repository](https://github.com/penpot/penpot)
- [Penpot User Guide](https://help.penpot.app/user-guide/)
- [Dev tools and code handoff](https://help.penpot.app/user-guide/dev-tools/)
- [Design Tokens](https://help.penpot.app/user-guide/design-systems/design-tokens/)
- [Figma-to-Penpot Migration Guide](https://help.penpot.app/user-guide/first-steps/migration-guide/)
- [The open .penpot file format](https://help.penpot.app/user-guide/export-import/penpot-file-format/)
- [Technical Guide and self-hosting](https://help.penpot.app/technical-guide/)
- [Configuration](https://help.penpot.app/technical-guide/configuration/)
- [Docker install, update and backup operations](https://help.penpot.app/technical-guide/getting-started/docker/)
- [Plugin API documentation](https://help.penpot.app/plugins/api/)
