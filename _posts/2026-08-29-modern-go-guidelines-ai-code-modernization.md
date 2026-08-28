---
title: "AI가 최신 Go 코드를 쓰게 하는 법: Modern Go Guidelines 검증 기준"
description: "JetBrains Modern Go Guidelines가 Go 버전에 맞는 규칙을 에이전트에 주입하는 구조를 살펴보고, go fix와 함께 안전하게 도입하는 검증 순서를 제시한다."
author: heracles-jo
date: 2026-08-29 07:15:00 +0900
categories: [Developer Tools, AI Infrastructure]
tags: [go-modern-guidelines, golang, ai-coding-agent, code-modernization, go-fix, developer-tools]
image:
  path: https://heracles-jo.github.io/assets/img/posts/modern-go-guidelines-ai-code-modernization/cover.svg
  alt: "Go 버전 탐지와 Modern Go 규칙, 컴파일·테스트 검증을 연결한 AI 코딩 워크플로"
---

AI 코딩 에이전트에게 Go 코드를 맡겼는데 `go.mod`는 Go 1.26을 가리키고 결과는 몇 년 전 관용구로 가득한 경우가 있다. 컴파일은 되지만 `slices.Contains` 대신 수동 검색 루프를 만들고, `sync.WaitGroup.Go` 대신 `Add`와 `Done`을 반복하며, 새 표준 라이브러리가 해결한 문제에 별도 헬퍼를 추가한다. 반대로 최신 문법을 무조건 요구하면 오래된 모듈에서 빌드가 깨진다. 이 문제의 핵심은 모델이 Go를 아느냐가 아니라 **대상 모듈의 언어 버전에 맞는 지식을 실행 직전에 공급하고, 그 조언이 동작을 보존하는지 검증하느냐**다.

2026년 8월 29일 07:25 KST의 GitHub Trending daily 공개 스냅샷에서 [JetBrains/go-modern-guidelines](https://github.com/JetBrains/go-modern-guidelines)는 574 stars today로 표시됐다. 같은 시점 GitHub API에서 저장소는 2,570 stars, 78 forks, 8개의 열린 이슈·PR, Apache-2.0 라이선스를 보였고, 최신 커밋은 8월 19일이었다. 이 수치는 시점에 따라 바뀐다. 순위보다 주목할 신호는 JetBrains가 “최신 Go 사용법”을 긴 정적 프롬프트가 아니라 **Go 버전을 해석하는 CLI와 에이전트 스킬**로 결합했다는 점이다.

이번 실행 환경에서는 Search Console의 검색어·노출·CTR과 Analytics의 유입 데이터에 접근할 수 없었다. 따라서 유입 성과를 봤다고 가정하지 않았다. 기존 글의 제목·설명·저장소·중심 논지를 대조하고 daily·weekly 후보와 1차 자료를 확인했다.

## 후보 5개를 비교한 결과: Go 버전별 코드 생성은 별도 검색 의도다

오늘 후보는 대부분 에이전트 스킬이나 코드 이해에 가까웠다. 그러나 이미 이 블로그에는 범용 [Agent Skills 기반 개발 절차](/posts/github-trending-agent-skills-engineering-workflow/), [코드베이스 기억 계층](/posts/github-trending-codebase-memory-mcp-code-intelligence-layer/), 아키텍처 문서화 글이 있다. 같은 “에이전트가 더 잘 코딩하게 한다”는 문장을 반복하지 않고, 사용자가 실제로 찾을 구체적인 문제를 비교했다.

| 후보 | 공개 신호 스냅샷 | 기존 글과의 중복 | 장기 검색 의도 판단 |
| --- | --- | --- | --- |
| [tt-a1i/archify](https://github.com/tt-a1i/archify) | daily 4,561 stars, weekly 8,530 stars, MIT, v2.15.0 | Architecture as Code 글과 중심 의도가 매우 가까움 | 강한 신호지만 신규 글은 검색 의도 잠식 가능성이 큼 |
| [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) | daily 720 stars, MIT, v2.64.0 | 범용 Agent Skills와 과학 자동화 글에 인접 | 과학 검증이라는 차이는 있으나 범위가 지나치게 넓음 |
| [abhigyanpatwari/GitNexus](https://github.com/abhigyanpatwari/GitNexus) | daily 189 stars, 최근 커밋 지속, PolyForm Noncommercial 표기 | 코드 지식 그래프·MCP 기억 계층과 직접 경쟁 | 라이선스와 실행 구조는 중요하지만 검색 의도 중복이 큼 |
| [calesthio/OpenMontage](https://github.com/calesthio/OpenMontage) | daily 1,144 stars, AGPL-3.0, 열린 이슈·PR 257개 | 영상 생성·편집 자동화 글과 인접 | 창작 파이프라인 의도는 유효하나 기존 클러스터 연결이 약함 |
| [JetBrains/go-modern-guidelines](https://github.com/JetBrains/go-modern-guidelines) | daily 574 stars, Apache-2.0, 최신 커밋 8월 19일 | 범용 스킬 운영과 연결되지만 언어 버전 호환성은 미다룸 | **AI가 최신 Go를 쓰되 빌드를 깨지 않게 하는 법**이라는 독립 의도 |

선택 이유는 제품의 규모가 아니라 질문의 선명도다. Go 팀은 언어 호환성을 유지하면서도 표준 라이브러리와 관용구를 계속 개선한다. 모델 학습 시점과 공개 코드의 빈도 편향 때문에 에이전트는 새 API를 모르거나 알고도 오래된 패턴을 선호할 수 있다. Modern Go Guidelines는 그 간극을 `go.mod` 버전과 연결한다. 다만 공식 자동 변환기인 `go fix`가 이미 있는 상황에서 이 도구의 역할과 신뢰 경계를 구분해야 실제 도입 판단이 가능하다.

![AI 에이전트가 대상 파일에서 Go 버전을 확인하고 버전별 규칙을 조회한 뒤 컴파일과 테스트로 검증하는 흐름](https://heracles-jo.github.io/assets/img/posts/modern-go-guidelines-ai-code-modernization/workflow.svg)

## 구조는 단순하다: 버전 탐지, 규칙 선택, 필요한 설명만 조회

[공식 README](https://github.com/JetBrains/go-modern-guidelines)는 Junie, Claude Code, Codex, Cursor와 `skills.sh` 설치 경로를 제공한다. 실제 스킬 파일은 에이전트가 Go 파일을 쓰거나 수정하기 전에 wrapper의 `list --file-path path/to/file.go`를 호출하도록 요구한다. CLI는 파일에서 위쪽으로 `go.mod` 또는 `go.work`를 찾고, 명시된 Go 버전 이하에서 사용할 수 있는 지침만 최신순으로 반환한다. 특정 규칙이 적용되는지 애매할 때만 `explain <guideline-id>`로 상세 설명과 before/after 예제를 요청한다.

이 설계에는 실무적으로 좋은 제약이 세 가지 있다.

첫째, “최신 Go”를 하나의 고정 버전으로 취급하지 않는다. 모노레포나 workspace에서는 모듈마다 `go` 지시문이 다를 수 있다. 파일 경로를 넘기면 에이전트가 지금 수정하는 모듈의 언어 버전에 맞춰 판단할 수 있다. Go 1.21 모듈에 Go 1.26의 `new(expression)`을 넣거나, Go 1.24 모듈에 Go 1.25의 `WaitGroup.Go`를 넣는 실수를 줄이는 방향이다.

둘째, 전체 설명을 매번 프롬프트에 밀어 넣지 않는다. `list`는 규칙 ID와 짧은 설명만 주고, `explain`은 실제로 검토할 항목에만 호출한다. 이는 [토큰 절감형 개발 도구](/posts/github-trending-token-economy-devtools/)에서 다룬 것처럼 검색 범위를 먼저 좁히고 필요한 증거만 가져오는 방식이다. 긴 규칙집을 항상 컨텍스트에 넣는 것보다 토큰 비용과 지침 충돌을 줄일 수 있다.

셋째, 규칙 데이터와 실행 코드가 같은 버전의 CLI에 들어간다. 현재 wrapper의 `VERSION`은 `v0.1.1`이고, 첫 실행에 `go install github.com/JetBrains/go-modern-guidelines@v0.1.1`로 바이너리를 사용자 캐시에 설치한다. 설치 후 바이너리의 `--version`을 확인해 요청 버전과 다르면 중단한다. `GOWORK=off`, `CGO_ENABLED=0`, 별도 `GOBIN`을 사용해 프로젝트 workspace와 설치 위치의 영향을 줄인 점도 확인할 수 있다.

하지만 이것은 체크섬이 고정된 사전 빌드 바이너리를 검증하는 구조는 아니다. 첫 실행은 네트워크와 Go 모듈 공급망에 의존하며, 사용자 홈의 캐시에 실행 파일을 만든다. 조직에서는 프록시·모듈 미러, egress, 캐시 권한, 버전 업데이트 승인, 설치 로그를 통제해야 한다. “JetBrains 공식 저장소”라는 출처 신호와 “우리 빌드 환경에서 재현 가능하고 승인된 실행물”은 같은 말이 아니다.

## `go fix`와 경쟁하지 말고 역할을 나눠야 한다

Go 팀의 [Using go fix to modernize Go code](https://go.dev/blog/gofix) 문서에 따르면 Go 1.26에서 `go fix`가 새 분석기 기반으로 다시 작성됐다. `go fix -diff ./...`로 변경을 미리 보고, clean Git 상태에서 적용하며, 새 Go toolchain으로 올릴 때 실행하는 흐름을 공식적으로 권한다. `any`, `forvar`, `mapsloop`, `minmax`, `stringscutprefix`, `waitgroup` 등 기계적으로 식별 가능한 현대화는 컴파일러·타입 정보와 결합된 공식 도구가 더 강한 기준점이다.

두 도구의 질문은 다르다.

| 계층 | 답하는 질문 | 강점 | 놓치기 쉬운 부분 |
| --- | --- | --- | --- |
| Go release notes | 이 버전에 무엇이 추가·변경됐나 | 언어와 표준 라이브러리의 공식 사실 | 팀 코드에서 적용할 위치를 직접 찾지 않음 |
| `go fix -diff` | 기존 코드 중 안전하게 자동 변환할 후보는 무엇인가 | 분석기·타입 정보 기반, diff로 검토 가능 | 아직 생성하지 않은 코드의 선택을 미리 안내하지 않음 |
| Modern Go Guidelines | 에이전트가 새 코드를 쓸 때 어떤 현대적 선택을 고려할까 | 생성 전에 버전별 지식을 제공, 여러 에이전트에 이식 가능 | 자연어 규칙과 예제가 완전한 의미 보존을 보장하지 않음 |
| CI·테스트·벤치마크 | 변경이 실제 계약과 성능을 지키는가 | 저장소 고유의 실행 증거 | 테스트하지 않은 경로는 보장하지 못함 |

따라서 권장 순서는 “스킬을 설치했으니 `go fix`가 필요 없다”가 아니다. 기존 저장소를 새 Go 버전으로 올릴 때는 먼저 clean branch에서 `go fix -diff ./...`의 공식 변환 후보를 검토한다. 그 다음 Modern Go Guidelines를 새 코드 생성과 리뷰의 힌트로 사용한다. 마지막 판단은 `go test`, 정적 분석, race test, 벤치마크와 사람 리뷰가 맡는다. 스킬은 생성 시점의 기억을 보완하지만 컴파일러가 아니다.

## 가장 중요한 실패 모드: 현대화가 의미 보존과 같지는 않다

이 저장소를 무조건적인 “source of truth”로 취급하기 어려운 이유는 공개 이슈 자체가 보여준다. 8월 26일 열린 [이슈 #14](https://github.com/JetBrains/go-modern-guidelines/issues/14)는 여섯 예제의 before/after가 특정 입력에서 서로 다른 결과를 낸다고 보고한다. 예를 들어 `maps.Clone`은 nil map을 nil로 보존하지만 `make` 후 복사한 map은 쓰기 가능하다. `slices.Clone`과 `append([]T(nil), values...)`는 빈 non-nil slice에서 nil 여부가 달라 JSON 표현까지 바뀔 수 있다. `min`이나 `slices.Max`는 부동소수점 NaN 처리에서 수동 비교와 결과가 달라질 수 있다. `context.AfterFunc` 등록 직후 `defer stop()`을 넣으면 함수가 먼저 반환된 뒤 취소되는 경우 cleanup이 실행되지 않을 수 있다.

이 보고는 “현대 API가 나쁘다”는 뜻이 아니다. 더 짧고 표준적인 표현으로 바꾸는 과정에서도 기존 코드가 암묵적으로 의존하던 nil, empty, NaN, lifecycle 계약이 달라질 수 있다는 뜻이다. [AI 코딩 에이전트 과잉 구현을 줄이는 기준](/posts/ai-coding-agent-overengineering-ponytail/)과 같은 원칙이 여기에도 적용된다. 짧은 코드가 항상 작은 의미 변경은 아니다. 에이전트가 `after` 예제를 복사하기 전에 입력 경계와 호출자의 관찰 가능 상태를 확인해야 한다.

같은 이슈는 버전 탐지의 경계도 지적한다. `go` 지시문이 없는 오래된 `go.mod`에서 CLI가 로컬 toolchain으로 fallback하면, Go 명령이 해당 모듈에 적용하는 언어 버전과 다른 최신 규칙을 반환할 수 있다. 또한 인자 없는 `list`는 현재 디렉터리의 `go.mod`가 아니라 로컬 toolchain을 본다. 공식 스킬이 `--file-path` 사용을 우선하므로 정상 경로에서는 위험이 줄지만, 팀 wrapper가 편의상 bare `list`를 쓰면 다시 노출된다.

이 문제는 도입 중단 사유라기보다 검증 설계의 출발점이다. 현재 열린 결함을 추적하고, 버전을 고정하며, 적용 후보를 테스트로 증명할 수 있는 팀만 “자동 규칙”으로 승격해야 한다. 그렇지 않다면 참고 문서 수준으로 사용해야 한다.

![Modern Go 변환에서 버전 불일치, 의미 변경, 공급망 설치, 검증 누락이 실패로 이어지는 위험 지도](https://heracles-jo.github.io/assets/img/posts/modern-go-guidelines-ai-code-modernization/risk-map.svg)

## 팀에 넣을 때는 세 개의 게이트로 제한한다

### 1. 버전 게이트: 파일 경로와 실제 빌드 언어 버전을 함께 기록한다

에이전트는 반드시 수정 대상 `.go` 파일을 `list --file-path`에 넘겨야 한다. 반환된 규칙 목록과 해석된 Go 버전을 작업 로그에 남기고, CI의 toolchain 버전과 `go.mod`의 `go`·`toolchain` 지시문을 구분한다. toolchain이 새롭다고 모듈의 모든 새 언어 기능을 쓸 수 있는 것은 아니다. workspace에 여러 모듈이 있다면 대표 파일 하나가 아니라 변경한 각 모듈을 검사한다.

Go 버전 업그레이드는 별도 PR로 만드는 편이 낫다. `go.mod` 버전 변경, `go fix` 결과, 에이전트가 제안한 관용구 변경, 기능 변경을 한 diff에 섞으면 회귀 원인을 찾기 어렵다. 생성 규칙 업데이트도 의존성 업데이트처럼 changelog와 영향 범위를 검토한다.

### 2. 의미 게이트: 컴파일 성공보다 관찰 가능한 계약을 테스트한다

현대화 후보마다 “더 짧다”가 아니라 보존해야 할 동작을 적는다. collection 변환은 nil과 empty, 순서와 aliasing을 확인한다. float 변환은 NaN과 infinity를 포함한다. context·goroutine 변환은 함수 반환 전후의 취소와 cleanup 시점을 검사한다. error 변환은 wrapping과 `errors.Is`·`errors.As` 동작을 검증한다. JSON은 필드 누락, `null`, 빈 배열의 차이를 golden test로 고정한다.

컴파일과 unit test만으로 부족한 변경도 있다. `strings.SplitSeq`, map·slice helper, 동시성 API처럼 성능을 이유로 선택했다면 기존 구현과 새 구현을 같은 입력 분포로 benchmark한다. 할당 수, 처리량, tail latency를 측정하지 않고 “새 API니까 더 빠르다”고 결론 내리지 않는다. 가독성 개선이 목적이라면 성능 향상 주장을 붙이지 않는다.

### 3. 운영 게이트: 스킬도 코드 공급망으로 취급한다

외부 스킬은 에이전트의 행동을 바꾸고 첫 실행에 도구를 설치한다. [AI 에이전트 위험 명령 차단](/posts/ai-agent-destructive-command-guard/)이 실행 직전 통제점을 강조했듯, 스킬 지침만으로 설치와 명령 실행을 신뢰해서는 안 된다. 조직은 저장소·tag·모듈 checksum을 승인하고, Go proxy 또는 내부 mirror를 사용하며, 자동 업데이트 대신 검증된 버전을 승격해야 한다.

업데이트 때는 규칙 데이터의 diff를 읽는다. 새 guideline ID, `since_version`, before/after 예제, wrapper의 다운로드·설치 경로, 지원 agent manifest를 검토한다. 에이전트에게는 소스 수정 권한과 별개로 tool install 권한을 최소화하고, CI에서는 이미 준비된 승인 바이너리나 재현 가능한 설치 단계로 실행하는 편이 안전하다.

## 2주 PoC에서 측정할 것은 ‘최신 문법 사용량’이 아니다

PoC는 최근 Go 코드 리뷰에서 반복된 구식 패턴 10~20건을 표본으로 잡는다. 한 그룹은 기존 에이전트와 `go fix -diff`만 사용하고, 다른 그룹은 파일 경로 기반 Modern Go Guidelines 조회를 추가한다. 같은 테스트와 리뷰 기준을 적용해 다음 지표를 비교한다.

- **버전 부적합 제안률**: 대상 모듈에서 컴파일할 수 없는 언어 기능·API를 제안한 비율
- **의미 변경 발견률**: nil, empty, NaN, 취소 시점, error wrapping 같은 경계 테스트에서 달라진 후보 수
- **공식 도구 중복률**: 스킬이 제안한 변경 중 `go fix -diff`가 이미 안전하게 제시하는 비율
- **리뷰 리드타임**: 현대화 diff의 근거와 부작용을 확인하는 데 든 사람 시간
- **불필요한 헬퍼 감소**: 표준 라이브러리로 대체되어 신규 유틸리티·의존성이 줄어든 사례
- **성능 증거**: 성능을 근거로 채택한 변경의 benchmark와 allocation 결과
- **규칙 신선도**: 새 Go 릴리스 뒤 승인된 스킬 버전과 팀 기준이 갱신되기까지 걸린 시간

성공 기준은 `slices`나 `cmp` 호출 수가 늘어나는 것이 아니다. 빌드 실패와 의미 회귀 없이 불필요한 구현을 줄이고, 리뷰어가 왜 이 API가 해당 Go 버전과 계약에 맞는지 더 빨리 확인할 수 있어야 한다. 최신 문법을 KPI로 삼으면 에이전트는 멀쩡한 코드를 장식적으로 바꾸게 된다.

## 도입 판단: Go를 자주 올리는 팀에는 유용하지만 자동 승인기는 아니다

Modern Go Guidelines는 여러 AI 코딩 도구를 쓰고, Go 버전 업그레이드가 잦으며, 생성 코드가 오래된 관용구로 돌아가는 팀에 유용하다. 특히 모듈별 Go 버전이 다른 조직에서는 “최신”이라는 모호한 지시를 파일 경로 기반 규칙으로 좁힐 수 있다. Apache-2.0 라이선스, 공개 구현, version-pinned wrapper, 공식 `go fix`와의 개념적 정렬도 긍정적이다.

반대로 Go 코드가 작고 에이전트 사용이 드물거나, 이미 `go fix`, `gopls`, 정적 분석, 강한 리뷰 기준으로 현대화를 충분히 관리한다면 추가 스킬의 운영비가 이익보다 클 수 있다. 규제 환경이나 폐쇄망에서는 첫 실행 설치 경로와 캐시 정책을 먼저 해결해야 한다. 더 중요한 것은 열린 정확성 이슈를 추적할 여력이 없는 팀이 규칙을 자동 적용하게 해서는 안 된다는 점이다.

좋은 기본 흐름은 짧다. **release notes로 사실을 확인하고, `go fix -diff`로 기존 코드의 공식 변환을 찾고, Modern Go Guidelines로 새 코드 생성 시점의 기억을 보완한 뒤, 저장소 테스트와 benchmark로 의미를 증명한다.** 이 순서에서 스킬은 유용한 지식 어댑터다. 그러나 언어 버전, 타입, 런타임 계약을 최종 판정하는 권한은 여전히 Go toolchain과 검증 가능한 테스트에 남겨야 한다.
