---
title: "Sure 셀프호스팅 가계부: 금융 데이터 보안·복구 기준"
description: "Sure로 계좌·거래·투자 데이터를 직접 운영할 때 동기화 정합성, 암호화 키, MCP 권한, 백업 복원과 Actual Budget·Firefly III 비교 기준을 정리한다."
author: heracles-jo
date: 2026-11-16 08:30:00 +0900
categories: [FinTech, Security]
tags: [sure, mcp-security, self-hosted-finance, personal-finance]
image:
  path: https://heracles-jo.github.io/assets/img/posts/sure-self-hosted-personal-finance-security/cover.svg
  alt: "Sure 셀프호스팅 개인 금융 시스템의 데이터 동기화, 보안, AI 권한, 백업 복구 경계"
---

셀프호스팅 가계부를 고르는 이유는 보통 “내 금융 데이터를 내가 보관하고 싶다”로 시작한다. 하지만 계좌 잔액, 카드 거래, 투자 포지션, 대출, 영수증을 한곳에 모으는 순간 이 서버는 일반적인 홈랩 앱보다 훨씬 높은 신뢰를 요구한다. 은행 연결이 같은 거래를 두 번 가져오거나 통화 환산이 잘못되면 자산 현황이 틀어진다. 암호화 키를 잃으면 백업이 있어도 provider token을 읽지 못하고, 외부 AI에 MCP를 연결하면 조회뿐 아니라 거래 수정과 예산 변경까지 허용될 수 있다.

[we-promise/sure](https://github.com/we-promise/sure)는 중단된 Maybe Finance를 이어받은 커뮤니티 포크다. 웹 앱을 중심으로 계좌·거래·예산·투자·대출을 관리하고, Docker 셀프호스팅, 모바일·macOS 클라이언트, API, AI assistant와 MCP endpoint를 제공한다. 기능 폭은 매력적이지만 도입 판단의 핵심은 화면이 아니라 **금융 원장의 정합성, 비밀과 권한의 경계, 빈 서버 복구 가능성**이다.

2026년 11월 16일 08시 38분 KST 전후 GitHub Trending weekly에서 Sure는 `4,483 stars this week`로 표시됐다. GitHub API 확인 시점에는 15,696 stars, 1,373 forks, 열린 issue와 pull request를 합친 941개, AGPL-3.0 라이선스였고 11월 16일 KST에도 commit과 pull request 활동이 이어졌다. 최신 안정 릴리스는 11월 12일의 `v0.7.6-hotfix.1`이다. 이 수치는 공개 페이지의 시점별 스냅샷이며 제품의 정확성이나 보안을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근하지 못했으므로 이를 선정 근거로 사용하지 않았다.

## 후보 비교: 에이전트 도구가 아닌 개인 금융 원장의 운영 문제를 골랐다

오늘 daily·weekly 후보 대부분은 코딩 에이전트, 리뷰, 브라우저 자동화와 UI 생성에 몰려 있었다. 최근 글의 중심 논지와 대조하면 같은 독자 의도를 반복할 가능성이 높았다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Sure](https://github.com/we-promise/sure) | weekly 4,483, API 15,696 stars, AGPL-3.0, v0.7.6-hotfix.1 | **개인 금융 데이터를 직접 호스팅할 때 정합성·암호화·AI 권한·복구를 어떻게 검증할 것인가**라는 독립 검색 의도가 있어 선택했다. |
| [Univer](https://github.com/dream-num/univer) | daily 1,041, API 25,586 stars, Apache-2.0 | AI 오피스 SDK는 장기 가치가 있지만 기존 OfficeCLI·문서 자동화·협업 워크스페이스 글과 인접한다. |
| [LoopForge](https://github.com/Tencent/LoopForge) | daily 484, API 1,450 stars, 라이선스 API 표기 없음 | 코딩 에이전트 delivery와 승인 gate는 Orca·OpenBot·CI 보안 글의 중심 의도와 겹친다. |
| [ggml](https://github.com/ggml-org/ggml) | daily 53, API 15,896 stars, MIT | 로컬 추론 tensor runtime은 가치가 있으나 저VRAM·MLX·양자화·GPU kernel 글과 검색 의도 분리가 더 필요하다. |
| [SkillEvaluator](https://github.com/NVIDIA/SkillEvaluator) | daily 205, API 1,644 stars, Apache-2.0 | skill 품질 gate와 중복 탐지는 기존 Agent Skills·SkillSpector·보안 감사 검증 클러스터와 직접 경쟁한다. |

기존 [Vibe-Trading 에이전트형 금융 리서치 글](/posts/github-trending-vibe-trading-agentic-finance-governance/)은 가설, 백테스트, 브로커 연결과 승인 흐름을 다뤘다. [오픈소스 금융 터미널 글](/posts/github-trending-open-finance-terminal/)은 시장 데이터의 라이선스와 리서치 재현성이 중심이었다. Sure의 질문은 투자 판단 자동화가 아니다. **한 가정의 실제 계좌와 생활 거래를 장기간 보관하는 원장을 누가 운영하고 어떻게 복원할 것인가**다.

## Sure는 단일 앱이 아니라 금융 데이터 허브에 가깝다

공식 문서는 Sure의 중심을 Rails server로 설명한다. 브라우저, Tauri 기반 macOS shell, Flutter 모바일 앱, API client와 MCP agent는 모두 같은 server의 계정·사용자·인증 규칙·금융 데이터를 사용한다. 기본 Compose는 web, Sidekiq worker, PostgreSQL, Redis, 영속 storage를 나누며 선택적으로 backup과 off-site copy service를 붙인다.

데이터 흐름을 운영 관점에서 나누면 다음과 같다.

1. 사용자가 manual entry, statement import 또는 Plaid·SimpleFIN·Enable Banking·거래소 같은 provider connection으로 데이터를 넣는다.
2. worker가 동기화, 잔액 재계산, rule, 시장 가격 수집, 분류 작업을 비동기로 처리한다.
3. PostgreSQL이 계좌·거래·예산·규칙·사용자·설정을 보관하고 storage volume이 statement와 attachment를 맡는다.
4. 웹·모바일·API가 같은 계산 결과를 읽고, AI assistant나 MCP client는 금융 도구를 호출한다.
5. backup service가 DB, upload, `.env`, Compose, version manifest를 묶어 복원 artifact를 만든다.

![Sure의 provider 동기화, 금융 원장, 클라이언트, AI·MCP, 백업 경계](https://heracles-jo.github.io/assets/img/posts/sure-self-hosted-personal-finance-security/architecture.svg)

이 구조의 장점은 명확하다. 여러 기관의 데이터를 한 화면에서 보고, 수동 거래와 자동 동기화를 결합하며, 서버 계산을 여러 client가 재사용한다. 반대로 장애 반경도 커진다. provider adapter가 잘못된 부호나 통화를 적용하면 dashboard뿐 아니라 API와 AI 답변도 같은 오류를 재사용한다. worker가 멈추면 화면은 열리지만 동기화와 예약 작업이 낡을 수 있다. 데이터베이스만 살아 있다고 서비스가 정상인 것은 아니다.

## 금융 앱의 첫 번째 SLO는 가용성이 아니라 정합성이다

Sure의 최근 commit과 issue에는 DST 이후 SimpleFIN 동기화 실패, pending-inclusive balance 처리, 투자 입출금과 수익의 구분, cross-currency transfer, 거래소 수수료와 보유 수량처럼 금융 데이터에서 자주 틀리는 경계가 계속 등장한다. 활발한 수정은 유지보수 신호이면서, provider별 원천 데이터가 얼마나 불균일한지도 보여 준다.

따라서 셀프호스팅 운영자는 “sync 성공”을 정답으로 취급하면 안 된다. 최소한 다음 불변조건을 정기적으로 대조해야 한다.

- 기관 화면의 closing balance와 Sure의 account balance가 기준일·통화까지 일치하는가
- pending과 posted 거래가 중복되거나 사라지지 않는가
- 내부 이체가 지출과 수입으로 이중 계산되지 않는가
- 외화 계좌·환전·투자 거래에서 원 통화와 기준 통화가 섞이지 않는가
- stock split, 수수료, 배당, 입출금이 투자 수익률로 잘못 잡히지 않는가
- provider 재연결과 backfill 뒤 같은 external transaction이 다시 생성되지 않는가
- manual correction이 다음 sync에서 덮어써지는지, lock 또는 override 규칙이 무엇인가

월말에는 주요 계좌의 statement와 잔액을 대조하고, provider 연결을 추가하거나 버전을 올린 뒤에는 최근 30~90일 구간을 다시 확인하는 편이 안전하다. 자동화가 많을수록 표본 검증을 없애는 것이 아니라 **어떤 오류가 자동으로 확대될 수 있는지에 맞춰 reconciliation을 설계**해야 한다.

특히 AI가 생성한 설명은 원장의 정합성을 대신하지 않는다. 최신 릴리스가 일부 insight를 LLM narration 대신 사실 기반 template로 바꾼 점은 유의미하다. 그러나 자연어 문장이 그럴듯해도 기반 거래의 부호, 중복, 계좌 범위가 틀리면 결론도 틀린다. AI assistant는 원장을 해석하는 client이지 원장의 진실을 보증하는 감사 계층이 아니다.

## `SECRET_KEY_BASE`를 잃으면 백업도 완전하지 않다

Sure의 Compose 문서는 `SECRET_KEY_BASE`를 session cookie 서명뿐 아니라 Active Record encryption key 자동 파생의 기반으로 사용한다고 설명한다. 명시적인 `ACTIVE_RECORD_ENCRYPTION_*` 값을 설정하지 않았다면 provider API token과 민감 데이터의 암호화 키가 이 값에서 결정된다. 새 설치마다 강한 값을 만들어야 하지만, 이미 운영 중인 instance에서 아무 생각 없이 바꾸면 기존 암호문을 읽지 못할 수 있다.

운영 절차는 세 가지를 분리해야 한다.

- **새 설치**: 공개 예제나 공통값이 아닌 고유한 `SECRET_KEY_BASE`와 DB password를 생성한다.
- **일상 백업**: DB만이 아니라 `.env`, Compose, upload storage와 version 정보를 함께 보관한다.
- **키 회전**: 이전 키를 일시적인 previous scheme으로 전달해 dry-run과 재암호화 결과를 확인한 뒤 제거한다.

공식 encryption 문서는 재암호화 task가 모든 model에 대해 `ok: true`, `failed_count: 0`인지 확인하고, login·provider sync·MFA를 점검하라고 안내한다. 키 회전은 환경 변수 한 줄을 교체하는 작업이 아니라 **암호문을 새 키로 이관하고 이전 키 없이 읽히는지 검증하는 migration**이다.

[Vaultwarden 셀프호스팅 비밀번호 관리 글](/posts/vaultwarden-self-hosted-password-manager/)에서 client-side encryption과 server 운영 책임을 분리했듯, Sure도 “내 서버에 있다”만으로 데이터가 안전해지지 않는다. host compromise, 잘못 공개된 `.env`, 느슨한 backup 권한, 취약한 reverse proxy는 모두 평문에 가까운 운영 접근권을 만든다. 금융 원장 서버는 관리 UI를 인터넷에 직접 노출하기보다 VPN 또는 접근 제한 proxy 뒤에 두고, MFA·patch·audit를 기본값으로 봐야 한다.

## MCP의 편의는 가족 금융 데이터에 대한 `read_write` 권한이다

Sure의 MCP endpoint는 external assistant가 거래, 계좌, 보유 자산, 순자산, 손익, 예산을 조회하게 한다. 문제는 권한이 읽기에 머물지 않는다는 점이다. 공식 도구 목록에는 goal·tag·category 생성과 수정, 거래 metadata 변경, transfer match, budget update, statement import, bill 생성과 payment 기록이 포함된다. OAuth client는 문서상 `read_write` scope를 받고, static token은 특정 사용자의 family data 전체에 연결된다.

일부 위험한 작업에는 `dry_run`, preview token, 변경 시 deactivation 같은 보호 장치가 있다. rule 적용은 preview 이후 대상이 바뀌면 거부하고, account share permission도 다시 확인한다. 그러나 이것은 최소한의 transaction safety이지 사람 승인 정책 전체가 아니다.

실무에서는 MCP를 다음처럼 다뤄야 한다.

1. 처음에는 별도 test family와 synthetic transaction에서 연결한다.
2. 가능하면 조회 전용 client를 별도 구현하고, 기본 `read_write` token을 범용 desktop agent에 주지 않는다.
3. statement, receipt, transaction note에 prompt injection이 들어올 수 있다고 가정한다.
4. 외부 model provider를 쓰면 어떤 금융 필드가 전송되는지와 보존 정책을 확인한다.
5. write tool은 preview 결과, 변경 전후 diff, 사람 승인, audit log를 거쳐 실행한다.
6. token을 production secret으로 관리하고 client 분실·provider 교체 시 즉시 revoke할 수 있어야 한다.

[OpenBao 시크릿 관리 전환 글](/posts/openbao-secrets-management-migration/)에서 동적 자격증명과 감사 경계를 강조한 이유와 같다. AI에게 금융 데이터를 연결할 때도 핵심은 대화 품질보다 **어떤 신원에 어떤 도구가 발급됐고 언제 철회할 수 있는가**다. 로컬 LLM을 쓰면 model request가 외부로 나가지 않을 수 있지만, MCP client와 Sure server가 가진 write 권한·host 보안까지 자동으로 해결되지는 않는다.

## 백업은 `.env`까지 담기 때문에 복구 자산이자 최고 등급 비밀이다

`v0.7.6-hotfix.1` 릴리스는 database, local upload, configuration, version을 포함하는 확장 backup·restore·rollback workflow를 안내한다. sample Compose의 backup service는 `db.dump`, `storage.tar.gz`, `.env`, `compose.yml`, manifest, restore script와 checksum을 만든다. 새 폴더나 새 machine으로 복원하면서 당시 image version을 pin하는 경로도 제공한다.

이는 DB dump만 남기는 것보다 훨씬 낫다. 하지만 backup bundle 안에는 `SECRET_KEY_BASE`, provider key, encryption key가 들어갈 수 있다. 공격자가 이 묶음을 얻으면 원장뿐 아니라 연결 자격증명까지 복원할 수 있다. off-site copy는 별도 암호화와 최소 권한 remote를 사용하고, restore operator와 일상 app operator의 접근을 나누는 편이 좋다. 외부 object storage를 Active Storage로 사용하면 그 object는 기본 backup에 포함되지 않으므로 bucket versioning·replication을 따로 검증해야 한다.

![Sure를 개인 금융 원장으로 승격하기 전 확인할 정합성·권한·복구 결정 게이트](https://heracles-jo.github.io/assets/img/posts/sure-self-hosted-personal-finance-security/decision.svg)

복구 시험은 파일 존재 여부가 아니라 다음 결과로 판정한다.

- 빈 host에서 backup checksum 검증 후 당시 version으로 기동되는가
- 사용자 login, MFA, 계좌 범위와 공유 권한이 유지되는가
- provider token을 읽고 test sync를 수행할 수 있는가
- attachment와 statement가 누락되지 않았는가
- worker와 scheduled job이 다시 실행되는가
- 주요 계좌의 잔액·거래 수·예산·투자 포지션이 복구 전 snapshot과 일치하는가
- off-site storage가 손상되거나 key가 없을 때 어떤 부분까지 복구 가능한가

[Supabase 셀프호스팅 운영 글](/posts/supabase-self-hosting-operations/)에서 backup 보유와 restore 성공을 구분했듯, Sure도 **새 서버에서 같은 금융 의미를 재현하는 것**이 기준이다. 화면이 열려도 환율, 잔액, 거래 연결과 권한이 달라졌다면 복구가 끝난 것이 아니다.

## Actual Budget·Firefly III와는 기능 수보다 원장 철학을 비교해야 한다

개인 금융 앱은 모두 거래를 보여 주지만 중심 모델이 다르다. 2026년 11월 16일 API 스냅샷에서 Actual Budget은 30,281 stars와 MIT 라이선스, Firefly III는 25,259 stars와 AGPL-3.0 라이선스를 보였고 둘 다 최근 commit 활동이 있었다. 숫자는 인기 순위가 아니라 생태계 규모를 가늠하는 참고 신호다.

| 선택지 | 중심 강점 | 더 확인할 경계 | 맞는 경우 |
|---|---|---|---|
| Sure | 자산·부채·투자·대출·provider sync·AI/MCP를 한 server에 통합 | provider 정합성, 넓은 권한 표면, PostgreSQL·Redis·worker·키·backup 운영 | 순자산과 여러 금융 유형을 통합하고 운영 검증을 감당할 수 있을 때 |
| Actual Budget | local-first와 envelope budgeting, device 간 sync, desktop/local-only 선택 | 투자·대출·provider 범위와 원하는 보고서가 충분한지 | 예산 통제와 local-first 사용 경험이 우선일 때 |
| Firefly III | 성숙한 개인 재무 원장, 규칙·분류·API와 긴 셀프호스팅 이력 | 투자 포트폴리오·AI·현대 client 요구를 별도 조합할지 | 거래 기록과 규칙 기반 재무 관리가 중심일 때 |
| 스프레드시트·수동 원장 | 구조와 계산을 직접 통제하고 외부 연결을 최소화 | 입력 비용, 중복, 다중 기기, 감사 trail과 자동화 한계 | 계좌 수가 적고 단순성과 검증 가능성이 기능보다 중요할 때 |

Sure가 언제나 더 좋은 선택은 아니다. 자동 provider sync와 AI가 필요 없고 envelope budgeting이 핵심이면 Actual의 범위가 더 명확할 수 있다. 복잡한 거래 rule과 전통적인 ledger 관리를 선호하면 Firefly III가 더 익숙할 수 있다. 반대로 여러 자산·부채를 하나의 household balance sheet로 보고 API와 agent까지 연결하려면 Sure의 폭이 장점이 된다. 다만 기능 폭만큼 실패 모드와 patch surface도 넓어진다.

## 30일 PoC는 예쁜 dashboard보다 틀린 숫자를 찾는 시험이어야 한다

처음부터 모든 은행·거래소·가족 구성원을 연결하지 않는다. manual account 하나, read-only provider 1~2개, 외화 또는 투자 계좌 하나로 시작하고 실제 기관 statement와 대조 가능한 기간을 고른다. AI와 MCP는 원장 검증이 끝난 뒤 별도 단계로 연다.

| 시험 | 측정 항목 | 중단 또는 보완 조건 |
|---|---|---|
| 초기 import와 재동기화 | 중복·누락 거래, 잔액, pending 전환 | 재연결마다 원장이 달라지거나 수동 수정이 반복됨 |
| 내부·외화 이체 | 수입·지출 이중 계산, 환율, transfer match | 순자산이나 cash flow가 transfer 때문에 왜곡됨 |
| 투자·대출 표본 | 수수료, 입출금, 원금·이자, 수익률 | 기관 statement와 핵심 수치가 설명 없이 불일치 |
| worker 중단·재시작 | sync 지연, 예약 job catch-up, health 표시 | 화면은 정상인데 데이터 신선도 실패가 드러나지 않음 |
| 버전 업그레이드 | migration, provider, rule, client 회귀 | backup 없이 rollback할 수 없거나 암호화 데이터 오류 발생 |
| MCP test family | 조회 범위, write preview, token revoke, prompt injection | 범용 agent가 승인 없이 원장 변경 가능 |
| 빈 서버 복원 | RTO, key·attachment·worker·provider 복구 | DB만 복원되고 금융 의미나 자격증명이 유실됨 |

성공 기준은 계좌를 많이 연결했거나 AI가 지출을 잘 설명했다는 것이 아니다. 표본 기간에서 원천 statement와 정합성을 유지하고, secret·MCP token·가족 권한을 분리하며, backup으로 새 host를 재구성한 뒤 같은 잔액과 거래 의미를 재현해야 한다.

Sure는 개인 금융 데이터를 SaaS 밖으로 가져오고 여러 자산을 한 원장에 모으려는 사람에게 강력한 선택지다. 동시에 운영자가 database administrator, security owner, integration tester, backup custodian 역할까지 맡는 시스템이다. 도입 판단은 세 문장으로 압축된다. **provider sync 뒤 숫자를 원천 자료로 대조할 수 있는가. encryption key와 AI write 권한을 별도 비밀·승인 경계로 관리할 수 있는가. 빈 서버에서 금융 원장과 attachment를 같은 의미로 복원할 수 있는가.** 이 세 조건을 증명할 때 셀프호스팅은 단순한 데이터 소유 선언을 넘어 실제 통제력이 된다.

> 1차 자료: [Sure 저장소와 README](https://github.com/we-promise/sure), [Docker self-hosting](https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md), [sample Compose](https://github.com/we-promise/sure/blob/main/compose.example.yml), [encryption key rotation](https://github.com/we-promise/sure/blob/main/docs/hosting/encryption.md), [AI configuration](https://github.com/we-promise/sure/blob/main/docs/hosting/ai.md), [MCP server와 도구 권한](https://github.com/we-promise/sure/blob/main/docs/hosting/mcp.md), [client 구조](https://github.com/we-promise/sure/blob/main/docs/clients.md), [보안 정책](https://github.com/we-promise/sure/blob/main/SECURITY.md), [AGPL-3.0 LICENSE](https://github.com/we-promise/sure/blob/main/LICENSE), [v0.7.6-hotfix.1 릴리스](https://github.com/we-promise/sure/releases/tag/v0.7.6-hotfix.1), [최근 commits](https://github.com/we-promise/sure/commits/main/), [공개 issues](https://github.com/we-promise/sure/issues), [공개 pull requests](https://github.com/we-promise/sure/pulls), [Actual Budget](https://github.com/actualbudget/actual), [Firefly III](https://github.com/firefly-iii/firefly-iii). Trending·저장소 수치는 2026년 11월 16일 08시 38분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
