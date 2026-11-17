---
title: "Uptime Kuma 셀프호스팅 모니터링: 외부 감시·복구 설계 기준"
description: "Uptime Kuma의 HTTP·TCP·DNS 감시와 상태 페이지를 운영할 때 감시 위치, 알림 실패, 보안 패치, 백업·복구를 검증하는 실무 기준을 정리한다."
author: heracles-jo
date: 2026-11-15 08:30:00 +0900
categories: [Cloud Infrastructure, Observability]
tags: [uptime-kuma, incident-response, docker, self-hosted-monitoring]
image:
  path: https://heracles-jo.github.io/assets/img/posts/uptime-kuma-self-hosted-monitoring/cover.svg
  alt: "Uptime Kuma 셀프호스팅 모니터링의 감시 위치, 알림, 상태 페이지, 복구 경계"
---

서비스가 응답하는지 확인하는 일은 단순해 보인다. 일정 간격으로 URL을 호출하고 실패하면 메시지를 보내면 된다. 그러나 실제 장애에서는 모니터링 서버가 애플리케이션과 함께 멈추고, 내부 DNS만 정상이라 외부 사용자의 실패를 놓치며, 알림 채널도 같은 네트워크 장애에 묶인다. 상태 페이지가 초록색이어도 로그인·결제·파일 업로드 같은 핵심 흐름은 이미 깨져 있을 수 있다.

[Uptime Kuma](https://github.com/louislam/uptime-kuma)는 HTTP(S), TCP, DNS, Ping, WebSocket, JSON query, Docker container 등 여러 대상을 짧은 간격으로 확인하고 알림과 공개 상태 페이지를 제공하는 MIT 라이선스의 셀프호스팅 도구다. Docker Compose 한 파일로 시작할 수 있어 개인 서비스와 소규모 팀의 첫 외부 감시 계층으로 매력적이다. 반면 설치가 쉬운 것과 믿을 수 있는 감시 시스템을 운영하는 것은 다른 문제다. 핵심 질문은 **모니터를 몇 개 만들 수 있는가가 아니라, 본 서비스와 다른 실패 영역에서 장애를 발견하고 모니터링 자체의 고장을 구분·복구할 수 있는가**다.

2026년 11월 15일 08시 36분 KST 전후 GitHub Trending daily에서 Uptime Kuma는 `432 stars today`로 표시됐다. GitHub API 확인 시점에는 94,219 stars, 8,819 forks, 열린 issue와 pull request를 합친 855개, MIT 라이선스였고 11월 14일까지 commit 활동이 이어졌다. 최신 안정 릴리스는 11월 12일 공개된 `2.5.11`이다. 이 수치는 공개 페이지의 시점별 스냅샷이며 제품 적합성이나 운영 안정성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근하지 못했으므로 이를 주제 선택 근거로 사용하지 않았다.

## 후보 비교: 에이전트 도구 사이에서 독립된 운영 질문을 골랐다

오늘 daily·weekly 목록은 코딩 에이전트와 협업 도구 비중이 높았다. 저장소 이름만 다르고 독자가 해결하려는 문제가 같은 글을 늘리지 않기 위해 기존 제목·태그·중심 논지와 함께 비교했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Uptime Kuma](https://github.com/louislam/uptime-kuma) | daily 432, API 94,219 stars, MIT, v2.5.11 | **가벼운 셀프호스팅 외부 감시와 상태 페이지를 어떻게 신뢰할 것인가**라는 독립 검색 의도가 있어 선택했다. |
| [Plannotator](https://github.com/backnotprop/plannotator) | daily 412, API 11,097 stars, Apache-2.0, v0.28.64 | 사람 승인·주석 UX는 유효하지만 전날 설계 리뷰와 기존 AI 코드 리뷰 글의 중심 질문에 가깝다. |
| [Modern Web Guidance](https://github.com/GoogleChrome/modern-web-guidance-src) | daily 1,225 | 브라우저 호환성·접근성 검증은 11월 13일 글에서 같은 저장소와 검색 의도로 다뤘다. |
| [Open Code Review](https://github.com/alibaba/open-code-review) | daily 897 | 결정론적 규칙과 LLM 리뷰 결합은 이미 전용 글이 있어 직접 중복된다. |
| [Univer](https://github.com/dream-num/univer) | daily 495, API 24,464 stars, Apache-2.0, v1.5.0 | AI 오피스 SDK는 장기 가치가 있지만 기존 문서 자동화·에이전트 워크스페이스 의도와 인접한다. |

기존 [Prometheus 3.16 업그레이드 글](/posts/prometheus-316-query-cost-upgrade/)은 대규모 시계열 수집·질의·룰 엔진의 자원과 복구를 다뤘다. Uptime Kuma는 그보다 얇은 합성 감시 계층에 가깝다. 인프라 내부 metric을 깊게 분석하기보다 “사용자가 도달하는 endpoint가 지금 응답하는가”를 빠르게 확인한다. 두 도구는 대체 관계가 아니라 서로 다른 장애 증거를 제공한다.

## Uptime Kuma의 장점은 기능 수보다 짧은 피드백 경로다

공식 README가 안내하는 기본 Compose는 `louislam/uptime-kuma:2` 이미지를 실행하고 호스트의 `./data`를 컨테이너 `/app/data`에 연결하며 3001 포트를 연다. 이 단순한 구조 덕분에 운영자는 복잡한 수집 파이프라인 없이 대상, 주기, 재시도, 알림 채널과 상태 페이지를 UI에서 구성할 수 있다.

감시 흐름은 네 단계로 나눠 보는 편이 정확하다.

1. Uptime Kuma가 정해진 위치에서 HTTP·TCP·DNS·Ping 등의 probe를 실행한다.
2. 결과와 heartbeat, 인증·알림 설정, 상태 페이지 구성을 데이터 디렉터리에 저장한다.
3. 실패와 복구 이벤트를 SMTP, Slack, Discord, Telegram 등 선택한 채널로 보낸다.
4. 내부 대시보드와 별도의 공개 상태 페이지가 현재 상태와 incident를 사용자에게 보여 준다.

![Uptime Kuma의 probe, 상태 저장, 알림, 공개 상태 페이지 구조](https://heracles-jo.github.io/assets/img/posts/uptime-kuma-self-hosted-monitoring/architecture.svg)

이 구조는 작은 팀이 “관측 도구를 구축하느라 정작 서비스를 못 보는” 상황을 피하게 해 준다. HTTP status뿐 아니라 keyword나 JSON query를 확인하면 단순한 200 응답보다 한 단계 깊게 볼 수 있고, 인증서 정보와 DNS record 감시는 만료·해석 실패를 별도 신호로 만든다. 공개 상태 페이지는 장애 공지의 출발점도 된다.

하지만 이 피드백 경로가 짧다는 것은 단일 인스턴스의 판단에 많은 책임이 모인다는 뜻이다. probe 실행, 판정, 기록, 알림, 상태 페이지가 같은 프로세스와 데이터 경계에 있으면 그 인스턴스가 멈춘 순간 “모든 서비스가 조용히 정상처럼 보이는” 실패가 생길 수 있다. Uptime Kuma를 설치한 뒤 가장 먼저 추가할 모니터는 다른 서비스가 아니라 **Uptime Kuma 자체를 외부에서 확인하는 dead-man monitor**여야 한다.

## 같은 서버에 두면 서버 장애를 감시하지 못한다

가장 흔한 배치는 애플리케이션 Docker Compose에 Uptime Kuma 컨테이너를 하나 더 넣는 방식이다. 내부 서비스 이름으로 연결하기 편하고 비용도 적다. 그러나 host kernel, 디스크, 전원, ISP, DNS resolver, reverse proxy, firewall과 배포 작업을 공유한다. 이 구성은 개별 프로세스 실패는 잡아도 호스트·네트워크 전체 장애에는 함께 사라진다.

감시 위치는 적어도 다음 실패 영역과 분리해야 한다.

- 애플리케이션 호스트와 다른 VM 또는 물리 장비
- 운영 서비스와 다른 cloud region 또는 provider의 작은 인스턴스
- 내부 DNS뿐 아니라 실제 공개 DNS와 TLS 경로를 사용하는 endpoint
- 운영 배포·방화벽 변경과 별도의 계정·프로젝트·네트워크
- 본 서비스의 메일·채팅 인프라와 겹치지 않는 보조 알림 채널

완전한 다중 지역 관측 플랫폼이 필요한 것은 아니다. 개인 서비스라도 운영 서버와 다른 네트워크에 작은 Uptime Kuma를 두고, 그 Uptime Kuma는 외부 SaaS heartbeat나 별도 지역의 두 번째 checker가 감시하도록 만들면 단일 실패 영역은 크게 줄어든다. 반대로 내부 DB 포트나 사설 API처럼 외부에서 열어서는 안 되는 대상은 내부 checker로 나눈다. “한 인스턴스가 모든 것을 본다”보다 **외부 사용자 경로와 내부 의존성 경로를 서로 다른 위치에서 본다**가 더 안전하다.

[Caddy 자동 HTTPS 운영 글](/posts/caddy-automatic-https-operations/)에서 인증서 자동화와 실제 사용자 경로를 분리해 검증했듯, Uptime Kuma도 origin에 직접 붙는 probe와 CDN·WAF·reverse proxy를 통과하는 probe를 구분해야 한다. origin은 정상인데 CDN 설정이 깨질 수 있고, 반대로 외부 경로는 정상처럼 보이지만 내부 관리 API가 실패할 수 있다.

## 200 OK는 사용자 성공이 아니다

HTTP monitor가 200을 받았다는 사실은 웹 서버가 응답했다는 뜻일 뿐이다. 캐시된 오류 화면, 빈 JSON, 로그인 redirect loop, 읽기 전용 DB, queue 적체까지 정상으로 판정할 수 있다. keyword와 JSON query 기능을 사용하더라도 하나의 endpoint에 너무 많은 의미를 넣으면 장애 원인을 구분하기 어렵다.

실무에서는 probe를 계층화하는 편이 낫다.

| 계층 | 확인 질문 | 실패 시 의미 |
|---|---|---|
| 네트워크 | DNS가 해석되고 TCP·TLS 연결이 되는가 | 경로, 인증서, 방화벽, listener 문제 |
| 얕은 HTTP | `/healthz`가 제한 시간 안에 기대 status를 반환하는가 | 프로세스·proxy·기본 dependency 문제 |
| 준비 상태 | `/readyz`가 필수 DB·queue 연결을 확인하는가 | 트래픽을 받을 준비가 되지 않음 |
| 핵심 합성 흐름 | 테스트 계정으로 읽기·쓰기 결과를 검증하는가 | 실제 사용자 기능 또는 데이터 경로 실패 |
| 공개 경로 | 사용자 도메인·CDN·WAF를 거쳐 같은 결과가 나오는가 | edge 설정이나 외부 접근 문제 |

깊은 합성 흐름을 20초마다 실행하면 비용과 부작용이 커진다. 주문 생성, 이메일 발송, 파일 업로드 같은 작업은 전용 test tenant와 idempotency key, 자동 정리, 낮은 주기를 사용해야 한다. destructive action이나 실제 결제는 감시 대상에서 제외하고 더 안전한 대리 신호를 만든다. 반대로 `/healthz`가 언제나 200을 반환하도록 구현하면 빠르지만 가치가 없다. probe마다 **무엇을 증명하고 무엇을 증명하지 않는지** runbook에 적어야 한다.

## 알림이 많아질수록 장애를 빨리 아는 것은 아니다

Uptime Kuma는 90개가 넘는 알림 통합을 안내하지만 채널 수와 탐지 품질은 비례하지 않는다. interval이 짧고 retry가 없으면 순간 packet loss가 incident가 되고, retry가 길면 실제 장애 탐지가 늦어진다. 복구 메시지까지 여러 채널로 반복되면 on-call은 동일 사건을 서로 다른 장애로 오해할 수 있다.

알림 정책은 monitor별 임계치보다 서비스 중요도와 실패 모드로 나눠야 한다.

- 외부 사용자 경로는 짧은 timeout과 2~3회의 빠른 재시도로 탐지 지연과 오탐을 조절한다.
- 배치·개발 환경은 즉시 paging하지 않고 누적 실패를 업무 채널에 보낸다.
- 의존성이 같은 monitor는 group과 incident key를 사용해 상위 원인 중심으로 묶는다.
- planned maintenance는 알림 억제뿐 아니라 상태 페이지의 설명과 종료 확인까지 포함한다.
- down과 recovery 알림이 실제로 전달되는지 정기적으로 강제 실패 시험을 한다.
- 주 알림 채널 장애에 대비해 다른 provider와 네트워크를 쓰는 보조 채널을 둔다.

최근 공개 pull request에도 transport error 시 알림 재시도, maintenance 뒤 중복 down 알림 방지, uptime 왜곡 수정이 올라와 있다. 이는 알림 전달과 uptime 계산이 “설정하면 끝나는 기능”이 아니라 계속 검증해야 할 상태 계산이라는 뜻이다. 월간 가용률 숫자는 probe 간격, maintenance 처리, retry, checker 자체의 downtime에 따라 달라진다. 계약상 SLO 근거가 필요하다면 Uptime Kuma의 표시값만 단독 원장으로 쓰지 말고 원시 사건과 다른 관측 계층을 함께 보존해야 한다.

## 셀프호스팅 모니터는 강한 네트워크 권한을 가진다

Uptime Kuma는 운영자가 입력한 URL, header, credential, proxy, Docker endpoint와 여러 notification secret을 사용해 네트워크 요청을 만든다. 따라서 일반 대시보드보다 SSRF와 자격증명 탈취, 내부망 탐색의 영향이 크다. 공개 보안 공지에는 인증된 계정이 cloud metadata endpoint를 조회할 수 있는 위험이 기록돼 있고 patched version이 제시되지 않은 항목도 있다. 보안 정책은 SSRF 보고를 받지 않는다고 명시한다. 이는 해당 위험이 사라졌다는 뜻이 아니라 **운영자가 신뢰된 관리자만 접근시키고 egress를 제한해야 하는 제품 경계**라는 뜻에 가깝다.

11월 12일의 `2.5.11` 릴리스는 upstream package 회귀로 인한 admin-only RCE 수정과 의존성 업데이트를 포함한다고 안내한다. 상세 정보는 공개 시점 기준 7일 뒤 공개 예정이라 확인 시점에는 전체 공격 경로를 검증할 수 없었다. 앞선 2.5 계열에도 Apprise CLI argument injection RCE, rootless image 권한 상승, badge endpoint 자원 고갈, host-header 기반 cache poisoning 수정이 연속으로 공개됐다. 설치 후 버전을 장기간 고정하는 운영은 위험하다.

공식 `SECURITY.md`는 Docker tag `2`, `2-slim`, `2-rootless` 계열 등을 지원하고 `1`, `latest`, `debian`은 지원하지 않는다고 명시한다. 따라서 이미지 tag는 문서에 맞게 선택하되, 자동 재시작만 믿지 말고 digest와 릴리스 노트를 확인한 단계적 업데이트를 해야 한다.

보안 기준은 다음과 같다.

1. UI는 인터넷에 직접 3001 포트로 노출하지 않고 localhost bind 또는 reverse proxy·VPN 뒤에 둔다.
2. 2FA를 켜고 관리자 계정을 최소화하며, 여러 사용자가 임의 URL을 등록하는 공용 서비스로 운영하지 않는다.
3. checker의 egress를 필요한 대상과 DNS·알림 provider로 제한하고 cloud metadata 주소와 내부 관리망을 차단한다.
4. monitor header·basic auth·OAuth credential과 notification token을 별도 비밀로 분류해 백업·로그·상태 페이지에 노출되지 않는지 확인한다.
5. Docker socket을 직접 연결해야 한다면 read-only 표기만 믿지 말고 socket proxy와 최소 API를 사용한다.
6. 공개 상태 페이지에는 내부 hostname, port, 응답 본문, incident 원인 중 공격에 도움이 되는 정보를 싣지 않는다.

![Uptime Kuma를 운영 감시로 승격하기 전 확인할 실패·보안·복구 게이트](https://heracles-jo.github.io/assets/img/posts/uptime-kuma-self-hosted-monitoring/risk-checklist.svg)

## 백업 파일보다 빈 서버 복원이 기준이다

기본 Compose의 영속 경계는 `/app/data`다. 공식 README는 NFS 같은 network filesystem을 지원하지 않으며 local directory나 volume을 사용하라고 경고한다. 이 조건을 무시하면 평상시에는 동작하다가 latency, locking, mount 장애에서 heartbeat 기록과 DB 정합성이 흔들릴 수 있다.

백업은 데이터 디렉터리를 복사하는 것으로 시작하지만 끝나지 않는다. 실행 중인 SQLite 계열 파일을 무작정 복사하면 일관된 시점을 보장하기 어렵고, 업그레이드가 schema migration을 수행한 뒤에는 구버전 binary로 단순 rollback하기 어려울 수 있다. 정기적으로 다음 절차를 실제로 수행해야 한다.

- 현재 image tag와 digest, Compose·reverse proxy·방화벽 설정을 함께 기록한다.
- 일관된 backup 방식을 사용해 `/app/data`와 필요한 TLS·proxy secret을 암호화 보관한다.
- 네트워크 파일시스템이 아닌 빈 local volume에 복원한다.
- 동일 또는 지원되는 새 버전으로 기동해 monitor 수, 상태 페이지, 알림 설정, 인증을 대조한다.
- 테스트 target을 강제로 down/recovery시켜 probe 실행과 알림 전달을 확인한다.
- 외부에서 Uptime Kuma 자체 URL과 공개 상태 페이지를 확인한다.

[Supabase 셀프호스팅 운영 글](/posts/supabase-self-hosting-operations/)에서 backup 존재와 복원 성공을 분리했듯, 감시 시스템도 DB 파일이 있다는 사실보다 **새 호스트에서 정해진 RTO 안에 다시 장애를 발견하고 알릴 수 있는가**가 복구 기준이다. 장애 중에 모니터링을 복원해야 하므로 runbook과 자격증명을 Uptime Kuma 안에만 저장해서도 안 된다.

## Prometheus와 비교할 때는 규모가 아니라 질문을 나눠야 한다

Uptime Kuma, Prometheus·Blackbox Exporter, 관리형 synthetic monitoring은 기능이 일부 겹치지만 운영 질문이 다르다.

| 선택지 | 잘 답하는 질문 | 강점 | 주의할 경계 |
|---|---|---|---|
| Uptime Kuma | 내 서비스와 endpoint가 지금 외부에서 살아 있는가 | 빠른 설치, 다양한 probe, 알림·상태 페이지 통합 | 단일 인스턴스, 고급 SLO·다중 위치 분석 한계 |
| Prometheus + Blackbox Exporter | probe 결과를 다른 metric·alert와 어떻게 상관 분석할 것인가 | label, rule, 장기 시계열, Grafana 연계 | 구축·운영 복잡도와 cardinality 관리 |
| 관리형 synthetic 서비스 | 여러 지역·브라우저에서 사용자 흐름이 성공하는가 | global vantage, browser journey, 운영 부담 감소 | 사용량 비용, 데이터·credential 위탁, vendor 경계 |
| cloud provider health check | load balancer가 backend를 트래픽 대상에 둘 수 있는가 | traffic routing과 직접 연동 | 사용자 기능·외부 DNS·타 provider 장애는 제한적으로 봄 |

[PostHog 통합 제품 관측성 글](/posts/posthog-unified-product-observability/)은 사용자 행동, replay, flag와 LLM trace를 연결하는 제품 문맥을 다뤘다. Uptime Kuma는 그 문맥을 대신하지 않는다. “회원가입 전환이 떨어진 이유”를 설명하기보다 “회원가입 endpoint와 외부 경로가 실패했는가”를 빠르게 좁힌다. 도구를 하나로 통합하려 하기보다 사건 timeline에서 각 증거가 맡을 역할을 정하는 편이 낫다.

## 2주 PoC는 uptime 숫자보다 탐지·오탐·복구를 측정한다

PoC에는 실제 중요 서비스 5~10개만 넣는다. 외부 홈페이지, 인증, 핵심 API, DNS·TLS, queue를 거친 비동기 결과, Uptime Kuma 자체 heartbeat를 포함한다. 테스트 계정과 synthetic data를 분리하고 운영 DB에 불필요한 쓰기를 만들지 않는다.

두 주 동안 정상 관찰만 하지 말고 계획된 failure injection을 실행한다.

| 시험 | 측정 항목 | 중단 또는 보완 조건 |
|---|---|---|
| application process 종료 | 탐지 시간, retry, incident 묶음 | 중복 paging 또는 목표 MTTD 초과 |
| reverse proxy·DNS 오설정 | origin probe와 공개 경로 probe 차이 | 내부 정상만 보고 사용자 장애를 놓침 |
| 알림 provider 차단 | 전송 실패 가시성, 보조 채널 도달 | checker는 down을 알지만 사람이 통보받지 못함 |
| Uptime Kuma 종료 | dead-man alert와 상태 페이지 동작 | 모니터 자체 장애가 무음으로 남음 |
| host·region 네트워크 차단 | 실패 영역 분리와 외부 checker | 본 서비스와 monitor가 함께 사라짐 |
| backup에서 빈 서버 복원 | RTO, monitor·secret·상태 페이지 정합성 | 수동 기억에 의존하거나 probe 재개가 늦음 |
| 구버전→최신 버전 업데이트 | migration, UI, 알림, rollback | 복원 없이 되돌릴 수 없거나 설정 유실 |

성공 기준은 대시보드가 예쁘거나 가용률이 99.9%로 표시되는 것이 아니다. 목표한 장애를 제한 시간 안에 발견하고, 같은 원인의 알림을 사람이 처리 가능한 수로 묶으며, checker와 알림 경로의 고장을 별도 신호로 드러내고, 빈 서버 복원을 반복할 수 있어야 한다. 이 조건을 만족하지 못하면 monitor 수를 늘리기 전에 배치와 운영 경계를 고쳐야 한다.

Uptime Kuma는 작은 팀이 외부 감시와 상태 페이지를 빠르게 확보하는 데 강하다. 다만 그 편의성을 관측성 전체의 대체물로 해석하면 안 된다. 내부 metric과 log가 원인을 설명하고, 외부 probe가 사용자 경로의 실패를 확인하며, 별도 dead-man 경로가 감시 시스템의 침묵을 발견해야 한다.

도입 판단은 세 질문으로 압축할 수 있다. **Uptime Kuma가 본 서비스와 다른 실패 영역에 있는가. 200 응답이 아니라 실제 사용자 성공을 필요한 깊이까지만 검증하는가. 최신 보안 패치와 빈 서버 복원을 운영 절차로 증명했는가.** 세 조건이 충족될 때 Uptime Kuma는 홈랩용 대시보드를 넘어 신뢰할 수 있는 첫 번째 incident 신호가 된다.

> 1차 자료: [Uptime Kuma 저장소와 README](https://github.com/louislam/uptime-kuma), [Docker Compose](https://github.com/louislam/uptime-kuma/blob/master/compose.yaml), [보안 정책과 지원 Docker tag](https://github.com/louislam/uptime-kuma/blob/master/SECURITY.md), [MIT LICENSE](https://github.com/louislam/uptime-kuma/blob/master/LICENSE), [v2.5.11 릴리스](https://github.com/louislam/uptime-kuma/releases/tag/2.5.11), [공개 보안 공지](https://github.com/louislam/uptime-kuma/security/advisories), [최근 commits](https://github.com/louislam/uptime-kuma/commits/master/), [공개 issues](https://github.com/louislam/uptime-kuma/issues), [공개 pull requests](https://github.com/louislam/uptime-kuma/pulls). Trending·저장소 수치는 2026년 11월 15일 08시 36분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
