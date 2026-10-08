---
title: "Claude Code 메모리 플러그인: claude-mem 운영 기준"
description: "claude-mem의 세션 캡처·요약·검색·컨텍스트 주입 구조를 분해하고, 기억 유실·오염·비밀 노출·토큰 비용을 검증하는 도입 기준을 제시한다."
author: heracles-jo
date: 2026-10-09 08:12:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [claude-mem, claude-code, agent-memory, context-engineering, mcp, local-first]
image:
  path: https://heracles-jo.github.io/assets/img/posts/claude-mem-agent-session-memory/cover.svg
  alt: "AI 코딩 에이전트의 세션 활동이 캡처·요약·검색을 거쳐 다음 세션 컨텍스트로 돌아오는 구조"
---

AI 코딩 에이전트가 같은 저장소를 며칠 동안 다루면 반복 비용이 눈에 띄기 시작한다. 어제 결정한 API 경계, 이미 실패한 접근, 수정한 파일과 남은 위험을 새 세션마다 다시 설명해야 한다. 그렇다고 전체 대화와 도구 출력을 매번 프롬프트에 넣으면 컨텍스트가 커지고, 오래된 사실과 비밀정보까지 함께 되살아난다. 필요한 것은 무제한 기록이 아니라 **무엇을 기억으로 승격하고, 언제 검색하며, 어떤 근거와 비용으로 다음 세션에 주입할지 통제하는 계층**이다.

[thedotmack/claude-mem](https://github.com/thedotmack/claude-mem)은 Claude Code를 비롯한 여러 에이전트 호스트의 lifecycle hook에서 prompt와 tool 사용을 포착하고, 관찰 요약을 SQLite와 Chroma에 보관한 뒤 검색 결과를 다음 세션에 공급한다. README가 내세우는 핵심은 세션 간 지속성, progressive disclosure, MCP 검색, 로컬 worker다. 그러나 실무 도입 질문은 “에이전트가 기억하는가”보다 더 까다롭다. **캡처되지 않은 활동을 알아챌 수 있는가, 잘못 요약된 기억을 원문과 대조할 수 있는가, provider와 vector backend로 나가는 데이터를 설명할 수 있는가**가 운영 가능성을 가른다.

2026년 10월 9일 08시 17분 KST 전후 GitHub Trending daily에서 claude-mem은 **662 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 **98,424 stars**, 8,633 forks, 열린 이슈와 PR을 합친 108개, Apache-2.0 라이선스였고 최신 릴리스는 10월 6일의 `v13.34.2`였다. 10월 9일 KST 새벽까지 OpenCode V2 hook 계약과 Chroma 의존성 호환성을 고치는 커밋이 이어졌다. 수치와 활동은 확인 시점의 공개 스냅샷이며 기억 정확도나 프로덕션 적합성을 보증하지 않는다. 이번 실행 환경에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근할 수 없어 선정 근거로 사용하지 않았다.

## 후보 비교에서 남은 검색 의도는 “세션 기억의 운영 신뢰성”이었다

오늘 후보에는 역공학, 콘솔 실행 파일 포팅, 에이전트 skill, 지식 노동 플러그인, 창작 도구가 섞여 있었다. 기존 글은 에이전트 메모리 제품의 데이터 수명주기, 코드베이스 지식 그래프, 런타임 이벤트 원장을 이미 다뤘다. claude-mem을 선택한 이유는 메모리 일반론을 반복하기 위해서가 아니다. **개발 도구의 hook에서 활동을 캡처해 압축하고 다음 세션 prompt에 다시 넣는 경로가 어디서 조용히 실패하는지**라는 별도 검색 의도가 있기 때문이다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | daily 662, 98,424 stars, Apache-2.0, v13.34.2 | 세션 캡처·요약·검색·주입의 신뢰성과 개인정보 경계라는 독립 질문이 있어 선택했다. |
| [morluto/rea](https://github.com/morluto/rea) | daily 7,744, 25,470 stars, MIT, rea-agents 6.0.0 | 에이전트 역공학은 강한 신호지만 도구 권한과 합법적 분석 범위를 함께 다뤄야 하며 전날 후보와도 반복된다. |
| [boykopovar/AnyPS5](https://github.com/boykopovar/AnyPS5) | daily 4,640, 15,451 stars, GPL-2.0, v0.1.1 | 초기 호환 계층과 콘텐츠 권리 경계가 중심이라 일반 개발 조직의 장기 검색 의도가 좁다. |
| [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) | daily 309, 27,499 stars, Apache-2.0 | 플러그인·skill 운영은 기존 agent skill 엔지니어링 및 공급망 글과 가깝다. |
| [storytold/artcraft](https://github.com/storytold/artcraft) | daily 2,510, 7,772 stars, 라이선스 API `NOASSERTION` | 창작 workflow는 가치가 있지만 현재 사이트의 AI 인프라·개발 도구 권위와 연결성이 낮고 라이선스 검토가 더 필요하다. |

[AI 에이전트 메모리 설계 글](/posts/github-trending-ai-memory-supermemory/)은 사용자 프로필·외부 지식·삭제 정책을 제품 컨텍스트 계층에서 비교했다. [코드베이스 기억 계층](/posts/github-trending-codebase-memory-mcp-code-intelligence-layer/)은 AST와 지식 그래프로 저장소 구조를 재사용하는 문제를 다뤘다. claude-mem은 그 사이에서 **에이전트가 실제로 수행한 개발 세션을 관찰하고 압축해 재호출하는 운영 경로**에 초점이 있다.

## hook에서 다음 세션까지, 기억은 네 번 변형된다

공식 architecture는 Claude Code의 lifecycle hook, Bun 기반 CLI 계층, 로컬 worker daemon, SQLite·Chroma 저장소를 분리한다. `SessionStart`는 worker와 컨텍스트 주입을 준비하고, `UserPromptSubmit`은 세션과 semantic injection을 시작한다. `PostToolUse`가 도구 사용을 observation queue로 보내며, stop·session end 단계에서 요약과 drain을 수행한다. 검색은 MCP 도구를 통해 작은 index를 먼저 받고 필요한 observation만 자세히 가져오는 progressive disclosure를 지향한다.

![claude-mem의 hook 캡처부터 다음 세션 컨텍스트 주입까지 이어지는 아키텍처](https://heracles-jo.github.io/assets/img/posts/claude-mem-agent-session-memory/architecture.svg)

이 흐름에는 원문 그대로 보존되는 단일 “기억”이 없다. 첫째, host hook이 사건을 골라낸다. 둘째, worker가 prompt와 tool result를 observation 후보로 묶는다. 셋째, 모델이 이를 제목·서사·사실로 요약한다. 넷째, keyword·vector 검색과 주입 정책이 다음 세션에 보여 줄 일부를 다시 선택한다. 각 단계는 토큰을 줄이지만 동시에 정보를 버린다.

따라서 검색 결과에 observation ID가 있다는 사실만으로 provenance가 충분하지 않다. 최소한 원본 session, host와 project, 발생 시각, tool 이름, 요약을 만든 provider·model, schema version, 원문 또는 안전한 원문 참조, retrieval score와 injection 이유를 연결해야 한다. “지난번에 인증 코드를 수정했다”는 문장이 실제 diff에서 나온 것인지 모델의 과도한 일반화인지 대조할 수 없다면 기억은 근거가 아니라 또 하나의 생성 텍스트가 된다.

[Apache Maka 런타임 이벤트 원장 글](/posts/apache-maka-agent-runtime-event-log/)과의 차이도 여기서 선명해진다. Maka의 중심 질문은 실행 사실을 append-only canonical log로 남기는 방법이다. claude-mem의 observation은 재사용을 위한 손실 있는 기억에 가깝다. 감사·복구가 필요하다면 Git commit, CI artifact, terminal log, runtime event처럼 별도의 기준 증거를 유지하고 메모리는 그 증거를 찾는 index로 사용해야 한다.

## fail-open은 개발 흐름을 지키지만 기억의 완전성을 약속하지 않는다

공식 문서는 worker transport 오류가 나도 Claude Code 세션을 막지 않는 graceful degradation을 설명한다. 개발 도구로서는 합리적이다. 메모리 daemon이 잠시 죽었다고 코드 수정이 중단되면 보조 계층이 주 경로보다 더 큰 장애가 된다. 문제는 사용자가 이 실패를 눈치채지 못할 때다.

공개 이슈에는 provider quota cooldown 중 수집된 observation이 worker 재시작 전에 처리되지 않으면 유실될 수 있다는 보고와, Codex observer의 deadline이 실제 전송 전 queue 대기까지 포함해 작업이 timeout 되는 문제가 올라와 있다. 최근 OpenCode V2 수정도 plugin이 로드됐지만 checkout 경로를 잘못 읽어 observation을 조용히 버리는 실패를 다뤘다. **프로그램이 계속 동작하는 것과 기억이 완전한 것은 별개**다.

운영에서는 세 가지 상태를 분리해 보여 줘야 한다.

- host hook이 사건을 생성했는가
- worker queue가 사건을 durable하게 받아들였는가
- observation과 embedding이 검색 가능한 상태가 됐는가

세션 종료 시 captured, pending, failed, indexed 개수를 남기고, worker 재시작 뒤 processing row를 어떻게 회수하는지 장애 주입으로 확인해야 한다. 일정 시간 동안 observation이 0건이어도 “할 일이 없었다”와 “hook 계약이 바뀌어 캡처가 멈췄다”를 구분하는 canary가 필요하다. 호스트 버전을 올릴 때는 plugin load 성공만 보지 말고 fixture tool call이 정해진 project namespace에 저장되고 다음 세션에서 검색되는지 end-to-end로 시험한다.

## 로컬 저장과 로컬 처리는 같은 약속이 아니다

Security 문서는 SQLite, Chroma, 로그와 설정이 기본적으로 `~/.claude-mem/`에 저장되고 worker가 loopback에 bind하며 telemetry를 수집하지 않는다고 설명한다. 동시에 observation·transcript·prompt는 요약 provider로 전송될 수 있다. 기본 Claude Agent SDK 경로는 Anthropic API를 사용하고, Gemini·OpenRouter·OpenAI-compatible endpoint를 선택하면 같은 문맥이 해당 provider로 나간다. Chroma embedding backend 역시 설정에 따라 원격 API를 호출할 수 있다.

따라서 “데이터가 로컬 DB에 있다”는 문구만으로 데이터 흐름을 승인하면 안 된다. 저장 위치, 요약 실행 위치, embedding 실행 위치, cloud sync 여부를 각각 그려야 한다. `<private>...</private>` tag는 특정 내용을 저장 전에 제외하는 유용한 기능이지만 사용자가 항상 정확한 범위를 표시한다고 기대할 수 없다. tool output에는 `.env`, stack trace의 token, 고객 데이터, source code가 자동으로 섞일 수 있다.

민감한 저장소에서는 provider 전송 전 allowlist 기반 필드 축소, secret scanner, 파일 경로 정책, 최대 payload 크기, binary·lockfile 제외를 적용한다. 로컬 모델을 쓰더라도 worker DB와 viewer는 같은 OS 계정의 다른 프로세스가 읽을 수 있는 자산이다. full-disk encryption, 파일 권한, 백업 범위, endpoint 보안과 사용자별 분리를 함께 봐야 한다. [OpenShell 정책 런타임 글](/posts/openshell-agent-policy-runtime/)에서 설명했듯 자연어 privacy tag는 파일·네트워크 권한을 강제하는 sandbox나 egress policy를 대신하지 못한다.

또 하나의 경계는 라이선스다. 저장소 루트와 공개 core는 Apache-2.0이지만 공식 `ip-boundary.md`는 hosted cloud, team sync, enterprise RBAC·audit UI·DLP·관리형 eval 등을 reserved commercial/private 영역으로 구분한다. “오픈소스 core가 있으니 팀 기능까지 동일하게 자체 운영할 수 있다”고 가정하지 말고 필요한 기능이 공개 구현에 실제 포함되는지 확인해야 한다.

## 압축과 검색은 토큰을 줄이지만 prompt cache를 깨뜨릴 수도 있다

`v13.34.2` 릴리스는 observer conversation의 오래된 tool payload를 매 요청 전에 축약하던 동작을 되돌렸다. 이미 provider에 보낸 앞부분을 다음 요청에서 다시 쓰면 prompt prefix가 달라져 cache를 재사용하지 못한다는 이유다. 원문을 유지하면 generation이 size budget에 더 빨리 도달해 session을 더 자주 재생성할 수 있다. 릴리스는 실제 production 비용 절감을 측정하지 않았다고 명시한다.

이 사례는 메모리 시스템의 비용이 단순한 “주입 토큰 수”가 아님을 보여 준다. 캡처를 요약하는 모델 호출, embedding, vector index, 검색, prompt injection, cache hit 변화, compaction과 generation recycle이 모두 비용에 영향을 준다. observation을 짧게 만들면 정보 손실이 커지고, 길게 유지하면 저장·검색·prompt 비용과 민감정보 면적이 커진다.

PoC에서는 다음을 따로 측정해야 한다.

| 단계 | 최소 측정값 | 위험 신호 |
|---|---|---|
| 캡처 | hook 사건 대비 durable queue 수신율, host별 누락률 | plugin은 로드됐지만 특정 tool·project가 0건 |
| 요약 | 원문 사실 보존율, 잘못된 일반화, provider latency·비용 | 성공·실패나 파일 역할이 뒤집힌 기억 |
| 검색 | recall@k, 오래된 기억 비율, project 간 교차 검색 | 다른 repository의 결정이 현재 세션에 주입 |
| 주입 | 입력 토큰, cache hit, 실제 사용된 기억 비율 | 매 prompt에 많은 기억을 넣지만 답변에는 미사용 |
| 복구 | worker kill·quota·DB lock 뒤 queue 회수율 | 조용한 유실, 중복 observation, 무한 재시도 |
| 삭제 | SQLite·Chroma·log·backup·cloud sync 제거 시간 | 원문 삭제 뒤 embedding이나 요약이 다시 검색됨 |

## 오래된 기억과 프롬프트 인젝션은 다음 세션으로 전파된다

세션 기억은 단발성 RAG보다 오염의 수명이 길다. 악성 README나 issue 내용이 tool output에 섞이고, 모델이 이를 “프로젝트 규칙”으로 요약하면 이후 세션에도 반복 주입될 수 있다. 실제 사용자가 내린 결정과 외부 문서의 지시, 모델이 추론한 가설을 같은 observation type으로 저장하면 신뢰 등급을 잃는다.

기억 schema에는 source class와 권한을 넣는 편이 안전하다. 사용자 명시 결정, Git으로 검증된 코드 사실, 테스트 결과, 외부 비신뢰 문서, 모델 추론을 구분하고 만료 기간과 주입 가능 범위를 다르게 둔다. 보안 경고나 삭제 요청처럼 고위험 변경은 새 기억을 추가하는 것만으로 끝내지 말고 이전 기억을 supersede하거나 검색에서 차단해야 한다.

[PostHog 통합 관측성 글](/posts/posthog-unified-product-observability/)에서 여러 문맥을 한곳에 모을수록 조사 속도와 민감정보 위험이 함께 커진다고 설명했다. 개발 세션 기억도 같다. prompt, source code, shell output, commit, 사용자 행동을 연결하면 유용하지만 그 데이터셋은 원본 저장소보다 더 넓은 맥락을 드러낼 수 있다. viewer·MCP·API key의 접근 범위와 project isolation을 기능 추가 뒤가 아니라 저장 시작 전에 설계해야 한다.

![claude-mem 도입을 확대·보류·중단하는 캡처 완전성·기억 정확성·보안 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/claude-mem-agent-session-memory/risk-gates.svg)

## 2주 PoC는 “기억해서 편했다”를 수치로 바꿔야 한다

대상은 활발한 저장소 하나와 실제 개발 작업 20~30개로 제한한다. 절반은 세션 간 연속성이 필요한 migration·버그 수정·리팩터링으로, 나머지는 기억이 없어도 되는 독립 작업으로 구성한다. stateless baseline과 claude-mem 사용군에 같은 acceptance test를 적용하되 모델·호스트 버전·repository SHA를 고정한다.

1. **재설명 절감**: 새 세션에서 사용자가 반복 입력한 제약과 파일 수, 첫 유효 변경까지 걸린 시간을 비교한다.
2. **정확성**: 주입된 기억 중 현재 SHA와 일치한 비율, stale·contradicted·unsupported 비율을 사람이 표본 감사한다.
3. **완전성**: fixture prompt와 tool call 100건에서 queue·observation·embedding·검색 결과까지 단계별 손실을 센다.
4. **격리**: 이름이 비슷한 두 저장소와 branch를 만들어 서로의 기억이 검색되거나 주입되지 않는지 확인한다.
5. **비밀정보**: canary token을 prompt, file, environment, tool output에 넣고 provider request, SQLite, Chroma, log, viewer, backup에서 추적한다.
6. **장애 복구**: worker process kill, provider 429, network 단절, DB lock, host upgrade를 주입해 유실·중복·복구 시간을 측정한다.
7. **비용**: 작업당 observer·embedding·검색·주입 토큰과 prompt cache hit, p50/p95 hook 지연을 기록한다.
8. **삭제**: project 삭제와 사용자 요청 뒤 모든 online store와 optional sync에서 canary가 정해진 시간 안에 사라지는지 검증한다.

확대 조건은 단순한 만족도가 아니다. project 간 누출과 canary 비밀 전송은 0건이어야 하고, 캡처 손실은 탐지 가능해야 하며, stale 기억이 코드 변경을 유도했을 때 기준 테스트가 이를 차단해야 한다. 메모리 장애가 발생해도 에이전트는 stateless mode로 계속 작업하고 사용자에게 degraded 상태를 알려야 한다.

claude-mem의 장점은 에이전트 기억을 별도 SaaS API 한 번으로 추상화하지 않고, host hook·worker·SQLite·vector search·MCP라는 관찰 가능한 구성 요소로 드러낸다는 데 있다. 여러 host를 지원하고 progressive disclosure로 필요한 기억만 깊게 가져오려는 방향도 현실적이다. 반면 host 계약 변화, 요약 provider, queue 복구, project identity, open-core 경계가 함께 움직이기 때문에 설치 후 잊어도 되는 플러그인은 아니다.

도입 기준은 “어제 일을 기억해 줬다”가 아니라 **기억이 만들어지고 선택되고 폐기되는 전 과정을 운영자가 설명할 수 있는가**다. 원본 증거와 손실 있는 기억을 구분하고, 조용한 누락을 계측하며, provider로 나가는 데이터와 삭제 범위를 검증할 수 있다면 세션 메모리는 재설명 비용을 줄이는 실질적 개발 인프라가 된다. 그렇지 않으면 편리한 자동 주입이 오래된 결정과 민감정보를 다음 세션으로 운반하는 새로운 실패 경로가 된다.

> 1차 출처: [claude-mem 저장소와 README](https://github.com/thedotmack/claude-mem), [Architecture Overview](https://github.com/thedotmack/claude-mem/blob/main/docs/architecture-overview.md), [Security Policy](https://github.com/thedotmack/claude-mem/blob/main/SECURITY.md), [Server Storage Boundary](https://github.com/thedotmack/claude-mem/blob/main/docs/server-storage-boundary.md), [IP Boundary](https://github.com/thedotmack/claude-mem/blob/main/docs/ip-boundary.md), [`v13.34.2` release](https://github.com/thedotmack/claude-mem/releases/tag/v13.34.2), [최근 commits](https://github.com/thedotmack/claude-mem/commits/main/), [공개 issues](https://github.com/thedotmack/claude-mem/issues), [공개 pull requests](https://github.com/thedotmack/claude-mem/pulls). Trending·저장소 수치는 2026년 10월 9일 08시 17분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
