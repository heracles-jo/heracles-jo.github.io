---
title: "Linux·Windows iOS 앱 빌드: xtool 도입 기준"
description: "xtool이 SwiftPM·Xcode SDK·Apple 서명·실기기 설치를 연결하는 방식을 분석하고, macOS 없는 iOS 개발의 지원 경계와 CI 도입 기준을 정리한다."
author: heracles-jo
date: 2026-10-14 08:15:00 +0900
categories: [Mobile, DevOps]
tags: [xtool, ios-build, swiftpm, xcode-alternative, code-signing, cross-platform-development]
image:
  path: https://heracles-jo.github.io/assets/img/posts/xtool-cross-platform-ios-build/cover.svg
  alt: "Linux와 Windows에서 xtool로 SwiftPM 기반 iOS 앱을 빌드하고 서명해 실기기에 설치하는 흐름"
---

“iOS 앱 개발에는 Mac이 필요하다”는 문장은 빌드, 서명, 시뮬레이터, App Store 배포를 한 덩어리로 묶을 때는 대체로 맞다. 그러나 각 단계를 분리하면 경계가 달라진다. Swift 컴파일러와 Swift Package Manager는 Linux에서도 실행되고, iPhone 실기기 통신에는 `usbmuxd`와 libimobiledevice 생태계가 있으며, Apple Developer Services도 일부는 API로 접근할 수 있다. 남는 문제는 Apple SDK를 Swift 도구 체인에 연결하고, 앱 번들을 만들고, 인증서·프로비저닝 프로파일로 서명한 뒤 기기에 설치하는 통합 계층이다.

[xtool](https://github.com/xtool-org/xtool)은 바로 이 빈 구간을 겨냥한다. 공식 README는 Linux·WSL·macOS에서 SwiftPM 패키지를 iOS 앱으로 빌드하고, Apple Developer Services와 연동해 서명·설치하는 도구로 설명한다. **xtool의 현실적인 가치는 Xcode를 완전히 복제하는 데 있지 않다. 코드 편집 환경과 iOS 빌드 호스트를 분리하고 싶은 팀이 어디까지 Mac 의존성을 줄일 수 있는지 검증하는 데 있다.** 이 차이를 놓치면 “Windows용 Xcode”라는 과장과 “쓸모없는 실험”이라는 과소평가 사이를 오가게 된다.

2026년 10월 14일 08시 20분 KST 전후 GitHub Trending daily에서 xtool은 **1,182 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 9,286 stars, 393 forks, 열린 이슈와 PR을 합쳐 94개, MIT 라이선스, 주 언어 Swift였고 마지막 push는 10월 14일 KST였다. 최신 정식 릴리스는 10월 6일 공개된 `1.21.0`이다. 최근 커밋에는 XcodeGen 설치 수정, Apple 로그인 수정, Xcode 프로젝트 포맷 처리, Swift 6.4 빌드 전환이 포함됐다. 이 수치와 활동은 확인 시점의 공개 스냅샷이며 안정성이나 Apple의 장기 호환성을 보증하지 않는다. 이번 실행 환경에서는 Search Console과 Analytics에 접근할 수 없어 주제 선정 근거로 사용하지 않았다.

## 후보를 비교하니 “비 macOS iOS 빌드”가 남았다

오늘 daily·weekly 후보에는 이미 이 블로그가 다룬 저장소가 여럿 다시 등장했다. 같은 저장소의 star 상승을 새 검색 의도로 오해하지 않기 위해 제목과 태그뿐 아니라 중심 질문까지 대조했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [xtool](https://github.com/xtool-org/xtool) | daily 1,182, MIT, v1.21.0, 최근 로그인·빌드 수정 | Linux·Windows에서 iOS 앱을 **빌드·서명·실기기 배포**하는 문제는 기존 IPA 수집·사이드로딩 글과 구분된다. |
| [Hyperframes](https://github.com/heygen-com/hyperframes) | weekly 4,482, Apache-2.0 | HTML 비디오 렌더링 파이프라인을 이미 별도 글에서 다뤄 검색 의도가 중복된다. |
| [VoiceStudio](https://github.com/debpalash/VoiceStudio) | daily 2,277 | 로컬 음성 제작·복제 거버넌스와 오픈소스 TTS 글이 있어 주제 잠식 위험이 높다. |
| [God's Eye View](https://github.com/bilawalsidhu/gods-eye-view) | daily 1,961 | 브라우저 OSINT와 공간 데이터 신뢰 경계를 이미 분석했다. |
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | daily 187 | 에이전트 스킬 설치·공급망·워크플로 주제가 기존 클러스터와 강하게 겹친다. |

xtool과 [iLoader의 iOS 사이드로딩 운영](/posts/iloader-ios-sideloading-security/)은 모두 Apple 계정, 인증서, 프로비저닝 프로파일과 실기기를 다루지만 출발점이 다르다. iLoader는 이미 만들어진 IPA를 개인 기기에 설치하는 신뢰 자산의 수명주기가 중심이다. xtool은 Swift 소스와 `Package.swift`에서 출발해 앱 번들을 만들고 서명 가능한 산출물로 바꾸는 **빌드 시스템**이 중심이다. [ipatool의 App Store IPA 아티팩트 거버넌스](/posts/ipatool-appstore-artifact-governance/)도 배포 후 스토어 바이너리를 수집하는 흐름이므로, 배포 전 컴파일·패키징을 다루는 xtool과 역할이 겹치지 않는다.

## Xcode를 없애는 것이 아니라 기능을 다시 조립한다

xtool 프로젝트는 일반 SwiftPM 패키지에 `xtool.yml`과 Build Server Protocol 설정을 더한다. `xtool.yml`은 Swift 라이브러리를 iOS 앱 번들로 만드는 데 필요한 bundle identifier와 앱 구조를 기술하고, `.bsp/xtool.json`은 VS Code 같은 편집기가 xtool에 빌드 정보를 요청해 SourceKit-LSP의 완성·진단·문서 조회를 사용할 수 있게 한다. 즉 IDE, 빌드 그래프, Apple SDK, 서명, 기기 설치를 하나의 거대한 앱에 넣는 대신 공개 도구와 선언 파일로 다시 연결한다.

![xtool이 SwiftPM 소스에서 iOS 실기기까지 연결하는 아키텍처](https://heracles-jo.github.io/assets/img/posts/xtool-cross-platform-ios-build/architecture.svg)

공식 Linux·Windows 설치 문서에서 확인되는 실행 경로는 다음과 같다.

1. Linux에는 Swift 6.4 도구 체인과 `usbmuxd`를 설치한다. Windows 사용자는 현재 WSL과 USB passthrough가 전제다.
2. Apple Developer 사이트에서 Xcode 27의 `Xcode.xip`를 직접 내려받고 라이선스에 동의한다.
3. `xtool setup`이 XIP에서 iOS SDK를 추출해 Swift의 Darwin SDK bundle로 설치한다.
4. `xtool new`가 SwiftPM 기반 앱 골격, `xtool.yml`, BSP 설정을 만든다.
5. `xtool dev`가 의존성을 계획하고 iOS SDK용 모듈을 빌드한 뒤 앱 번들을 구성한다.
6. Apple 계정 또는 App Store Connect API key로 인증해 기기, 인증서, App ID, provisioning profile을 준비한다.
7. 앱을 서명하고 USB로 연결된 iPhone에 설치·실행한다.

여기서 “Xcode-free”를 **Apple 자산과 무관한 빌드**로 해석하면 안 된다. Linux에서도 Xcode 배포물에서 SDK를 추출해야 하고, 공식 문서는 브라우저에서 Apple ID로 로그인해 라이선스에 동의한 뒤 XIP를 받도록 요구한다. 무료 Apple ID를 위한 password 모드는 private Apple API에 의존하며, 문서도 별도 계정을 고려하라고 경고한다. 유료 Developer Program의 API key 모드는 공개 App Store Connect API를 사용하지만 모든 개발 서비스와 Xcode 기능을 동일하게 제공한다는 뜻은 아니다.

따라서 xtool은 Apple 플랫폼을 독립적으로 재구현한 SDK가 아니다. **Apple이 배포한 SDK와 개발 서비스 위에 SwiftPM 중심의 대체 오케스트레이션을 얹은 도구**에 가깝다. 이 구조는 법적·운영적으로 중요하다. SDK 파일을 팀 내부 아티팩트 저장소에 무단 재배포하는 방식, 라이선스 동의 없이 CI 이미지에 굽는 방식, 개인 Apple ID 비밀번호를 공용 runner에 넣는 방식은 기술적으로 가능해 보여도 정당한 운영 설계가 아니다.

## 지원 범위는 “SwiftPM 앱”에서 시작해야 한다

xtool의 가장 강한 경로는 새 SwiftPM 프로젝트다. 공식 튜토리얼도 `xtool new`로 생성한 SwiftUI 앱을 `xtool dev`로 빌드하고 실기기에 설치하는 흐름을 기준으로 한다. 저장소의 `Sources`는 패키징, Developer API, 기기 통신, Xcode 프로젝트 처리, 지원 라이브러리로 나뉘어 있지만, 이것이 기존 Xcode 프로젝트의 모든 설정과 빌드 단계를 재현한다는 의미는 아니다.

공개 이슈가 경계를 잘 보여 준다. 기존 Xcode project 빌드, Linux·Windows iOS Simulator, 네이티브 Windows 지원, Flutter·React Native·Compose Multiplatform, unit test 실행은 여전히 요청 또는 개선 영역이다. 앱 extension의 dead stripping, conditional dependency, asset catalog, entitlement와 provisioning profile 정합성, Swift 버전 확인도 실제 실패 지점으로 남아 있다. 최근 PR 목록에 distribution signing, App Store Connect upload, AssetKit 기반 asset catalog, SDK build key 반영이 열린 작업으로 보인다는 점도 현재의 무게 중심이 개발용 빌드·실기기 반복에 있음을 보여 준다.

그래서 기존 iOS 앱을 그대로 옮기기 전에 다음을 분류해야 한다.

- 순수 SwiftPM 모듈과 SwiftUI 앱인가, 아니면 `.xcodeproj`·`.xcworkspace`에 설정이 집중돼 있는가?
- CocoaPods, Xcode build phase script, code generation, binary framework, resource bundle을 얼마나 사용하는가?
- app extension, widget, entitlement, associated domains, push notification처럼 서명과 capability가 복잡한가?
- unit/UI test, simulator matrix, Instruments, archive validation, App Store upload가 필수인가?
- Xcode build setting의 조건부 값과 `.xcconfig`를 재현해야 하는가?

첫 질문에 가깝고 나머지가 단순할수록 xtool의 장점이 커진다. 반대로 기존 대형 앱의 Xcode project를 그대로 대체하려 하면 도구 평가가 아니라 빌드 시스템 재작성 프로젝트가 된다. 이 경우 [C++에서 `std::format`으로 옮길 때 호환성 경계를 먼저 측정한 방법](/posts/cpp-std-format-fmt-migration/)처럼, 전체 전환보다 독립 모듈 하나를 잘라 동등성을 확인하는 접근이 낫다.

## 가장 어려운 부분은 컴파일보다 신뢰 자산이다

첫 빌드는 Swift SDK 모듈 캐시 때문에 느릴 수 있지만, 성능 문제는 캐시와 runner 크기로 어느 정도 측정할 수 있다. 더 까다로운 것은 Apple 계정과 서명 상태다. 공식 튜토리얼에서 `xtool dev`는 기기를 등록하고 인증서, App ID, provisioning profile을 만든 뒤 앱을 서명한다. 편리하지만 한 명령이 여러 원격 상태를 바꾸므로 실패 원인을 분리하지 않으면 재시도가 자산을 더 꼬이게 할 수 있다.

최근 이슈에는 인증서 체인 검증 실패, 로그인 오류, 만료 토큰, 2FA 코드 미수신, 무료 팀 인증서 serial 처리, WSL 연결 정지 등이 보인다. 이런 문제는 Swift 코드가 맞아도 빌드를 막는다. 특히 password 인증이 private API에 의존한다는 사실은 CI 표준화를 어렵게 한다. Apple이 인증 흐름이나 응답 형식을 바꾸면 xtool 릴리스가 따라잡을 때까지 파이프라인이 멈출 수 있다.

![xtool 도입 범위와 중단 조건을 구분한 의사결정 지도](https://heracles-jo.github.io/assets/img/posts/xtool-cross-platform-ios-build/decision-map.svg)

운영 경계는 다음처럼 잡는 편이 안전하다.

| 영역 | 권장 기준 | 중단 조건 |
|---|---|---|
| Apple 인증 | 유료 팀은 최소 권한 API key 우선, 개인 실험은 별도 계정과 복구 수단 사용 | 개인 주 계정 비밀번호·2FA를 공용 CI에 저장 |
| SDK 공급 | 담당자가 Apple에서 직접 내려받고 버전·해시·동의 절차를 기록 | Xcode SDK를 출처 불명 이미지나 공개 저장소에서 재배포 |
| 서명 자산 | 전용 App ID·기기·인증서로 PoC 영향 반경 제한 | 기존 운영 인증서를 자동 폐기하거나 팀 앱에 영향 가능 |
| 기기 연결 | 비주력 iPhone, USB·WSL 경로와 재연결 절차 검증 | 간헐적 성공만 있고 실패 로그를 계층별로 구분 못함 |
| 빌드 동등성 | 동일 소스의 macOS Xcode 빌드와 기능·리소스·entitlement 비교 | 서명 성공만 확인하고 런타임 차이를 측정하지 않음 |
| 탈출구 | Xcode 기반 정식 archive·배포 경로 유지 | xtool 장애 시 릴리스 전체가 중단되고 복구 경로 없음 |

[가상 iPhone 연구 환경의 보안 경계](/posts/vphone-cli-virtual-iphone-security-boundary/)와도 구분해야 한다. xtool은 iOS Simulator나 가상 iPhone을 제공하는 도구가 아니라 실제 iPhone에 앱을 넣는 개발 경로다. 따라서 테스트 격리는 VM snapshot이 아니라 별도 기기, 별도 Apple 계정·팀, 제한된 App ID와 데이터로 만들어야 한다.

## CI보다 먼저 개발 루프의 경제성을 측정한다

xtool을 바로 Linux CI에 넣기보다 개인 개발 루프에서 가치를 확인해야 한다. 가장 적합한 PoC는 SwiftPM 중심의 작은 SwiftUI 앱 또는 기존 앱에서 분리 가능한 내부 도구다. 2주 정도 다음 항목을 같은 소스의 Xcode 빌드와 비교하면 된다.

1. 깨끗한 환경의 `xtool setup` 시간과 Xcode XIP 저장·추출 비용
2. 최초 빌드와 증분 빌드 시간, SDK 모듈 캐시 적중률
3. SourceKit-LSP 진단·자동 완성·문서 탐색의 누락 정도
4. 앱 번들의 리소스, Info.plist, entitlement, embedded framework 차이
5. 무료 계정과 유료 API key 인증의 성공률, 2FA·토큰 만료 복구 시간
6. WSL USB 연결 해제·재부팅·기기 재페어링 후 복구 절차
7. 서명·설치 후 실제 기기에서의 launch, network, background mode 동작
8. xtool 버전과 Xcode SDK·Swift 버전을 올렸을 때 회귀 범위

성공선은 “Hello World가 한 번 실행됐다”가 아니다. 개발자가 하루 동안 반복 편집·빌드·설치를 수행해도 인증과 USB 상태가 예측 가능해야 하고, macOS 기준 산출물과 차이를 설명할 수 있어야 한다. 실패 로그에서 SwiftPM 해석, SDK, 패키징, 서명, 기기 연결, 런타임 문제를 구분할 수 있어야 한다. [BrewUI 글에서 GUI가 실제 `brew` 명령과 변경 상태를 숨기지 않아야 한다고 본 것](/posts/brewui-homebrew-gui-package-management/)과 같은 기준이다. 편리한 명령 하나보다 아래 계층의 상태가 관측 가능해야 팀 도구가 된다.

CI는 그다음이다. Xcode XIP와 생성된 SDK bundle은 크고 라이선스·보관 정책이 필요하다. USB 실기기를 runner에 연결하면 예약, 잠금 해제, Developer Mode, 케이블 장애, 기기 업데이트가 새로운 운영 변수가 된다. 서명용 API key도 일반 패키지 빌드 secret보다 영향이 크다. 먼저 Linux에서 **컴파일과 앱 번들 생성만** 검증하고, 정식 archive·서명·TestFlight 업로드는 macOS runner에 남기는 하이브리드 구조가 현실적일 수 있다.

## 도입 판단: Mac 제거보다 빌드 경계 가시화가 먼저다

xtool은 Linux·Windows 개발자가 Swift와 iPhone 실기기를 연결할 수 있다는 점만으로도 의미가 있다. 교육, 개인 SwiftUI 실험, 서버 중심 조직의 작은 내부 iOS 도구, SwiftPM 라이브러리 개발에는 Mac 장비 대기 시간을 줄일 수 있다. 공개 표준인 SwiftPM과 BSP를 중심에 두기 때문에 소스 구조를 Xcode UI 밖에서도 설명하게 만드는 효과도 있다.

하지만 기업의 기존 iOS 제품에서 Xcode를 즉시 없애는 선택은 아직 보수적으로 봐야 한다. 시뮬레이터, 테스트, asset catalog, extension, 복잡한 capability, archive 검증, App Store 배포까지 포함하면 Xcode가 제공하던 통합 기능을 팀이 직접 조립하고 운영해야 한다. Apple private API에 의존하는 인증 경로와 SDK 라이선스도 장기 리스크다. 최신 릴리스와 빠른 수정 활동은 긍정적이지만 플랫폼 소유자의 변경 속도를 통제할 수는 없다.

따라서 좋은 도입 목표는 “Mac 비용 0원”이 아니라 **SwiftPM 기반 코드가 어느 빌드 계층까지 이식 가능한지 측정하고, Apple 전용 단계와 일반 개발 단계를 분리하는 것**이다. 작은 앱에서 xtool과 Xcode의 산출물 동등성, 인증 복구, USB 안정성, 업그레이드 회귀를 확인한 뒤 범위를 넓혀야 한다. 그 과정에서 Xcode project에 숨어 있던 설정과 서명 의존성이 드러난다면, xtool을 최종 표준으로 채택하지 않더라도 PoC는 충분한 가치가 있다.

> 1차 자료: [xtool 저장소와 README](https://github.com/xtool-org/xtool), [Linux·Windows 설치 문서](https://xtool.sh/documentation/xtool/installation-linux/), [첫 iOS 앱 튜토리얼](https://xtool.sh/tutorials/xtool/first-app/), [v1.21.0 릴리스](https://github.com/xtool-org/xtool/releases/tag/1.21.0), [최근 commits](https://github.com/xtool-org/xtool/commits/main/), [공개 issues](https://github.com/xtool-org/xtool/issues), [공개 pull requests](https://github.com/xtool-org/xtool/pulls), [Swift Package Manager 문서](https://docs.swift.org/package-manager/). Trending·저장소 수치는 2026년 10월 14일 08시 20분 KST 전후 확인한 공개 스냅샷이다.
