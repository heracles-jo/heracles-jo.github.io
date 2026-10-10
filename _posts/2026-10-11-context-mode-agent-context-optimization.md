---
title: "AI 코딩 에이전트 컨텍스트 최적화: Context Mode 검증 기준"
description: "Context Mode의 MCP 샌드박스·FTS5 검색·hook 라우팅을 분해해 토큰 절감 수치의 의미, 코드 실행 보안, 세션 복구와 실무 PoC 기준을 정리한다."
author: heracles-jo
date: 2026-10-11 08:25:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [context-mode, context-engineering, mcp, ai-coding-agent, token-optimization, sandbox]
image:
  path: https://heracles-jo.github.io/assets/img/posts/context-mode-agent-context-optimization/cover.svg
  alt: "대용량 도구 출력을 컨텍스트 밖에서 처리하고 필요한 결과만 AI 코딩 에이전트에 전달하는 구조"
---

AI 코딩 에이전트의 컨텍스트가 빨리 소진되는 원인은 대화가 길어서만이 아니다. 브라우저 접근성 트리, 수백 줄의 테스트 로그, GitHub issue 목록, 빌드 출력처럼 **답에 필요한 정보보다 훨씬 큰 도구 결과**가 매 호출마다 모델 입력으로 들어온다. 파일 50개의 함수 개수를 세는 일조차 모델이 원문을 모두 읽고 계산하면, 정작 설계 판단과 코드 변경에 쓸 문맥이 줄어든다.

[mksglu/context-mode](https://github.com/mksglu/context-mode)는 이 문제를 MCP 도구와 호스트 hook 사이에서 푼다. 큰 원문은 별도 프로세스에서 코드로 집계하거나 SQLite FTS5에 색인하고, 모델에는 집계 결과와 검색된 일부 chunk만 돌려준다. 동시에 파일 변경·Git 작업·오류·사용자 결정을 세션 이벤트로 기록해 compaction 이후 복구하려 한다. 중요한 점은 “컨텍스트를 98% 아낀다”는 숫자 자체가 아니다. **어떤 데이터를 모델에서 숨겨도 되는지, 실행 샌드박스의 권한은 어디까지인지, 압축 뒤 작업 상태를 얼마나 정확히 복구하는지**가 실제 도입 가치를 결정한다.

2026년 10월 11일 08시 32분 KST 전후 GitHub Trending daily에서 Context Mode는 **178 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 26,296 stars, 1,890 forks, 열린 issue와 PR을 합친 340개였고 10월 10일까지 커밋이 이어졌다. `package.json`과 공개 release의 최신 버전은 `1.0.169`였으며 라이선스는 OSI 승인 오픈소스 라이선스가 아닌 **Elastic License 2.0 기반 source-available**이다. 수치와 활동은 확인 당시의 공개 스냅샷이고, README의 절감률은 프로젝트가 제공한 fixture와 측정 방식에서 나온 결과다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근하지 못했으므로 선정 근거로 사용하지 않았다.

## 후보 다섯 개 중 남은 질문은 “도구 출력의 정보 예산”이었다

오늘 daily 상위에는 전날 다룬 REA와 이전에 분석한 Diagram Design이 다시 등장했다. 저장소가 달라도 에이전트 skill이나 세션 메모리 일반론을 반복하면 검색 의도가 겹친다. Context Mode는 최근 [claude-mem 글](/posts/claude-mem-agent-session-memory/)과 인접하지만, 영속 기억보다 **현재 세션에 들어오는 원문을 어디서 계산하고 얼마나 돌려줄 것인가**에 초점이 있다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [mksglu/context-mode](https://github.com/mksglu/context-mode) | daily 178, API 26,296 stars, ELv2, v1.0.169 | 대용량 tool output의 격리 처리와 검색적 공개라는 독립된 운영 질문이 남는다. |
| [hugohe3/ppt-master](https://github.com/hugohe3/ppt-master) | daily 515, 59,398 stars, MIT | native PowerPoint 생성은 실용적이지만 현재 사이트의 에이전트 인프라·보안 클러스터와 연결성이 낮다. |
| [storytold/artcraft](https://github.com/storytold/artcraft) | daily 3,217, 14,391 stars, Apache-2.0 | 창작 엔진의 장기 가치는 있으나 3D·미디어 제작 검색 의도는 최근 핵심 클러스터에서 벗어난다. |
| [boykopovar/AnyPS5](https://github.com/boykopovar/AnyPS5) | daily 5,831, 26,688 stars, GPL-2.0 | 플랫폼 실행 파일 변환은 권리·재배포·호환성 경계가 커서 일반 개발 조직의 적용 범위가 좁다. |
| [mattpocock/skills](https://github.com/mattpocock/skills) | daily 1,737, 284,417 stars, MIT | 에이전트 skill 모음은 기존 skill 공급망·표준화 글과 중심 논지가 겹친다. |

Context Mode를 [코드베이스 기억 계층 글](/posts/github-trending-codebase-memory-mcp-code-intelligence-layer/)과도 구분해야 한다. 코드베이스 지식 그래프는 소스 구조를 재사용하는 장기 색인이고, Context Mode는 로그·웹 응답·도구 결과를 모델에게 전부 보여주지 않고 계산하는 **I/O 경로 최적화**가 중심이다. 둘은 함께 쓸 수 있지만 성능 지표와 실패 모드는 다르다.

## 컨텍스트 절감은 삭제가 아니라 계산 위치를 옮기는 일이다

공식 구현은 크게 세 경로로 나뉜다. `ctx_execute`와 `ctx_execute_file`은 JavaScript·Python·shell 같은 코드를 별도 프로세스에서 실행해 원문을 집계한다. `ctx_index`와 `ctx_search`는 문서와 결과를 chunk로 나눠 SQLite FTS5에 저장한 뒤 BM25 검색으로 필요한 조각만 반환한다. 100KB를 넘는 큰 출력은 자동 색인하고 pointer를 돌려주는 경로도 있다.

![Context Mode가 원시 도구 출력을 실행·색인 계층에서 줄여 모델 컨텍스트로 전달하는 아키텍처](https://heracles-jo.github.io/assets/img/posts/context-mode-agent-context-optimization/architecture.svg)

이 설계의 핵심은 요약 모델을 한 번 더 호출하는 것이 아니라 **질문을 계산으로 바꾸는 것**이다. 테스트 로그 5만 줄에서 실패 suite와 첫 stack trace가 필요하다면 모델이 5만 줄을 읽을 이유가 없다. 스크립트가 exit code별 개수, 반복 오류 signature, 최초 실패 지점을 계산하고 수십 줄만 반환하면 된다. 반대로 API 문서의 정확한 코드 예제가 필요하면 요약보다 색인 후 원문 chunk 검색이 적합하다.

따라서 “작게 돌려준다”는 하나의 규칙으로는 부족하다.

- **집계 가능한 데이터**: 로그, CSV, 테스트 결과, Git history는 코드로 count·group·sort한다.
- **정확한 원문이 필요한 데이터**: API signature, 설정 예제, 정책 문장은 색인 후 좁게 검색한다.
- **전체 구조가 필요한 데이터**: architecture 문서나 짧은 핵심 파일은 그대로 읽는 편이 왜곡이 적다.
- **행동 근거가 되는 데이터**: patch 대상 코드와 오류 주변 문맥은 최종 변경 전에 원문으로 재확인한다.

잘못 적용하면 절감률은 높지만 답은 나빠진다. 예를 들어 컴파일 오류를 파일별 개수로만 집계하면 가장 중요한 generic type mismatch의 구체적 타입을 잃는다. 보안 로그를 status code별로만 세면 낮은 빈도의 인증 우회 패턴을 숨길 수 있다. 정보 예산은 byte 수가 아니라 **의사결정에 필요한 증거의 최소 단위**로 잡아야 한다.

## 98%는 제품 보증이 아니라 특정 측정의 결과다

공식 `BENCHMARK.md`는 21개 scenario에서 총 376KB를 처리하고 모델 컨텍스트에는 16.5KB를 전달해 전체 96% 절감을 보고한다. 그중 로그·테스트·브라우저 snapshot 같은 구조화 데이터 집계는 315KB를 5.5KB로 줄여 98% 절감을 기록했고, 정확한 chunk를 돌려주는 FTS5 검색은 60.3KB를 11KB로 줄여 82% 절감이었다. 같은 문서에서도 작은 network request는 13% 절감에 그친다.

이 수치는 방향을 설명하는 데는 유용하지만 세 가지 이유로 그대로 비용 예측에 쓰면 안 된다.

첫째, byte 절감과 token 절감은 같지 않다. JSON key 반복, 코드, 한국어 문장, stack trace는 tokenizer 비용이 다르다. 둘째, 원문을 숨긴 뒤 잘못된 집계 때문에 재호출하면 전체 비용은 늘 수 있다. 셋째, Context Mode 자체의 tool call, 검색 결과, hook 지시문, session event와 SQLite I/O도 비용과 지연을 만든다.

PoC에서는 `without`과 `with`를 같은 작업·모델·repository SHA로 비교해야 한다. 입력 token만 보지 말고 첫 유효 patch까지의 시간, 추가 검색 횟수, 잘못된 파일 수정, 테스트 재실행, 사람이 원문을 다시 열어야 했던 횟수를 함께 측정한다. 절감률이 높아도 acceptance test 통과율이나 조사 재현성이 떨어지면 최적화가 아니라 관측 손실이다.

## 이름이 sandbox여도 OS 격리는 별도 문제다

Context Mode README는 `ctx_execute` 계열을 sandbox 도구라고 부른다. 여기서 sandbox의 주된 의미는 **대량 출력이 모델 컨텍스트에 직접 들어오지 않는 별도 실행 경로**에 가깝다. 공식 보안 설명도 `ctx_execute`와 `ctx_batch_execute`가 임의 코드를 실행하며 process의 파일시스템 접근 권한을 상속하므로, 실행 승인은 arbitrary code 실행 승인으로 다뤄야 한다고 밝힌다.

프로젝트 경계 방어는 도구마다 다르다. `ctx_execute_file`은 대상 path의 realpath를 검사해 workspace 밖의 절대 경로, `../` traversal, 외부를 가리키는 symlink를 기본 차단한다. 그러나 일반 `ctx_execute`는 코드가 직접 파일 API나 subprocess를 사용할 수 있어 같은 수준의 파일 경계가 아니다. 기존 Claude Code 형식의 `permissions.allow`, `deny`, `ask`를 읽고 shell chain을 나눠 `sudo` 같은 패턴을 검사하지만, 이것도 container·VM·macOS sandbox 같은 커널 격리를 대신하지 않는다.

`ctx_fetch_and_index`에는 scheme과 IP 검사가 있다. cloud metadata와 link-local, multicast, 일부 reserved range는 차단하지만 local 개발을 위해 loopback과 RFC1918 주소는 기본 허용한다. 공유 CI나 hosted service처럼 내부망 접근 자체가 위험한 환경에서는 `CTX_FETCH_STRICT=1` 같은 엄격 모드를 켜야 한다. URL fetch가 가능한 에이전트에서 이 설정 차이는 곧 SSRF 경계 차이다.

[OpenShell 정책 런타임 글](/posts/openshell-agent-policy-runtime/)에서 다룬 것처럼 실행 격리는 도구 이름이 아니라 kernel, filesystem, network, credential 경계로 검증해야 한다. Context Mode를 민감 저장소에 붙일 때는 최소한 read-only workspace 복제본, 비밀 없는 환경 변수, outbound allowlist, process·CPU·시간 제한을 별도 runner에서 강제하는 편이 안전하다.

## 세션 복구는 압축 손실을 줄이지만 새로운 상태 저장소를 만든다

Context Mode는 큰 출력만 줄이는 도구가 아니다. hook이 파일 읽기·수정, task, 사용자 결정, Git 작업, 오류와 해결 과정을 SQLite에 구조화하고, compaction 직전 약 2KB 우선순위 snapshot을 만든다. 이후 `SessionStart`에서 핵심 상태를 복구하고 세부 내용은 FTS5 검색으로 찾는 구조다. 모든 호스트가 같은 hook을 제공하지 않으므로 지원 수준도 다르다.

이 기능은 최근 claude-mem 글의 장기 기억과 일부 겹치지만 데이터 수명과 목적이 다르다. Context Mode의 기본 목표는 현재 작업이 compaction을 건너 계속되도록 하는 것이고, 새 세션을 깨끗하게 시작하면 이전 session data를 지우는 경로를 강조한다. 그래도 SQLite에는 사용자 prompt, 파일 경로, Git 작업, 오류, 외부 reference가 남을 수 있다. tool input의 token·password·cookie류를 정규식으로 redaction하지만 모든 조직 비밀과 개인정보를 알아내는 DLP는 아니다.

또한 상태 저장소는 동시성 문제를 만든다. 프로젝트의 ADR은 여러 에이전트 창이 같은 SQLite DB를 열 수 있도록 WAL과 bounded retry를 택했고, 과거 exclusive lock 접근이 정상적인 multi-window 사용을 막아 되돌린 과정을 기록한다. 이 결정은 합리적이지만 process가 비정상 종료되거나 writer가 누적될 때 WAL growth, `SQLITE_BUSY`, stale session attribution을 관측해야 한다는 뜻이기도 하다.

운영자는 다음 상태를 분리해 봐야 한다.

1. host hook이 사건을 실제로 발생시켰는가.
2. session DB에 어느 project·worktree·session ID로 기록됐는가.
3. compaction snapshot에 어떤 우선순위로 포함됐는가.
4. 복구된 내용이 현재 branch와 repository SHA에서 아직 유효한가.
5. purge가 session DB, FTS5 chunk, WAL·SHM sidecar까지 제거했는가.

“작업을 기억했다”보다 **틀린 작업 상태를 자신 있게 복구하지 않았는가**가 더 중요하다. 다른 branch의 미완료 task나 이전 사용자의 prompt가 현재 세션에 섞이면 편의 기능이 코드 오염 경로가 된다.

## 라이선스는 팀 도입과 서비스화에서 갈린다

GitHub API가 라이선스를 `NOASSERTION`으로 표시하지만 저장소의 `LICENSE`와 `package.json`은 Elastic License 2.0을 명시한다. 소스를 보고 수정·배포할 수 있어도, 소프트웨어의 상당한 기능을 제3자에게 hosted 또는 managed service로 제공하는 것은 제한된다. 라이선스 고지 제거와 license key 기능 우회도 금지된다.

개발자가 로컬 플러그인으로 쓰는 것과 회사가 이를 감싼 멀티테넌트 “에이전트 컨텍스트 최적화 서비스”를 판매하는 것은 전혀 다른 판단이다. 내부 플랫폼도 외부 고객·계열사·파트너에게 기능을 제공한다면 법무 검토가 필요하다. “GitHub에 소스가 있다”를 “제약 없는 오픈소스”와 동일시하면 안 된다.

## 2주 PoC는 절감률보다 정보 손실과 권한 확대를 측정한다

![Context Mode PoC에서 정보 보존·보안·복구·비용을 순서대로 판단하는 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/context-mode-agent-context-optimization/decision-gates.svg)

작업군은 세 종류로 나누는 편이 좋다. 대규모 테스트 로그와 build output을 읽는 디버깅, 문서·issue·PR을 비교하는 조사, compaction을 여러 번 거치는 중간 규모 리팩터링이다. 각 작업에는 사람이 검증할 수 있는 정답과 acceptance test를 둔다.

1. **실제 token**: provider usage 기준 input·output·cache token을 기록하고 단순 byte 추정과 분리한다.
2. **정보 보존**: 원문에 있던 핵심 오류·제약·코드 예제 중 최종 판단에 남은 비율과 누락 유형을 감사한다.
3. **재조회 비용**: 부족한 요약 때문에 `ctx_search`, 원문 read, tool 재실행이 몇 번 발생했는지 센다.
4. **정확성**: 동일한 acceptance test에서 수정 성공률, 오답 patch, 관련 없는 파일 변경을 비교한다.
5. **지연과 안정성**: tool별 p50·p95, subprocess timeout, SQLite busy, hook fail-open을 기록한다.
6. **권한 경계**: workspace 밖 canary file, fake credential, blocked domain, link-local endpoint 접근을 시험한다.
7. **프로젝트 격리**: 이름이 비슷한 두 저장소와 worktree에서 session·FTS5 검색 결과가 섞이지 않는지 확인한다.
8. **복구 정확도**: compaction 전후 task, 수정 파일, 미해결 오류, 사용자 결정을 ground truth와 대조한다.
9. **삭제**: project purge 뒤 DB·WAL·SHM·index·log에서 canary가 다시 검색되지 않는지 검증한다.
10. **라이선스 적합성**: 사용자가 내부 개발자인지 외부 고객인지, managed service에 해당할 여지가 있는지 확인한다.

확대 조건은 “98%에 가까웠다”가 아니다. 보안 canary 접근과 프로젝트 간 혼입은 0건이어야 하고, 핵심 오류와 코드 근거가 보존돼야 하며, 비용 절감이 재조회와 실패 수정 비용을 포함해도 남아야 한다. hook이나 DB가 실패하면 원래 도구 경로로 돌아가되 degraded 상태를 사용자가 알 수 있어야 한다.

Context Mode가 보여 주는 중요한 방향은 모델에게 더 큰 창만 제공하는 대신 **도구 I/O를 설계 대상으로 다루는 것**이다. 로그는 계산하고, 문서는 색인하며, 정확한 근거만 검색하고, 작업 상태는 구조화해 복구한다. 이 접근은 컨텍스트 창 크기가 커져도 유효하다. 불필요한 원문은 비용뿐 아니라 중요한 신호를 묻는 잡음이기 때문이다.

다만 최적화 계층이 임의 코드 실행, URL fetch, 영속 session DB, hook 강제 라우팅을 함께 가진 순간 그것은 단순한 토큰 절약 플러그인이 아니다. **에이전트가 무엇을 볼지와 무엇을 실행할지를 중재하는 로컬 제어면**이다. 도입 판단도 절감률 하나가 아니라 정보 손실, 실행 권한, 상태 격리, 삭제 가능성, 라이선스를 함께 통과해야 한다.

> 1차 출처: [Context Mode 저장소와 README](https://github.com/mksglu/context-mode), [Benchmark](https://github.com/mksglu/context-mode/blob/main/BENCHMARK.md), [Security implementation](https://github.com/mksglu/context-mode/blob/main/src/security.ts), [Session DB ADR](https://github.com/mksglu/context-mode/blob/main/docs/adr/0001-sessiondb-multi-writer.md), [Platform support](https://github.com/mksglu/context-mode/blob/main/docs/platform-support.md), [공개 releases](https://github.com/mksglu/context-mode/releases), [최근 commits](https://github.com/mksglu/context-mode/commits/main/), [공개 issues](https://github.com/mksglu/context-mode/issues), [Elastic License 2.0](https://github.com/mksglu/context-mode/blob/main/LICENSE). Trending·저장소 수치는 2026년 10월 11일 08시 32분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
