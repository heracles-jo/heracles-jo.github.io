---
title: "Ruff 전환: Flake8·Black 통합 시 회귀 검증 기준"
description: "Ruff로 Flake8·isort·Black을 통합할 때 규칙 동등성, 자동 수정 안전성, 포맷 차이, 모노레포 설정과 CI 전환을 검증하는 실무 기준을 정리한다."
author: heracles-jo
date: 2026-11-08 08:05:00 +0900
categories: [Developer Tools, Python]
tags: [ruff, python, lint, formatter, pyproject, ci]
image:
  path: https://heracles-jo.github.io/assets/img/posts/ruff-python-lint-format-migration/cover.svg
  alt: "Ruff 전환에서 린트 규칙, 포맷, 자동 수정, CI 회귀를 검증하는 구조"
---

Python 저장소의 품질 도구는 쉽게 늘어난다. Flake8에 플러그인을 붙이고, import 정렬은 isort, 포맷은 Black, 오래된 문법 교체는 pyupgrade, 미사용 import 정리는 autoflake가 맡는다. 각 도구는 잘 작동하지만 설정 파일, 제외 경로, 캐시, 에디터 확장, pre-commit hook, CI 로그가 갈라진다. 느린 실행보다 더 큰 문제는 **같은 파일을 서로 다른 규칙과 순서로 해석해 로컬과 CI의 결과가 달라지는 것**이다.

[Ruff](https://github.com/astral-sh/ruff)는 이 여러 단계를 Rust 기반 linter와 formatter 하나로 통합한다. 공식 README는 Flake8 계열, isort, pydocstyle, pyupgrade, autoflake 등의 규칙을 자체 구현하고 900개가 넘는 lint rule을 제공한다고 설명한다. formatter는 Black 호환성을 목표로 하며, 프로젝트 설정은 `pyproject.toml`, `ruff.toml`, `.ruff.toml`에서 관리한다. 매력적인 방향이지만 “명령이 하나가 됐다”는 사실이 기존 정책과 출력의 동등성을 보장하지는 않는다.

핵심 질문은 속도가 아니다. **현재 도구 조합이 잡던 결함과 허용하던 예외를 Ruff가 같은 의미로 재현하고, 자동 수정과 포맷 변경을 리뷰 가능한 범위로 통제할 수 있는가**가 전환의 기준이다.

2026년 11월 8일 08시 13분 KST 전후 GitHub Trending daily에서 Ruff는 **350 stars today**로 표시됐다. GitHub API 기준 저장소는 50,964 stars, 2,628 forks, issue와 pull request를 합친 open item 2,283개, MIT 라이선스였으며 11월 8일 KST 새벽까지 변경이 이어졌다. 최신 정식 릴리스 `0.17.4`는 11월 6일 KST에 공개됐고 parser panic 수정, lint fix 안전성 조정, formatter 성능 개선과 artifact attestation 검증 안내를 포함한다. 이 수치는 확인 시점의 공개 스냅샷이며 품질이나 도입 적합성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근하지 못했으므로 주제 선정 근거로 사용하지 않았다.

## 후보 비교: 새 기능보다 반복되는 Python 품질 파이프라인의 비용을 골랐다

오늘 Trending 상위권에는 에이전트 스킬과 브라우저 자동화가 많았다. 그러나 이 블로그에는 이미 스킬 공급망, 브라우저 런타임, 에이전트 워크플로 글이 누적돼 있다. Ruff는 단순한 “빠른 Rust 도구” 소개가 아니라 **여러 Python 품질 도구를 하나로 바꿀 때 어떻게 의미 회귀를 막는가**라는 독립적인 검색 의도가 남는다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [astral-sh/ruff](https://github.com/astral-sh/ruff) | daily 350, 50,964 stars, `0.17.4`, MIT | Flake8·isort·Black 통합의 규칙 동등성과 대규모 migration이라는 지속적인 운영 질문이 선명해 선택했다. |
| [meta/astryx](https://github.com/meta/astryx) | daily 185, 14,456 stars, `v0.7.11`, MIT | agent-ready design system은 유효하지만 과거 후보 조사와 디자인 시스템 글에서 중복 위험을 이미 확인했다. |
| [google/skills](https://github.com/google/skills) | daily 449, 23,362 stars, Apache-2.0 | 공식 스킬 배포는 Android Skills·에이전트 지침 표준화 주제와 검색 의도가 가깝다. |
| [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | daily 180, 46,785 stars, `v0.41.2` | 브라우저 자동화 CLI는 Lightpanda·computer-use 평가·브라우저 보안 클러스터와 경쟁한다. |
| [mbillow/localthings](https://github.com/mbillow/localthings) | daily 184, 1,044 stars, MIT | 로컬 가전 제어는 흥미롭지만 Home Assistant 로컬 우선 운영 글과 중심 논지가 인접한다. |

[Rust 웹 툴체인 글](/posts/github-trending-swc-rust-web-toolchain/)에서 빠른 구현체의 가치는 빌드 단계별 병목을 분리해서 측정할 때만 드러났다. Ruff도 같다. 기존 도구의 총 실행 시간만 재고 한 번에 교체하면 속도는 좋아져도 rule coverage, formatter diff, suppression 의미가 바뀐 사실을 늦게 발견할 수 있다.

## 먼저 도구 목록이 아니라 정책 목록을 만든다

마이그레이션 전에는 현재 CI 명령과 설정을 그대로 보존한 baseline이 필요하다. `flake8`, `black --check`, `isort --check-only`, `pyupgrade`, 별도 플러그인과 사내 스크립트를 나열하는 것만으로는 부족하다. 각 단계가 실제로 무엇을 강제하는지 정책 단위로 바꿔 적어야 한다.

- 활성화한 Flake8 코드와 plugin별 규칙
- project-wide ignore, per-file ignore, inline `noqa`
- Python target version과 `src`·namespace package 해석
- Black line length, preview 사용 여부, target version
- isort profile, section, known first-party, 강제 줄바꿈 옵션
- 생성 코드, migration, notebook, test fixture의 제외 범위
- 자동 수정 허용 규칙과 사람 리뷰가 필요한 규칙
- 로컬 hook, IDE, CI에서 실제 실행하는 버전과 명령

이 목록은 설정 파일을 옮기기 위한 체크리스트가 아니라 **현재 팀이 암묵적으로 운영하는 코드 품질 계약**이다. 예를 들어 Flake8 설정에 `B`, `I`, `UP`가 보인다고 해당 그룹 전체를 Ruff에서 켜면 안 된다. 기존 plugin 버전과 Ruff의 자체 구현 시점이 다를 수 있고, 같은 rule code라도 edge case와 fix 제공 여부가 다를 수 있다.

![기존 Python 품질 도구를 정책 원장과 Ruff 실행 계층으로 전환하는 아키텍처](https://heracles-jo.github.io/assets/img/posts/ruff-python-lint-format-migration/architecture.svg)

규칙 원장은 최소한 `기존 도구·코드`, `Ruff 대응 코드`, `현재 위반 수`, `의도적 예외`, `fix 안전성`, `담당자`를 가진다. 대응 규칙이 없는 사내 검사나 plugin은 Ruff 밖에 남겨도 된다. 통합의 목표는 명령 수를 1로 만드는 것이 아니라, 중복 파싱과 상충 설정을 줄이면서 필요한 검사를 잃지 않는 것이다.

## `ALL`보다 작은 명시적 rule set이 안전하다

Ruff 공식 linter 문서는 `select`로 규칙 집합을 명시하고, `ALL`은 업그레이드 때 새 규칙까지 암묵적으로 활성화하므로 신중히 쓰라고 권한다. 기존 저장소에서는 `E`, `F` 같은 작은 기반에서 시작하고 `B`, `UP`, `SIM`, `I` 등을 그룹별로 추가하는 편이 낫다. 신규 규칙을 켤 때는 코드 수정량보다 진단의 품질을 먼저 본다.

한 번에 수천 건을 활성화한 뒤 baseline 파일로 모두 숨기면 전환은 빨라 보인다. 하지만 baseline이 영구 예외 저장소가 되면 새 코드에만 엄격하고 기존 핵심 모듈에는 결함이 남는 이중 정책이 생긴다. 반대로 모든 위반을 한 PR에서 고치면 blame, backport, 리뷰가 어려워진다. 현실적인 순서는 다음과 같다.

1. 현재 도구와 Ruff를 같은 commit에서 병렬 실행한다.
2. 기존 규칙과 의미가 같은 진단부터 CI 필수 조건으로 승격한다.
3. 새 규칙은 영역별 violation 수와 오탐률을 측정한다.
4. baseline을 쓰더라도 파일·규칙·만료 조건을 기록한다.
5. 수정 PR은 import, syntax modernization, bug-risk rule처럼 의미가 다른 변경을 분리한다.

[Open Code Review 글](/posts/open-code-review-hybrid-ai-code-review/)에서 결정론적 정적 분석과 LLM 판단을 분리했듯, Ruff 전환에서도 “기계적으로 비교 가능한 규칙 동등성”과 “팀이 새 정책으로 채택할 규칙”을 같은 승인으로 묶지 않는 편이 좋다.

## 자동 수정은 safe라는 라벨만 믿지 않는다

Ruff는 fix를 safe와 unsafe로 나눈다. 기본 `--fix`는 safe fix를 적용하고, 의미 변경 가능성이 있는 수정은 `--unsafe-fixes`를 별도로 요구한다. 이 구분은 좋은 안전장치지만 조직의 테스트와 리뷰를 대신하지 않는다. safe는 도구가 의도한 일반적 의미 보존 분류이지, 애플리케이션의 동적 import, plugin discovery, reflection, 예외 타입 의존까지 안다는 뜻이 아니다.

특히 다음 변경은 별도 batch와 회귀 테스트가 필요하다.

- 미사용으로 보이지만 import side effect가 있는 모듈 제거
- `__init__.py`의 re-export와 public API 정리
- typing 문법 현대화가 runtime annotation 평가에 미치는 영향
- 예외, iterator, truthiness 표현을 바꾸는 성능·단순화 fix
- notebook cell과 문서 code block 자동 수정
- `noqa` 정리로 인해 다시 노출되는 이전 진단

`0.17.4`가 `G004` fix에서 동작 변경과 syntax error를 피하도록 수정하고, 이후 관련 fix를 unsafe로 표시한 최근 commit은 fix 분류도 릴리스 과정에서 조정될 수 있음을 보여 준다. 자동 수정은 버전을 고정하고, `ruff check --diff` 또는 전용 branch에서 결과를 검토한 뒤, unit·integration·type test를 통과시켜야 한다.

[Modern Go Guidelines 글](/posts/modern-go-guidelines-ai-code-modernization/)에서 언어 현대화 규칙보다 compiler와 test가 최종 판정을 맡아야 한다고 본 이유와 같다. lint fix는 변경 후보를 빠르게 만들지만, 의미 보존의 증거는 저장소 테스트가 제공한다.

## Black 호환은 동일 출력과 같은 말이 아니다

Ruff formatter는 Black-formatted 대형 프로젝트에서 99.9%가 넘는 line이 동일하다고 설명하지만, 공식 문서는 알려진 deviation이 있으며 Black과 계속 번갈아 사용하는 방식을 권하지 않는다. 0.1% 차이도 수십만 줄 저장소에서는 큰 diff가 될 수 있고, comment 이동이나 implicit string 처리처럼 의미 검토가 필요한 사례가 남는다.

formatter 전환은 세 개의 commit으로 나누는 편이 추적하기 쉽다.

1. 설정과 CI를 추가하되 아직 파일을 바꾸지 않는 commit
2. formatter만 실행한 기계적 reformat commit
3. lint fix와 정책 변경 commit

reformat commit에는 기능 변경을 섞지 않고, generated code와 vendor directory를 제외하며, formatter 전후 AST 또는 compile 결과와 test를 비교한다. 현재 Black의 preview style을 사용한다면 Ruff의 stable·preview 동작 중 무엇이 대응하는지 corpus에서 확인해야 한다. `line-length = 88`이 같아도 quote, magic trailing comma, docstring code format, pragma 처리, import formatting 설정이 다르면 결과는 달라질 수 있다.

또한 formatter와 충돌하는 lint rule을 함께 켜면 반복 실행 때 diff가 생길 수 있다. 공식 문서는 `W191`, 일부 `E`·`D`·`Q`, `COM812`, `COM819` 등 formatter와 충돌 가능한 규칙과 isort 설정을 명시한다. `ruff format` 경고가 없는지 확인하고, `ruff format` → `ruff check --fix` → `ruff format --check`를 두 번 반복해 두 번째 실행이 깨끗한지 보는 idempotency test가 유용하다.

## 모노레포에서는 가장 가까운 설정 하나만 적용된다는 점이 중요하다

Ruff는 파일별로 디렉터리 계층에서 가장 가까운 설정을 사용한다. 부모 설정을 자동 병합하지 않고, 상속이 필요하면 `extend`를 명시한다. ESLint식 cascade를 기대하거나 root `pyproject.toml`과 package별 설정이 합쳐진다고 생각하면 package마다 규칙이 조용히 사라질 수 있다.

모노레포에서는 대표 파일마다 `ruff check --show-settings` 결과를 저장해 다음을 검증한다.

- root와 package별 `target-version`
- `src`와 first-party import 분류
- test·migration·generated file의 per-file ignore
- notebook·Markdown 포함 여부
- CLI `--config` 사용 시 상대 경로 기준
- pre-commit이 직접 전달한 excluded file을 `force-exclude`가 막는지

설정 경로는 실행 위치에도 영향을 받을 수 있다. 개발자가 package directory에서 실행할 때와 CI가 repository root에서 실행할 때 같은 파일에 동일 설정이 적용되는지 fixture로 고정해야 한다. [scriptc TypeScript 컴파일 글](/posts/scriptc-typescript-native-compiler/)에서 언어 표면과 runtime 동등성을 분리했듯, 품질 도구도 config discovery와 실제 진단 결과를 별도 계약으로 다뤄야 한다.

## 빠른 CI는 gate 순서를 바꿀 기회를 준다

Ruff의 속도 이점은 단순 runner minute 절감보다 피드백 위치를 앞당기는 데 있다. 전체 test 뒤에 있던 lint를 pre-commit과 PR 첫 단계로 옮기면 개발자는 수 분 뒤가 아니라 수 초 안에 실패를 본다. 다만 캐시가 빠르다는 이유로 측정을 섞으면 안 된다.

PoC에서는 cold·warm 실행을 분리하고 다음 값을 기록한다.

- 전체 저장소와 변경 파일 기준 p50·p95 시간
- cache hit·miss와 CI ephemeral runner 차이
- 기존 도구 대비 진단 수, 누락, 신규 진단, 오탐
- formatter 변경 line 수와 수동 검토 시간
- fix 적용 후 test failure와 revert 비율
- 개발자 로컬 hook 실패율과 우회 횟수
- 버전 업그레이드 PR당 rule·format churn

성능은 **동일한 검사 범위와 동일한 성공 판정**에서 비교해야 한다. 기존 Flake8 plugin 일부를 빼고 Ruff가 빨라졌다면 도구 개선이 아니라 coverage 축소다. 반대로 Ruff에서 새 규칙을 대량 활성화한 결과를 기존 최소 설정과 비교하는 것도 공정하지 않다.

## 배포 artifact와 버전 고정도 품질 파이프라인의 일부다

lint·formatter는 모든 개발자의 코드와 CI artifact를 읽고 때로는 자동으로 수정한다. 따라서 단순 개발 의존성보다 공급망 영향이 넓다. `0.17.4` release는 플랫폼별 binary checksum과 GitHub Artifact Attestations 검증 방법을 제공한다. 조직에서는 설치 편의보다 provenance를 기준으로 경로를 정하는 편이 안전하다.

- lockfile 또는 tool manager로 Ruff 버전을 고정한다.
- GitHub Action도 mutable tag만 믿지 말고 조직 정책에 맞게 SHA 또는 승인된 version을 사용한다.
- standalone binary는 checksum과 attestation을 검증해 내부 artifact registry에 승격한다.
- 인터넷이 제한된 runner에서는 검증된 wheel·binary의 mirror와 rollback version을 준비한다.
- preview rule과 preview formatter는 stable 정책과 별도 lane에서 평가한다.

Ruff 저장소는 활발하지만 같은 저장소에서 type checker `ty` 개발도 진행된다. 전체 commit 수를 Ruff linter의 안정성 지표로 그대로 해석하지 말고, 사용하는 crate·rule·release note와 관련 issue를 추적해야 한다. 공개 저장소에 별도 `SECURITY.md`가 확인되지 않았다는 점도 내부 도입자가 패키지 서명, 취약점 공지 경로, 업데이트 SLA를 자체 공급망 정책으로 보완해야 할 이유다.

## 전환은 4단계 gate로 끝내는 편이 안전하다

![Ruff 전환의 기준선 수집, shadow 실행, 자동 수정, CI 승격 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/ruff-python-lint-format-migration/workflow.svg)

| 단계 | 실행 내용 | 통과 기준 | 중단 조건 |
|---|---|---|---|
| 기준선 | 기존 도구 버전·규칙·예외·시간 기록 | 현재 정책을 rule 단위로 설명 가능 | plugin·사내 검사의 대응 관계를 모름 |
| shadow | Ruff를 non-blocking으로 병렬 실행 | 누락·신규 진단을 표본 리뷰하고 분류 | 핵심 결함 누락 또는 package별 설정 불일치 |
| 변환 | formatter와 safe fix를 분리 적용 | idempotent, test 통과, diff가 리뷰 가능 | comment·public API·runtime 의미 회귀 |
| 승격 | local hook·editor·CI를 고정 버전으로 전환 | 동일 commit이 모든 환경에서 같은 결과 | 실행 위치·cache·버전 차이로 결과 변동 |

좋은 전환은 기존 도구를 즉시 삭제하지 않는다. 한두 번의 release cycle 동안 shadow 결과를 보관하고, CI 필수 gate를 Ruff로 옮긴 뒤에도 기존 도구를 비교 lane에서 잠시 유지한다. 차이가 충분히 설명되고 rollback 명령과 설정이 준비됐을 때 의존성과 설정을 제거한다.

Ruff를 도입할 이유는 “Rust라서 빠르다”에 머물지 않는다. 빠른 공통 parser와 단일 설정은 품질 검사를 개발자의 편집 루프 가까이 옮기고, 여러 도구의 중복 설정을 줄일 수 있다. 대신 팀은 toolchain이 분산돼 있을 때 우연히 드러나던 차이를 하나의 정책으로 명시해야 한다.

결정 기준은 세 가지다. **기존 rule coverage를 증명했는가, 자동 수정과 formatter 차이를 기능 변경과 분리했는가, 모노레포·에디터·CI가 같은 설정과 고정 버전을 쓰는가.** 이 세 조건이 충족되면 Ruff 전환은 단순한 속도 최적화가 아니라 Python 코드 품질 계약을 더 짧고 재현 가능한 피드백 루프로 옮기는 작업이 된다.

> 1차 자료: [astral-sh/ruff 저장소와 README](https://github.com/astral-sh/ruff), [0.17.4 릴리스](https://github.com/astral-sh/ruff/releases/tag/0.17.4), [Ruff configuration](https://github.com/astral-sh/ruff/blob/main/docs/configuration.md), [Ruff linter](https://github.com/astral-sh/ruff/blob/main/docs/linter.md), [Ruff formatter](https://github.com/astral-sh/ruff/blob/main/docs/formatter.md), [MIT LICENSE](https://github.com/astral-sh/ruff/blob/main/LICENSE), [최근 commits](https://github.com/astral-sh/ruff/commits/main/), [공개 issues와 pull requests](https://github.com/astral-sh/ruff/issues). Trending·저장소 수치는 2026년 11월 8일 08시 13분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
