---
title: "Codex Security CI 도입: AI 취약점 스캔을 게이트로 쓰는 기준"
description: "Codex Security의 diff·Deep Scan, 패치 검증, SARIF와 GitHub Actions를 분석하고 오탐·비용·스캔 신선도를 통제하는 단계적 CI 도입 기준을 정리한다."
author: heracles-jo
date: 2026-11-12 07:52:00 +0900
categories: [Security, Developer Tools]
tags: [codex-security, ai-security-scan, devsecops, github-actions, sarif, vulnerability-management]
image:
  path: https://heracles-jo.github.io/assets/img/posts/codex-security-ci-gate/cover.svg
  alt: "Codex Security 스캔을 보고 모드에서 검증 가능한 CI 게이트로 승격하는 구조"
---

AI 보안 스캐너를 CI에 붙이는 일은 명령 한 줄보다 어렵다. 모델이 취약점 후보를 찾더라도 실제 변경 범위를 모두 읽었는지, 결과가 현재 PR의 base와 head를 가리키는지, 패치가 원래 경계를 닫았는지, 스캔 실패를 “취약점 없음”으로 오해하지 않는지까지 증명해야 한다. 비용과 지연이 확률적으로 움직인다는 점도 기존 SAST와 다르다.

[openai/codex-security](https://github.com/openai/codex-security)는 저장소·선택 경로·Git diff를 스캔하고, 후보 검증, 패치 생성, 기존 수정 확인, SARIF·JSON·CSV 내보내기와 GitHub Actions 연동을 한 도구 체계로 묶는다. 이 글의 질문은 “AI가 취약점을 잘 찾는가”보다 좁다. **Codex Security 결과를 언제 참고 보고서에서 merge 게이트로 승격할 수 있는가**다.

2026년 11월 12일 08시 KST 전후 GitHub Trending daily에서 Codex Security는 **20 stars today**로 표시됐다. 같은 시점 GitHub API에서는 11,676 stars, 931 forks, 열린 issue와 pull request를 합친 139개, Apache-2.0 라이선스를 확인했다. 최신 릴리스 `npm-v0.9.1`은 11월 10일 공개됐고, 11월 12일 KST 새벽에도 진단 오류 분류와 정책 거부 처리 관련 커밋이 이어졌다. 이 수치는 공개 페이지의 시점별 스냅샷이며 탐지 정확도나 기업 환경 적합성을 보증하지 않는다.

이번 실행에서는 Search Console·Analytics의 실제 검색어, 노출, 클릭 데이터에 접근하지 못했으므로 주제 선정에 사용하지 않았다.

## 후보 비교: 새로운 검색 의도는 “AI 스캔의 merge 자격”이었다

기존 글의 제목·description·저장소 링크와 중심 논지를 먼저 대조했다. Scrapling은 weekly에서 강한 신호를 보였지만 이미 적응형 웹 스크래핑 인프라를 전용 글로 다뤘다. agent-browser, agent skills, ASTRYX도 브라우저 에이전트·스킬 공급망·생성 UI 클러스터와 겹쳤다. Codex Security는 기존 AI 보안 감사 글과 인접하지만, **실제 CLI·SDK·Action을 PR 신선도, 비용 한도, exit code, 패치 검증과 연결하는 운영 질문**이 별도로 남아 있었다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [openai/codex-security](https://github.com/openai/codex-security) | daily 20, 11,676 stars, `npm-v0.9.1`, Apache-2.0 | 저장소 스캔부터 검증·패치·SARIF·CI 게이트까지의 운영 계약이 독립적인 검색 의도라 선택했다. |
| [D4Vinci/Scrapling](https://github.com/D4Vinci/Scrapling) | weekly 7,291, 101,620 stars, `v0.5.1`, BSD-3-Clause | 적응형 파싱·안티봇·크롤러 운영을 6월 1일 글에서 이미 직접 다뤄 제외했다. |
| [GoogleChrome/modern-web-guidance-src](https://github.com/GoogleChrome/modern-web-guidance-src) | daily 133, 1,703 stars, Apache-2.0, 정식 release 없음 | 최신 Web API 지침은 유용하지만 Android·Go 에이전트 지침 검증 글과 중심 질문이 가깝다. |
| [shadcn/improve](https://github.com/shadcn/improve) | daily 333, 10,810 stars, MIT, 최근 push 9월 12일 | 고성능 모델이 계획하고 저비용 모델이 실행하는 분리는 흥미롭지만 코딩 에이전트 워크플로 클러스터와 경쟁한다. |
| [we-promise/sure](https://github.com/we-promise/sure) | daily 1,079, 12,898 stars, `v0.7.6`, AGPL-3.0 | 개인 금융 통합은 별도 의도지만 개인정보·데이터 공급자·금융 규제까지 검증 범위가 넓어 이번에는 보류했다. |

[Cloudflare Security Audit Skill 글](/posts/cloudflare-security-audit-skill-validation-pipeline/)은 정찰·커버리지 원장·독립 반증으로 AI 감사의 증거 품질을 높이는 절차를 다뤘다. Codex Security에서 새로 봐야 할 부분은 그 원칙을 **스캔 상태, diff 범위, Action check, 비용 정책, 패치 후 확인**이라는 운영 인터페이스로 어떻게 강제하는가다.

## 하나의 명령이 아니라 네 개의 상태 전이다

Codex Security는 새 취약점을 찾는 `scan`, 공급된 후보를 원본 코드와 대조하는 `validate`, 특정 finding을 수정하는 `patch`, 현재 checkout이 실제로 고쳐졌는지 확인하는 `verify-fix`를 구분한다. 수정 확인 결과도 `fixed`, `still_vulnerable`, `inconclusive`로 나뉜다.

![Codex Security의 범위 고정, 발견, 검증, 수정과 CI 판정을 분리한 아키텍처](https://heracles-jo.github.io/assets/img/posts/codex-security-ci-gate/architecture.svg)

이 구분이 중요한 이유는 발견과 수정이 같은 작업이 아니기 때문이다.

1. **범위 고정**: repository, 선택 경로, committed diff, working tree 중 무엇을 읽을지 정한다.
2. **발견과 검증**: Standard scan은 선택 범위를 조사하고, Deep Scan은 Standard scan을 반복해 결과를 deduplicate한다.
3. **수정**: 확정한 finding 하나에 대해 패치를 준비한다. 자동 수정은 스캔 성공의 부수 효과가 아니라 별도 쓰기 작업이다.
4. **수정 확인**: 원래 finding과 현재 source를 다시 대조해 경계가 닫혔는지 판정한다.
5. **배포 판정**: CI는 finding severity뿐 아니라 스캔 상태, 범위, 제외 경로, 현재 PR snapshot과의 일치 여부를 함께 읽는다.

`cs scan . --diff origin/main`처럼 변경 범위를 스캔할 수 있지만, “diff를 읽었다”는 말만으로 PR 전체를 검증한 것은 아니다. 생성된 `scan-manifest.json`의 scope와 `review.excludedPaths`, retained scope 목록을 같이 봐야 한다. 보고서가 0건이어도 제외 경로나 unresolved question은 남을 수 있다.

[Open Code Review 글](/posts/open-code-review-hybrid-ai-code-review/)에서 모델에 전달되지 않은 파일은 절대 검토할 수 없다고 구분했다. 보안 스캔도 같다. finding 수보다 먼저 **어떤 revision의 어떤 파일이 discovery 대상이었는지**를 artifact로 남겨야 한다.

## Deep Scan은 “더 깊은 모델”이 아니라 반복 발견 시스템이다

공식 문서에서 Deep Scan은 선택 범위에 Standard scan을 반복하고, 각 batch의 finding을 병합·중복 제거하는 모드다. worker 수, worker당 subagent, 새 finding이 없는 연속 실행 수, 최대 discovery run과 discovery 시간 한도를 설정할 수 있다. 중단된 `running` scan은 원래 checkout·output·session·state directory가 남아 있으면 resume할 수 있다.

이 구조는 한 번의 긴 prompt보다 운영하기 쉽지만 세 가지 비용을 만든다.

- 반복 실행이 같은 root cause를 다른 표현으로 보고할 수 있어 deduplication 비용이 생긴다.
- worker가 늘면 model 비용과 wall time뿐 아니라 source snapshot·설정 일관성 검증이 어려워진다.
- 중단 복구가 가능해도 완료된 stage와 미완료 model turn의 경계를 이해해야 한다. resume은 모든 추론을 그대로 이어 주는 마법이 아니다.

`max_cost_usd_per_scan` 또는 `--max-cost`는 한 scan attempt의 추정 비용 한도다. 이미 진행 중인 요청은 한도를 넘을 수 있고, batch 전체나 이후 patch·validate 작업의 총예산은 아니다. Standard의 `max-time`은 advisory investigation allowance이며 Deep에서는 discovery 제한으로 강제된다. 비용 한도가 있는 scan에서 patch나 validate를 한 번에 묶을 수 없다는 문서상의 제약도 합리적이다. 탐지 예산과 수정 권한을 분리해야 비용 초과가 자동 쓰기 작업으로 번지지 않는다.

PoC에서는 “Deep가 Standard보다 몇 개 더 찾았다”만 보지 않는다. 반복 횟수별 신규 root cause, 중복률, finding당 검증 시간, scan당 비용 분포, resume 후 source 일치 실패를 함께 측정한다. 새 finding이 거의 늘지 않는데 비용만 증가하면 worker나 반복 수를 줄이는 편이 낫다.

## exit code 0은 저장소가 안전하다는 뜻이 아니다

CLI의 scan exit code는 세 범주다.

- `0`: scan이 완료됐고 설정한 severity threshold를 넘지 않았다.
- `1`: `--fail-on-severity` 기준 이상의 finding이 있다.
- `2`: 실행, target integrity 또는 필수 output 생성이 실패했다.

여기서 `0`은 선택한 범위와 예산 안에서 threshold를 통과했다는 뜻이다. coverage gap과 investigation note는 완료된 scan을 자동 실패시키지 않는다. 반대로 모델 refusal이나 safety block으로 Action이 중단되면 `fail-on-severity: none`이어도 실패한다. **스캔 실패는 취약점 없음이 아니다.**

따라서 CI wrapper는 최소한 다음 조건을 별도로 검사해야 한다.

| 조건 | 보고 모드 | merge 게이트 |
|---|---|---|
| scan status | 결과를 저장하고 알림 | `completed` 또는 검증된 empty diff만 허용 |
| target revision | 보고서에 SHA 기록 | 현재 PR head·base와 정확히 일치 |
| scope·exclusions | 사람이 확인 | 승인되지 않은 고위험 제외 경로가 없어야 함 |
| severity | 추세 관찰 | 검증된 threshold 이상만 차단 |
| refusal·runtime error | 재실행 큐 | 성공으로 변환하지 않고 hard fail |
| artifact | Markdown만 보관 가능 | manifest·SARIF·cost·coverage receipt 함께 보관 |

Cloudflare 감사 절차에서 `confirmed 0건`과 “취약점 없음”을 분리했듯, Codex Security에서도 scan completion과 제품 안전성 보증을 분리해야 한다.

## GitHub Actions의 핵심 위험은 stale check다

공식 Action은 repository 또는 PR diff를 스캔하고, severity threshold, annotation, JSON·SARIF artifact를 제공한다. 예제는 Action tag가 아니라 검토한 **distribution commit SHA 전체**를 고정하고, checkout credential persistence를 끄며, 기본적으로 contents read 권한만 준다. 공급망 관점에서 타당한 기본값이다.

더 까다로운 부분은 PR 신선도다. GitHub는 head commit이 같으면 base branch만 바뀐 뒤에도 과거 성공 check를 재사용할 수 있다. 그러나 merge diff는 달라졌다. 공식 문서가 PR 이벤트의 head SHA, target branch, base SHA와 live base를 스캔 전후에 다시 확인하고, 별도의 merge-time freshness gate를 요구하는 이유다. Action 자체는 merge queue의 `merge_group`을 지원하지 않으므로, merge queue를 쓰는 저장소에서 required check 하나만으로 현재 합성 결과가 스캔됐다고 증명할 수 없다.

![Codex Security 결과를 report-only에서 merge gate로 승격하기 위한 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/codex-security-ci-gate/decision.svg)

처음 도입할 때는 다음 순서가 안전하다.

1. **예약 repository scan**: merge를 막지 않고 scan completion, 비용, 오탐과 exclusion을 수집한다.
2. **trusted branch의 PR diff scan**: fork PR에는 secret을 노출하지 않고 같은 저장소의 신뢰된 contributor부터 적용한다.
3. **snapshot 검증**: head·base·live base가 scan receipt와 일치할 때만 결과를 인정한다.
4. **결정론적 실패부터 차단**: runtime error, artifact 누락, scope 불일치, stale snapshot을 먼저 hard fail로 둔다.
5. **검증된 severity 차단**: 팀 corpus에서 재현성과 triage SLA가 확보된 뒤 high·critical threshold를 올린다.
6. **merge-time freshness**: base가 바뀌면 재스캔하거나 현재 merge 결과를 별도 gate가 확인하게 한다.

`pull_request_target`로 비신뢰 fork 코드를 checkout하고 API key를 사용하는 우회는 피해야 한다. 비밀정보가 필요한 scanner는 trusted-contributor 경로와 fork review 경로를 분리하는 편이 낫다.

## 스캐너 설정 파일도 비신뢰 입력이 될 수 있다

Codex Security project configuration은 scope, knowledge base, cost limit, severity threshold와 native Codex 설정을 저장할 수 있다. 문제는 native 설정이 MCP server를 시작하거나 model request 목적지를 바꿀 수 있다는 점이다. 공식 문서는 CI에서 operator-controlled 설정을 스캔 대상 checkout 밖에 두라고 경고한다.

이는 사소한 운영 팁이 아니다. 공격자가 PR에서 `codex-security.yaml`을 바꿔 더 넓은 도구 권한, 다른 provider, 외부 output 경로를 선택할 수 있다면 scanner가 공격 경로가 된다. 설정은 다음처럼 다룬다.

- workflow와 scanner config는 protected ref 또는 별도 운영 저장소에서 읽는다.
- `--dry-run --json`과 `info --json`으로 effective scope·provider·output 경로의 출처를 확인한다.
- Action은 검토한 full commit SHA에 고정하고 업데이트 시 수동 실행으로 검증한다.
- self-hosted runner에서는 sandbox가 이미 동작해야 하며, 스캔 대상과 credential·Docker socket·cloud metadata를 분리한다.
- output은 scanned worktree 밖의 private artifact 경로에 두고, public issue·PR에는 실제 취약점과 private source를 노출하지 않는다.

[CubeSandbox의 MicroVM 격리 글](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)에서 다뤘듯 “read-only workspace”는 완전한 격리와 다르다. Codex Security의 Deep Scan worker도 read-only 실행을 사용하지만 공식 보안 정책은 이를 offline isolated environment로 보지 말라고 명시한다. inherited MCP server와 현재 사용자 권한이 남을 수 있으므로, runner 자체의 최소 권한과 egress 정책이 필요하다.

## 자동 패치는 finding과 같은 증거 수준으로 다시 심사한다

`patch`가 코드를 만들었다고 finding이 닫힌 것은 아니다. 원래 취약점이 권한 우회라면 happy-path 테스트 통과가 아니라 공격자가 사용하던 경로가 거부되는지 확인해야 한다. `verify-fix`의 `inconclusive`는 실패가 아니라 필요한 증거가 부족하다는 상태다.

수정 승격에는 네 증거를 묶는 편이 좋다.

1. 원래 finding ID, source revision과 영향 경로
2. 최소 재현 또는 negative security test
3. patch diff와 일반 회귀 테스트
4. 독립된 fix verification 결과와 reviewer 승인

패치 에이전트가 만든 테스트만으로 패치를 검증하면 같은 오해를 코드와 테스트에 복제할 수 있다. 고위험 finding은 사람이 threat boundary와 exploit condition을 다시 확인하거나, 별도 모델·도구 lane에서 원본 재현을 수행한다. [위험 명령 차단 글](/posts/ai-agent-destructive-command-guard/)의 사전 실행 guard도 도움이 되지만 sandbox와 사람 승인을 대체하지 않는다.

## 2주 PoC에서 측정할 것은 발견 수보다 운영 영수증이다

과거에 실제로 수정한 인증·인가, path traversal, SSRF, unsafe deserialization 같은 결함이 있는 저장소 하나를 고른다. 수정 전 commit과 수정 후 commit을 blind corpus로 만들고 Standard, Deep, 기존 SAST, 사람 리뷰를 같은 결함 등급으로 비교한다.

측정값은 다섯 묶음이면 충분하다.

- **범위**: 대상 파일 대비 retained in-scope file, 승인되지 않은 exclusions, base/head 불일치 건수
- **탐지**: 과거 결함 재발견률, 신규 true positive, finding별 오탐·중복률
- **검증·수정**: validate 판정 재현률, patch 적용 성공보다 exploit closure 비율, `inconclusive` 원인
- **운영**: scan p50/p95 시간, interruption·resume 성공률, SARIF·manifest 생성 실패, stale check 차단률
- **비용·보안**: scan당 추정 비용과 초과폭, 외부 전송 범위, runner credential 노출 0건, config 변조 fixture 차단

처음 합격선은 severity보다 구조에 둔다. 예를 들어 target SHA 불일치 0건, runtime error를 pass로 변환한 사례 0건, required artifact 누락 0건, 검증된 high finding의 사람 재현률 100%, private source가 승인되지 않은 provider로 전송된 사례 0건처럼 쓴다. 그다음 실제 corpus에서 high·critical recall과 오탐 비용을 보고 merge threshold를 정한다.

Codex Security의 장점은 스캔, 후보 검증, 패치, 수정 확인과 결과 내보내기를 한 lifecycle로 연결한다는 데 있다. 동시에 이 통합은 scan status와 source snapshot, 설정 파일, model 비용, patch 쓰기 권한을 잘못 묶으면 더 큰 자동화 실패를 만든다.

따라서 첫 도입 목표는 “AI가 발견한 high를 모두 차단”이 아니다. **현재 merge diff를 정확히 스캔했다는 영수증을 남기고, 실행 실패와 coverage gap을 보안 성공으로 바꾸지 않으며, finding과 patch를 독립적으로 재검증하는 것**이다. 이 세 조건이 반복해서 지켜질 때 Codex Security는 보고서 생성기를 넘어 CI의 보조 게이트가 될 수 있다.

> 1차 자료: [Codex Security 저장소와 README](https://github.com/openai/codex-security), [Security workflows](https://github.com/openai/codex-security/blob/main/docs/agent-workflows.md), [CLI 문서](https://github.com/openai/codex-security/blob/main/sdk/typescript/docs/cli.md), [SDK 문서](https://github.com/openai/codex-security/blob/main/sdk/typescript/docs/sdk.md), [GitHub Action 문서](https://github.com/openai/codex-security/blob/main/github-action/README.md), [project configuration](https://github.com/openai/codex-security/blob/main/docs/project-configuration.md), [findings storage와 deduplication](https://github.com/openai/codex-security/blob/main/sdk/typescript/docs/findings-service.md), [보안 정책](https://github.com/openai/codex-security/blob/main/SECURITY.md), [`npm-v0.9.1` release](https://github.com/openai/codex-security/releases/tag/npm-v0.9.1), [Apache-2.0 LICENSE](https://github.com/openai/codex-security/blob/main/LICENSE), [최근 commits](https://github.com/openai/codex-security/commits/main/), [공개 issues](https://github.com/openai/codex-security/issues), [공개 pull requests](https://github.com/openai/codex-security/pulls). Trending·저장소 수치는 2026년 11월 12일 08시 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
