---
title: "SimpleX Chat과 식별자 없는 메시징의 설계 비용"
description: "SimpleX Chat의 대화별 단방향 큐와 2-hop private routing을 바탕으로 메타데이터 최소화가 온보딩, 복구, 푸시 알림, 자체 릴레이 운영과 규정 준수에 만드는 비용을 분석한다."
author: heracles-jo
date: 2026-06-30 07:31:00 +0900
categories: [Security, Collaboration]
tags: [simplex-chat, privacy, security, messaging]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-simplex-chat-private-messaging/cover.svg
  alt: 사용자 식별자 없이 동작하는 프라이버시 중심 메시징 네트워크 SimpleX Chat 분석
---

SimpleX Chat을 “Signal보다 더 안전한 메신저”라고 한 줄로 요약하면 핵심을 놓친다. SimpleX가 바꾸려는 것은 암호화 알고리즘 하나가 아니라 메시지 전달 주소의 단위다. 일반적인 메신저는 전화번호, 사용자명, 계정 ID, 홈서버 주소, 공개키처럼 여러 대화에서 재사용되는 식별자를 중심으로 연락처와 전달 경로를 만든다. SimpleX는 네트워크 전체에서 사용자를 가리키는 주소 대신, 수신자가 만든 **대화별 단방향 메시지 큐**를 사용한다. 메시지 본문뿐 아니라 “누가 누구와 연결됐는가”라는 관계 그래프의 노출을 줄이려는 설계다.

이 선택은 공짜가 아니다. 검색 가능한 주소록, 중앙 계정 복구, 쉬운 멀티 디바이스, 조직 SSO, 관리자 보존, 스팸 필터 같은 기능은 재사용 가능한 신원과 중앙 상태가 있을 때 만들기 쉽다. SimpleX는 메타데이터를 줄이는 대신 초대 링크 전달, 상대 검증, 장치 데이터 보존, 알림 설정, 릴레이 선택과 장애 대응을 사용자와 운영자에게 더 많이 돌려준다. 따라서 도입 판단의 질문은 “프라이버시 기능이 많은가”가 아니라 **우리 위협 모델에서 관계 그래프를 덜 노출하는 이익이 운영 비용보다 큰가**여야 한다.

2026년 11월 17일 KST [GitHub API 저장소 응답](https://api.github.com/repos/simplex-chat/simplex-chat) 스냅샷에서 [simplex-chat/simplex-chat](https://github.com/simplex-chat/simplex-chat)은 19,710 stars, 1,321 forks, Haskell 기반, AGPL-3.0 라이선스였고 최신 릴리스는 2026년 11월 14일의 `v7.1.4`였다. 해당 릴리스는 새로운 Trail of Bits 보안 감사를 알리면서 보고서와 수정 설명은 추후 공개할 예정이라고 밝혔다. 즉 감사 수행 발표는 최신 신뢰 신호지만, 아직 공개되지 않은 보고서 내용을 근거로 안전성을 단정해서는 안 된다. 프로젝트의 보안 정책에는 2022년 구현 평가와 2024년 프로토콜 암호 설계 검토가 별도로 기록되어 있다.

이 글은 기존의 [SimpleX 네트워크 구조·Signal·Matrix·Session 비교 글](/posts/github-trending-simplex-private-messaging-network/)을 반복하지 않는다. 이번에는 식별자 없는 설계를 실제 개인·조직 워크플로에 넣을 때 발생하는 **복구, 릴레이 운영, 푸시 알림, 감사, 공급망 검증의 비용**을 중심으로 본다.

## “식별자가 없다”는 말을 정확히 해석해야 한다

SimpleX에도 로컬 프로필 이름, 대화 상대 정보, 큐 주소, 암호학적 자격 증명, 선택적으로 공개할 수 있는 장기 contact address와 SimpleX name이 존재한다. 따라서 어떤 식별자도 전혀 없다고 이해하면 틀리다. 공식 문서의 핵심 주장은 **네트워크 전체에서 한 사용자를 지속적으로 가리키는 사용자 프로필 ID가 메시지 전달에 필요하지 않다**는 것이다.

이 차이는 중요하다. 대화마다 별도의 큐와 자격 증명을 쓰면 한 릴레이가 관찰한 큐 A와 큐 B가 같은 사람의 것이라고 바로 연결하기 어려워진다. 반면 사용자가 같은 전송 연결과 IP를 여러 큐에 반복 사용하거나, 장기 주소를 넓게 공개하거나, 모든 연락처에 동일한 프로필 정보를 쓰면 애플리케이션·네트워크 관찰자가 상관관계를 만들 단서는 다시 생긴다. 프로토콜 설계는 연결 가능성을 낮출 뿐, 사용 행태와 단말 흔적까지 지우지 않는다.

SimpleX의 “ID 없음”은 익명성을 자동 보장하는 마케팅 문구가 아니라 주소 설계의 제약이다. 이 제약이 주는 이익과 비용을 각각 분리해서 봐야 한다.

## 아키텍처: 계정 서버가 아니라 리소스 주소를 가진 릴레이 네트워크

공식 프로토콜 개요는 SimpleX를 endpoint-based addressing이 아닌 resource-based addressing 네트워크로 설명한다. 사용자를 목적지 주소로 삼는 대신 특정 릴레이의 큐나 파일 packet이 주소가 된다. Chat 애플리케이션 아래에 Agent와 Client 계층이 있고, Client가 SMP(SimpleX Messaging Protocol)로 독립적인 router와 통신한다.

```text
SimpleX Chat UI / local profile
  → Chat core and Agent
  → SimpleX Client
  → first SMP router (sender transport is visible here)
  → second SMP router (recipient retrieves here)
  → recipient Client / Agent / Chat
```

SMP 큐는 수신자가 만들고, 송신과 수신 권한에 서로 다른 암호학적 자격 증명을 사용한다. 양방향 대화는 하나의 공유 mailbox가 아니라 방향별 큐를 조합해 구성한다. 큰 파일은 메시지 큐에 그대로 넣지 않고 XFTP의 packet 주소와 별도 relay를 사용한다. 공식 privacy 문서에 따르면 메시지는 고정 16KB block으로 패딩되며 파일은 정해진 크기의 chunk로 전송된다.

private routing은 두 router 경로를 사용해 송신자의 IP·session을 수신자가 선택한 destination router로부터 분리하려는 구조다. 첫 router는 송신 측 연결을 알고, 두 번째 router는 수신 측 연결을 알지만, 한 router가 양쪽 정보를 모두 갖지 않도록 역할을 나눈다. 이것은 Tor와 동일한 익명 네트워크라는 뜻이 아니다. 공식 프로토콜도 트래픽 시간, 연결 재사용, 악성 router 기록, 수동 네트워크 관찰자를 통한 correlation 위험이 남는다고 설명한다.

![사용자 식별자 없이 동작하는 프라이버시 중심 메시징 네트워크 SimpleX Chat 분석](https://heracles-jo.github.io/assets/img/posts/github-trending-simplex-chat-private-messaging/architecture.svg)

## 메타데이터 최소화가 주는 실질적 이점

### 중앙 사용자 디렉터리가 공격 표면이 되지 않는다

전화번호나 사용자명으로 전체 사용자를 찾는 모델에서는 enumeration, 연락처 업로드, 계정 존재 확인, 프로필 scraping이 관계 분석의 출발점이 된다. SimpleX는 one-time link나 QR, 선택적 장기 주소를 통해 연결한다. 사용자는 초대를 공유하기 전에는 일반적인 사용자 검색 대상이 되지 않는다.

이 특성은 내부 제보, 취약점 조율, 사고 대응, 민감한 외부 파트너 연락처럼 **접촉 사실 자체가 중요한 정보**인 상황에서 의미가 있다. 메시지 본문이 암호화되어도 특정 사건 직후 법무팀·포렌식 업체·경영진 사이의 연락 빈도가 증가했다는 사실은 공격자에게 가치가 있다.

### relay는 계정과 연락처 저장소가 아니다

공식 문서상 SMP router는 사용자 계정을 호스팅하지 않고, 전달 전 암호화된 메시지를 일시적으로 buffer한다. 프로필과 연락처, 대화 기록은 기본적으로 단말에 있다. 운영자가 자체 relay를 세우더라도 중앙 서버 데이터베이스 하나를 탈취해 전체 사용자와 연락처를 얻는 전통적 계정형 구조와는 다른 공격 표면을 가진다.

다만 “서버가 아무것도 모른다”는 표현도 과하다. router는 연결되는 IP, timing, queue operation과 전송 session의 일부를 관찰할 수 있고, 운영자가 소프트웨어를 수정해 더 많은 로그를 남길 가능성도 있다. SimpleX의 장점은 수집할 수 있는 정보와 이를 전역 사용자 ID에 연결하는 능력을 줄이는 데 있지, 모든 네트워크 흔적을 제거하는 데 있지 않다.

### relay 선택권과 이동성이 있다

수신자는 연락처별로 메시지를 받을 relay를 선택할 수 있고, 자체 서버나 다른 운영자의 서버를 사용할 수 있다. 한 중앙 사업자의 계정 namespace에 종속되지 않는다는 점은 검열·장애·사업자 정책 변경에 대한 복원력을 높일 수 있다.

그러나 자체 운영이 곧 더 강한 익명성을 뜻하지는 않는다. 조직 전용 relay는 패치와 로그 정책을 통제하기 쉽지만, 외부 관찰자에게 “이 relay를 쓰는 집단”이라는 식별 가능한 경계를 만들 수 있다. 공개 대형 relay는 통제권이 낮은 대신 더 많은 사용자 traffic에 섞일 가능성이 있다. 공식 프로토콜 문서도 이 군중 크기와 신뢰의 trade-off를 명시한다.

## 편의성을 제거하면 운영 절차가 보안 기능이 된다

### 초대 링크는 신원 검증 절차를 대체하지 않는다

SimpleX 연결은 one-time link나 QR로 시작할 수 있다. 링크는 이메일이나 기존 메신저 같은 별도 채널로 전달할 수 있지만, 링크를 보낸 사람이 실제 상대인지와 전달 중 교체되지 않았는지는 확인해야 한다. 연결 후 security code를 비교할 수 있는 이유도 여기에 있다.

조직 PoC에서는 “링크를 보낼 수 있다”를 성공으로 보면 안 된다. 링크를 어떤 채널로 전달하고, 첫 대화에서 어떤 문구로 상대를 확인하며, 고위험 연락처의 security code를 음성·대면·기존 서명 채널 중 어디서 검증할지를 정해야 한다. 이 절차가 없으면 전역 ID를 없앤 이익이 사회공학 공격에 의해 사라질 수 있다.

### 복구 불가능성이 데이터 주권의 반대편이다

공식 privacy 문서는 프로필과 대화 기록이 단말에 저장되므로 앱을 삭제하고 backup이 없으면 데이터와 private connection을 영구적으로 잃는다고 명시한다. 중앙 사업자가 비밀번호 재설정 이메일로 연락망을 복구해 주는 구조가 아니다. 이 특성은 서버 탈취 위험을 낮추지만, 장치 분실·고장·초기화·퇴사 처리 비용을 키운다.

백업 파일을 만들었다면 그 파일은 연락처와 대화가 집중된 고가치 자산이 된다. 암호, 저장 위치, 복사본 수, 복구 테스트, 폐기 절차가 필요하다. backup을 개인 클라우드에 무심코 올리면 전송 중 메타데이터를 줄인 설계가 저장 시점의 중앙집중 위험으로 되돌아올 수 있다.

Linked device와 프로필 이전 기능도 운영 검증 대상이다. 장치 두 대에서 같은 프로필 복사본을 임의로 동시에 사용하면 E2EE 상태를 깨뜨릴 수 있다는 공식 안내가 있으므로, 사용자가 데이터 폴더를 단순 동기화하는 방식은 피해야 한다. 모바일·데스크톱 연결은 앱이 제공하는 절차로 시험해야 한다.

### 푸시 알림은 모바일 OS 사업자와 별도 서버를 다시 경계에 넣는다

모바일에서 즉시 알림을 받으려면 운영체제 push 생태계를 완전히 피하기 어렵다. SimpleX 사용자 가이드는 iOS에서 instant notification이 편의성과 metadata 사이의 trade-off라고 설명한다. privacy 문서는 notification server가 device token과 알림이 활성화된 queue 수, queue별 대략적 메시지 활동을 관찰할 수 있다고 적는다. Apple에는 E2EE된 notification metadata가 전달되지만 알림 시각과 수량 자체는 별도 신호가 될 수 있다.

따라서 고위험 사용자는 instant, periodic, no push 모드의 지연·배터리·metadata 차이를 실제 기기에서 시험해야 한다. 메시지 본문 E2EE만 보고 notification path를 위협 모델에서 빼면 안 된다.

## 자체 SMP relay 운영은 프라이버시 제품 구매가 아니라 SRE 업무다

SimpleX는 systemd와 Docker 기반 SMP server 운영 문서를 제공한다. 필요한 것은 VPS, 도메인, TLS·offline certificate, 방화벽, 상태 디렉터리, server password, 업데이트와 모니터링이다. server를 띄우는 명령 자체는 어렵지 않지만, 운영 품질은 다음 질문에 달려 있다.

- private key와 offline certificate를 어디에 보관하고 어떻게 회전할 것인가?
- 메시지 store log와 daily statistics가 어떤 데이터를 남기며 보존 기간은 얼마인가?
- disk full, certificate expiry, database 손상, process hang을 어떤 health check로 탐지할 것인가?
- DDoS·스팸·과도한 queue 생성에 어떤 제한을 둘 것인가?
- 릴리스 전 staging에서 migration과 rollback을 검증할 수 있는가?
- server 장애 후 기존 연락처의 receiving address를 어떻게 이동할 것인가?

공개 preset relay는 availability와 retention을 보장하는 계약형 서비스가 아니다. 공식 privacy policy도 public relay를 실험적이며 “as is”로 제공한다고 밝힌다. 조직이 업무 연속성을 요구한다면 복수 operator, 자체 relay, 비상 연락 채널, 장애 공지 절차를 함께 설계해야 한다.

자체 relay 로그를 많이 남기면 장애 분석은 쉬워지지만 metadata 최소화 목표와 충돌한다. 반대로 로그를 전혀 남기지 않으면 abuse와 장애 원인 분석이 어렵다. 정답은 “무로그” 선언이 아니라 필요한 지표를 queue·IP와 장기간 연결하지 않으면서 health, capacity, error rate를 관측하는 것이다. 이는 [Mattermost를 보안형 협업 운영 평면으로 볼 때의 감사·가용성 요구](/posts/github-trending-mattermost-secure-dev-collaboration/)와 반대 방향의 trade-off다. Mattermost는 중앙 관리와 감사가 가치이고, SimpleX는 중앙 관계 그래프를 만들지 않는 것이 가치다.

## 보안 경계는 relay보다 endpoint에서 더 자주 무너진다

### 단말 탈취와 화면 노출

공식 security policy는 사용자 또는 root 권한으로 단말에 접근한 공격자가 앱 storage, 암호화된 database, 단말에 저장된 database key에 접근할 수 있음을 위협 모델 밖 또는 제한적 완화 영역으로 명시한다. E2EE는 잠금 해제된 휴대폰의 알림 미리보기, screenshot, 키보드 clipboard, malware를 막아 주지 않는다.

고위험 배포에서는 OS 암호화, 강한 화면 잠금, 알림 preview 제한, biometric 실패 시 passcode 정책, 앱 database passphrase, MDM 원격 삭제, rooted·jailbroken 장치 금지를 함께 검토해야 한다. “메신저가 안전하다”는 문장보다 단말 운영 기준이 더 중요하다.

### 릴리스 공급망 검증

SimpleX는 GitHub release에 platform별 SHA-256을 공개하고, 공식 build signing key로 release signature를 검증하는 절차와 Linux·Android reproducible build 문서를 제공한다. 민감한 환경에서는 앱스토어 배포만 신뢰할지, 공식 binary hash와 signature를 확인할지, 직접 재현 빌드를 할지 위험 수준에 따라 정해야 한다.

재현 빌드는 비용이 크다. 공식 문서는 Android 전체 architecture 재현에 대규모 disk와 긴 build 시간이 필요하다고 안내한다. 모든 팀이 매 릴리스마다 수행하기 어렵다면 최소한 서명 key fingerprint 검증, checksum 확인, 승인된 version pinning, 긴급 security release 배포 SLA를 정해야 한다. 최신 `v7.1.4`가 연락처에게 upgrade를 요청한 것처럼 프라이버시 메신저도 신속한 patch 운영 없이는 안전하지 않다.

### 공개 감사는 범위와 시점을 읽어야 한다

2022년 구현 audit, 2024년 protocol cryptographic review, 2026년 새 audit 발표는 긍정적인 신호다. 그러나 각 평가는 특정 commit과 범위를 본다. 이후 추가된 mobile UI, linked device, group·channel, relay, notification, file transfer 변화가 모두 같은 깊이로 검토됐다고 가정할 수 없다.

조직은 audit 유무를 체크박스로 쓰지 말고 report 범위, 발견 사항의 severity, 수정 commit, 회귀 테스트, 현재 배포 version과의 차이를 추적해야 한다. 2026년 audit report는 2026년 11월 17일 확인 시점에는 공개 예정 상태이므로 공개 후 findings와 remediation을 다시 검토해야 한다.

## Signal·Matrix·Mattermost와 비교할 때 질문이 달라야 한다

| 선택지 | 우선 최적화하는 것 | 운영 강점 | SimpleX 대비 비용·한계 |
|---|---|---|---|
| Signal | 대중적 E2EE와 사용성 | 성숙한 앱 경험, 쉬운 연락과 그룹 사용 | 계정·연락처·push 생태계의 metadata를 완전히 없애지는 않음 |
| Matrix | 연합형 조직·커뮤니티 통신 | 홈서버 통제, room·bridge·조직 운영 | 계정·room·membership event가 풍부한 metadata와 운영 부담을 만듦 |
| Mattermost | 중앙 관리형 업무 협업 | SSO, 감사, 보존, ChatOps, 관리 정책 | 관계 그래프와 기록을 중앙 시스템에 의도적으로 모음 |
| SimpleX | 전역 사용자 ID 없는 private connection | 대화별 queue, relay 선택, 관계 연결 가능성 축소 | 발견성, 복구, 감사, 온보딩, 자체 운영이 어려움 |

SimpleX는 전사 협업 도구의 자연스러운 대체재가 아니다. eDiscovery, 법적 보존, 관리자 계정 회수, 퇴사자 접근 종료, DLP, 조직 검색이 필수라면 중앙 관리형 도구가 더 적합하다. [Logto의 ID 운영 평면 분석](/posts/github-trending-logto-identity-infrastructure/)에서 다룬 SSO·RBAC·조직 수명주기는 SimpleX가 의도적으로 중심에 두지 않는 문제다.

반대로 내부 제보자와 조사팀의 접촉 사실, 취약점 reporter와 vendor의 관계, 고위험 지역 인력의 연락망처럼 중앙 디렉터리와 관계 그래프 자체가 위험하다면 SimpleX의 비용을 지불할 이유가 생긴다. 핵심은 공식 기록 채널과 비밀 접촉 채널을 구분하는 것이다.

## 조직 PoC는 기능 목록이 아니라 실패 조건을 시험해야 한다

![사용자 식별자 없이 동작하는 프라이버시 중심 메시징 네트워크 SimpleX Chat 분석 체크리스트](https://heracles-jo.github.io/assets/img/posts/github-trending-simplex-chat-private-messaging/checklist.svg)

2주 PoC라면 10~20명의 제한된 참가자와 두세 개의 명확한 시나리오가 적당하다. 실제 기밀을 넣기 전에 다음 항목을 시험해야 한다.

### 위협 모델과 정책 경계

- 보호 대상이 본문, 연락 관계, IP, 접속 시각, 장치 데이터 중 무엇인지 우선순위를 정한다.
- 법적 보존·감사 대상 대화와 기록을 남기지 않을 고위험 접촉을 구분한다.
- SimpleX에서 공유하면 안 되는 고객 정보, regulated data, 장기 기록 유형을 정한다.
- 사고 시 기존 공식 채널로 전환할 조건과 책임자를 정한다.

### 연결과 사용자 검증

- one-time link를 이메일, 기존 메신저, 대면 QR 중 어떤 채널로 전달할지 시험한다.
- 링크 교체와 가짜 지원 계정 시나리오를 만들어 사용자가 security code를 검증하는지 본다.
- 장기 contact address를 공개할 사람과 일회성 link만 사용할 사람을 구분한다.
- 비기술 사용자가 설명 없이 첫 연결을 완료하는 데 걸리는 시간과 실패율을 측정한다.

### 장치·백업·복구

- 모바일 분실, 앱 삭제, OS 교체, 새 휴대폰 이전, desktop linked device 해제 절차를 실제로 실행한다.
- backup 파일의 암호화·저장·복원·폐기를 검증하고, 복구 후 연락처와 메시지 상태를 확인한다.
- 화면 잠금, 알림 preview, database passphrase, MDM 정책이 기대대로 작동하는지 확인한다.
- 퇴사자나 역할 변경자의 장치에서 접근을 종료할 수 있는 범위를 문서화한다.

### 네트워크와 relay

- 회사 Wi-Fi, VPN, mobile network, 제한된 국가·프록시 환경에서 연결 성공률과 지연을 측정한다.
- 공개 relay, 자체 relay, 혼합 구성에서 message delivery p50/p95, offline delivery, file upload 성공률을 비교한다.
- relay 장애, certificate expiry, disk full, 재시작, version upgrade를 주입해 복구 시간을 측정한다.
- 로그와 monitoring에 IP·queue·message timing이 얼마나 남는지 확인하고 보존 기간을 정한다.

### 릴리스·보안 대응

- GitHub release checksum과 signature를 검증하는 절차를 한 번 실제로 수행한다.
- security release 공지 후 모바일·desktop·server를 며칠 안에 올릴지 SLA를 정한다.
- audit report와 remediation을 누가 읽고 배포 version에 반영할지 책임을 지정한다.
- AGPL-3.0이 내부 수정, 재배포, 외부 서비스 제공 방식과 충돌하지 않는지 법무 검토한다.

PoC 결과는 “사용자 만족도” 하나로 끝내지 말고 연결 완료율, 상대 검증률, 메시지·파일 전달 성공률, 알림 지연, battery 영향, backup 복구 성공률, relay 장애 복구 시간, support 문의 수를 함께 봐야 한다. 프라이버시 이익이 추상적인데 운영 비용만 측정되면 도입 논의가 왜곡되므로, 위협 모델에서 제거하거나 줄인 metadata path도 명시적으로 기록해야 한다.

## 적합한 팀과 피해야 할 도입 방식

SimpleX는 취약점 제보, 사고 대응, 내부 제보, 법무가 승인한 민감 연락, 언론·인권·현장 조사처럼 관계 자체가 민감한 제한된 채널에 적합하다. 사용자 교육과 단말 보안, backup, relay 운영을 맡을 기술 인력이 있고, 중앙 복구보다 metadata 최소화가 우선인 경우에 가치가 커진다.

반대로 전사 메신저를 한 번에 교체하거나 “서버가 내용을 못 보니 규정 준수도 자동 해결된다”는 접근은 피해야 한다. 대화 보존과 eDiscovery가 법적 의무인 조직, SSO와 자동 계정 회수가 필요한 조직, non-technical 사용자가 많은 대규모 조직에는 기본 업무 도구로서 마찰이 크다. 자체 relay를 세우면서 모든 사용자를 한 도메인과 IP 범위에 모으면 오히려 조직 경계를 더 잘 드러낼 수도 있다.

실무적인 결론은 SimpleX를 하나의 제품이 아니라 **메타데이터 예산을 줄이는 별도 통신 계층**으로 보는 것이다. 공식 업무 기록은 중앙 관리형 시스템에 남기고, 접촉 사실의 노출 비용이 높은 좁은 시나리오만 SimpleX로 분리하는 혼합 운영이 더 현실적이다. 이때 초대 링크, security code, 단말 잠금, backup, notification, relay log, patch SLA가 모두 보안 기능의 일부가 된다.

SimpleX의 설계가 중요한 이유는 전역 ID가 편의 기능의 기반인 동시에 감시와 상관관계 분석의 기반이기도 하다는 점을 드러내기 때문이다. 그러나 ID를 없애면 사라지는 것은 metadata만이 아니다. 검색, 복구, 감사, 자동화도 함께 어려워진다. 그 비용을 이해하고 감당할 수 있는 팀만이 식별자 없는 메시징의 이점을 실제 보안으로 바꿀 수 있다.

> 1차 출처: [simplex-chat/simplex-chat 저장소](https://github.com/simplex-chat/simplex-chat), [공식 README](https://github.com/simplex-chat/simplex-chat/blob/stable/README.md), [SimpleX platform 설명](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/SIMPLEX.md), [SimpleXMQ 프로토콜 개요와 threat model](https://github.com/simplex-chat/simplexmq/blob/stable/protocol/overview-tjr.md), [Privacy Policy](https://github.com/simplex-chat/simplex-chat/blob/stable/PRIVACY.md), [Security Policy](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/SECURITY.md), [SMP server 운영 문서](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/SERVER.md), [release 검증·재현 빌드 문서](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/REPRODUCE.md), [v7.1.4 릴리스](https://github.com/simplex-chat/simplex-chat/releases/tag/v7.1.4), [2022 Trail of Bits audit 보고서](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/SimpleX_Chat_Final_Report_11_03_2022.pdf), [2024 design review 보고서](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/SimpleX_Design_Review_2024_Summary_Report_12_08_2024.pdf). 저장소 수치는 2026년 11월 17일 KST GitHub API 확인 시점의 스냅샷이며, v7.1.4에서 발표한 새 audit 보고서는 그 시점에 공개 예정 상태였다.
