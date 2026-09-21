---
title: "모바일 스파이웨어 포렌식: MVT 증거 수집·판정 기준"
description: "MVT의 iOS 백업·AndroidQF·STIX IOC 분석 구조를 바탕으로 모바일 스파이웨어 조사에서 증거 보존, 오탐·미탐, 동의와 판정 경계를 정리한다."
author: heracles-jo
date: 2026-09-22 08:35:00 +0900
categories: [Security, Mobile]
tags: [mvt, mobile-forensics, mobile-spyware, incident-response, stix, digital-forensics]
image:
  path: https://heracles-jo.github.io/assets/img/posts/mvt-mobile-spyware-forensics/cover.svg
  alt: "MVT로 모바일 기기 증거를 수집하고 IOC와 행위 흔적을 교차 검증하는 포렌식 흐름"
---

휴대전화가 느려졌거나 배터리가 빨리 닳는다는 이유만으로 스파이웨어 감염을 판정할 수는 없다. 반대로 공개된 악성 도메인과 파일 해시가 발견되지 않았다고 기기가 안전하다고 결론 내려서도 안 된다. 상용 스파이웨어는 흔적을 지우고 인프라를 교체하며, 운영체제 업데이트와 정상 앱도 비슷한 로그를 만든다. **모바일 포렌식의 핵심은 탐지 도구를 한 번 실행하는 것이 아니라, 동의를 받은 증거 수집과 재현 가능한 분석, 불확실성을 보존한 판정을 하나의 절차로 묶는 데 있다.**

[mvt-project/mvt](https://github.com/mvt-project/mvt)는 Amnesty International Security Lab이 Pegasus Project 조사 과정에서 공개한 Mobile Verification Toolkit이다. `mvt-ios`는 iTunes/Finder 백업, 파일시스템 덤프, sysdiagnose를 분석하고, `mvt-android`는 AndroidQF 수집물·백업·침입 로그를 검사한다. STIX2 형식의 IOC를 대조하고 여러 포렌식 모듈의 결과를 JSON으로 남기지만, 공식 문서도 MVT를 일반 사용자의 자가 진단 앱이 아니라 기술자와 조사자를 위한 도구로 규정한다.

2026년 9월 22일 08시 50분 KST 전후 GitHub Trending daily에서 MVT는 **177 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 **13,573 stars**, 1,323 forks였고, 9월 21일 공개된 `v2026.9.21` 릴리스에는 iOS 버전 데이터 갱신, 암호화 백업 처리 의존성 업데이트, Android mount 정보의 읽기·쓰기 판정 수정이 포함됐다. 최신 저장소 활동과 수치는 확인 시점의 스냅샷이며 탐지 정확도를 보증하지 않는다. 이번 실행 환경에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근하지 못해 주제 선정에 사용하지 않았다.

## 오늘 후보에서 남은 질문은 “감염 여부를 어떻게 증명하는가”였다

오늘 후보는 에이전트 프레임워크와 개발 환경이 강세였지만, 최근 글의 제목·description·저장소 링크뿐 아니라 중심 질문까지 대조하면 상당수가 기존 클러스터와 겹쳤다. MVT는 모바일 보안이라는 점에서 최근 iOS 글과 인접하지만, 앱 설치 권한이나 테스트 격리가 아니라 **침해 흔적을 수집하고 판정하는 조사 절차**라는 별도 검색 의도가 있다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [MVT](https://github.com/mvt-project/mvt) | daily 177, 13,573 stars, MVT License 1.1, v2026.9.21 | iOS·Android 증거 수집, IOC 한계, chain of custody를 묶는 모바일 스파이웨어 포렌식 의도가 분명해 선택했다. |
| [agent-native](https://github.com/BuilderIO/agent-native) | daily 607, 5,873 stars, 라이선스 미표시, 0.8.4 계열 릴리스 | 에이전트 앱 프레임워크는 전날 Cua와 기존 장기 실행·에이전트 아키텍처 글에 인접한다. |
| [ai-memory](https://github.com/akitaonrails/ai-memory) | daily 217, 7,654 stars, MIT, v2.4.0 | 코딩 에이전트 장기 기억과 벤더 간 handoff는 기존 AI 메모리 계층 글과 검색 의도가 겹친다. |
| [Coder](https://github.com/coder/coder) | daily 461, 16,410 stars, AGPL-3.0, v2.36.6 | 에이전트용 안전한 개발 환경은 workspace·sandbox·개발 환경 제어면 클러스터와 반복 가능성이 높다. |
| [OpenStock](https://github.com/Open-Dev-Society/OpenStock) | daily 843, 17,693 stars, AGPL-3.0, 정식 release 없음 | 금융 데이터 앱은 별도 의도지만 데이터 라이선스·시세 지연·투자 오인 방지까지 검증할 1차 자료가 더 필요하다. |

[iLoader의 iOS 사이드로딩 보안](/posts/iloader-ios-sideloading-security/)은 Apple 계정, 개발 인증서와 pairing 파일이 앱 설치 권한을 어떻게 만드는지 다뤘다. MVT도 기기 백업과 pairing 계층을 지나지만 목적은 앱을 넣는 것이 아니라 이미 남은 기록을 보존하고 해석하는 것이다. [vphone-cli의 가상 iPhone 보안 경계](/posts/vphone-cli-virtual-iphone-security-boundary/)가 반복 가능한 연구 기기를 만드는 문제였다면, 이번 질문은 실제 사용자의 기기를 최대한 덜 변경하면서 어떤 증거를 확보할 것인가다.

## 분석 전에 수집 방법이 판정의 상한을 정한다

MVT의 iOS 공식 방법론은 곧바로 명령을 실행하지 말고 먼저 조사 계획을 세우라고 요구한다. 가장 많은 데이터를 얻는 방식은 jailbreak 후 전체 파일시스템을 덤프하는 것이지만, 기기·iOS 버전에 따라 불가능할 수 있고 중요한 레코드를 오염시키거나 기기 상태를 바꿀 수 있다. 기기를 사용자에게 돌려줘야 한다면 백업과 비침습 수집을 먼저 소진하고, jailbreak는 영향과 필요성을 별도로 판단해야 한다.

Finder 또는 iTunes 백업은 파일시스템 전체가 아니라 일부 데이터만 제공한다. 그래도 의심스러운 웹 기록, 메시지 첨부, 프로세스·도메인 관련 흔적을 찾는 데 충분할 수 있다. 암호화 백업에는 Safari 기록과 상태처럼 비암호화 백업에 없는 자료가 추가되므로 수집 품질이 달라진다. 다만 백업 암호를 다룬 순간 조사 환경은 새로운 민감정보 저장소가 된다. 비밀번호를 명령 이력·티켓·공유 문서에 남기지 않고, 백업 원본과 분석용 복제본의 접근 권한을 분리해야 한다.

Android는 조건이 더 까다롭다. 공식 문서는 제조사와 Android 버전에 따라 bugreport 형식과 내용이 달라지고, 일반 Android 백업의 포렌식 자료가 제한적이라고 설명한다. 현재 권장 경로는 AndroidQF로 백업·bugreport·시스템 로그를 일관된 묶음으로 수집한 뒤 `mvt-android check-androidqf`로 분석하는 것이다. 직접 ADB에서 즉석 추출하던 기능은 수집 결과가 불안정하고 AndroidQF와 일치하지 않는다는 이유로 제거됐다. 이는 편리한 실시간 접근보다 **원본 수집과 분석을 분리한 표준화된 acquisition**이 더 중요하다는 판단이다.

![MVT 모바일 포렌식에서 원본 기기부터 판정까지 증거를 분리하는 아키텍처](https://heracles-jo.github.io/assets/img/posts/mvt-mobile-spyware-forensics/architecture.svg)

아키텍처를 운영 책임으로 나누면 다섯 층이다.

1. **승인·범위 층**: 데이터 소유자의 명시적 동의, 조사 목적, 보존 기간, 반출 범위를 고정한다.
2. **수집 층**: iOS backup·filesystem·sysdiagnose 또는 AndroidQF로 원본 아티팩트를 확보한다.
3. **보존 층**: 원본을 읽기 전용으로 봉인하고 해시·시각·도구 버전·담당자를 기록한다.
4. **분석 층**: MVT 모듈과 STIX IOC를 버전 고정된 환경에서 실행하고 결과 JSON과 로그를 남긴다.
5. **판정 층**: IOC 일치, 비정상 행위, 타임라인과 외부 위협 인텔리전스를 사람이 교차 검증한다.

이 층을 섞으면 “MVT에서 경고가 나왔다”는 문장이 무엇을 뜻하는지 알 수 없다. 원본이 바뀌었는지, IOC가 언제 받은 것인지, 단축 URL 해석 과정에서 외부 요청이 발생했는지, 분석 결과를 누가 검토했는지를 재현할 수 있어야 결과가 증거가 된다.

## IOC 일치는 출발점이지 감염 판결이 아니다

MVT는 STIX2 파일에서 도메인, URL, 파일 이름·경로·해시, 프로세스 이름, 앱 ID, configuration profile ID 같은 값을 읽어 수집 자료와 대조한다. 여러 IOC 파일을 동시에 적용할 수 있고 `mvt download-iocs`로 공개 지표 묶음을 내려받을 수 있다. 그러나 지원하는 STIX 표현은 일부 단일 값 비교에 한정되며, 모든 복합 조건과 행위 관계를 표현하는 규칙 엔진은 아니다.

더 중요한 한계는 공개 IOC의 시간성이다. 공격자가 새 도메인과 인증서, 전달 경로를 사용하면 어제의 IOC에는 아무것도 걸리지 않는다. 반대로 CDN·공유 호스팅·정상 프로세스 이름처럼 문맥이 약한 지표는 오탐을 만들 수 있다. 따라서 결과는 최소한 세 단계로 분류하는 편이 낫다.

- **직접 일치**: 고유성이 높은 도메인·파일 해시·프로세스·프로파일이 신뢰할 수 있는 IOC와 일치한다.
- **정황 일치**: 비정상 crash, 의심스러운 redirect, 설치·삭제 시각, 네트워크 기록이 같은 시간대에 모인다.
- **공백**: 공개 IOC와 알려진 흔적이 없지만 수집 범위나 로그 보존 기간 때문에 배제할 수 없다.

“경고 0건”은 세 번째 상태다. 공식 README도 공개 IOC만으로 기기가 깨끗하거나 특정 스파이웨어의 표적이 아니었다고 판단할 수 없다고 경고한다. [AI 보안 감사의 커버리지 원장](/posts/cloudflare-security-audit-skill-validation-pipeline/)에서 `confirmed 0건`과 `취약점 없음`을 구분했듯, 모바일 포렌식 보고서도 분석한 자료·기간·모듈과 수집하지 못한 영역을 함께 써야 한다.

## 네트워크를 허용하면 분석기가 새로운 관찰자를 만든다

MVT는 URL IOC를 검사할 때 단축 URL을 확인하기 위해 기본적으로 HTTP HEAD 요청을 수행할 수 있다. 요청은 중복 제거와 동시 실행을 사용하며 환경 변수로 네트워크 접근과 timeout을 제어한다. 기능만 보면 편리하지만 조사 대상 URL로 외부 요청을 보내면 DNS resolver, 프록시, 목적지 서버에 조사 시각과 분석 환경의 주소가 남을 수 있다. 공격 인프라가 아직 살아 있다면 조사 사실을 알리는 신호가 될 수도 있다.

초기 triage는 `MVT_NETWORK_ACCESS_ALLOWED=false`로 오프라인 실행하고, URL 해석이 꼭 필요할 때만 별도 egress 프록시·기록 정책을 둔 격리 환경에서 수행하는 편이 안전하다. AndroidQF의 VirusTotal 연동도 같은 경계다. 비시스템 APK 해시를 외부 서비스에 보내면 파일 자체를 업로드하지 않더라도 조직이 가진 앱 목록과 조사 맥락이 간접 노출될 수 있다. API key 관리, 해시 반출 승인, rate limit, 결과 보존 조건을 사전에 정해야 한다.

MVT 플러그인도 신뢰 경계를 넓힌다. 포렌식 모듈과 사용자 정의 CLI를 확장할 수 있지만, 플러그인은 민감한 수집물과 같은 프로세스에서 동작할 수 있다. 설치 출처, version pin, dependency hash, 네트워크 권한을 검토하지 않으면 분석 도구 공급망이 원본 데이터를 읽는 새로운 제3자가 된다. [Trivy 기반 공급망 검사](/posts/github-trending-trivy-supply-chain-security/)처럼 알려진 패키지 위험을 확인하는 절차와, 실행 환경의 egress·secret·filesystem 권한 제한을 함께 둬야 한다.

## MVT License는 사용 목적까지 운영 통제에 넣는다

GitHub API가 MVT 라이선스를 `NOASSERTION`으로 표시하는 이유는 단순한 메타데이터 누락이 아니다. MVT는 Mozilla Public License 2.0을 수정한 자체 **MVT License 1.1**을 사용한다. 3.0의 Consensual Use Restriction은 기기에서 추출하거나 분석하는 데이터의 소유자가 강요 없이 명시적으로 동의하고, 절차의 성격·프라이버시 영향·보존과 폐기 정책을 충분히 안내받아야 사용을 허용한다.

공식 라이선스 문서는 이 사용 제한 때문에 FSF의 자유 소프트웨어 정의와 OSI의 오픈소스 정의를 충족하지 않을 수 있다고 직접 설명한다. 따라서 “GitHub에 공개돼 있으니 일반적인 오픈소스 포렌식 도구”라고 조달 표에 적는 것은 부정확하다. 조직이 MVT를 도입한다면 최소한 다음을 기록해야 한다.

- 누가 기기와 데이터의 소유자이며 어떤 방식으로 동의를 받았는가
- 조사자는 어떤 자료를 수집하고 누구에게 제공하는가
- 원본·복제본·보고서를 언제 폐기하는가
- 고용·수사·가정 관계에서 동의가 강요되지 않았는가
- 플러그인이나 larger work에도 같은 조건을 어떻게 적용하는가

이는 법률 자문을 대신하는 체크리스트가 아니다. 특히 직원 기기, 미성년자 기기, 압수물, 제3자 메시지가 섞인 백업은 소유권과 데이터 주체가 다를 수 있다. 기술적으로 접근 가능하다는 사실과 라이선스·법적으로 허용된다는 사실을 분리해야 한다.

## 실패 모드는 탐지 실패보다 증거 훼손에서 먼저 시작한다

공개 이슈에는 입력 parser가 특정 라인을 잘못 자르거나, MIUI·HyperOS wrapper archive에서 빈 결과인데도 성공 종료 코드를 반환하거나, 같은 AndroidQF 자료를 ZIP과 폴더로 넣었을 때 결과가 달라지는 사례가 보고돼 있다. 열린 이슈 하나가 전체 도구를 신뢰할 수 없다는 뜻은 아니다. 다만 포렌식 자동화에서 **정상 종료와 분석 완전성은 같은 상태가 아니다**라는 점을 보여 준다.

실패를 다섯 종류로 나누면 대응이 선명해진다.

| 실패 유형 | 잘못된 결론 | 통제 방법 |
|---|---|---|
| 수집 누락 | 결과가 없으므로 이상 없음 | acquisition manifest, 예상 파일 수·크기, 플랫폼별 필수 레코드 검사 |
| parser 차이 | ZIP과 디렉터리 결과 중 편한 쪽을 채택 | 동일 fixture의 두 입력 형태 회귀 비교, 경고·stderr 보존 |
| IOC 노후화 | 최신 공개 지표로 검사했으니 안전 | IOC source·commit·수집 시각 고정, 비IOC 행위 흔적 병행 |
| 원본 오염 | 재수집했으니 더 정확함 | 원본 read-only, 작업 복제본, 해시와 도구 실행 전후 비교 |
| 과도한 확정 | 단일 domain match로 감염 판정 | 타임라인·다른 모듈·전문가 검토와 반증 절차 요구 |

도구 업그레이드도 결과를 바꿀 수 있다. MVT README는 최근 v3 branch 병합이 출력 소비 스크립트를 깨뜨릴 수 있는 breaking change라고 경고한다. 운영 파이프라인은 “최신 버전”을 매번 설치하지 말고 Python·MVT·IOC·플러그인 버전과 container digest를 한 manifest에 고정해야 한다. 새 릴리스는 과거 익명화 fixture를 다시 분석해 JSON schema, record 수, warning, IOC match 차이를 비교한 뒤 승격한다.

![MVT 결과를 감염 판정으로 승격하기 전 확인해야 할 증거·동의·반증 게이트](https://heracles-jo.github.io/assets/img/posts/mvt-mobile-spyware-forensics/decision-gates.svg)

## PoC는 탐지율보다 재현성과 중단 능력을 측정한다

MVT를 사고 대응 절차에 넣기 전 실제 피해자 기기로 연습해서는 안 된다. 조직이 소유한 초기화 가능한 테스트 기기와 공개·합성 fixture를 사용하고, 알려진 IOC 일치와 정상 데이터를 섞은 corpus를 만든다. iOS 암호화·비암호화 백업, AndroidQF ZIP·디렉터리, 네트워크 차단, 오래된 IOC, 손상된 archive를 각각 독립 시나리오로 둔다.

| 측정 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 증거 무결성 | 원본·복제본 해시, acquisition manifest, 실행 전후 변경 | 원본이 writable이거나 어떤 도구가 파일을 바꿨는지 설명할 수 없음 |
| 분석 재현성 | 같은 버전·입력의 결과 hash, ZIP·폴더 차이, 경고 일치 | 동일 fixture 결과가 실행마다 달라지고 원인을 분리하지 못함 |
| 커버리지 | 실행 모듈, skipped·failed module, 수집 기간과 자료 목록 | exit 0만으로 전체 분석 성공 처리 |
| 판정 품질 | 알려진 fixture 재발견, 오탐 반증 시간, 전문가 재현률 | 단일 IOC만으로 최종 감염 라벨을 자동 부여 |
| 프라이버시 | egress 0건, secret·백업 접근자, 로그 마스킹 | URL·APK hash·개인 데이터가 승인 없이 외부 전송됨 |
| 거버넌스 | 동의서, 목적, 보존·폐기 시각, 보고서 수신자 | 데이터 소유자의 자유롭고 충분한 동의를 증명할 수 없음 |

실행 순서는 수집 검증, 오프라인 분석, 결과 schema 검증, 사람의 반증, 제한된 외부 조회 순이 안전하다. 첫 단계에서 acquisition manifest가 예상과 다르면 탐지를 계속하지 말고 수집 실패로 중단한다. MVT 결과가 비어 있어도 module error와 parser warning을 별도 실패로 집계한다. IOC match가 나오면 같은 시각대의 다른 기록과 원본 레코드를 확인하고, 고위험 판정은 독립된 분석자가 깨끗한 작업 복제본에서 재현한다.

MVT가 잘 맞는 곳은 모바일 침해 대응 역량이 있고, 민감한 백업을 격리해 보관하며, 결과를 불확실성까지 포함해 해석할 수 있는 보안팀·디지털 포렌식 조사자다. 반대로 일반 사용자의 안심 확인, 직원 감시, 배우자·가족의 비동의 조사, 자동화된 대량 기기 판정에는 맞지 않는다. 감염이 의심되지만 내부 역량이 없다면 직접 반복 실행하며 흔적을 바꾸기보다 평판 있는 전문 지원 조직에 도움을 요청하는 편이 안전하다.

MVT의 가치는 “스파이웨어를 찾아주는 명령”보다 **증거를 질문 가능한 형태로 바꾸는 공통 분석 계층**에 있다. 그러나 수집 방식이 빠뜨린 자료를 복원하지 못하고, 공개 IOC의 공백을 메우지 못하며, 동의와 보존 정책을 대신 결정하지도 않는다. 신뢰할 수 있는 모바일 포렌식은 원본 보존, 버전 고정, 오프라인 기본값, 커버리지 공개, 독립 반증, 명시적 동의를 함께 운영할 때만 성립한다.

> 1차 자료: [MVT 저장소와 README](https://github.com/mvt-project/mvt), [MVT 공식 문서](https://docs.mvt.re/en/latest/), [iOS forensic methodology](https://docs.mvt.re/en/latest/ios/methodology/), [Android forensic methodology](https://docs.mvt.re/en/latest/android/methodology/), [STIX IOC 문서](https://docs.mvt.re/en/latest/iocs/), [MVT License 설명](https://docs.mvt.re/en/latest/license/), [MVT License 1.1 원문](https://github.com/mvt-project/mvt/blob/main/LICENSE), [v2026.9.21 release](https://github.com/mvt-project/mvt/releases/tag/v2026.9.21), [최근 commits](https://github.com/mvt-project/mvt/commits/main/), [공개 issues](https://github.com/mvt-project/mvt/issues). Trending·저장소 수치는 2026년 9월 22일 08시 50분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
