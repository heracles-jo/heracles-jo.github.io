---
title: "App Store 심사 거절 예방: 사전 제출 컴플라이언스 게이트"
description: "App Store Compliance Playbook의 정적 검사·체크리스트·증거 원장을 분해하고, 오탐·정책 신선도·라이선스 경계를 통제하는 모바일 릴리스 게이트 설계를 제시한다."
author: heracles-jo
date: 2026-11-22 08:03:00 +0900
categories: [Mobile, Security]
tags: [app-store-compliance, mobile-compliance, app-review, google-play, release-gate]
image:
  path: https://heracles-jo.github.io/assets/img/posts/app-store-compliance-pre-submission-gate/cover.svg
  alt: "App Store와 Google Play 제출 전에 코드 정책 선언 운영 증거를 검증하는 컴플라이언스 게이트"
---

모바일 앱 심사 거절은 코드 결함 하나로 설명되지 않는다. 빌드가 성공하고 기기 테스트를 통과해도 개인정보 선언이 실제 SDK 동작과 다르거나, 리뷰 계정이 잠겨 있거나, 스토어 설명과 결제 흐름이 어긋나면 제출은 멈춘다. 반대로 정적 분석이 깨끗하다고 해서 App Store Connect와 Play Console의 계정·계약·설문 상태까지 자동으로 확인되는 것도 아니다. **App Store 심사 거절을 줄이려면 코드 스캔, 스토어 메타데이터, 콘솔 상태, 사람의 증거 확인을 하나의 릴리스 게이트로 묶되 각 검사의 관찰 범위를 분리해야 한다.**

[mjmirza/app-store-compliance](https://github.com/mjmirza/app-store-compliance)는 이 문제를 문서 모음에 머물지 않고 사전 제출 guard, 메타데이터 검사, 규제 마감 데이터, waiver ledger와 fleet 단위 판정으로 다루는 공개 저장소다. 2026년 11월 22일 08시 11분 KST 전후 GitHub Trending daily에는 `724 stars today`로 표시됐다. [공식 저장소](https://github.com/mjmirza/app-store-compliance)의 GitHub API 확인 시점에는 3,363 stars, 209 forks, 이슈와 PR을 합친 open count 33이었고, 최신 공개 릴리스는 11월 15일의 `v2.4.0`이다. 같은 시점 main에는 `v2.5.0` 준비 PR과 Windows 실행 경로 수정 PR이 열려 있었다. 수치와 활동은 확인 시점의 스냅샷이며 도구의 정확성이나 스토어 승인 가능성을 보증하지 않는다. 이번 실행 환경에서는 Search Console과 Analytics의 검색어·노출·CTR 데이터에 접근하지 못했다.

## 후보 비교: 또 다른 에이전트 스킬보다 릴리스 판정 경계가 선명했다

오늘 daily·weekly 상위권은 코딩 에이전트 스킬, 웹 수집, 보안 자동화와 에이전트 협업 UI에 집중돼 있었다. 저장소 이름뿐 아니라 독자가 해결하려는 문제를 기존 글과 대조하면, 범용 에이전트 방법론과 코드 리뷰는 이미 여러 글에서 다뤘다. App Store Compliance Playbook은 모바일 앱을 **어떻게 만들 것인가**보다 **언제 제출 가능한 상태라고 판정할 것인가**에 초점을 둔다는 점에서 별도 검색 의도가 있다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [mjmirza/app-store-compliance](https://github.com/mjmirza/app-store-compliance) | daily 724, API 3,363 stars, `v2.4.0`, OpenRoots ORA 2.3 | 코드·메타데이터·콘솔 증거를 분리한 사전 제출 게이트라는 독립적인 모바일 운영 질문이 있어 선택했다. |
| [Tracer-Cloud/opensre](https://github.com/Tracer-Cloud/opensre) | daily 450, API 13,971 stars, Apache-2.0, 당일 release | CI/CD 장애 조사 에이전트는 유효하지만 기존 관측성·배포 복구 클러스터와 중심 질문이 인접한다. |
| [elementalsouls/Claude-BugHunter](https://github.com/elementalsouls/Claude-BugHunter) | daily 1,794, API 15,969 stars, MIT | 레드팀 스킬 묶음은 Security Audit Skill·Codex Security의 권한과 증거 검증 문제와 겹친다. |
| [obra/superpowers](https://github.com/obra/superpowers) | daily 884, API 323,694 stars, MIT | 에이전트 개발 방법론은 기존 Agent Skills·Cursor Plugins·설계 리뷰 글과 검색 의도가 포화돼 있다. |
| [firecrawl/firecrawl](https://github.com/firecrawl/firecrawl) | daily 999, API 206,143 stars, AGPL-3.0 | 웹 수집과 에이전트 지식 인입은 문서 파서·RAG·헤드리스 브라우저 글과 경쟁한다. |

[Android Skills를 빌드·테스트로 검증한 글](/posts/android-skills-agent-workflow-validation/)은 에이전트 지침이 컴파일러와 테스트를 대체할 수 없다고 봤다. 이번 주제는 그 다음 단계다. 빌드와 테스트가 통과한 앱도 스토어 정책, 개인정보 선언, 리뷰 준비 상태 때문에 거절될 수 있다. [ipatool의 App Store 아티팩트 거버넌스](/posts/ipatool-appstore-artifact-governance/)가 고객에게 실제 배포된 IPA를 사후 증거로 확보하는 문제였다면, 여기서는 제출 직전의 판정 계약이 중심이다.

## 한 번의 스캔으로는 제출 가능성을 증명할 수 없다

저장소의 `v2.4.0` 데이터에는 123개 rejection pattern이 있고, 심각도는 critical 38개, high 65개, medium 20개로 나뉜다. guard는 Xcode·Android·Flutter·React Native·Expo·Capacitor 같은 프로젝트 구조를 찾아 개인정보 manifest, 권한, 결제, 계정 삭제, 제출 명령의 위험 신호를 검사한다. `data/regulatory-deadlines.json`에는 107개 마감 항목이 있고, 별도의 gold case 32개가 fleet 판정과 waiver·ruling 동작을 시험한다.

숫자가 많다는 사실보다 중요한 것은 **검사 가능한 것과 불가능한 것을 구분한 구조**다. 소스 트리에서는 `PrivacyInfo.xcprivacy`, Android manifest, API symbol, 설정 파일과 제출 script를 볼 수 있다. 그러나 App Store Connect의 계약 수락, 리뷰용 계정의 실제 로그인 가능 여부, Play Console Data safety form의 현재 답변, 국가별 배포 범위, 고객지원 URL의 정상 동작은 로컬 정적 검사만으로 알 수 없다. 저장소도 guard의 `CLEAR` 뒤에 체크리스트를 수행하도록 분리한다.

![모바일 앱 제출에서 코드 스캔 스토어 선언 콘솔 상태 사람 승인을 분리하는 컴플라이언스 아키텍처](https://heracles-jo.github.io/assets/img/posts/app-store-compliance-pre-submission-gate/architecture.svg)
_그림 1. 자동 검사는 관찰 가능한 코드와 메타데이터를 판정하고, 콘솔·계약·실기기 흐름은 별도 증거와 승인으로 합류해야 한다._

Apple의 공식 privacy manifest 문서는 앱과 SDK가 수집하는 데이터 유형과 required reason API 사용 이유를 manifest에 기록하도록 설명한다. Google Play의 Data safety 문서도 개발자가 앱과 제3자 SDK의 데이터 수집·공유·보호 방식을 정확히 선언할 책임이 있다고 명시한다. 여기서 실패가 자주 생기는 이유는 선언 파일과 실제 실행 경로의 source of truth가 다르기 때문이다. SDK를 업데이트했지만 privacy manifest와 Data safety 답변이 그대로이거나, 기능 flag로 켜진 분석 기능이 스토어 설명에는 반영되지 않을 수 있다.

따라서 사전 제출 게이트는 하나의 초록색 체크가 아니라 최소 네 계층으로 나누는 편이 안전하다.

1. **소스·빌드 계층**: manifest, entitlement, 권한, required reason API, release build 설정, 서명 대상과 SDK inventory를 검사한다.
2. **스토어 선언 계층**: 설명, 스크린샷, 지원·개인정보 URL, Data safety, App Privacy, 결제와 구독 설명의 일치 여부를 본다.
3. **운영 준비 계층**: 리뷰 계정, live backend, 기능 flag, 지역 제한, 계정 삭제, 복원 구매와 고객지원 경로를 실기기에서 확인한다.
4. **증거·승인 계층**: 누가 어떤 버전과 정책 snapshot을 확인했는지, 예외는 왜 허용됐고 언제 만료되는지 남긴다.

이 분리를 하지 않으면 자동화의 `CLEAR`가 조직 안에서 “심사 통과 보장”으로 번역된다. 도구가 볼 수 없는 상태를 깨끗하다고 간주하는 순간 fail-open이 된다.

## 정책 데이터베이스의 핵심 위험은 코드 버그보다 신선도다

스토어 정책 도구는 오늘 정확해도 다음 제출 때 틀릴 수 있다. Apple App Review Guidelines와 Google Play Developer Policy Center는 계속 수정되고, 같은 요구사항도 시행일·대상 국가·앱 유형·신규 앱과 기존 앱 여부에 따라 범위가 달라진다. 프로젝트가 citation verifier와 `verified_on` 필드를 두고 180일이 지난 출처를 경고하는 이유도 여기에 있다.

하지만 URL이 200을 반환한다는 사실은 내용이 여전히 같은 요구사항을 뒷받침한다는 뜻이 아니다. 문서 제목과 anchor가 바뀌거나, 정책 본문이 수정되거나, 지역별 예외가 추가될 수 있다. 릴리스 게이트에서 사용하는 규칙은 다음 네 값을 함께 고정해야 한다.

- app-store-compliance release 또는 commit SHA
- rejection pattern·deadline 데이터의 version과 digest
- Apple·Google 공식 문서를 마지막으로 사람이 확인한 날짜
- 앱의 target platform, 배포 국가, 기능과 SDK inventory snapshot

정책 변경을 자동으로 pull해 즉시 blocking rule로 승격하는 방식도 위험하다. 새 문구를 잘못 해석하면 정상 릴리스가 대량으로 멈춘다. 반대로 사람이 읽기 전까지 전부 advisory로 두면 실제 마감일을 놓친다. 좋은 운영 방식은 **변경 감지 → 출처 비교 → 영향받는 앱 식별 → 비차단 경고 → 표본 검증 → blocking 승격** 순서다. 법률·규제 항목은 엔지니어의 해석만으로 확정하지 말고 법무·개인정보 담당자가 적용 범위와 증거를 승인해야 한다.

## 오탐을 없애려 하지 말고 예외를 만료시킨다

정적 검사는 의미를 완전히 이해하지 못한다. 문자열이 코드 주석인지 실제 실행 경로인지, 특정 API가 테스트 target에만 있는지, 개인정보 수집이 지역별로 비활성화되는지 잘못 판단할 수 있다. 그렇다고 오탐이 나올 때마다 rule을 끄면 다음 앱의 실제 결함도 놓친다.

이 저장소의 waiver ledger 개념은 실무적으로 중요하다. 예외는 “이 규칙은 귀찮다”는 전역 해제가 아니라 앱, finding, severity, 파일, 근거와 만료일에 묶인다. 팀 내부 게이트도 같은 속성을 요구해야 한다.

| 예외 필드 | 필요한 이유 |
|---|---|
| 앱·버전·파일 | 다른 앱이나 다음 릴리스로 예외가 번지는 것을 막는다. |
| rule ID와 탐지 증거 | 무엇을 우회했는지 재현할 수 있게 한다. |
| 승인자와 근거 링크 | 개발자의 자기 승인과 구두 합의를 피한다. |
| 만료일 | SDK·정책·코드가 바뀐 뒤 오래된 판단이 남지 않게 한다. |
| 대체 통제 | 실기기 테스트, 콘솔 screenshot, 법무 확인처럼 자동 검사의 공백을 보완한다. |

오탐률만 낮추는 것은 충분하지 않다. 더 중요한 지표는 **false negative**, 즉 실제 거절 위험을 `CLEAR`로 통과시킨 비율이다. 승인된 앱만 성공 사례로 세면 위험하다. 앱이 승인됐어도 선언이 부정확할 수 있고, 다음 업데이트에서 같은 경로가 거절될 수 있다. 반대로 guard가 경고했지만 심사를 통과했다고 해서 경고가 무가치한 것도 아니다. 정책 위반과 심사 결과는 항상 일대일로 대응하지 않는다.

## AI 코딩 도구 앞의 hook은 최종 판정기가 아니다

프로젝트는 여러 AI 코딩 도구의 shell hook 앞에 guard를 설치해 `fastlane`, `eas submit`, `gradle bundleRelease` 같은 제출 명령 전에 검사를 실행한다. 이 위치는 실수를 줄이는 데 유용하다. 에이전트가 코드를 만들고 같은 세션에서 제출까지 진행하는 흐름이라면 사람이 마지막 검사를 잊는 문제를 줄일 수 있다.

그러나 개발자 홈 디렉터리의 hook만 required gate로 삼아서는 안 된다. 사용자가 다른 장비에서 제출하거나 hook을 비활성화할 수 있고, CI service account가 별도 경로로 업로드할 수 있다. 로컬 hook은 빠른 피드백 계층이고, 최종 강제는 보호된 CI workflow와 릴리스 권한에서 맡아야 한다. [xtool의 비 macOS iOS 빌드 검증](/posts/xtool-cross-platform-ios-build/)에서 빌드 경로와 최종 Apple 서명·실기기 검증을 분리했듯, 모바일 컴플라이언스도 개발 편의와 제출 권한을 분리해야 한다.

권장 구조는 이렇다.

- PR에서 빠른 source scan과 변경된 SDK·권한 diff를 실행한다.
- release candidate에서 archive/AAB 등 실제 제출 artifact를 검사한다.
- store metadata를 repository로 pull해 locale별 diff와 URL을 검증한다.
- 사람 승인에는 리뷰 계정, 삭제·구독 복원, 개인정보 흐름, 국가별 정책 증거를 첨부한다.
- 제출 credential은 모든 검사를 통과한 protected job만 사용한다.
- 승인·거절 결과를 rule ID와 연결해 다음 기준선에 반영한다.

## 비표준 라이선스는 도입 판단의 일부다

GitHub API는 이 저장소 라이선스를 `NOASSERTION`으로 반환한다. `LICENSE`와 README에는 `LicenseRef-OpenRoots-ORA-2.3`이 명시돼 있으며, 저장소 설명에 따르면 일정 매출 기준을 넘는 기업의 royalty, 재판매 제한, AI training 별도 허가 같은 조건이 있다. 이는 MIT·Apache-2.0처럼 익숙한 허용형 라이선스와 운영 조건이 다르다. 이전 릴리스의 라이선스도 날짜에 따라 다르다고 설명한다.

따라서 문서 일부를 복사하거나 guard를 조직 공통 플랫폼에 내장하기 전에 사용할 정확한 release와 행위를 법무가 검토해야 한다. 공개 저장소라는 이유로 사내 제품에 무조건 자유롭게 재배포할 수 있다고 가정하면 안 된다. 특히 여러 고객에게 compliance 서비스를 제공하거나 규칙 데이터 자체를 제품 기능으로 판매하려는 경우, 단순한 내부 개발 도구 사용과 조건이 다를 수 있다. 이 글은 법률 자문이 아니며, 실제 적용은 canonical license text와 조직의 계약 검토를 기준으로 해야 한다.

## 2주 PoC는 탐지 수보다 판정 재현성을 측정한다

처음부터 모든 앱의 제출을 차단하면 오탐과 오래된 정책 때문에 팀이 우회 경로를 만든다. 지난 6~12개월의 승인·거절 이력이 있는 앱 2~3개를 골라 shadow mode로 시작하는 편이 낫다.

![모바일 컴플라이언스 게이트를 과거 릴리스 재생부터 shadow mode 차단 승격까지 확장하는 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/app-store-compliance-pre-submission-gate/decision-gates.svg)
_그림 2. 규칙 수가 아니라 과거 결함 재현, 현재 앱의 오탐 처리, 증거 완전성과 우회 불가능성을 통과한 뒤 차단 범위를 넓힌다._

첫 주에는 과거 release commit과 당시 metadata를 재생한다. 실제로 발생했던 거절 사유를 찾는지, 승인된 릴리스에서 어떤 오탐이 나는지, 검사 시간이 PR 피드백을 방해하는지 본다. 두 번째 주에는 현재 release candidate를 대상으로 코드·artifact·스토어 선언·실기기 checklist를 연결하고, 차단은 critical 중 자동으로 증명 가능한 항목에만 적용한다.

최소 측정값은 다음과 같다.

| 영역 | 측정값 | 중단 조건 예시 |
|---|---|---|
| 탐지 품질 | 과거 거절 재현율, critical 오탐, rule별 미확인 비율 | 실제 거절 사례를 반복해서 `CLEAR` 처리 |
| 정책 신선도 | 출처 확인 경과일, 변경 감지 후 승인 시간, stale rule 수 | 적용 범위를 확인하지 못한 규칙이 blocking으로 승격 |
| 운영 마찰 | PR·release scan 시간, waiver 처리 시간, 우회 제출 수 | 개발자가 반복적으로 다른 제출 경로를 사용 |
| 증거 완전성 | artifact digest, metadata snapshot, 콘솔·실기기 확인율 | 승인자가 같은 판정을 재현할 자료가 없음 |
| 보안 | hook·CI 권한, 제출 credential 노출, 외부 PR 실행 경계 | 비신뢰 PR이 제출 secret이나 사용자 홈 설정에 접근 |
| 결과 학습 | 승인·거절과 rule ID 연결률, 수정 후 재검증 시간 | 심사 결과가 도구 개선에 전혀 반영되지 않음 |

PoC가 성공해도 모든 규칙을 즉시 required check로 만들 필요는 없다. 정적 증거가 강한 release debuggable, 필수 manifest 누락, 명백한 URL 형식 오류는 차단하기 쉽다. 반면 법적 적용 범위, 사용자 흐름의 충분성, 설명 문구의 오해 가능성은 사람 승인과 함께 두는 편이 안전하다.

## 도입 기준은 승인 보장이 아니라 불완전한 제출의 조기 발견이다

App Store Compliance Playbook은 모바일 팀에 없는 사실을 대신 만들어 주지 않는다. 앱이 실제로 어떤 데이터를 수집하는지, 어떤 국가에 배포되는지, 리뷰 계정이 작동하는지, 구독 해지가 충분히 명확한지는 팀이 증명해야 한다. 도구의 가치는 그 증명을 제출 버튼 직전에 처음 요구하지 않고 개발·PR·릴리스 과정으로 앞당기는 데 있다.

모바일 앱이 핵심 제품이고 여러 SDK·지역·앱을 운영하며, 거절 이력과 수동 체크리스트가 흩어진 조직이라면 검토 가치가 크다. 반대로 연간 릴리스가 적고 정책 담당자가 모든 제출을 직접 검토하며, 비표준 라이선스 조건을 수용하기 어렵다면 저장소를 그대로 설치하기보다 공개된 검사 관점을 참고해 사내 체크를 만드는 편이 나을 수 있다.

최종 판단은 세 질문으로 압축된다. **자동 검사가 볼 수 없는 콘솔·실기기 상태를 별도 증거로 요구하는가, 정책과 예외에 버전·승인자·만료일이 있는가, 로컬 hook을 우회해도 제출 credential 앞의 CI gate가 남는가.** 세 답이 명확할 때 사전 제출 검사는 “승인을 보장하는 점수”가 아니라 불완전한 릴리스를 더 일찍 멈추는 운영 통제가 된다.

## 1차 자료와 확인 범위

- [App Store Compliance Playbook 저장소](https://github.com/mjmirza/app-store-compliance)
- [v2.4.0 릴리스](https://github.com/mjmirza/app-store-compliance/releases/tag/v2.4.0)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Google Play Developer Policy Center](https://play.google/developer-content-policy/)
- [Google Play Data safety 안내](https://support.google.com/googleplay/android-developer/answer/10787469)
- [OpenRoots Agent License 2.3 pointer](https://github.com/mjmirza/app-store-compliance/blob/main/LICENSE)

Trending·GitHub 수치와 저장소 상태는 2026년 11월 22일 08시 11분 KST 전후의 공개 페이지와 API 스냅샷이다. 패턴·deadline·gold case 수는 main의 `v2.4.0` 데이터 파일을 직접 집계했다. 스토어 정책과 법적 의무는 바뀔 수 있으므로 실제 제출 시점의 Apple·Google 공식 문서, 콘솔 상태와 법무 검토가 우선한다.
