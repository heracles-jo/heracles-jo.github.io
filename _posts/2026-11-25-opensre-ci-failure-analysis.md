---
title: "OpenSRE CI 실패 분석: 자동 복구 에이전트 운영 기준"
description: "OpenSRE의 GitHub Actions 분석·수정 루프를 바탕으로 flaky CI와 코드 결함을 구분하고, 자동 복구 권한·증거·중단 조건을 설계하는 기준을 제시한다."
author: heracles-jo
date: 2026-11-25 08:45:00 +0900
categories: [DevOps, Observability]
tags: [opensre, ci-cd, site-reliability-engineering, github-actions, incident-response]
image:
  path: https://heracles-jo.github.io/assets/img/posts/opensre-ci-failure-analysis/cover.svg
  alt: "OpenSRE가 CI 실패 증거를 수집하고 격리된 브랜치에서 수정안을 검증하는 구조"
---

CI가 빨간색이 되면 팀은 대개 실패 로그를 열고, 재실행 버튼을 누르고, 최근 변경을 훑는다. 문제는 이 세 행동이 서로 다른 원인을 같은 방식으로 취급한다는 데 있다. runner나 외부 서비스가 흔들린 **CI 자체 결함**, 새 커밋이 만든 **코드 결함**, 오래된 flaky test, base branch 이동, 권한·비밀·캐시 문제는 해결 절차가 달라야 한다. 원인을 나누지 못한 자동 복구는 불필요한 코드 변경을 만들거나, 재실행으로 실제 결함을 가린다.

[Tracer-Cloud/opensre](https://github.com/Tracer-Cloud/opensre)는 GitHub Actions 이력을 분석하고 실패한 pull request의 로그를 읽어 수정 브랜치를 만든 뒤 새 check를 기다리는 오픈소스 SRE 에이전트다. 2026년 11월 25일 08시 53분 KST 전후 GitHub Trending daily에서는 **408 stars today**로 표시됐다. 같은 시점 [GitHub 저장소 메타데이터](https://github.com/Tracer-Cloud/opensre) 기준 약 **1.52만 stars, 2,010 forks, 28 open issues**, Apache-2.0 라이선스였고, 전날 `v0.1.2026.11.24` 릴리스와 Sentry·PostHog MCP 연결, Grafana·Datadog·PagerDuty·AWS preset 관련 커밋이 확인됐다. 프로젝트 스스로 `public alpha`라고 밝히므로 빠른 활동량을 성숙도와 동일시해서는 안 된다. 수치와 상태는 확인 시점의 공개 스냅샷이다.

## 후보 비교: 또 하나의 에이전트보다 CI 증거 체계를 골랐다

오늘 상위 후보 다수는 이미 다룬 검색 의도와 겹쳤다. `CLI-Anything`은 에이전트 네이티브 소프트웨어 글에서 직접 분석했고, `Cursor Plugins`, `Diagram Design`, `OpenVINO`, `NGINX`, `AFFiNE`, App Store compliance도 별도 글이 있다. OpenSRE 역시 관측성·복구 클러스터와 인접하지만, **CI 실패를 분류하고 수정 권한을 어디까지 자동화할 것인가**라는 독립적인 운영 질문이 남아 있다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Tracer-Cloud/opensre](https://github.com/Tracer-Cloud/opensre) | daily 408, API 15,176 stars, Apache-2.0, 전날 release | flaky CI와 코드 결함 분리, 수정 권한, check 증거라는 구체적 운영 의도가 있어 선택했다. |
| [elementalsouls/Claude-BugHunter](https://github.com/elementalsouls/Claude-BugHunter) | daily 1,833, API 21,427 stars, MIT | 레드팀 자동화는 Security Audit Skill·Codex Security 글의 승인·증거 검증과 강하게 겹친다. |
| [HKUDS/CLI-Anything](https://github.com/HKUDS/CLI-Anything) | daily 1,075, API 64,721 stars, Apache-2.0 | GUI를 agent-native CLI로 감싸는 중심 논지를 이미 다뤘다. |
| [firecrawl/firecrawl](https://github.com/firecrawl/firecrawl) | daily 990, API 208,913 stars, AGPL-3.0 | 웹 수집·RAG 인입은 Scrapling, 문서 파서, 헤드리스 브라우저 글과 경쟁한다. |
| [jingyaogong/minimind](https://github.com/jingyaogong/minimind) | daily 727, API 70,158 stars, Apache-2.0 | 소형 LLM 학습은 유용하지만 Marin의 학습 재현성과 로컬 LLM 클러스터에 가깝다. |

Search Console·Analytics의 실제 검색어, 노출, CTR 데이터에는 접근하지 못했으므로 후보 선정에 사용하지 않았다. Trending 순위도 주제의 우수성을 증명하는 지표가 아니라, 지금 어떤 운영 문제가 개발자 관심을 받는지 확인하는 약한 신호로만 사용했다.

## OpenSRE의 핵심은 코딩 에이전트가 아니라 실패 분류다

OpenSRE의 CI 분석 문서는 최근 30일 GitHub Actions 실행을 읽고 실패를 두 부류로 나눈다. 동일 commit이 재실행 또는 새 workflow run에서 통과하면 CI 신뢰성 실패로, branch가 새 commit으로 이동한 뒤에야 통과하면 source-code failure로 분류한다. 완벽한 인과 추론은 아니지만 “실패 후 성공”을 전부 flaky로 계산하는 것보다 낫다.

이 구분이 중요한 이유는 대응 정책이 반대이기 때문이다.

- 동일 SHA 재실행이 통과했다면 테스트 격리, runner, 네트워크, 외부 API, 시간 의존성을 조사해야 한다.
- 새 SHA에서만 통과했다면 코드·설정·lockfile·테스트 수정의 효과를 검토해야 한다.
- base branch를 합친 뒤 통과했다면 제품 결함보다 branch drift나 충돌이 원인이었을 수 있다.
- check가 등록되지 않았다면 성공이 아니라 workflow trigger, 권한, path filter 누락일 수 있다.

[Prometheus 쿼리 비용 제한과 복구 검증](/posts/prometheus-316-query-cost-upgrade/)에서 정상 지연과 timeout을 한 지표로 합치면 관측 시스템을 잘못 튜닝한다고 봤다. CI도 실패율 하나만 보면 같은 문제가 생긴다. **코드 결함률, CI 자체 실패율, 재실행 성공률, default branch red time, 수정 후 check 등록률**을 분리해야 자동화의 효과를 설명할 수 있다.

## 안전한 자동 복구는 여섯 단계를 서로 다른 권한으로 나눈다

![OpenSRE CI 실패 분석과 자동 복구의 증거·권한 분리 구조](https://heracles-jo.github.io/assets/img/posts/opensre-ci-failure-analysis/architecture.svg)
_OpenSRE를 운영에 넣을 때는 로그 수집, 원인 가설, 격리 수정, push, 새 check 확인, 사람 승인을 하나의 자율 권한으로 묶지 않는 편이 안전하다._

OpenSRE 문서의 실제 흐름은 단순한 “로그를 LLM에 보내고 고친다”보다 길다.

1. **대상 고정**: PR 번호, head SHA, base SHA, 실패한 check와 workflow run을 기록한다.
2. **증거 수집**: PR metadata와 압축한 실패 job 로그를 읽고, base branch가 뒤처졌는지도 확인한다.
3. **격리 실행**: 지정 저장소는 isolated checkout, 명시적으로 선택한 로컬 저장소는 linked worktree에서 수정한다.
4. **변경 검증**: 코딩 에이전트가 테스트·lint·build를 실행하되, 내장 에이전트 자체는 commit과 push를 하지 않는다.
5. **제한된 쓰기**: 같은 저장소의 PR branch 또는 새 repair branch에만 commit하고 force push를 사용하지 않는다.
6. **원격 재검증**: push한 정확한 commit의 check가 등록될 때까지 기다린 뒤 pass, fail, superseded, timeout을 구분한다.

이 순서에서 가장 중요한 경계는 “수정안을 만들 수 있음”과 “원격 branch를 변경할 수 있음”의 분리다. [Open Code Review의 하이브리드 AI 리뷰 구조](/posts/open-code-review-hybrid-ai-code-review/)처럼 모델 판단은 후보를 만드는 데 쓰고, 승격은 결정적 조건으로 통제해야 한다. 로컬 테스트가 통과했다는 이유만으로 push가 허용되어서는 안 되고, push가 성공했다는 이유만으로 복구가 완료된 것도 아니다.

## flaky CI와 코드 결함은 통계만으로 완전히 구분되지 않는다

동일 commit의 재실행이 통과했다면 CI 결함일 가능성이 높다. 그러나 다음 경우에는 오분류가 생길 수 있다.

- 외부 package registry나 SaaS가 잠시 실패했다가 복구됐다.
- 테스트가 공유 데이터, wall clock, 실행 순서에 의존한다.
- mutable image나 unpinned dependency가 재실행 사이에 바뀌었다.
- feature flag·secret·runner image가 코드 변경 없이 갱신됐다.
- 첫 실행은 캐시 miss, 두 번째는 cache hit로 자원 조건이 달라졌다.

따라서 자동 분류에는 신뢰도와 근거가 필요하다. 최소한 실패 check, 첫 실행과 재실행의 SHA, runner image, dependency lock digest, 외부 서비스 오류, 테스트 seed와 artifact를 남겨야 한다. 같은 SHA가 통과했다는 사실은 **코드가 무관하다는 증명**이 아니라, 코드 변경 없이 결과가 달라졌다는 증거다.

flaky test를 재실행 정책으로 덮는 것도 위험하다. [Cypress E2E 테스트 운영 기준](/posts/github-trending-cypress-browser-e2e-testing-governance/)에서 재시도는 임시 완충재일 뿐이라고 본 이유다. 재실행 횟수가 늘수록 pipeline은 녹색이 될 수 있지만, 결함 탐지력이 낮아지고 대기 시간과 runner 비용은 늘어난다. 테스트별 flaky rate, quarantine 기간, 소유자와 제거 SLA를 따로 관리해야 한다.

## 자동 수정에서 가장 먼저 잠가야 할 것은 branch와 commit이다

OpenSRE는 fork PR을 거부하고, 같은 저장소의 PR head branch만 수정 대상으로 삼는다. branch 대상에서는 기본적으로 `opensre/ci-fix-*` 같은 새 repair branch를 만들며, 사용자가 명시적으로 요청한 경우에만 대상 branch 직접 push를 시도한다. force push는 하지 않고, 원격 branch가 이동하면 검증을 중단하거나 최신 base를 한 번 병합해 새 commit을 다시 확인한다.

이 정책은 최소선이다. 조직 환경에서는 다음 제약을 추가할 만하다.

- token은 선택한 저장소와 repair branch에 필요한 Contents 권한만 가진다.
- protected `main` 직접 push와 workflow 파일 변경은 별도 승인을 요구한다.
- `.github/workflows`, 배포 manifest, IAM·Terraform, lockfile 변경은 일반 코드보다 높은 위험 등급으로 분류한다.
- commit에는 원인 가설, 실행한 검사, 사용한 base/head SHA와 도구 버전을 남긴다.
- 자동 생성 branch는 만료 시간과 소유자를 갖고, 실패한 시도도 삭제 전에 artifact를 보존한다.

특히 workflow 자체를 수정할 때는 에이전트가 자신을 평가하는 시험을 바꾸는 문제가 생긴다. 실패한 테스트를 삭제하거나 path filter로 제외해 check를 녹색으로 만드는 변경은 “복구”가 아니다. required check 목록, 테스트 수, skip·xfail 변화, coverage와 보안 scan 구성을 base와 비교해야 한다.

## 로그와 관측 데이터는 프롬프트가 아니라 민감한 운영 자산이다

CI 로그에는 API endpoint, 내부 hostname, branch 이름, 고객 식별자, 임시 token과 실패 payload가 들어갈 수 있다. OpenSRE는 선택적 masking과 secret-shaped 문자열 redaction을 제공하지만, 공식 privacy 문서도 알려진 token 형태만 탐지하며 임의의 민감 정보까지 지우지는 못한다고 밝힌다. prompt·response logging과 product analytics는 기본적으로 켜져 있고, 원격 forwarding을 끄려면 `OPENSRE_NO_TELEMETRY=1`, 전체 prompt log를 끄려면 `OPENSRE_PROMPT_LOG_DISABLED=1` 같은 명시적 설정이 필요하다.

운영 도입 전에는 데이터 경로를 먼저 그려야 한다.

| 데이터 | 최소 수집 | 보존·전송 정책 |
|---|---|---|
| CI 로그 | 실패 step 주변의 제한된 구간, artifact link | secret scan 후 전달, 원문 접근 감사 |
| 저장소 코드 | 실패와 관련된 파일·diff | private repo 경계 유지, 모델 제공자 정책 확인 |
| 관측 데이터 | 필요한 시간 범위의 log·metric·trace | tenant·서비스 범위 제한, 고객 식별자 masking |
| 에이전트 대화 | 가설·도구 결과·승인 기록 | 보존 기간, 삭제, 원격 analytics opt-out 결정 |
| 수정 artifact | patch, commit, 테스트 결과 | head/base SHA와 함께 불변 저장 |

“셀프호스팅 가능”도 자동으로 데이터가 외부로 나가지 않는다는 뜻은 아니다. 사용하는 LLM provider, Sentry·PostHog telemetry, GitHub와 관측 도구 연결을 함께 봐야 한다. [Coolify 셀프호스팅 PaaS 분석](/posts/coolify-self-hosted-paas-operations/)에서 제어면을 직접 운영해도 외부 DNS·registry·Git provider 의존성이 남는다고 본 것과 같은 문제다.

## repair loop는 무한 자율성보다 예산이 중요하다

OpenSRE의 문서화된 repair loop는 30초마다 한 PR을 확인하되, 실패한 복구 시도는 최대 3회, 전체 시간은 10분으로 제한한다. 이 값이 모든 팀에 맞는다는 뜻은 아니지만, 자동 복구에 **시도 예산과 종료 조건**이 필요하다는 설계는 옳다.

무제한 루프는 다음과 같은 진동을 만든다.

- 에이전트 A의 수정이 check X를 고치고 check Y를 깨뜨린다.
- 다음 시도가 이를 되돌리며 X를 다시 깨뜨린다.
- base branch가 계속 움직여 merge commit이 반복 생성된다.
- 외부 서비스 장애인데 코드 수정 commit만 누적된다.
- 실패 로그가 같은데 모델 표현만 달라진 유사 patch가 반복된다.

재시도 여부는 단순 횟수보다 **새 증거가 생겼는가**로 판단하는 편이 낫다. 실패 check나 stack trace, base SHA, dependency 상태가 같다면 같은 종류의 수정안을 반복할 이유가 적다. 반대로 새 check가 등록됐거나 failure class가 바뀌었다면 한 번 더 시도할 근거가 있다.

## PoC는 수정 성공률보다 오수정 비용을 측정해야 한다

![OpenSRE 자동 복구 PoC의 관찰·제안·제한 실행·승격 결정 흐름](https://heracles-jo.github.io/assets/img/posts/opensre-ci-failure-analysis/decision.svg)
_읽기 전용 분석에서 시작해 patch 제안, 비핵심 저장소의 제한된 push로 단계적으로 승격하고, 증거 부족·권한 초과·반복 실패가 나타나면 중단한다._

2~4주 PoC라면 처음부터 production 저장소에 자동 push를 허용하기보다 세 단계로 나누는 편이 안전하다.

| 단계 | 허용 범위 | 측정 항목 | 중단 조건 |
|---|---|---|---|
| 관찰 | Actions 이력과 로그 읽기, 실패 분류 | 분류 정확도, 근거 링크, 분석 시간, API 비용 | 동일 SHA 성공만으로 원인을 확정하거나 민감 로그를 과수집 |
| 제안 | isolated checkout에서 patch와 검사 결과 생성 | 사람 수용률, 수정 파일 수, 테스트 재현성, 오수정률 | 테스트 삭제·skip 증가, workflow 약화, 근거 없는 대규모 변경 |
| 제한 실행 | 비핵심 repo의 same-repo PR branch push | 첫 시도 성공률, check 등록 시간, rollback, 사람 검토 시간 | protected branch 접근, force push, 다른 PR 변경, 반복 진동 |
| 운영 승격 | 위험 등급별 승인과 bounded repair loop | red time 감소, flaky backlog, developer wait, token·모델 비용 | CI 시간은 줄지만 결함 누락·재작업·권한 사고가 증가 |

핵심 KPI는 “에이전트가 몇 건 고쳤는가”가 아니다. 사람이 재현 가능한 원인 설명을 받았는지, 첫 patch가 required checks를 약화하지 않고 통과했는지, 잘못된 수정이 review 전에 차단됐는지, 동일 유형의 flaky failure가 줄었는지를 본다. OpenSRE가 계산하는 default branch red time과 developer downtime도 유용하지만, 조직별 working hours와 workflow 중요도를 반영해 해석해야 한다.

도입 대상도 선별할 필요가 있다. deterministic unit test와 lint, lockfile·format 오류처럼 실패 범위가 좁은 저장소는 자동 복구 효과를 확인하기 좋다. 반대로 하드웨어, 장시간 E2E, 결제·의료·안전 시스템, production data migration, 다중 저장소 배포처럼 사람이 의미를 판단해야 하는 영역은 분석과 patch 제안까지만 맡기는 편이 낫다.

OpenSRE가 보여주는 방향은 CI를 단순 pass/fail 도구에서 **증거를 가진 운영 시스템**으로 바꾸는 것이다. 다만 성공 조건은 코딩 에이전트의 능력보다 실패 분류, branch 격리, 최소 권한, 원격 check 재검증, telemetry 통제와 종료 예산에 달려 있다.

자동 복구를 승인하기 전 세 질문에 답해야 한다. **동일 commit의 재실행 성공과 실제 코드 결함을 어떤 증거로 구분하는가. 에이전트가 바꿀 수 있는 branch·파일·workflow의 경계가 기계적으로 제한되는가. push한 정확한 commit의 required checks와 사람 검토가 끝나기 전에는 성공으로 기록되지 않는가.** 이 세 조건을 실행 결과로 증명할 수 있을 때 CI 에이전트는 재실행 버튼을 자동으로 누르는 봇이 아니라, 신뢰성 부채를 줄이는 제한된 운영 도구가 된다.

## 1차 자료

- [OpenSRE 저장소와 README](https://github.com/Tracer-Cloud/opensre)
- [CI/CD overview](https://github.com/Tracer-Cloud/opensre/blob/main/docs/cicd/overview.mdx)
- [CI/CD analytics](https://github.com/Tracer-Cloud/opensre/blob/main/docs/cicd/cicd-analytics-demo.mdx)
- [GitHub CI fix](https://github.com/Tracer-Cloud/opensre/blob/main/docs/cicd/github-ci-fix.mdx)
- [CI repair agent](https://github.com/Tracer-Cloud/opensre/blob/main/docs/cicd/ci-repair-agent.mdx)
- [Headless CLI approvals](https://github.com/Tracer-Cloud/opensre/blob/main/docs/guides/headless-cli.mdx)
- [Interactive Shell Privacy](https://github.com/Tracer-Cloud/opensre/blob/main/docs/platform/interactive-shell-privacy.mdx)
- [SECURITY.md](https://github.com/Tracer-Cloud/opensre/blob/main/SECURITY.md), [Apache-2.0 LICENSE](https://github.com/Tracer-Cloud/opensre/blob/main/LICENSE)
- [릴리스](https://github.com/Tracer-Cloud/opensre/releases), [최근 commits](https://github.com/Tracer-Cloud/opensre/commits/main/), [공개 issues와 pull requests](https://github.com/Tracer-Cloud/opensre/issues)

Trending·저장소 수치는 2026년 11월 25일 08시 53분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
