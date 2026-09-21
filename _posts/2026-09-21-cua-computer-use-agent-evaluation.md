---
title: "컴퓨터 사용 에이전트 평가: Cua Bench 운영 기준"
description: "Cua의 격리 데스크톱·크로스 OS 드라이버·검증 가능한 태스크 구조를 바탕으로 GUI 에이전트의 성공률, 재현성, 보안 경계와 PoC 측정 기준을 정리한다."
author: heracles-jo
date: 2026-09-21 08:45:00 +0900
categories: [AI Infrastructure, Testing]
tags: [cua, computer-use-agent, agent-evaluation, gui-automation, benchmark, ai-infrastructure]
image:
  path: https://heracles-jo.github.io/assets/img/posts/cua-computer-use-agent-evaluation/cover.svg
  alt: "컴퓨터 사용 에이전트를 격리된 데스크톱과 검증 가능한 평가 루프로 운영하는 구조"
---

브라우저에서 버튼 하나를 누르는 데모는 만들기 쉽다. 문제는 에이전트가 Windows, macOS, Linux의 실제 애플리케이션을 오가며 파일을 저장하고, 폼을 채우고, 결과를 확인하는 순간부터다. 화면 해상도와 테마가 달라지고, 팝업이 끼어들며, 클릭은 성공했지만 최종 파일은 잘못된 위치에 저장될 수 있다. **컴퓨터 사용 에이전트의 품질은 “클릭을 했는가”가 아니라, 동일한 시작 상태에서 업무 결과를 반복해 만들고 그 과정을 독립적으로 검증할 수 있는가로 평가해야 한다.**

[trycua/cua](https://github.com/trycua/cua)는 이 문제를 단일 GUI 자동화 라이브러리보다 넓게 다룬다. Cua Driver는 여러 운영체제의 앱과 브라우저를 조작하는 표면을 제공하고, Lume과 Sandbox는 로컬 VM·격리 데스크톱 수명주기를 맡으며, Cua Fleets는 병렬 실행 환경을 공급한다. Cua-Bench는 태스크의 시작 상태, 에이전트 인터페이스, 평가기를 분리해 결과를 점수와 trajectory로 남긴다. 최근에는 OSWorld 디스크를 Fleet에서 실행하는 경로와, 제한된 결정을 맡는 CUA-S1 연구 구성도 추가됐다.

2026년 9월 21일 09시 전후 KST 공개 스냅샷에서 Cua는 GitHub Trending daily에 **1,012 stars today**로 표시됐다. GitHub API 기준 저장소는 **25,132 stars**, 1,729 forks, MIT 라이선스였고 9월 20일까지 커밋이 이어졌다. 최신 Sandbox 릴리스 `0.8.0`은 9월 15일 공개됐으며 OSWorld 디스크의 Fleet 실행을 주요 기능으로 포함한다. 수치와 활동 상태는 확인 시점의 값이며, 에이전트 성능이나 서비스 안정성을 보증하지 않는다. 이번 실행 환경에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근하지 못해 주제 선정에 사용하지 않았다.

## 후보 5개를 비교하니 “평가 인프라”가 남았다

오늘 daily·weekly 후보에는 에이전트 스킬과 프레임워크가 많았다. 기존 글의 제목·description·저장소 링크뿐 아니라 중심 논지까지 대조한 결과, 새 기능 소개보다 **GUI 에이전트를 재현 가능하게 시험하는 방법**이 별도 검색 의도로 남았다.

| 후보 | 확인 시점 신호 | 중복·장기 가치 판단 |
|---|---|---|
| [Cua](https://github.com/trycua/cua) | daily 1,012, 25,132 stars, MIT, Sandbox 0.8.0 | 브라우저 자동화 소개가 아니라 크로스 OS 태스크·평가기·격리 실행을 묶는 **컴퓨터 사용 에이전트 평가 운영**에 답할 수 있어 선택했다. |
| [ECC](https://github.com/affaan-m/ECC) | daily 837, weekly 6,265 | 스킬·메모리·보안 하네스는 에이전트 네이티브 소프트웨어와 개발 절차 글의 검색 의도와 겹친다. |
| [agent-native](https://github.com/BuilderIO/agent-native) | daily 89, TypeScript | 에이전트 앱 프레임워크는 장기 가치가 있지만 기존 장기 실행 워크플로·에이전트 아키텍처 클러스터와 인접한다. |
| [security-audit-skill](https://github.com/cloudflare/security-audit-skill) | daily 2,375 | 독립 검증형 보안 감사는 중요하지만 9월 17일 글에서 이미 파이프라인과 증거 구조를 직접 다뤘다. |
| [Higgsfield](https://github.com/higgsfield-ai/higgsfield) | daily 461, 5,364 stars, Apache-2.0 | 대규모 GPU 학습 오케스트레이션은 유효하나 오늘 후보 중 독자가 바로 적용할 독립적 전환 질문은 Cua의 평가 재현성이 더 선명했다. |

전날 글에서는 Cua를 브라우저 자동화·에이전트 보안 클러스터와 겹칠 가능성이 높다고 제외했다. 이번 글은 기능 소개로 돌아가지 않는다. 화면을 조작하는 능력보다 **태스크 정의, 환경 초기화, 결과 평가, trajectory 증거, 병렬 실행의 공정성**을 중심에 둔다. 이 각도는 [Cypress 브라우저 E2E 테스트 거버넌스](/posts/github-trending-cypress-browser-e2e-testing-governance/)와 연결되지만, 고정된 테스트 스크립트가 아니라 불확정적인 에이전트 행동을 평가한다는 점에서 질문이 다르다.

## 점수의 출발점은 모델이 아니라 시작 상태다

Cua-Bench 문서는 태스크를 자연어 지시문 하나가 아니라 반복 가능한 실험으로 정의한다. 하나의 태스크는 prompt, setup, variant, agent interface, evaluator를 함께 가진다. 데이터셋은 여러 태스크와 변형을 묶고, runner는 환경을 할당해 실행 결과와 trajectory, reward를 수집한다.

핵심 흐름은 다음과 같다.

```text
dataset → task → variant → environment session → trajectory → evaluator → reward
```

여기서 중요한 것은 `variant`다. 같은 “스프레드시트에 합계를 입력하라”는 목표라도 초기 데이터, 창 배치, 운영체제 테마, 해상도, 언어, 애플리케이션 버전이 달라질 수 있다. 한 화면에서 성공한 좌표 기반 자동화가 다른 화면에서도 일반화되는지 보려면 입력과 시작 조건을 체계적으로 바꿔야 한다. 반대로 각 실행의 시작 상태가 제각각이면 모델 A와 B의 점수 차이가 모델 때문인지 환경 때문인지 설명할 수 없다.

Cua-Bench는 lifecycle을 configuration, setup, solve, evaluate로 나눈다. `solve`는 정답 클릭 순서를 강요하는 채점기가 아니라 환경이 실제로 성공 상태를 만들 수 있는지 검증하는 oracle이다. `evaluate`는 최종 상태가 목표를 만족했는지를 별도로 판단한다. 이 분리는 중요하다. 사용자가 요청한 PDF가 올바르게 생성됐다면 에이전트가 메뉴를 열었는지 단축키를 썼는지는 부차적이다. 반대로 화면상 성공 메시지만 띄웠지만 파일이 저장되지 않았다면 실패로 처리해야 한다.

![Cua의 태스크·에이전트·격리 데스크톱·평가기 계층](https://heracles-jo.github.io/assets/img/posts/cua-computer-use-agent-evaluation/architecture.svg)

## 데스크톱 실행 계층과 평가 계층을 분리해야 한다

Cua의 구성은 네 층으로 읽을 수 있다. 첫째, **태스크·평가 층**은 Cua-Bench가 맡는다. 둘째, **행동 번역 층**은 agent adapter와 Cua Driver가 모델 출력을 클릭, 키 입력, 스크롤, 앱 상태 조회 같은 명시적 행동으로 바꾼다. 셋째, **컴퓨터 층**은 simulated provider, 로컬 VM, 컨테이너, Fleet의 격리 데스크톱을 제공한다. 넷째, **증거 층**은 screenshot, action argument, before/after state, trajectory와 reward를 보존한다.

이 분리가 없으면 모델 교체와 인프라 교체가 한꺼번에 일어난다. 새 모델을 시험하면서 VM 이미지와 드라이버 버전까지 바꾸면 점수 상승의 원인을 찾을 수 없다. 평가 기간에는 최소한 태스크 버전, 이미지 digest, 앱 버전, 화면 크기, 드라이버·모델 설정, seed와 timeout을 고정해야 한다. 소프트웨어 릴리스에서 test fixture와 실행 이미지를 고정하는 것과 같은 원칙이다.

Cua의 OSWorld Fleet 가이드는 이 운영 비용을 잘 보여 준다. 공식 Ubuntu 디스크에 Driver MCP 서비스를 넣고, OCI `containerDisk`로 게시한 뒤, pool과 claim을 통해 깨끗한 데스크톱을 할당한다. 이미지 준비에는 약 60GB의 여유 공간이 필요하고, OSWorld control server와 MCP·VLC·Chrome CDP 포트를 구분해야 한다. Fleet에는 snapshot revert가 없으므로 반복 평가에서 깨끗한 상태를 얻으려면 새 claim을 사용해야 한다. “VM이 있으니 재현 가능하다”가 아니라 **어떤 이미지와 초기화 절차가 매 실행에 적용됐는가**가 재현성을 결정한다.

[CubeSandbox의 MicroVM 실행 격리](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)에서 다룬 것처럼 격리 런타임은 모델 품질과 다른 책임이다. Cua Fleet의 claim이나 로컬 VM도 자동으로 최소 권한을 보장하지 않는다. 네트워크, 공유 폴더, 클립보드, 호스트 자격증명, MCP endpoint가 열려 있다면 GUI 작업은 곧 데이터 유출 경로가 될 수 있다.

## reward 하나로는 실패 이유를 알 수 없다

최종 성공률은 필요하지만 충분하지 않다. GUI 에이전트는 같은 `0`점 안에서도 전혀 다른 이유로 실패한다.

- **인지 실패**: 대상 요소를 찾지 못하거나 팝업을 본 화면의 일부로 오인한다.
- **행동 실패**: 좌표 변환, 포커스, 더블클릭, 키보드 레이아웃 때문에 올바른 의도를 잘못 실행한다.
- **상태 실패**: 앱은 조작했지만 저장 위치, 파일 형식, 세션 상태가 목표와 다르다.
- **환경 실패**: VM 부팅, 포트 readiness, 앱 시작, 네트워크, evaluator가 깨져 에이전트와 무관하게 실패한다.
- **판정 실패**: 결과는 맞지만 evaluator가 특정 클릭 순서나 취약한 문자열에 과적합돼 실패 처리한다.

따라서 reward와 함께 trajectory를 봐야 한다. Cua Driver는 행동별 전후 상태, screenshot, argument를 기록할 수 있고 Cua-Bench trace는 세션의 observation과 action을 보존한다. 다만 녹화물이 곧 감사 로그라는 뜻은 아니다. 편집된 데모 영상은 대기·재시도를 잘라낼 수 있고, screenshot에는 개인정보와 토큰이 남을 수 있다. [Apache Maka의 런타임 이벤트 로그 설계](/posts/apache-maka-agent-runtime-event-log/)에서 강조했듯 canonical execution fact와 사람이 보기 좋은 projection을 구분해야 한다. 평가용 trajectory에는 원본 action ID, 시각, 환경·태스크 버전, evaluator 결과를 남기고, 공유용 영상은 별도 파생물로 취급하는 편이 안전하다.

![컴퓨터 사용 에이전트 평가와 실패 분류·개선 루프](https://heracles-jo.github.io/assets/img/posts/cua-computer-use-agent-evaluation/evaluation-loop.svg)

## 실패를 줄이려다 벤치마크를 오염시키는 경우

첫 번째 함정은 **평가기 누출**이다. 에이전트가 evaluator 코드, 정답 파일, oracle trajectory에 접근할 수 있으면 실제 업무를 해결하지 않고 채점 기준만 만족시킬 수 있다. 태스크 파일과 비밀 정답을 실행 계정에서 분리하고, evaluator는 agent 종료 후 별도 권한으로 실행해야 한다.

두 번째는 **환경 과적합**이다. 항상 같은 1920×1080 화면, 같은 다크 모드, 같은 창 위치만 쓰면 모델은 업무 의미보다 시각적 위치를 외운다. variant로 테마와 입력을 바꾸되, 난이도 상승과 환경 결함을 구분할 기준선이 필요하다. oracle도 실패하는 variant는 모델 평가에서 빼고 fixture 문제로 분류해야 한다.

세 번째는 **성공률만 높이는 무제한 재시도**다. 에이전트가 같은 버튼을 열 번 누른 뒤 우연히 성공한다면 운영 품질은 낮다. task completion과 함께 action 수, retry 수, wall-clock time, model token, screenshot 수, VM 비용을 측정해야 한다. 외부 API나 이메일 발송처럼 부작용이 있는 업무에서는 재시도가 중복 실행을 만들 수 있으므로 idempotency key와 승인 gate가 필요하다.

네 번째는 **simulated provider와 실제 OS의 혼동**이다. Playwright 기반 simulated task는 빠르고 evaluator를 검증하기 좋지만, 실제 데스크톱의 권한 팝업, IME, 접근성 API 차이, 렌더링 지연, 파일 선택기, 창 관리자 경쟁을 재현하지 않는다. simulated 환경은 태스크 로직 단위 테스트로 쓰고, 대표 OS·앱 조합은 native VM에서 별도 회귀 시험해야 한다. [DeerFlow의 장기 실행 에이전트 워크플로](/posts/github-trending-deer-flow-long-horizon-agent-workflow/)에서 다룬 체크포인트와 중간 검증도 GUI 실행에서는 창 상태와 저장 결과라는 더 구체적인 형태로 필요하다.

## 모델보다 먼저 평가 파이프라인을 PoC하라

2주 PoC라면 화려한 앱 100개보다 업무 결과가 명확한 태스크 20~30개가 낫다. 브라우저 입력, 스프레드시트 편집, 파일 변환, 데스크톱 설정처럼 서로 다른 행동 유형을 포함하되 실제 운영 데이터를 쓰지 않는다.

| 측정 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 결과 품질 | strict success, 부분 reward, variant별 성공률 | oracle이 통과하는 핵심 태스크 성공률이 기준선보다 낮음 |
| 재현성 | 동일 조건 반복 분산, OS·테마·입력 변화 민감도 | 작은 UI 변화에서 성공률이 급락하고 원인을 분류하지 못함 |
| 효율 | action 수, retry, 완료 시간, token·VM 비용 | 성공률 개선보다 실행 시간·비용 증가가 큼 |
| 환경 안정성 | boot·setup·readiness·evaluator 실패율 | 인프라 실패가 전체 run의 2~3%를 넘고 모델 실패와 분리되지 않음 |
| 보안 | egress, secret 접근, 공유 폴더, evaluator 격리 | 태스크 범위 밖 파일·네트워크 접근을 차단하거나 탐지하지 못함 |
| 진단성 | trajectory 완전성, 실패 분류 시간 | 운영자가 15분 안에 모델·환경·평가기 실패를 구분하지 못함 |

실행 순서는 단순해야 한다. 먼저 simulated provider에서 task lifecycle과 evaluator를 검증한다. 다음으로 고정 digest의 native 이미지에서 oracle을 반복 실행해 환경 자체의 안정성을 확인한다. 그 뒤 모델 후보를 동일한 task·variant manifest에 투입하고, 마지막에 제한된 Fleet 병렬 실행으로 throughput과 비용을 측정한다. 병렬 worker 수를 늘리기 전에 reset·step·finish latency를 각각 기록해야 한다. Cua-Bench 자체도 worker benchmark에서 평균 reset time, step time, finish time, steps/sec를 분리한다.

채택 기준도 단일 리더보드 점수가 되어서는 안 된다. 모델 A가 성공률은 높지만 action 수와 비용이 두 배일 수 있고, 모델 B는 빠르지만 OS 변화에 취약할 수 있다. 팀의 실제 업무에서 잘못된 저장·전송의 비용이 높다면 partial reward보다 strict final-state verification과 보수적 중단 능력이 더 중요하다.

## Cua를 도입할 팀과 아직 이른 팀

Cua류 스택은 컴퓨터 사용이 제품 기능인 팀, 여러 모델·OS를 같은 태스크로 비교해야 하는 연구팀, GUI 자동화 실패를 trajectory로 재현해야 하는 플랫폼팀에 적합하다. 특히 사람이 작성한 고정 스크립트가 아니라 모델이 다음 행동을 선택하고, 그 선택을 학습 데이터나 회귀 평가로 다시 써야 한다면 task·provider·evaluator 분리가 가치가 있다.

반대로 내부 업무 몇 개를 안정적으로 자동화하는 것이 목표라면 Playwright, RPA, 애플리케이션 API가 더 단순할 수 있다. GUI는 API가 없을 때 필요한 최후의 호환 계층이지 항상 최선의 통합 방식은 아니다. 환경 이미지, 평가기, trajectory 저장, 비밀정보 통제, Fleet 비용을 운영할 인력이 없다면 먼저 고정 스크립트와 사람이 검토하는 반자동 흐름으로 실패 비용을 파악하는 편이 낫다.

Cua가 Trending에 오른 사실보다 중요한 신호는 computer-use가 데모 단계에서 **평가 가능한 시스템**으로 이동하고 있다는 점이다. 좋은 모델을 고르는 일은 마지막 단계다. 그 전에 시작 상태를 고정하고, 결과를 클릭 경로와 독립적으로 판정하며, 환경 실패를 분리하고, trajectory를 증거로 남겨야 한다. 이 기반이 없으면 성공률 숫자는 재현되지 않고, 기반이 있으면 모델과 드라이버가 바뀌어도 같은 질문을 다시 시험할 수 있다.

> 1차 출처: [trycua/cua](https://github.com/trycua/cua), [Cua README](https://github.com/trycua/cua/blob/main/README.md), [Cua-Bench 개요](https://github.com/trycua/cua/blob/main/docs/content/docs/concepts/what-is-cua-bench.mdx), [태스크 lifecycle](https://github.com/trycua/cua/blob/main/docs/content/docs/concepts/cua-bench-task-lifecycle.mdx), [태스크 정의](https://github.com/trycua/cua/blob/main/docs/content/docs/reference/cua-bench/task-definition.mdx), [OSWorld Fleet 가이드](https://github.com/trycua/cua/blob/main/docs/content/docs/how-to-guides/sandbox/run-osworld-on-cloud-fleet.mdx), [Sandbox runtime support](https://github.com/trycua/cua/blob/main/docs/content/docs/reference/sandbox-sdk/runtime-support.mdx), [trajectory recording](https://github.com/trycua/cua/blob/main/docs/content/docs/how-to-guides/driver/record-and-render-a-trajectory.mdx), [Security Policy](https://github.com/trycua/cua/blob/main/SECURITY.md), [Sandbox 0.8.0](https://github.com/trycua/cua/releases/tag/sandbox-v0.8.0). Trending·저장소 수치는 2026년 9월 21일 09시 전후 KST 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
