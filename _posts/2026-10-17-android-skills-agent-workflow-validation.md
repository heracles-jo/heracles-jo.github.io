---
title: "Android Skills 도입: AI 코딩 지침을 빌드·테스트로 검증하는 법"
description: "Google Android Skills의 30개 공식 지침을 분석하고, 에이전트가 만든 Android 변경을 버전 고정·빌드·테스트·보안 검증으로 통제하는 도입 기준을 정리한다."
author: heracles-jo
date: 2026-10-17 08:45:00 +0900
categories: [Developer Tools, Mobile]
tags: [android-skills, android, coding-agent, agent-skills, gradle, software-testing]
image:
  path: https://heracles-jo.github.io/assets/img/posts/android-skills-agent-workflow-validation/cover.svg
  alt: "Android Skills를 AI 코딩 에이전트와 빌드·테스트 검증 게이트 사이에 배치하는 도입 구조"
---

Android 개발에 AI 코딩 에이전트를 붙였을 때 가장 위험한 오류는 문법 오류가 아니다. 모델이 몇 달 전의 Android Gradle Plugin 조합을 권하거나, 이미 폐기된 API를 그럴듯하게 사용하거나, `AndroidManifest.xml`의 exported component를 넓혀 놓고도 빌드 성공을 완료 조건으로 판단하는 오류가 더 비싸다. Android는 Gradle·Kotlin·JDK·SDK·Jetpack 라이브러리·Play 정책의 호환 범위가 함께 움직인다. 한 계층의 지식만 최신이어도 안전한 변경이 되지 않는다.

[android/skills](https://github.com/android/skills)는 이 간극을 줄이기 위해 Google Android 팀이 공개한 공식 Agent Skills 저장소다. 2026년 10월 17일 기준 저장소에는 AGP 9 전환, R8 규칙 분석, Play 정책 점검, Intent 보안, 테스트 구성, Compose·Wear·TV·XR 같은 작업을 다루는 `SKILL.md` 30개가 있다. 그러나 공식 지침이라는 이유만으로 에이전트의 변경을 신뢰할 수는 없다. **Skill은 최신 문맥과 작업 순서를 제공하는 제어 문서이지, 컴파일러·테스트·정책 심사·보안 리뷰를 대체하는 판정기가 아니다.**

같은 날 08시 55분 KST 전후 GitHub Trending daily에서 Android Skills는 `163 stars today`로 표시됐다. GitHub API 확인 시점에는 8,056 stars, 535 forks, 열린 이슈와 PR을 합쳐 37개, Apache-2.0 라이선스였고 마지막 push는 10월 16일 KST였다. 최신 릴리스는 10월 14일의 `v1.0.15`다. 수치와 활동은 확인 시점의 공개 스냅샷이며, 이번 실행 환경에서는 Search Console이나 Analytics 데이터에 접근하지 않았다.

## 후보 비교: 또 하나의 범용 스킬 모음보다 Android 변경 검증이 남았다

오늘 daily·weekly 상위권은 Claude 플러그인, 과학용 스킬, 범용 에이전트 harness처럼 이미 여러 차례 다룬 주제가 많았다. 저장소 신호보다 기존 글의 검색 의도와 실제 운영 질문을 먼저 대조했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Android Skills](https://github.com/android/skills) | daily 163, 8,056 stars, Apache-2.0, v1.0.15 | 범용 스킬 공급망이 아니라 **Android 버전 호환성·빌드·에뮬레이터·Play 정책을 에이전트 변경의 검증 게이트로 묶는 문제**가 선명하다. |
| [claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | daily 1,552, 40,519 stars, Apache-2.0 | 공식 디렉터리의 신뢰 모델은 중요하지만 Cursor Plugins와 Agent Skills 공급망 글의 중심 질문과 가깝다. |
| [scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) | daily 1,158, 51,482 stars, MIT, v2.72.0 | 과학 도메인은 별도 가치가 있으나 177개 스킬 전체를 한 글에서 평가하면 검증 범위가 지나치게 넓다. |
| [ArtCraft](https://github.com/storytold/artcraft) | weekly 22,319, 30,594 stars, Apache-2.0, v0.41.0 | 창작 엔진은 장기 가치가 있지만 최근 3D·미디어 파이프라인과 인접하고 현재 핵심 개발 운영 클러스터와 연결이 약하다. |
| [AnyPS5](https://github.com/boykopovar/AnyPS5) | weekly 25,174, 39,898 stars, GPL-2.0, v0.1.2 | 실행 파일 변환은 독립 의도지만 호환성보다 플랫폼 콘텐츠의 권리·재배포 경계가 글의 대부분을 차지할 가능성이 크다. |

기존 [Agent Skills 엔지니어링 워크플로](/posts/github-trending-agent-skills-engineering-workflow/)는 스킬을 재사용 가능한 실행 계약으로 만드는 일반 원칙을 다뤘다. [Skillspector 기반 스킬 보안](/posts/github-trending-skillspector-agent-skill-security/)은 설치 전에 악성 명령과 과도한 권한을 검사하는 공급망 문제에 초점을 맞췄다. 이번 질문은 그다음 단계다. 공식 스킬을 설치한 뒤 Android 저장소에서 실제 변경을 맡길 때 **어떤 결과물을 신뢰하고, 어떤 결과물은 반드시 도구로 다시 판정해야 하는가**를 다룬다.

## Android Skills는 지식 묶음이 아니라 작업별 제약 조건 묶음이다

공식 문서는 Skill을 모델의 기본 학습 시점보다 최근인 Android 지식과 반복 가능한 작업 순서를 필요할 때 불러오는 구조로 설명한다. 각 디렉터리에는 YAML 메타데이터가 있는 `SKILL.md`가 있고, 필요하면 `references/`, `scripts/`, `assets/`가 함께 들어간다. Claude Code와 Codex용 plugin manifest도 동일한 30개 경로를 가리킨다.

구성에서 중요한 점은 모든 Skill의 무게가 같지 않다는 것이다.

- `agp-9-upgrade`는 KMP를 지원 범위에서 제외하고, KSP·Hilt 최소 버전과 built-in Kotlin·새 DSL 전환 순서를 명시한다.
- `r8-analyzer`는 AGP·R8 버전에 따라 standalone task, 정량 분석, heuristic 분석으로 경로를 나누며 일부 경로에서 Python 스크립트를 실행한다.
- `play-policy-insights`는 정적 스캐너와 여러 분석 단계가 만드는 JSON을 집계해 compliance report를 생성한다.
- `android-intent-security`는 exported component, nested Intent, `PendingIntent`, ContentProvider, Binder caller 검증을 코드 변경 규칙으로 제공한다.
- `testing-setup`은 현재 DI·JUnit·Compose/View·Robolectric·screenshot test 구성을 먼저 읽고 기존 스택을 존중하도록 지시한다.
- `android-cli`는 SDK 관리, 프로젝트 생성, 문서 검색, emulator, 화면·layout 검사, skill 설치를 하나의 CLI 표면으로 묶는다.

![Android Skills가 에이전트의 계획 계층과 Android 빌드·테스트 판정 계층 사이에 놓이는 아키텍처](https://heracles-jo.github.io/assets/img/posts/android-skills-agent-workflow-validation/architecture.svg)

따라서 Skill을 “복사해 쓰는 프롬프트 모음”으로만 보면 부족하다. 어떤 Skill은 문서만 제공하지만, 어떤 Skill은 저장소를 스캔하고 스크립트를 실행하며 파일을 수정한다. 실행 권한, 출력 artifact, 실패 처리, 검증 비용이 서로 다르다. 설치 여부가 아니라 **활성화된 Skill이 무엇을 읽고, 무엇을 실행하고, 어떤 파일을 바꾸는지**를 작업 단위로 추적해야 한다.

[Cursor Plugins의 팀 워크플로 표준화](/posts/github-trending-cursor-plugins-agent-workflow/)에서도 plugin manifest가 있다고 결과의 품질이 보장되지는 않는다고 봤다. Android Skills는 공식 출처와 구체적인 도메인 지침이라는 장점이 있지만, 같은 원칙이 적용된다. manifest는 기능을 발견하게 하고 Skill은 행동을 유도한다. 최종 판정은 저장소의 빌드와 테스트가 맡아야 한다.

## 공식 저장소라도 버전을 고정해야 하는 이유

README는 `android skills add`와 `android skills update`를 통해 Skill을 설치·갱신하는 흐름을 제공한다. 공식 문서는 커스텀한 Skill의 이름을 바꾸지 않으면 update 과정에서 덮어써질 수 있다고 경고한다. 이는 Skill을 일반 문서가 아니라 **업데이트되는 개발 의존성**으로 취급해야 한다는 뜻이다.

팀 전체가 매번 `latest`를 받으면 같은 pull request를 재실행해도 에이전트의 판단 근거가 달라질 수 있다. 10월 14일 릴리스가 10월 17일 작업에 적절하더라도 다음 릴리스가 AGP 최소 버전, 추천 테스트 도구, 보고서 형식, 실행 스크립트를 바꾸면 결과가 달라진다. 모델·Skill·Android 도구 체인 세 축을 함께 기록하지 않으면 회귀 원인을 찾기 어렵다.

최소한 다음 항목을 실행 메타데이터로 남기는 편이 안전하다.

1. Android Skills release 또는 commit SHA
2. 활성화된 Skill 이름과 `last-updated`
3. 에이전트 제품·모델·plugin 버전
4. JDK, Gradle, AGP, Kotlin, compileSdk·targetSdk
5. 실행한 명령과 변경 전후 diff
6. 빌드·unit·instrumented·screenshot·정적 분석 결과
7. 사람이 승인한 예외와 남은 위험

저장소의 update workflow도 상위 디렉터리를 지운 뒤 Google 배포 ZIP과 별도 branch의 내용을 복사하고 plugin manifest의 Skill 목록을 다시 생성한다. 이는 유지보수 자동화로는 합리적이지만 소비자 입장에서는 내용이 release 사이에 크게 교체될 수 있음을 뜻한다. CI에서 재현성이 필요하면 검토한 tag나 commit을 내부 mirror 또는 lock 파일에 고정하고, 갱신 PR에서 Skill diff를 일반 코드 의존성처럼 리뷰해야 한다.

## “지침을 따랐다”와 “Android 변경이 맞다” 사이에는 네 개의 게이트가 필요하다

Android Skill의 출력은 네 종류의 증거를 통과해야 한다.

### 1. 정적 구조 게이트

먼저 에이전트가 잘못된 모듈이나 variant를 가정하지 않았는지 확인한다. version catalog, convention plugin, included build, product flavor, KMP 여부를 읽고 변경 대상과 지원 범위를 대조한다. `agp-9-upgrade`가 KMP를 제외하는 것처럼 Skill 자체의 limitation이 현재 저장소와 충돌하면 실행을 중단해야 한다.

이 단계에서는 다음을 자동 검사할 수 있다.

- 변경된 Gradle 파일과 실제 적용 module
- dependency alias와 직접 version 선언의 혼용
- manifest merger 결과에서 exported component·permission 변화
- 새 script와 binary의 출처, 실행 권한, network 사용
- generated file을 직접 고치지 않았는지 여부

### 2. 빌드·API 호환성 게이트

Gradle sync와 `./gradlew help`, dry run은 빠른 오류를 찾지만 충분하지 않다. 영향을 받는 variant의 compile, lint, unit test를 실행해야 한다. AGP·Kotlin·KSP·Hilt 전환은 debug만 성공하고 release에서 R8 또는 code generation이 깨질 수 있으므로 release 계열도 포함한다.

[Modern Go Guidelines를 에이전트 코드 현대화에 적용한 글](/posts/modern-go-guidelines-ai-code-modernization/)에서 버전별 규칙을 테스트와 묶어야 한다고 본 이유와 같다. 최신 지침은 잘못된 과거 습관을 줄이지만 프로젝트의 호환성 계약을 대신 알지는 못한다. Android에서는 minSdk, targetSdk, OEM 동작, manifest merger, resource shrinker까지 계약의 일부다.

### 3. 동작·UI 게이트

`testing-setup`은 local unit test, Robolectric UI test, device test, screenshot test, E2E를 구분한다. 이 분리는 에이전트 변경 검증에도 유용하다. 모든 변경을 E2E로 덮을 필요는 없지만 영향 계층에 맞는 실행 증거가 있어야 한다.

- business logic 변경: unit test와 fake 기반 오류 상태
- Compose/View 변경: semantic behavior test와 주요 window·font scale screenshot
- permission·Intent 변경: emulator 또는 device에서 허용·거부 경로
- navigation 변경: deep link, back stack, state restoration
- SDK·AGP 변경: 대표 device/API matrix와 release artifact 설치

에이전트가 screenshot test를 대량 생성했다고 UI가 맞는 것은 아니다. 기준 이미지가 잘못 업데이트되면 회귀를 승인하는 자동화가 된다. reference image 변경은 코드 diff와 분리해 사람이 확인하고, locale·font scale·dark mode·compact/expanded 화면을 필요한 범위에서 고정해야 한다.

### 4. 보안·정책 게이트

`android-intent-security`가 제공하는 allowlist와 immutable `PendingIntent` 원칙은 좋은 출발점이다. 하지만 예시 코드를 그대로 붙이는 방식은 위험하다. 앱의 실제 exported surface, partner signature, URI authority, minSdk, 인증 흐름을 반영해야 한다. 특히 서비스 caller 검증이나 ContentProvider 권한은 manifest와 runtime 코드가 함께 맞아야 한다.

`play-policy-insights`도 정적 분석 결과와 Play Console 선언을 대조하도록 설계돼 있지만, 공개 이슈에는 version catalog의 application alias를 놓치는 사례가 보고돼 있다. 자동 보고서에 위반이 없다고 해서 제출 가능하다는 뜻은 아니다. Data Safety, account deletion, restricted permission, foreground service 같은 항목은 코드 탐지 결과와 실제 제품 동작·서버 데이터 흐름·Play Console 선언을 사람이 함께 확인해야 한다.

## 실패 모드는 환각보다 조용한 부분 성공에서 나온다

에이전트 작업의 위험을 “존재하지 않는 API를 만든다”로만 보면 대응이 단순해진다. 실제로 더 흔한 문제는 일부 단계만 성공한 채 완료로 보고되는 것이다.

- AGP version은 올렸지만 convention plugin 또는 CI JDK가 그대로다.
- R8 broad keep rule을 줄여 APK 크기는 감소했지만 reflection 경로가 release에서만 깨진다.
- Intent를 sanitize했지만 `onNewIntent()` 경로에는 같은 검사가 빠진다.
- screenshot test를 추가했지만 CI는 해당 task를 실행하지 않는다.
- Play 정책 report는 생성됐지만 최신 Console declaration과 비교하지 않았다.
- Skill update가 팀 커스텀 지침을 덮어썼지만 plugin load는 정상이라 발견이 늦어진다.

![Android Skills 변경을 범위 확인부터 release artifact 검증까지 통과시키는 검증 워크플로](https://heracles-jo.github.io/assets/img/posts/android-skills-agent-workflow-validation/validation-workflow.svg)

이런 실패를 막으려면 에이전트의 자연어 “완료”를 신뢰하지 말고 gate별 artifact를 요구해야 한다. Gradle task의 exit code, JUnit XML, lint·R8 report, screenshot diff, merged manifest, APK/AAB hash, emulator 실행 log가 증거다. 보고서에 “검증함”이라고 쓰는 대신 어떤 명령을 어떤 variant와 device에서 실행했고 무엇이 실행되지 않았는지 남겨야 한다.

## PoC는 코드 생성량보다 수정 루프와 검출률을 측정해야 한다

Android Skills 도입 PoC는 전체 저장소에 30개를 설치하는 방식보다 실패 비용이 제한된 작업 세 개로 시작하는 편이 낫다.

첫 번째는 읽기 중심 작업이다. `r8-analyzer`로 기존 keep rule을 분석하되 파일 수정은 금지하고, 사람이 알고 있던 broad rule과 도구가 찾은 항목을 비교한다. 두 번째는 제한된 코드 변경이다. 내부 demo 앱의 Intent 또는 PendingIntent 한 경로를 보강하고 공격·정상 입력 test를 함께 작성한다. 세 번째는 도구 체인 변경이다. 작은 sample module에서만 AGP 9 migration을 수행해 Gradle·Kotlin·KSP·CI 호환성을 측정한다.

각 작업에서 다음 지표를 수집한다.

| 측정 항목 | 확인할 질문 |
|---|---|
| 첫 시도 빌드 성공률 | Skill이 저장소 구조와 version catalog를 정확히 읽었는가 |
| 테스트 추가 대비 결함 검출 | 생성한 test가 실제 mutation 또는 알려진 회귀를 잡는가 |
| 사람 수정 시간 | 제안 diff를 승인 가능한 상태로 고치는 데 얼마나 걸리는가 |
| 잘못된 범위 변경 | 요청 밖 module·dependency·format 변경이 발생했는가 |
| 보안·정책 누락률 | red-team checklist의 위험을 보고서가 놓쳤는가 |
| 재실행 재현성 | 같은 commit·Skill·모델에서 결과와 artifact가 얼마나 안정적인가 |
| 업그레이드 회귀 | Skill release를 올렸을 때 명령·diff·판정이 어떻게 달라지는가 |

성공선은 에이전트가 더 많은 Kotlin 코드를 쓰는 것이 아니다. 기존 수동 작업보다 검토 시간이 줄면서도 build·test·security gate의 결함 검출률이 유지되거나 높아져야 한다. Skill을 사용한 작업이 빠르지만 reviewer가 숨은 전제를 찾느라 더 오래 걸린다면 생산성이 개선된 것이 아니다.

## 도입 판단: 공식 Skill은 정책의 시작점, CI가 최종 계약이다

Android Skills의 강점은 분명하다. Android 팀이 최신 문서와 작업 순서를 task 단위로 압축했고, 범용 모델이 약한 AGP migration·R8·Play 정책·플랫폼 보안 같은 영역을 명시적으로 보강한다. plugin과 Android CLI를 통해 여러 에이전트에서 같은 지침을 재사용할 수 있다는 점도 팀 표준화에 유리하다.

그러나 저장소에는 이미 obsolete CLI 정보, 잘못된 명령, R8 analyzer의 위험한 제안, Play 정책 alias 탐지 누락 같은 공개 이슈가 있다. 활발한 수정은 긍정적이지만 “Google 공식”과 “현재 프로젝트에서 항상 정확함”은 다른 주장이다. Skill의 markdown과 script도 변경되는 소프트웨어이며, 모델은 지침을 부분적으로 따르거나 저장소 문맥에 잘못 적용할 수 있다.

현실적인 도입 순서는 이렇다. 먼저 release 또는 commit을 고정하고 읽기 전용 분석 Skill로 품질을 측정한다. 다음으로 작은 module에서 코드 변경 Skill을 사용하되 diff 범위와 실행 명령을 정책화한다. 마지막으로 build, lint, unit, instrumented, screenshot, security·policy 검증을 CI required check로 만들어 에이전트가 우회할 수 없게 한다. Skill update는 Dependabot과 비슷한 별도 PR로 받고 변경된 지침과 script를 리뷰한다.

공식 Android Skill을 도입할 때 물어야 할 질문은 “에이전트가 Android를 더 잘 아는가?”에서 끝나지 않는다. **어떤 버전의 지침으로 어떤 범위를 바꿨는가, 그 변경을 Android 도구 체인이 실제로 검증했는가, 실패했을 때 재현하고 되돌릴 증거가 남는가**를 함께 답해야 한다. Skill은 에이전트의 출발점을 개선한다. 제품에 들어갈 수 있는 코드인지 결정하는 일은 여전히 빌드·테스트·보안 게이트의 몫이다.

> 1차 자료: [Android Skills 저장소와 README](https://github.com/android/skills), [Android Skills 공식 문서](https://developer.android.com/tools/agents/android-skills), [v1.0.15 릴리스](https://github.com/android/skills/releases/tag/v1.0.15), [AGP 9 Upgrade Skill](https://github.com/android/skills/blob/main/build-system/agp/agp-9-upgrade/SKILL.md), [R8 Analyzer Skill](https://github.com/android/skills/blob/main/performance/r8-analyzer/SKILL.md), [Play Policy Insights Skill](https://github.com/android/skills/blob/main/play/play-policy-insights/SKILL.md), [Intent Security Skill](https://github.com/android/skills/blob/main/security/android-intent-security/SKILL.md), [Testing Setup Skill](https://github.com/android/skills/blob/main/testing/testing-setup/SKILL.md), [최근 commits](https://github.com/android/skills/commits/main/), [공개 issues](https://github.com/android/skills/issues), [공개 pull requests](https://github.com/android/skills/pulls). Trending과 저장소 수치는 2026년 10월 17일 08시 55분 KST 전후의 공개 스냅샷이다.
