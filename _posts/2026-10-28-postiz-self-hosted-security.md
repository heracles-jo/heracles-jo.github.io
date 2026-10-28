---
title: "Postiz 셀프호스팅 보안: v2.25.3 패치와 운영 기준"
description: "Postiz v2.25.3의 토큰 위조·파일 읽기 취약점을 출발점으로 OAuth, MCP, Temporal, 미디어 저장소를 안전하게 운영할 패치·격리·복구 기준을 정리한다."
author: heracles-jo
date: 2026-10-28 08:50:00 +0900
categories: [Security, Platform Engineering]
tags: [postiz, self-hosting, social-media-automation, oauth, mcp-security, temporal]
image:
  path: https://heracles-jo.github.io/assets/img/posts/postiz-self-hosted-security/cover.svg
  alt: "Postiz 셀프호스팅의 OAuth 토큰, Temporal 워크플로, 미디어 저장소와 패치 경계를 표현한 표지"
---

소셜 미디어 예약 도구를 셀프호스팅하면 콘텐츠와 채널 자격 증명을 직접 통제할 수 있다. 대신 한 서버가 조직의 게시 캘린더, OAuth 토큰, 미디어, 팀 권한, 자동화 API를 함께 보유한다. 여기에 AI 에이전트가 MCP로 게시물을 만들고 즉시 발행할 수 있다면 침해의 결과는 데이터 유출에 그치지 않는다. 공격자는 연결된 채널의 이름으로 콘텐츠를 게시하고, 예약 작업을 지우거나, 다른 조직의 API 키를 가져갈 수 있다.

[gitroomhq/postiz-app](https://github.com/gitroomhq/postiz-app)은 이 경계를 구체적으로 보여 주는 오픈소스 소셜 미디어 관리 플랫폼이다. 공식 문서는 34개 플랫폼 예약, API·CLI·MCP 자동화, 팀 승인, 분석과 셀프호스팅을 제공한다고 설명한다. 프런트엔드·백엔드·오케스트레이터가 PostgreSQL, Redis, Temporal, 파일 저장소와 연결되고, 각 소셜 플랫폼의 개발자 앱과 OAuth 자격 증명을 운영자가 준비한다. 편리한 통합 지점이 많은 만큼 인증·파일·비동기 작업 경계를 따로 검증해야 한다.

2026년 10월 28일 09시 1분 KST 전후 GitHub Trending daily에서 Postiz는 `953 stars today`로 표시됐다. GitHub API 기준 39,347 stars, 7,513 forks, AGPL-3.0 라이선스였으며 최신 릴리스는 10월 24일 공개된 `v2.25.3`이다. 이 릴리스는 등록 사용자가 서버 파일을 읽을 수 있는 `CVE-2026-115932`와 서명 토큰을 위조해 다른 사용자·조직을 탈취할 수 있는 `CVE-2026-115933`을 수정했다. 수치와 저장소 상태는 확인 시점의 공개 스냅샷이며 이후 달라질 수 있다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근하지 못했으므로 선정 근거로 사용하지 않았다.

## 후보 비교: 새 에이전트보다 운영 권한의 집중을 골랐다

오늘 daily·weekly 상위권에는 디자인 스킬, 범용 AI 작업 공간, 개인화 튜터와 코딩 IDE가 많았다. 기존 글은 에이전트 스킬·메모리·컨텍스트·병렬 실행을 이미 여러 각도에서 다뤘다. Postiz는 AI 도구 자체보다 **외부 채널의 장기 자격 증명과 예약 실행 권한을 한 제어면에 모을 때 무엇을 분리해야 하는가**라는 별도 검색 의도를 만든다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Postiz](https://github.com/gitroomhq/postiz-app) | daily 953, 39,347 stars, AGPL-3.0, `v2.25.3` | 소셜 플랫폼 OAuth·미디어·예약 작업·MCP를 함께 가진 셀프호스팅 제어면의 패치와 격리라는 독립 의도가 선명하다. |
| [DeepTutor](https://github.com/HKUDS/DeepTutor) | daily 1,587, 45,830 stars, Apache-2.0, `v1.6.15` | 개인화 튜터의 장기 기억과 학습 경로는 교육 지식 그래프·에이전트 메모리 글과 독자 문제가 인접한다. |
| [ThinkRail](https://github.com/JetBrains/thinkrail) | daily 1,211, 3,967 stars, Apache-2.0, `v0.2.0` | 에이전트 중심 IDE는 컨텍스트 최적화·병렬 코딩 에이전트·코드 리뷰 클러스터와 경쟁한다. |
| [OpenBot](https://github.com/nightly-labs/openbot) | daily 794, 2,398 stars, 라이선스 API `NOASSERTION`, `v0.52.1` | 지속형 AI 팀원의 작업 큐·브라우저 제어는 장기 실행 에이전트와 컴퓨터 사용 에이전트 의도를 다시 묶을 가능성이 크다. |
| [FastAPI](https://github.com/fastapi/fastapi) | weekly 1,066, 104,169 stars, MIT, `0.162.0` | 프로덕션 Python API는 장기 가치가 높지만 오늘 신호만으로는 업그레이드·배포·관측성 중 좁은 질문을 정하기 어렵다. |

Postiz의 최신 보안 릴리스는 “셀프호스팅이면 데이터가 내 서버에 있으니 안전하다”는 설명이 충분하지 않음을 보여 준다. 소셜 미디어 관리 서버는 일반 CMS보다 권한 밀도가 높다. 데이터베이스에는 게시물과 조직 정보가 있고, 환경 변수와 저장소에는 플랫폼 client secret·bot token·AI API key가 있으며, worker는 정해진 시각에 외부 서비스로 콘텐츠를 전송한다. API key나 MCP token 하나가 유출되면 여러 채널에 걸쳐 같은 권한이 재사용될 수 있다.

## 예약 발행은 단순한 cron이 아니라 권한 있는 워크플로다

Postiz 공식 아키텍처는 세 가지 내부 서비스를 설명한다. 프런트엔드는 사용자 인터페이스를 제공하고, 백엔드는 API·사용자·채널·게시물을 관리한다. 오케스트레이터는 Temporal workflow와 activity로 예약 발행, 토큰 갱신, 알림, 누락 게시물 확인을 수행한다. PostgreSQL은 영속 데이터를, Redis는 세션과 캐시를, local filesystem 또는 Cloudflare R2는 미디어를 보관한다.

![Postiz의 사용자·에이전트 입력이 백엔드, Temporal, 플랫폼 OAuth와 미디어 저장소를 거쳐 게시로 이어지는 보안 아키텍처](https://heracles-jo.github.io/assets/img/posts/postiz-self-hosted-security/architecture.svg)

Temporal은 재시작 뒤에도 작업 상태와 재시도를 보존하고 플랫폼별 task queue로 동시성을 제어한다. 그러나 취소된 캠페인이 이미 activity에 들어갔는지, provider의 429·503을 어떻게 분류하는지, 부분 성공한 thread를 어디서 이어갈지 정하지 않으면 “정확한 시각에 한 번 발행”이라는 약속이 깨진다. 공개 이슈에도 Mastodon 503 재시도 분류와 provider별 worker의 유휴 자원 소비가 보고돼 있다. PoC에서는 worker 수, queue backlog, retry, 중복·누락 게시를 함께 측정해야 한다.

[Coolify 셀프호스팅 PaaS 운영](/posts/coolify-self-hosted-paas-operations/)에서 제어면 장애와 워크로드 생존을 분리했듯, Postiz도 웹 화면이 열리는지와 예약 실행이 보존되는지를 따로 확인해야 한다. 백엔드가 잠시 중단돼도 Temporal에 남은 작업이 복구 후 정확히 한 번의 의도된 결과로 수렴하는지, DB를 복원했을 때 이미 발행된 activity가 재실행되지 않는지가 핵심이다.

## v2.25.3이 드러낸 두 경계: 파일 경로와 토큰 목적

`CVE-2026-115932`는 등록 사용자가 게시 미디어 경로를 조작해 upload directory 밖의 파일을 worker가 열게 만들 수 있던 취약점이다. 공식 권고는 Discord provider가 설정된 환경에서 읽은 파일을 공격자가 통제하는 채널로 전송할 수 있었고, worker가 읽을 수 있는 JWT secret·DB 주소·provider secret 등이 영향 범위에 들어갈 수 있다고 설명한다. 영향 버전은 `2.23.0` 이상, 수정 버전은 `2.25.3`이다.

문제는 확장자 검사보다 요청 시점과 worker 실행 시점의 신뢰 경계가 달랐다는 데 있다. 정규화된 실제 경로가 upload root 아래인지 다시 확인하고, worker를 비특권 사용자로 실행하며, `.env`, Docker socket과 host filesystem을 mount하지 않아야 한다.

`CVE-2026-115933`은 더 근본적이다. 공식 권고에 따르면 Postiz는 session, invitation, password reset 등 서로 다른 목적의 토큰을 한 shared secret으로 서명했고, 일부 경로가 요청자가 정한 claim을 서명하게 만들었다. 등록 사용자는 그렇게 얻은 토큰을 다른 사용자의 session이나 다른 조직의 super admin invitation으로 사용할 수 있었다. 영향 버전은 `2.15.0` 이상이며 역시 `2.25.3`에서 수정됐다.

서명 검증은 “이 용도로 발급됐다”는 보장이 아니다. 토큰마다 issuer, audience, purpose, 만료와 허용 claim을 구분해야 한다. session과 password reset이 같은 구조와 key를 공유하면 한 발급 경로의 문제가 다른 인증 흐름으로 번진다. [OpenBao 시크릿 관리 전환](/posts/openbao-secrets-management-migration/)에서 저장 위치보다 발급·사용·회수 수명주기를 강조한 이유가 여기에도 적용된다.

운영 대응은 `docker pull`로 끝나지 않는다. `v2.25.3` 이상으로 올린 뒤 worker가 접근 가능했던 session key, API key, OAuth·provider credential 목록을 만들고 회전해야 한다. JWT signing secret 변경이 기존 session과 invitation을 무효화하는지, 플랫폼 token 회전 중 예약 작업을 어떻게 정지·재개할지 runbook으로 검증해야 한다.

## MCP는 게시 보조가 아니라 조직 단위 쓰기 권한이다

Postiz MCP server는 integration 조회, 게시물 예약·즉시 발행, 이미지·영상 생성, clipping 등 13개 도구를 제공한다. 문서는 API key나 OAuth token으로 인증하며, API key는 자동 만료되지 않고 누출 시 회전만이 해결책이라고 밝힌다. 더구나 URL path에 key를 넣는 `/mcp/:apiKey` 방식도 지원한다. URL은 reverse proxy access log, shell history, 브라우저 기록, 오류 추적과 채팅 복사본에 남기 쉬우므로 운영 환경에서는 Bearer header 방식이 낫다.

공식 문서상 workspace API key는 조직 전체를 대표하고 OAuth token도 Public API 전체에 접근한다. “LinkedIn 초안만 생성”하는 에이전트에 즉시 발행·삭제·모든 채널 조회까지 줄 수 있다는 뜻이다. 운영 계층에서 전용 조직·채널, 승인 전 draft, 호출별 감사 로그와 rate limit를 둬야 한다.

[AWS Agent Toolkit의 MCP·IAM 권한 설계](/posts/aws-agent-toolkit-mcp-iam-governance/)에서 도구 발견과 실제 클라우드 권한을 분리했듯, MCP schema가 제공된다는 사실은 모델이 그 도구를 자율 실행해도 된다는 허가가 아니다. 게시 전에는 대상 채널, 발행 시각, media digest, 외부 link domain, 최종 본문을 결정론적으로 검증해야 한다. 즉시 발행은 별도 승인 토큰이나 사람의 확인이 있을 때만 허용하고, prompt에서 “지금 게시해”라고 말한 것만으로 운영 변경이 실행되지 않게 해야 한다.

Postiz OAuth access token은 자동 만료되지 않고, client secret 회전도 기존 access token을 무효화하지 않는다. 앱 삭제·사용자 revoke·조직 탈퇴 시 실제 접근이 끊기는지 시험하고, API key·OAuth token·소셜 플랫폼 refresh token을 함께 회전할 순서를 문서화해야 한다.

## 셀프호스팅 비용은 VM보다 플랫폼 승인이 더 크다

공식 요구사항은 소규모 팀에 4 vCPU, 8GB RAM, 50GB와 영속 upload volume을 권장하며 PostgreSQL 14, Redis 6, Temporal을 요구한다. 실제 비용은 미디어 크기, 예약 빈도, worker 수와 영상 처리에 따라 달라진다.

더 큰 숨은 비용은 플랫폼 개발자 앱이다. 셀프호스팅 사용자는 Meta, LinkedIn, TikTok, YouTube 등의 redirect URI, scope, 심사와 정책 변경을 직접 관리한다. provider가 권한 이름을 바꾸면 Postiz가 정상이어도 연결은 실패한다. 통제권의 대가는 심사 대기, token rotation과 장애 대응이다.

local filesystem은 여러 backend replica에서 shared volume이 필요하고, TikTok처럼 URL로 미디어를 가져가는 provider에는 public HTTPS가 필요하다. R2는 공개 URL 문제를 줄이지만 bucket policy와 access key를 추가한다. upload-from-URL에는 SSRF 방어, MIME·크기 제한, redirect 재검증과 cloud metadata 차단이 필요하다.

[Caddy 자동 HTTPS 운영](/posts/caddy-automatic-https-operations/)에서 다룬 것처럼 reverse proxy는 인증서 발급기만이 아니다. `/mcp`의 streaming HTTP, 대용량 upload, OAuth callback, WebSocket, request body limit와 access log 마스킹이 동시에 맞아야 한다. 특히 URL path API key를 허용한다면 proxy log에서 해당 경로를 제거하거나 사용 자체를 금지해야 한다.

## PoC는 게시 성공보다 침해 범위와 복구 시간을 측정한다

![Postiz를 패치, 권한 축소, 실패 주입, 복구 훈련을 거쳐 제한적으로 승격하는 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/postiz-self-hosted-security/decision.svg)

첫 PoC는 실제 기업 계정 전체가 아니라 테스트 조직과 비핵심 채널로 시작하는 편이 맞다. self-registration을 끄고, 필요 없는 provider 환경 변수는 비워 두며, worker를 비특권 사용자와 제한된 filesystem으로 실행한다. MCP는 초안 생성만 허용하고 즉시 발행은 사람 승인 뒤 별도 경로로 처리한다.

| 검증 영역 | 수집할 증거 | 중단 조건 예시 |
|---|---|---|
| 패치 기준선 | image digest, Postiz·DB·Redis·Temporal 버전, advisory 점검 | `v2.25.3` 미만이거나 긴급 패치를 같은 날 재현할 pipeline이 없음 |
| 토큰 경계 | API key·OAuth·provider token 목록, purpose·audience·만료·회전 기록 | 만료 없는 token의 소유자와 폐기 절차를 찾을 수 없음 |
| 파일 격리 | upload canonical path, mount 목록, worker UID, secret 접근 시험 | media 입력으로 upload root 밖 파일 존재 여부나 내용을 알 수 있음 |
| 예약 정확성 | task queue backlog, retry, 중복·누락률, provider별 429·5xx 처리 | 재시작·복원 뒤 중복 게시를 막거나 판별할 수 없음 |
| MCP 승인 | tool별 allowlist, draft-only gate, 최종 payload diff, 호출 감사 | 자연어 한 문장으로 여러 실제 채널에 즉시 발행 가능 |
| 복구 | PostgreSQL·upload·Temporal 백업, RTO·RPO, token 회전 훈련 | DB만 복원되고 미디어·workflow·credential 조합을 재현하지 못함 |
| 공급자 변경 | OAuth scope, callback, API quota, sandbox·실계정 회귀 | 플랫폼 정책 변경을 운영 장애와 보안 incident에서 구분할 수 없음 |

백업은 PostgreSQL dump 하나로 충분하지 않다. upload object, Temporal state, 애플리케이션 버전과 플랫폼 앱 설정이 같은 시점의 조합으로 복원돼야 한다. 복원 훈련에서는 이미 발행된 결과와 재실행·폐기할 작업을 구분해야 한다.

Postiz를 선택할 기준은 지원 채널 수보다 운영 경계에 있다. 최신 보안 릴리스를 신속하게 적용하고 노출 가능성이 있는 secret까지 회전할 수 있는가. OAuth·MCP·팀 초대가 각각 목적과 범위가 다른 자격 증명으로 통제되는가. Temporal 재시도와 DB 복원이 중복 게시 없이 수렴하는가. local media와 provider URL fetch가 host filesystem과 내부 네트워크를 침범하지 않는가.

이 질문에 자동화된 증거와 반복 가능한 runbook으로 답할 수 있다면 셀프호스팅은 데이터 통제와 확장성을 얻는 선택이 된다. 답할 수 없다면 관리형 서비스 비용보다 더 큰 값을 당직, 플랫폼 심사, 긴급 패치와 계정 탈취 위험으로 지불하게 된다. 소셜 미디어 자동화의 핵심은 콘텐츠를 더 빨리 만드는 기능이 아니라, **누가 어떤 채널에 무엇을 언제 발행할 수 있는지 끝까지 제한하고 되돌리는 능력**이다.

> 1차 자료: [Postiz 저장소와 README](https://github.com/gitroomhq/postiz-app), [공식 아키텍처](https://docs.postiz.com/self-host/architecture), [시스템 요구사항](https://docs.postiz.com/self-host/installation/system-requirements), [미디어 저장소](https://docs.postiz.com/self-host/configuration/uploads), [provider API key 설정](https://docs.postiz.com/self-host/providers/overview), [MCP 문서](https://docs.postiz.com/mcp/introduction), [OAuth2 문서](https://docs.postiz.com/oauth), [`v2.25.3` 릴리스](https://github.com/gitroomhq/postiz-app/releases/tag/v2.25.3), [CVE-2026-115932 권고](https://gadvisory.org/advisories/PSA-2026-E9AHFV), [CVE-2026-115933 권고](https://gadvisory.org/advisories/PSA-2026-YT2HMH), [AGPL-3.0 LICENSE](https://github.com/gitroomhq/postiz-app/blob/main/LICENSE), [최근 commits](https://github.com/gitroomhq/postiz-app/commits/main/), [공개 issues](https://github.com/gitroomhq/postiz-app/issues), [공개 pull requests](https://github.com/gitroomhq/postiz-app/pulls). Trending·저장소 수치는 2026년 10월 28일 09시 1분 KST 전후 확인한 공개 스냅샷이다.
