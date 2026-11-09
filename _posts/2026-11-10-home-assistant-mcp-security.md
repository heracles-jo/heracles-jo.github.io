---
title: "Home Assistant MCP 보안: ha-mcp와 내장 서버 선택 기준"
description: "Home Assistant 내장 MCP와 ha-mcp의 권한·인증·승인·복구 경계를 비교하고, AI 에이전트에 스마트홈 제어권을 맡길 때의 안전한 도입 기준을 정리한다."
author: heracles-jo
date: 2026-11-10 08:15:00 +0900
categories: [Security, AI Infrastructure]
tags: [home-assistant, ha-mcp, mcp-security, smart-home, access-control, ai-agent]
image:
  path: https://heracles-jo.github.io/assets/img/posts/home-assistant-mcp-security/cover.svg
  alt: "Home Assistant 내장 MCP와 ha-mcp의 인증·권한·승인 경계를 비교하는 보안 설계"
---

스마트홈에 AI 에이전트를 연결하면 자연어로 조명을 켜는 수준을 빠르게 넘어선다. 에이전트가 자동화와 스크립트를 고치고, 대시보드를 편집하고, 로그를 읽고, 백업을 만들거나 복원하며, 통합과 기기 레지스트리까지 건드릴 수 있다. 이때 MCP 서버는 편리한 플러그인이 아니라 **집의 상태와 물리 장치를 모델에게 연결하는 관리 평면**이 된다.

[homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp)는 Home Assistant를 구성·디버깅·관리하는 폭넓은 도구를 제공한다. 2026년 11월 10일 08시 22분 KST 전후 GitHub Trending daily에는 31 stars today로 표시됐고, GitHub API 확인 시점에는 5,923 stars, 293 forks, open issue와 pull request를 합친 25개 항목, MIT 라이선스였다. 최신 안정 릴리스 `v9.1.2`는 11월 9일 KST 공개됐으며, 11월 10일 KST에도 정책 파일 처리와 의존성 관련 변경이 이어졌다. 이 수치는 공개 페이지의 시점별 스냅샷이며 제품의 안전성이나 적합성을 보증하지 않는다.

이번 글의 질문은 “ha-mcp가 내장 MCP보다 기능이 많은가”가 아니다. Home Assistant 2026.11.1 공식 문서는 내장 MCP도 Device control뿐 아니라 모든 엔티티·로그·히스토리를 읽고 행동을 수행하는 Home Assistant 도구 집합, 관리자 계정 요구, read-only 옵션, 도구 집합별 URL을 제공한다고 설명한다. 따라서 오래된 기능표만 보고 선택하면 틀릴 수 있다. **현재 실제 도구 카탈로그와 권한 경계를 기준으로, 어느 서버에 어떤 책임을 맡길지**가 핵심이다.

이번 실행에서는 Search Console·Analytics의 실제 검색어·노출·클릭 데이터에 접근하지 못했으므로 주제 선정에 사용하지 않았다.

## 후보 비교: 또 하나의 범용 에이전트보다 물리 제어 권한을 골랐다

오늘 daily·weekly 후보에는 에이전트 스킬, 브라우저 자동화, 디자인 시스템, 로봇 시뮬레이터가 다수 포함됐다. 그러나 이 블로그에는 이미 에이전트 스킬 공급망, 컴퓨터 사용 에이전트, 브라우저 자동화, 로봇 정책 배포 글이 있다. ha-mcp는 **AI 도구 호출이 실제 조명·잠금·공조·카메라와 운영 설정으로 이어지는 물리적 권한 경계**라는 별도 검색 의도를 만든다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp) | daily 31, 5,923 stars, `v9.1.2`, MIT | 내장 MCP와 확장 서버의 인증·승인·복구 경계를 비교할 수 있어 선택했다. |
| [meta/astryx](https://github.com/meta/astryx) | daily 3,324, 19,887 stars, `v0.7.11`, MIT | agent-ready 디자인 시스템은 기존 디자인 산출물·스킬 검증 주제와 가깝다. |
| [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | daily 914, weekly 2,190 | 브라우저 에이전트는 Lightpanda·agent-desktop·Cua 글과 검색 의도가 겹친다. |
| [google-deepmind/mujoco](https://github.com/google-deepmind/mujoco) | daily 579, 16,886 stars, `4.0.0`, Apache-2.0 | 시뮬레이터 업그레이드는 가치가 있지만 최근 로봇 배포 글과 실험 의도가 인접하다. |
| [anthropics/claude-quickstarts](https://github.com/anthropics/claude-quickstarts) | daily 560, 19,988 stars, MIT | 배포 예제 모음은 범위가 넓어 하나의 지속적인 운영 질문으로 좁히기 어렵다. |

기존 [Home Assistant 로컬 우선 자동화 글](/posts/github-trending-home-assistant-local-first-automation/)은 클라우드 의존을 줄이고 현장의 제어권을 회수하는 구조를 다뤘다. 이번 글은 그 다음 단계다. 제어권을 되찾은 뒤 AI 에이전트에 다시 위임할 때, **자연어 편의가 로컬 우선의 보안 이점을 되돌리지 않게 만드는 법**을 본다.

## 두 서버의 차이는 도구 수보다 신뢰 주체에 있다

Home Assistant 내장 MCP의 최신 공식 문서에서 Main URL은 기본적으로 모든 AI 도구 집합을 노출하고 관리자 계정을 요구한다. 설정에서 전체 도구 노출을 끄고 필요한 집합만 고르거나 read-only로 제한할 수 있다. Device control 전용 URL은 Assist에 노출한 엔티티만 다루며, 다른 개별 URL과 Home Assistant 전체 도구는 더 높은 권한을 요구한다. 인증은 Home Assistant의 OAuth 2.0과 PKCE 흐름을 사용한다.

ha-mcp는 설치 형태가 더 다양하다. Home Assistant 안에서 실행하는 integration, app(add-on), 별도 Docker·PyPI 서버가 있고, secret URL, Home Assistant 계정 인증, 외부 OIDC 등 연결 방식도 나뉜다. 약 87개 도구를 통해 자동화·스크립트·대시보드·백업·업데이트·레지스트리·파일과 YAML 편집까지 넓힐 수 있으며, 도구별 비활성화, read-only endpoint, security policy와 승인 대기열, 자동 편집 전 백업 같은 자체 제어를 제공한다.

![Home Assistant 내장 MCP와 ha-mcp가 AI 클라이언트에서 인증·도구 정책·Home Assistant API로 이어지는 구조](https://heracles-jo.github.io/assets/img/posts/home-assistant-mcp-security/architecture.svg)

이 차이를 “내장은 단순 제어, ha-mcp는 관리”라고만 요약하면 현재 기준으로는 부족하다. ha-mcp README와 FAQ의 일부 비교표는 내장 MCP를 제한적인 장치 제어로 설명하지만, Home Assistant 2026.11.1 공식 문서는 Home Assistant 전체 도구 집합과 read-only, 개별 URL을 명시한다. 문서 갱신 시점이 다를 수 있으므로 PoC에서는 두 서버에 실제 연결해 `tools/list` 결과, destructive·read-only hint, 요구 계정과 호출 실패 형태를 저장해야 한다.

실무 선택은 다음처럼 나누는 편이 안전하다.

- 이미 Home Assistant가 제공하는 도구 집합으로 충분하고 OAuth·계정 수명주기를 하나로 유지하고 싶다면 내장 MCP부터 시작한다.
- 자동화 trace 분석, 세밀한 구성 편집, 백업, HACS·앱 관리, 도구별 승인 규칙처럼 ha-mcp 고유 기능이 필요할 때만 확장한다.
- 둘을 동시에 연결해야 한다면 같은 기능을 두 경로로 실행할 수 있는지 먼저 찾는다. 한쪽의 승인 규칙이 다른 쪽 호출까지 막아 주지는 않는다.

마지막 항목이 중요하다. ha-mcp 공식 FAQ도 정책은 **한 도구를 게이트할 뿐 동일한 기능 전체를 자동으로 막지 않는다**고 설명한다. 예를 들어 특정 이벤트 도구에 승인을 걸어도 다른 서비스 호출이나 raw WebSocket 명령이 같은 결과에 도달할 수 있다. 여러 MCP 서버를 함께 쓰면 이 우회 경로는 서버 경계까지 넓어진다.

## 관리자 토큰 하나가 곧 모든 자동화 권한이 되는 문제

ha-mcp의 보안 문서는 인증된 MCP 클라이언트를 trusted principal로 본다. secret URL을 알거나 OAuth를 끝낸 클라이언트가 악성이거나 prompt injection에 속았을 때, 서버가 그 클라이언트 자체를 적으로 가정해 방어하지 않는다는 뜻이다. 관리자 long-lived access token을 사용하면 에이전트의 실질 권한도 관리자 수준이 된다.

이 경계는 스마트홈에서 특히 무겁다. 소프트웨어 저장소의 잘못된 파일 수정은 Git으로 되돌릴 수 있지만, 잠금 해제·경보 해제·공조 정지·차고문 개방·백업 복원은 물리적 결과나 서비스 중단을 만든다. [온디바이스 도구 호출 글](/posts/github-trending-needle-tiny-on-device-tool-calling/)에서 모델보다 실행 계약이 중요하다고 본 이유와 같다. 모델이 올바른 JSON을 만들었다는 사실은 그 호출을 지금 실행해도 된다는 승인과 다르다.

따라서 전용 계정을 만들었다는 사실만으로 최소 권한이 달성되지는 않는다. ha-mcp의 권고처럼 별도 관리자 계정을 사용하면 활동 주체와 credential 회전은 분리할 수 있지만, 그 계정이 여전히 관리자라면 피해 범위는 크다. 내장 MCP도 Home Assistant 전체 도구를 노출하면 관리자 계정을 요구한다. 진짜 최소 권한은 다음 네 층을 함께 줄여야 한다.

1. **서버 표면**: 내장 MCP의 도구 집합·개별 URL 또는 ha-mcp의 disabled tools로 불필요한 도구를 숨긴다.
2. **호출 정책**: 읽기는 자동 허용하되 쓰기·삭제·재시작·복원은 승인 대상으로 둔다.
3. **대상 범위**: 출입·카메라·알람·위치 엔티티를 별도 영역이나 denylist로 관리한다.
4. **네트워크와 인증**: secret URL을 단순 링크가 아닌 credential로 취급하고, 원격 연결은 TLS와 계정 기반 인증을 우선한다.

[OpenShell 정책 런타임 글](/posts/openshell-agent-policy-runtime/)에서 L7 목적지와 자격 증명 주입을 분리했듯, 여기서도 “접속했다”와 “이 행동을 허용한다”를 분리해야 한다. 인증은 호출자를 알려 줄 뿐, 해당 시점의 냉난방 설정 변경이나 백업 복원이 정당한지 판정하지 않는다.

## read-only는 유용하지만 안전 모드 전체는 아니다

내장 MCP의 read-only 옵션은 변경 도구를 줄이는 좋은 출발점이다. ha-mcp도 `/readonly` endpoint와 전역 Read Only Mode를 제공하고, 캐시된 write tool이나 search proxy를 통한 쓰기도 차단한다고 문서화한다. 하지만 read-only를 “정보 유출이 없는 모드”로 해석하면 안 된다.

스마트홈의 읽기 데이터에는 재실 여부, 카메라, 출입 기록, 기기 이름, 자동화 조건, 에너지 패턴, 위치와 생활 시간이 포함된다. 공격자는 문을 직접 열지 않아도 집이 비는 시간과 보안 장치 구성을 알 수 있다. ha-mcp의 entity visibility enforce mode는 숨긴 엔티티의 직접 읽기와 해당 엔티티를 언급하는 구성·로그·trace를 차단할 수 있지만, 공식 문서는 이를 암호학적 경계가 아닌 우발적 노출을 줄이는 장치로 규정한다. 엔티티 ID를 직접 언급하지 않고 상태를 유도하는 계산이나 보이는 카메라 화면 속 정보까지 완전히 막지는 못한다.

또한 read-only 호출도 외부 AI 클라이언트로 데이터를 전달한다. ha-mcp 자체가 데이터를 수집하지 않는다는 privacy 설명과, MCP 클라이언트가 모델 제공자에 어떤 데이터를 보내는지는 별개의 문제다. 운영자는 “서버가 로컬에서 돈다”가 아니라 **어떤 도구 결과가 어느 모델·대화·로그 보존 정책으로 나가는가**를 검토해야 한다.

## 승인 정책은 기본 거부와 우회 경로 검사가 핵심이다

ha-mcp의 Tool Security Policies는 조건에 맞는 도구 호출을 대기시키고 settings UI나 Home Assistant event를 통해 승인·거부할 수 있다. 그러나 정책 문서를 MCP 도구로 수정하는 기능은 기본 비활성화다. 이를 켜면 연결된 클라이언트가 승인 gate 자체를 제거할 수 있어 서버가 경고를 남긴다. 정책 관리 도구를 상시 켜 두는 것은 방화벽 규칙 편집 권한을 방화벽 뒤의 자동화에 그대로 주는 것과 비슷하다.

승인 설계에는 세 가지 원칙이 필요하다.

- 허용 목록 방식으로 시작한다. 일상적인 상태 조회와 정해진 조명·공조 서비스만 자동 허용하고 나머지는 승인 대상으로 둔다.
- 승인 화면에는 도구 이름뿐 아니라 대상 엔티티, 인자, 예상 부작용, 요청 만료 시간을 보여 준다.
- 같은 행동에 도달하는 모든 경로를 테스트한다. `ha_call_service`, bulk control, automation 작성, script 실행, raw command와 두 번째 MCP 서버를 포함한다.

Home Assistant event로 휴대폰 승인 알림을 만들 수 있지만, ha-mcp 문서는 이벤트가 사람의 자동화에서 왔는지 에이전트가 만든 자동화에서 왔는지 구분할 수 없다고 경고한다. PIN이 유일한 분리선이며 충분한 권한의 에이전트가 우회할 가능성도 남는다. 고위험 행동은 편리한 event 승인보다 서버가 제공하는 admin-only settings UI에서 직접 판단하는 편이 낫다.

[AWS Agent Toolkit 권한 설계 글](/posts/aws-agent-toolkit-mcp-iam-governance/)에서 자연어 요청, MCP 도구, IAM 실행과 CloudTrail 증거를 분리했듯, 스마트홈에서도 요청 문장과 실제 Home Assistant context·logbook·automation trace를 연결해야 한다. “승인했다”는 기록만으로는 어떤 상태를 읽고 어떤 호출을 실행했는지 재구성할 수 없다.

## 자동 백업은 롤백 가능성과 물리적 부작용을 구분해야 한다

ha-mcp는 자동화·스크립트·대시보드와 일부 helper 편집 전에 백업을 만들고, snapshot 관리와 복원 기능도 제공한다. 이는 구성 변경의 안전망이지만 모든 결과를 되돌리지는 않는다. 자동화 YAML을 복원해도 이미 전송된 알림, 해제된 잠금, 변경된 온도, 삭제된 외부 서비스 데이터는 돌아오지 않는다.

백업 기능 자체도 고위험이다. 잘못된 restore는 정상 설정을 덮고 Home Assistant를 재시작하거나 장시간 사용할 수 없게 만들 수 있다. ha-mcp는 snapshot action 비활성화와 backup read-only 설정을 제공하므로, 평상시에는 목록·diff·자동 편집 전 백업만 허용하고 수동 snapshot restore·delete는 장애 대응 창구에서만 일시적으로 여는 편이 합리적이다.

복구 검증은 파일 존재가 아니라 다음 증거를 남겨야 한다.

- 편집 전후 diff와 백업 식별자가 같은 요청에 연결되는가
- 실패한 편집이 부분 적용됐는지 판별할 수 있는가
- 새 인스턴스에서 복원했을 때 integration credential과 entity ID가 유지되는가
- restore 이후 필수 자동화가 예상 모드로 다시 활성화되는가
- 물리 장치가 안전 상태로 돌아오지 않는 경우 수동 절차가 있는가

## 권장 배치: 한 서버, 두 URL, 세 위험 등급

![Home Assistant MCP를 읽기·제한 쓰기·관리 변경의 세 위험 등급으로 승격하는 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/home-assistant-mcp-security/decision.svg)

처음부터 모든 기능을 가진 에이전트를 만들 필요는 없다. 다음 단계가 운영 부담과 실패 반경을 줄인다.

| 단계 | 노출 범위 | 필수 검증 | 중단 조건 |
|---|---|---|---|
| 1. 관찰 | read-only, 비민감 엔티티, 상태·히스토리 일부 | 잘못된 직접 ID, 숨김 엔티티, 외부 모델 전송 범위 | 위치·출입·카메라 데이터가 예상 밖 결과에 포함됨 |
| 2. 제한 제어 | 조명·비필수 공조 등 allowlist 서비스 | dry-run 대화, 인자 범위, 중복 호출, timeout·retry | 재시도에서 중복 동작하거나 범위 밖 엔티티를 제어함 |
| 3. 구성 편집 | 자동화·스크립트·대시보드, 편집 전 백업 | diff, schema validation, trace, rollback | 부분 적용을 탐지하지 못하거나 복원 후 기능이 달라짐 |
| 4. 관리 작업 | 업데이트·재시작·백업 복원·파일/YAML | 사람 승인, 유지보수 창, 별도 break-glass 계정 | 에이전트가 승인 정책이나 복구 수단을 스스로 약화할 수 있음 |

가능하면 하나의 MCP 서버를 주 경로로 정한다. 내장 MCP로 요구를 충족할 수 있다면 그 경로가 가장 단순하다. ha-mcp가 필요한 경우에도 일반 대화에는 read-only 또는 제한된 catalog URL을 주고, 관리용 전체 catalog는 별도 클라이언트·별도 연결로 분리한다. 같은 credential이 normal endpoint에도 통한다면 read-only URL만 배포했다고 권한 자체가 축소된 것은 아니므로 normal URL과 secret의 배포 범위를 따로 통제해야 한다.

PoC에서 볼 지표도 응답 품질만으로 잡으면 안 된다. 승인 요청률과 거부율, 정책에 없는 쓰기 시도, 숨김 엔티티 차단, 잘못된 도구 선택, 중복 service call, 편집 rollback 성공률, backup restore 시간, 도구 catalog 변경 후 stale client 비율, 관리자 개입 시간을 함께 측정해야 한다. 도구가 많아질수록 “무엇을 할 수 있는가”보다 **잘못된 호출이 어디서 멈추는가**가 제품 품질이 된다.

ha-mcp는 Home Assistant를 AI가 관리할 수 있는 풍부한 인터페이스로 바꾼다. 동시에 공식 threat model이 솔직히 밝히듯, 인증된 MCP 클라이언트와 prompt injection을 서버가 자동으로 불신해 주는 제품은 아니다. 내장 MCP 역시 전체 Home Assistant 도구를 관리자 계정으로 노출하면 같은 종류의 책임을 진다.

선택 기준은 간단하다. **먼저 내장 MCP의 최소 도구 집합과 read-only로 검색 의도를 충족하는지 확인하고, 부족한 관리 기능만 ha-mcp로 확장한다. 두 경로를 함께 쓸 때는 정책이 공유된다고 가정하지 않는다. 출입·카메라·알람·복원은 읽기와 쓰기 모두 고위험으로 분류하고, 승인과 복구를 에이전트가 수정할 수 없는 별도 경계에 둔다.** 스마트홈 AI의 성숙도는 명령을 얼마나 자연스럽게 이해하는지가 아니라, 잘못 이해했을 때 집이 얼마나 안전하게 그대로 남는지로 판단해야 한다.

> 1차 자료: [homeassistant-ai/ha-mcp 저장소와 README](https://github.com/homeassistant-ai/ha-mcp), [Security Policy](https://github.com/homeassistant-ai/ha-mcp/blob/master/SECURITY.md), [FAQ](https://github.com/homeassistant-ai/ha-mcp/blob/master/docs/FAQ.md), [In-process server](https://github.com/homeassistant-ai/ha-mcp/blob/master/docs/in-process-server.md), [OIDC mode](https://github.com/homeassistant-ai/ha-mcp/blob/master/docs/oidc.md), [Privacy Policy](https://github.com/homeassistant-ai/ha-mcp/blob/master/PRIVACY.md), [v9.1.2 release](https://github.com/homeassistant-ai/ha-mcp/releases/tag/v9.1.2), [MIT LICENSE](https://github.com/homeassistant-ai/ha-mcp/blob/master/LICENSE), [Home Assistant 공식 MCP 문서](https://www.home-assistant.io/integrations/mcp_server/), [최근 commits](https://github.com/homeassistant-ai/ha-mcp/commits/master/), [공개 issues와 pull requests](https://github.com/homeassistant-ai/ha-mcp/issues). Trending·저장소 수치는 2026년 11월 10일 08시 22분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
