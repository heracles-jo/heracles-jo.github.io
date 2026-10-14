---
title: "Tiny11 Builder Windows 11 경량 ISO: 업데이트 가능한 이미지 기준"
description: "Tiny11 Builder의 오프라인 이미지 처리 구조를 분석하고, Windows Update·Defender·복구를 유지할 경계와 Core 이미지의 운영 위험, 검증 가능한 PoC 기준을 정리한다."
author: heracles-jo
date: 2026-10-15 08:10:00 +0900
categories: [Endpoint Management, Security]
tags: [tiny11-builder, windows-11, windows-image, dism, endpoint-management, supply-chain-security]
image:
  path: https://heracles-jo.github.io/assets/img/posts/tiny11-builder-windows-image/cover.svg
  alt: "Tiny11 Builder로 Windows 11 설치 이미지를 경량화하면서 업데이트와 복구 가능성을 판단하는 구조"
---

Windows 11을 가볍게 만들고 싶다는 요구는 흔하지만, 운영 환경에서 중요한 질문은 삭제할 앱의 개수가 아니다. **만든 이미지가 다음 누적 업데이트를 받을 수 있는지, 장애가 났을 때 복구할 수 있는지, 어떤 원본과 도구로 생성했는지 재현할 수 있는지**가 더 중요하다. 설치 직후 디스크 사용량이 줄어도 Windows Update, 구성 요소 저장소, 복구 환경, Defender까지 함께 사라졌다면 절감한 용량보다 더 큰 운영 부채를 떠안을 수 있다.

[ntdevlabs/tiny11builder](https://github.com/ntdevlabs/tiny11builder)는 공식 Windows 설치 미디어의 작업 복사본을 오프라인으로 수정해 새 ISO를 만드는 도구다. 현재 기본 브랜치의 WinUI 앱은 `Tiny11`, `Tiny11 Core`, `Custom` 세 모드를 제공한다. 여기서 핵심은 “더 작게”가 아니라 **서비스 가능한 경량 이미지와 되돌릴 수 없는 실험 이미지를 구분하는 것**이다. 일반 Tiny11은 Update, Defender, WinRE, Store와 공용 런타임을 유지하지만, Core는 구성 요소 저장소와 WinRE를 제거하고 Update와 Defender를 비활성화한다. 같은 프로젝트 안에서도 운영 목적이 완전히 다르다.

2026년 10월 15일 08시 16분 KST 전후 GitHub Trending daily에서 Tiny11 Builder는 `194 stars today`로 표시됐다. GitHub API 확인 시점에는 20,195 stars, 1,553 forks, 열린 이슈와 PR을 합쳐 36개, 마지막 push는 10월 13일 KST였다. 최신 릴리스 `winui-v0.1.1`은 10월 12일 공개됐고 Windows 11 26H2 이미지가 26100 계열 servicing base를 공유하는 경우를 잘못 거부하던 문제를 수정했다. 저장소에는 독립 라이선스 파일이 없으며 NOTICE도 공개 저장소라는 사실만으로 재배포 권한이 생기지 않는다고 명시한다. 수치와 상태는 확인 시점의 공개 스냅샷이고, 이번 실행 환경에서는 Search Console이나 Analytics 데이터에 접근하지 않았다.

## 후보 비교에서 남은 질문은 “경량화”가 아니라 “이미지 수명주기”였다

오늘 daily·weekly 후보 중 높은 신호만 따라가면 이미 다룬 AI 에이전트와 음성·역공학 주제를 반복하게 된다. 저장소 이름보다 검색 의도와 기존 글의 중심 논지를 비교했다.

| 후보 | 확인 시점 신호 | 기존 글 중복과 장기 가치 판단 |
|---|---|---|
| [Tiny11 Builder](https://github.com/ntdevlabs/tiny11builder) | daily 194, v0.1.1, 26H2 servicing 호환성 수정 | [Win11Debloat 글](/posts/github-trending-win11debloat-windows-endpoint-baseline/)은 실행 중인 장비의 기준선을 다뤘다. 이번에는 **설치 전 오프라인 이미지의 서비스 가능성·출처·검증**이라는 별도 검색 의도가 있다. |
| [nvm](https://github.com/nvm-sh/nvm) | daily 70, MIT, v0.40.8 | Node 버전 관리는 장기 검색 수요가 크지만 [mise 개발 환경 컨트롤 플레인](/posts/github-trending-mise-dev-environment-control-plane/)의 런타임 표준화와 중심 질문이 겹친다. |
| [scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) | daily 146, MIT, v2.72.0 | 과학 도메인은 유효하지만 Agent Skills의 검증·공급망을 이미 여러 글에서 다뤘고, 177개 스킬 전체를 한 글로 평가하면 질문이 흐려진다. |
| [PentAGI](https://github.com/vxcontrol/pentagi) | daily 1,070, MIT, v2.2.0 | 자율 침투 테스트의 권한 경계는 중요하지만 AI 보안 감사·공개 exploit·에이전트 샌드박스 클러스터와 잠식 가능성이 높다. |
| [VoiceStudio](https://github.com/debpalash/VoiceStudio) | daily 3,547, AGPL-3.0 | 로컬 음성 제작 스택과 오픈소스 TTS를 이미 분석해 같은 저장소를 다시 다룰 이유가 부족하다. |

Tiny11 Builder는 기존 Windows 글과 표면적으로 가까워 보인다. 그러나 [Win11Debloat 기반 엔드포인트 기준선](/posts/github-trending-win11debloat-windows-endpoint-baseline/)은 설치된 운영체제의 앱·레지스트리·사용자 경험을 정책화하는 문제다. Tiny11 Builder는 배포 전에 `install.wim` 또는 `install.esd`를 수정하고 설치 미디어를 다시 조립한다. 전자는 지속 정책과 장비 상태 관리가 중심이고, 후자는 **골든 이미지 생성 파이프라인과 그 산출물의 수명주기**가 중심이다.

## 실행 중인 PC가 아니라 작업 복사본을 서비스한다

공식 usage 문서에 따르면 새 WinUI 앱은 기존 PowerShell 스크립트를 감싸 실행하지 않는다. C# 이미지 빌더가 ISO 입력, WIM/ESD 탐색, 에디션 선택, DISM 작업, 레지스트리 수정, ISO 생성을 단계별로 처리한다. 원본 미디어와 실행 중인 Windows를 직접 수정하지 않고, 작업 공간에 만든 복사본을 서비스한다는 것이 중요한 안전 경계다.

![Tiny11 Builder가 공식 ISO에서 검증된 경량 ISO를 만드는 오프라인 이미지 파이프라인](https://heracles-jo.github.io/assets/img/posts/tiny11-builder-windows-image/architecture.svg)

흐름은 다음처럼 읽을 수 있다.

1. Microsoft 공식 ISO를 내려받거나 로컬 설치 미디어를 입력한다. 내장 다운로드는 Microsoft 호스트와 리디렉션만 허용하며, 가능한 경우 공개 SHA-256도 확인한다.
2. DISM으로 이미지의 아키텍처, 빌드, 에디션, 패키지·기능·capability를 읽는다. 파일명으로 버전을 추측하지 않는다.
3. 선택한 모드에 따라 앱, 기능, 서비스, 드라이버, CBS 패키지, WinSxS payload에 작업을 적용한다.
4. 오프라인 레지스트리 hive는 고유한 임시 키로 로드하고, 쓴 값을 다시 읽어 확인한 뒤 unload한다.
5. WIM을 commit·압축하고 setup 파일을 구성한 다음 UEFI 부팅 가능한 ISO를 만든다.
6. 결과 ISO의 SHA-256, JSON 보고서, 단계별 로그와 timing을 남긴다. 중단된 작업은 checkpoint와 manifest를 검증한 뒤 재개한다.

이 구조는 [vphone-cli의 가상 iPhone 보안 경계](/posts/vphone-cli-virtual-iphone-security-boundary/)에서 펌웨어 원본, 패치 단계, 실행 격리를 분리한 것과 닮았다. 운영체제 이미지를 다루는 도구는 “한 번 부팅됐다”보다 원본, 변환, 산출물, 실행 환경의 경계를 추적할 수 있어야 한다. Tiny11 Builder가 작업별 로그와 recipe, hash, report를 남기는 이유도 여기에 있다.

다만 로그가 존재한다고 자동으로 재현 가능한 것은 아니다. 원본 ISO의 정확한 해시, Builder 릴리스와 커밋, DISM·ADK provider 버전, 선택한 에디션, recipe, 출력 압축 방식까지 함께 보존해야 한다. `latest` ISO와 최신 브랜치를 매번 조합하면 같은 recipe라도 다른 결과가 나올 수 있다.

## Tiny11과 Core의 차이는 용량이 아니라 서비스 가능성이다

일반 Tiny11 모드는 번들 앱, Edge/WebView2와 OneDrive 바이너리, 일부 하드웨어 검사·예약 저장소·자동 암호화 설정을 줄이면서 Windows Update, Defender, WinRE, Store와 공용 런타임을 유지한다. 문서는 superseded component를 정리하되 `/ResetBase`는 사용하지 않아 기존 업데이트 제거 가능성을 보존한다고 설명한다. 이것은 향후 유지보수를 고려한 절충이다.

반면 Tiny11 Core는 구성 요소 기반을 reset하고 다수 WinSxS 폴더를 삭제하며 WinRE를 제거한다. Windows Update와 Defender도 비활성화한다. 언어·업데이트·기능을 나중에 추가할 수 없고 변경을 되돌릴 수 없다. 프로젝트 자체가 Core를 테스트 VM 전용으로 명시하는 이유다.

| 판단 축 | Tiny11 | Tiny11 Core | Custom에서 지켜야 할 기준 |
|---|---|---|---|
| Windows Update | 유지 | 사용 불가 | 누적 업데이트와 기능 업데이트를 실제 적용해 확인 |
| Defender | 유지 | 비활성화 | 대체 보안 에이전트가 설치 전후 모두 동작하는지 검증 |
| WinRE 복구 | 유지 | 제거 | BitLocker·복구 파티션·현장 복구 절차와 함께 판단 |
| 기능·언어 추가 | 가능성 유지 | 불가 | 업무 언어팩, .NET, optional feature의 사후 추가 시험 |
| 권장 범위 | 제한된 파일럿, 특수 목적 장비 | 격리된 단기 VM | dependency를 모르는 보호 항목은 제거하지 않음 |

“Core가 더 작으니 더 좋다”는 판단은 이미지 크기만 최적화한 결과다. 패치할 수 없는 장기 실행 장비는 취약점과 호환성 문제가 누적된다. Defender를 끄고 WinRE까지 제거하면 침해 대응과 부팅 장애 복구 경로가 동시에 줄어든다. 폐기 가능한 악성코드 분석 VM이나 짧은 데모 환경처럼 수명이 짧고 외부 상태를 보존하지 않는 경우에는 의미가 있을 수 있지만, 개발자 노트북·키오스크·현장 단말·업무 PC의 기본 이미지로 삼기에는 위험하다.

## 최근 0.1.1 수정이 보여 주는 servicing 도구의 함정

`winui-v0.1.1`의 핵심 수정은 Windows 11 26H2 빌드 26300을 26100 버전 도구가 처리할 때 단순 숫자 비교로 거부하던 문제다. 프로젝트는 23H2의 22631이 22621 기반을, 25H2·26H2의 26200·26300이 26100 servicing base를 공유한다고 모델링했다. 또한 `dism.exe` 실행 파일 버전만 보지 않고 `DismApi.dll`과 `dismcore.dll` provider를 함께 확인한다.

이 수정은 골든 이미지 파이프라인에서 “버전이 더 크면 새 도구가 필요하다”는 단순 규칙이 왜 실패하는지 보여 준다. launcher는 shim일 수 있고 실제 servicing engine이 다른 버전을 가질 수 있다. 반대로 알려지지 않은 Insider·Canary 빌드를 비슷해 보인다는 이유로 기존 계열에 억지로 넣는 것도 위험하다. Tiny11 Builder는 알려진 enablement 계열만 매핑하고, 모르는 새 빌드는 더 최신 ADK나 provider를 요구하도록 멈춘다.

운영팀도 같은 태도를 취해야 한다. 새 Windows 릴리스가 나왔을 때 스크립트가 끝났다는 사실만으로 호환 판정을 내리지 말고 다음을 분리해 확인해야 한다.

- 도구가 이미지를 mount하고 package inventory를 정확히 읽는가
- commit 후 WIM을 다시 mount할 수 있는가
- 생성 ISO가 UEFI에서 부팅되고 설치가 완료되는가
- 설치 후 첫 누적 업데이트가 성공하는가
- `sfc`, DISM health check, Store·WinGet, Defender, WinRE가 의도한 상태인가
- 기능 업데이트 또는 repair install 경로가 남아 있는가

## 신뢰 경계는 Microsoft ISO부터 출력 ISO까지 이어진다

Tiny11 Builder는 관리자 권한으로 실행되고 운영체제 이미지를 크게 수정한다. 따라서 GUI가 편리하다는 사실보다 입력과 도구의 출처가 중요하다. 공식 문서는 Microsoft ISO 호스트만 허용하고, 자체로 가져오는 `oscdimg.exe`는 특정 Microsoft symbol server 경로와 고정 SHA-256을 요구한다고 설명한다. 설치된 도구는 Microsoft Authenticode 서명과 publisher를 확인한다. 이는 긍정적인 공급망 통제다.

하지만 릴리스 ZIP 자체는 서명되지 않았고 저장소에는 독립 라이선스 파일이 없다. 조직이 취해야 할 최소 조치는 다음과 같다.

- GitHub 릴리스 자산의 제공된 SHA-256을 별도 채널의 기록과 대조한다.
- `latest`가 아니라 검토한 tag와 commit SHA를 내부 아티팩트 저장소에 고정한다.
- 소스에서 재빌드한다면 CI workflow, NuGet 의존성, self-contained runtime notices를 함께 검토한다.
- 독립 라이선스가 없으므로 수정본이나 바이너리를 외부에 재배포하기 전에 권리 관계를 확인한다.
- Windows ISO, ADK 도구, 생성 이미지의 사내 배포가 Microsoft 라이선스·활성화 조건을 우회하지 않도록 한다.

이 판단은 [mise에서 개발 도구 다운로드와 lock·서명 검증을 함께 본 이유](/posts/github-trending-mise-dev-environment-control-plane/)와 같다. 공급망 보안은 소스가 공개됐는지 여부가 아니라 **어떤 artifact를 누가 승인했고, 어떤 해시로 실행했으며, 재현할 수 있는가**의 문제다.

## Custom 모드는 자유도가 아니라 dependency 책임을 넘긴다

Custom 모드는 사전 선택 없이 시작해 앱, protected system app, optional feature, language capability, CBS package, service, driver, WinSxS component를 개별 선택할 수 있다. 세밀하지만 dependency solver는 없다. DISM이 보호 패키지 제거를 거부할 수 있고, 직접 system app이나 WinSxS payload를 지우는 기능은 문서에서도 unsupported operation으로 분류된다.

여기서 흔한 실패는 “현재 보이지 않는 기능”을 “불필요한 기능”으로 착각하는 것이다. 인쇄·스캔, VPN, 인증서 등록, 접근성, 원격 지원, Store 기반 업데이트, 언어 입력, .NET 앱, WebView 기반 사내 앱은 평소 사용량이 낮아도 특정 업무에서 필수다. 서비스 등록을 지웠는데 공유 `svchost` binary는 남는 식으로 파일과 등록 상태가 엇갈릴 수도 있다. 삭제 성공과 업무 기능 정상은 다른 검증 항목이다.

![Tiny11 Builder 모드와 사용 환경에 따른 도입·중단 의사결정 지도](https://heracles-jo.github.io/assets/img/posts/tiny11-builder-windows-image/decision-map.svg)

Custom 이미지는 제거 목록을 크게 잡기보다 역할별 최소 recipe로 시작하는 편이 낫다. 예를 들어 교육장, CI 테스트 VM, kiosk, 개발자 워크스테이션을 하나의 “경량 Windows” 이미지로 통합하지 않는다. 장비 역할마다 필요한 드라이버, 언어, 인증, 복구, 원격 관리, 보안 에이전트가 다르기 때문이다.

## PoC는 ISO 크기가 아니라 패치와 복구 비용을 측정해야 한다

안전한 PoC는 폐기 가능한 VM에서 시작한다. 공식 Windows 11 이미지와 동일 에디션을 기준선으로 두고 Tiny11 이미지를 나란히 설치한 뒤 다음 지표를 수집한다.

1. 원본 ISO, Builder tag·commit, recipe, ADK/DISM provider, 출력 SHA-256을 한 실행 단위로 기록한다.
2. 설치 시간, 첫 부팅 시간, 초기 디스크 사용량, 메모리 사용량을 기준 이미지와 비교한다.
3. Windows Update를 반복 실행해 최신 누적 업데이트까지 도달하는 시간과 실패 코드를 측정한다.
4. Defender 상태, WinRE 진입, BitLocker 복구, 안전 모드, 시스템 복원 또는 조직의 대체 복구 절차를 시험한다.
5. Store·WinGet, Microsoft 365, VPN, 프린터·스캐너, 보안 에이전트, 원격 지원 도구를 업무 시나리오로 검증한다.
6. `sfc /scannow`, DISM health check와 이벤트 로그에서 component corruption을 확인한다.
7. 다음 Windows feature update 또는 repair install을 적용해 이미지 수명주기의 상한을 찾는다.
8. 실패 시 표준 Microsoft ISO로 재설치하고 사용자 데이터와 관리 등록을 복구하는 데 걸리는 시간을 측정한다.

성공 기준은 “3GB대 ISO를 만들었다”가 아니다. 경량화로 절감한 설치·저장 비용이 패치 실패, 지원 티켓, 재이미징, 보안 예외 비용보다 커야 한다. 특히 최신 문서에 나온 26H2 Core 빌드 시간과 ISO 크기는 특정 개발 PC와 cache 상태에서 측정한 사례이며 보편적 성능 약속이 아니다. 조직의 장비와 recipe로 다시 측정해야 한다.

[Apple container에서 Mac 컨테이너가 경량 VM 경계로 돌아간 이유](/posts/github-trending-apple-container-mac-vm-isolation/)처럼, 격리·경량화 기술은 줄어든 자원만 보면 오판하기 쉽다. 운영에서 중요한 것은 장애 시 폐기하고 다시 만들 수 있는지, 외부 상태가 분리됐는지, 업데이트와 복구가 가능한지다. Tiny11 Core를 쓰려면 이 원칙을 더 엄격하게 적용해야 한다.

## 도입 기준: 일반 Tiny11도 골든 이미지 후보일 뿐 완성품은 아니다

Tiny11 Builder는 실험실 VM, 교육용 환경, 저장 공간이 제한된 테스트 장비, 특정 역할의 반복 설치 이미지를 만드는 데 유용할 수 있다. 원본을 직접 건드리지 않고, 작업 복사본과 recipe·로그·hash를 남기며, 일반 Tiny11에서 서비스 가능성을 보존하려는 설계는 이전 PowerShell 스크립트보다 운영 파이프라인에 가까워졌다.

그렇다고 일반 Tiny11을 곧바로 조직 표준 이미지로 승인할 수는 없다. 프로젝트의 새 WinUI 구현은 아직 `0.1.1`이고 공개 이슈에는 product key 응답 파일, offline registry, GUI navigation, component cleanup 실패 같은 최근 보고가 보인다. 릴리스 패키지가 서명되지 않았고 독립 라이선스가 없는 점도 배포 정책에 영향을 준다. 무엇보다 Microsoft가 지원하는 기본 이미지에서 구성 요소를 제거한 결과에 대해 조직이 직접 호환성과 복구 책임을 져야 한다.

현실적인 결정은 세 단계다. 먼저 일반 Tiny11을 격리된 VM에서 기준 이미지와 비교한다. 다음으로 역할별 Custom recipe를 최소 제거 원칙으로 만들고 업데이트·복구·업무 앱 회귀를 자동화한다. 마지막으로 절감 효과가 운영 비용보다 큰 장비군에만 제한적으로 배포한다. Core는 패치와 복구가 필요 없는 폐기형 테스트 VM에만 남겨야 한다.

Tiny11 Builder를 평가할 때 물어야 할 질문은 “얼마나 작아지는가?”가 아니다. **우리가 제거한 구성 요소의 책임을 이해하는가, 다음 달 패치를 적용할 수 있는가, 실패한 장비를 예측 가능한 시간 안에 복구할 수 있는가**다. 세 질문에 답하지 못하면 작은 ISO는 최적화된 운영체제가 아니라 지원하기 어려운 커스텀 이미지다.

> 1차 자료: [Tiny11 Builder 저장소와 README](https://github.com/ntdevlabs/tiny11builder), [WinUI 앱 usage·개발 문서](https://github.com/ntdevlabs/tiny11builder/blob/winui-preview/docs/usage.md), [v0.1.1 릴리스](https://github.com/ntdevlabs/tiny11builder/releases/tag/winui-v0.1.1), [NOTICE](https://github.com/ntdevlabs/tiny11builder/blob/winui-preview/NOTICE.md), [최근 commits](https://github.com/ntdevlabs/tiny11builder/commits/winui-preview/), [공개 issues](https://github.com/ntdevlabs/tiny11builder/issues), [공개 pull requests](https://github.com/ntdevlabs/tiny11builder/pulls), [Microsoft DISM 지원 플랫폼 문서](https://learn.microsoft.com/windows-hardware/manufacture/desktop/dism-supported-platforms), [Windows ADK 지원 문서](https://learn.microsoft.com/windows-hardware/get-started/adk-install). Trending과 저장소 수치는 2026년 10월 15일 08시 16분 KST 전후의 공개 스냅샷이다.
