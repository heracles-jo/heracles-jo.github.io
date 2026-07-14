---
title: "AI 에이전트 위험 명령 차단: dcg 도입 기준"
description: "AI 코딩 에이전트가 실행하는 rm, Git 강제 변경, 클라우드 삭제 명령을 dcg로 차단할 때의 훅 구조와 우회 경계, 오탐 비용, 라이선스 검토 기준을 정리한다."
author: heracles-jo
date: 2026-07-15 06:50:00 +0900
categories: [Security, Developer Tools]
tags: [destructive-command-guard, ai-agent-security, command-guard, devsecops, shell-safety, human-in-the-loop]
image:
  path: https://heracles-jo.github.io/assets/img/posts/ai-agent-destructive-command-guard/cover.svg
  alt: "AI 코딩 에이전트와 셸 사이에서 위험 명령을 판별하고 차단하는 destructive command guard"
---

AI 코딩 에이전트에게 터미널을 맡기면 생산성이 높아지는 만큼 실수의 반경도 커진다. 잘못 선택한 `git reset --hard`, 경로 변수가 비어 있는 `rm -rf`, 대상 컨텍스트를 착각한 `kubectl delete`, 검토 없이 실행한 `terraform destroy`는 모델의 답변 품질 문제가 아니라 실제 상태 손실로 이어진다. “실행 전에 사용자에게 물어보라”는 프롬프트만으로는 부족하다. 긴 작업에서 지침이 희석될 수 있고, 도구마다 승인 UX가 다르며, 에이전트가 안전하다고 오판한 명령은 승인 단계에 올라오지 않을 수도 있기 때문이다.

2026년 7월 15일 07:00 KST 전후 GitHub Trending daily에서 [Dicklesworthstone/destructive_command_guard](https://github.com/Dicklesworthstone/destructive_command_guard)(이하 dcg)는 4,353 stars, 163 forks, **481 stars today**로 표시됐다. GitHub API에서는 같은 시점 13개의 열린 이슈·PR, 7월 13일의 최신 푸시와 [v0.6.6 릴리스](https://github.com/Dicklesworthstone/destructive_command_guard/releases/tag/v0.6.6)를 확인했다. 수치는 시간에 따라 변하는 공개 스냅샷이다. 오늘 함께 살펴본 후보는 에이전트 스킬 모음 `mattpocock/skills`, 터미널 MCP 서버 `DesktopCommanderMCP`, 병렬 에이전트 환경 `stablyai/orca`, 오픈소스 영상 편집기 `OpenCut`이었다. 그러나 이 블로그에는 스킬·MCP·멀티 에이전트·영상 자동화 글이 이미 많다. dcg는 **에이전트가 명령을 생성하는 방법이 아니라, 실행 직전의 강제 통제점을 어떻게 설계할지**라는 별도의 검색 의도에 답할 수 있어 선택했다.

## 프롬프트 규칙과 셸 권한 사이에 빠진 통제점

에이전트 안전장치는 대개 세 층으로 나뉜다. 첫째, 프롬프트와 스킬이 올바른 절차를 유도한다. 둘째, 도구 호출 정책이 특정 명령을 승인 대상으로 보낸다. 셋째, 컨테이너나 MicroVM이 실행 결과의 영향 범위를 가둔다. dcg는 첫째와 셋째 사이, 즉 **명령이 셸로 전달되기 직전**에 훅으로 개입한다.

이 위치가 중요한 이유는 통제 목적이 서로 다르기 때문이다. [Agent Skills를 개발 절차로 만드는 방법](/posts/github-trending-agent-skills-engineering-workflow/)은 에이전트가 계획·테스트·리뷰를 잊지 않게 하지만, 지침 위반을 운영체제 수준에서 막지는 않는다. [SkillSpector의 에이전트 스킬 공급망 분석](/posts/github-trending-skillspector-agent-skill-security/)은 설치 전 악성 지침과 과도한 권한을 찾지만, 정상 스킬을 실행하던 에이전트의 우발적 오타까지 차단하지는 못한다. 반대로 [CubeSandbox의 MicroVM 실행 격리](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)는 침해 반경을 줄이지만, 개발자의 실제 작업 디렉터리나 클라우드 자격증명에 접근해야 하는 작업을 모두 샌드박스에 넣기는 어렵다.

![에이전트 명령 차단 계층](https://heracles-jo.github.io/assets/img/posts/ai-agent-destructive-command-guard/architecture.svg)

따라서 셋은 경쟁 제품이 아니라 겹쳐 써야 하는 방어선이다. 스킬 검사는 **무엇을 신뢰할지**, 명령 훅은 **지금 무엇을 실행할지**, 샌드박스는 **실행 후 어디까지 영향을 줄지**를 통제한다. 어느 하나를 나머지의 대체재로 보면 빈틈이 생긴다.

## dcg는 어떤 방식으로 명령을 판정하는가

[공식 README](https://github.com/Dicklesworthstone/destructive_command_guard/blob/main/README.md)에 따르면 dcg는 Claude Code, Codex CLI, Gemini CLI, Copilot CLI, Cursor, Hermes Agent 등 여러 도구의 사전 실행 훅에 연결된다. 입력된 명령을 정규화한 뒤 빠른 키워드 필터, 문맥 분류, 규칙 팩을 거쳐 허용 또는 거부 결과를 해당 에이전트의 훅 프로토콜로 돌려준다. Rust 구현과 지연 최소화는 훅이 모든 명령 앞에 놓여도 개발 흐름을 과도하게 늦추지 않으려는 선택이다.

기본 상태에서는 `core.filesystem`, `core.git`, `system.disk`처럼 복구하기 어려운 동작에 집중한다. 데이터베이스, Kubernetes, Docker, AWS·GCP·Azure, Terraform, 비밀 관리, CI/CD 등은 별도의 규칙 팩으로 제공되며 다수는 명시적으로 활성화해야 한다. 설치만 해두고 “클라우드 삭제도 모두 막혔다”고 믿으면 안 된다는 뜻이다. 실제 보호 범위는 `dcg packs` 결과와 로컬 설정을 함께 확인해야 한다.

판정 로직에서 어려운 문제는 위험 명령의 문자열이 아니라 **실행 문맥**이다. `grep "rm -rf" README.md`는 문서를 찾는 안전한 작업이지만, `rm -rf "$TARGET"`은 변수 값에 따라 치명적일 수 있다. `kubectl delete pod`는 재생성 가능한 개발 파드일 수 있지만, namespace 삭제는 공유 환경 전체에 영향을 준다. 프로젝트의 [팩 설계 결정 문서](https://github.com/Dicklesworthstone/destructive_command_guard/blob/main/docs/architecture/pack-design.md)는 REST API 삭제를 단순 키워드가 아닌 HTTP 메서드와 호스트·경로 조합으로 판단하고, dry-run 같은 안전 변형을 우선 허용하며, 모호한 명령은 명확한 플래그가 있을 때만 막는 방향을 설명한다.

이 설계는 SAST나 셸 린터와도 다르다. 린터는 저장된 스크립트를 리뷰할 때 유용하지만, 에이전트가 즉석에서 만든 한 줄 명령은 파일에 남지 않을 수 있다. dcg의 scan 모드는 CI와 pre-commit에도 연결할 수 있지만 핵심 가치는 실시간 실행 경로에 있다는 점이다.

## fail-open은 가용성을 지키지만 보안 경계는 약해진다

README는 파싱 오류나 타임아웃이 발생해도 워크플로를 막지 않는 **fail-open** 동작을 장점으로 제시한다. 개발자 도구로서는 합리적이다. 훅 버그 하나가 모든 빌드와 테스트를 멈추면 사용자는 곧 훅을 제거한다. 하지만 보안 통제로 평가할 때는 해석이 달라진다. 파서가 이해하지 못한 래퍼, 난독화, 표준입력 기반 REPL, 새 CLI 문법은 차단되지 않은 채 지나갈 수 있다.

프로젝트의 README도 위협 모델을 “선의이지만 실수할 수 있는 에이전트”로 한정한다. 공격자가 의도적으로 우회 문자열을 만들거나, 에이전트 프로세스와 동일 권한으로 훅 설정을 지우거나, `DCG_BYPASS=1` 같은 탈출구를 호출하는 상황을 완전하게 막는 제품은 아니다. 최근 커밋에는 표준입력·파이프·명령 치환을 이용한 REPL 우회를 알려진 한계로 문서화한 변경도 있다. 즉 dcg는 악성 코드를 격리하는 샌드박스나 권한을 강제하는 IAM이 아니라 **우발적 파괴를 줄이는 안전벨트**에 가깝다.

이 차이를 무시하면 위험 보상이 발생한다. 팀이 “dcg가 있으니 에이전트에 프로덕션 관리자 토큰을 줘도 된다”고 판단하면 통제 도입 전보다 더 큰 권한을 노출할 수 있다. [시스템 프롬프트 유출과 권한 경계](/posts/github-trending-system-prompts-leaks-ai-governance/)에서 강조했듯 최종 권한 검증은 자연어 지침 밖에 있어야 한다. 클라우드 IAM, Kubernetes RBAC, 데이터베이스 역할, 보호 브랜치, 승인형 배포는 그대로 유지해야 한다.

## 오탐을 0으로 만드는 대신 우회 비용을 설계해야 한다

명령 차단기는 거짓 양성(false positive)과 거짓 음성(false negative)의 교환 관계를 피할 수 없다. 규칙을 넓히면 안전한 빌드 디렉터리 정리까지 막고, 좁히면 따옴표·래퍼·리다이렉션 변형을 놓친다. 실제 공개 이슈에도 따옴표로 감싼 `/tmp` 삭제가 차단되는 사례, `sed` 치환식의 리다이렉션 오인, `git push origin +main` 변형이 strict 규칙을 빠져나가는 사례가 함께 보인다. 활발한 수정 신호인 동시에, 정규식과 경량 파싱만으로 셸 의미를 완벽히 모델링하기 어렵다는 증거다.

운영 가능한 정책은 “절대 오탐 없음”이 아니라 다음 세 가지를 분리한다.

1. **즉시 복구할 수 없는 명령**은 기본 차단한다. 루트 파일시스템 삭제, 디스크 포맷, 강제 Git 이력 손실처럼 영향이 명확한 동작이다.
2. **환경에 따라 위험한 명령**은 프로젝트 팩과 승인 절차로 관리한다. `terraform destroy`, `kubectl delete`, 데이터베이스 `DROP`은 개발 환경과 운영 환경의 결과가 다르다.
3. **반복되는 정상 작업**은 정확한 명령·규칙 ID·만료일·사유를 가진 allowlist로 좁게 예외 처리한다. 넓은 정규식이나 전역 bypass를 팀 표준으로 만들지 않는다.

특히 프로젝트 allowlist는 코드 리뷰 대상이어야 한다. 누가 어떤 이유로 예외를 추가했는지, 만료일이 있는지, 저장소 밖 사용자 설정에 더 넓은 예외가 숨어 있지 않은지 확인해야 한다. 위험한 명령이 차단된 횟수뿐 아니라 훅 비활성화, bypass 사용, 허용 목록 변경도 감사 이벤트로 수집해야 한다.

## 도입 전 반드시 확인할 라이선스 불일치

기능보다 먼저 멈춰야 할 지점도 있다. GitHub API는 이 저장소의 라이선스를 `NOASSERTION`으로 반환한다. README 상단 배지와 하단 문구는 “MIT”라고 적혀 있지만, 실제 [LICENSE 파일](https://github.com/Dicklesworthstone/destructive_command_guard/blob/main/LICENSE)은 **“MIT License (with OpenAI/Anthropic Rider)”**이며 OpenAI·Anthropic과 관련 주체에 권리를 부여하지 않는 추가 제한을 포함한다.

OSI의 MIT 라이선스와 동일하다고 간주해서는 안 된다. 특히 조직의 고객·투자자·서비스 제공자·계약 관계가 rider의 “직간접적으로 대신하거나 이익을 위해 행동하는 주체” 정의에 들어갈 가능성이 있다면 사용·배포·파생물 제공 범위를 법무와 확인해야 한다. README의 지원 도구 목록에 Codex와 Claude Code가 있다는 사실도 라이선스상 허용을 자동으로 뜻하지 않는다. 도구 호환성과 소프트웨어 사용권은 별개의 질문이다.

이 불일치는 PoC 단계에서도 기록해야 한다. 사내 오픈소스 정책이 SPDX 식별자와 자동 승인 목록에 의존한다면 `NOASSERTION`이 검토 큐로 들어가는지 확인하고, 바이너리를 조직 이미지에 재배포하거나 사내 포크를 운영하기 전에 rider를 검토해야 한다. 기술적으로 유용하다는 이유로 표준 MIT 의존성처럼 처리하면 이후 배포 경로를 되돌리는 비용이 커진다.

![dcg 도입 의사결정 매트릭스](https://heracles-jo.github.io/assets/img/posts/ai-agent-destructive-command-guard/decision.svg)

## 2주 PoC에서 측정할 항목

PoC는 전사 설치보다 최근 에이전트 작업에서 실제로 위험했던 저장소 한두 개로 시작하는 편이 낫다. [Terraform과 IaC 거버넌스](/posts/github-trending-terraform-iac-governance/)처럼 변경 계획과 승인 경계가 분명한 저장소라면 차단 정책의 효과를 측정하기 쉽다.

- **탐지 재현율**: 과거 사고·아차사고 명령과 팀이 만든 변형 코퍼스 중 몇 개를 잡는가.
- **오탐률과 우회 시간**: 정상 명령이 막힌 비율, 개발자가 원인을 이해하고 안전한 대안으로 전환하는 데 걸린 시간은 얼마인가.
- **훅 무결성**: 에이전트 업데이트나 설정 재작성 후에도 훅이 남는가. README는 설정 파일 재작성으로 훅이 제거될 수 있어 시작 시 점검을 권고한다.
- **프로토콜 실패 동작**: 훅 출력 JSON이 각 에이전트 버전에서 실제 거부로 처리되는가. 허용·거부·잘못된 입력을 자동화된 smoke test로 확인한다.
- **권한 축소 효과**: dcg 도입과 별개로 에이전트의 클라우드·배포·비밀 접근 권한을 얼마나 줄였는가.
- **예외 거버넌스**: allow-once, 프로젝트 allowlist, 환경변수 bypass가 로그에 남고 주기적으로 폐기되는가.

테스트 코퍼스에는 단순 예제만 넣지 말아야 한다. 절대 경로, 따옴표, 변수, `sudo`, 파이프, heredoc, `python -c`, 여러 명령 연결, dry-run, 임시 디렉터리를 포함해야 한다. 실패 시에는 “도구가 나쁘다”거나 “규칙 하나를 추가하면 된다”로 끝내지 말고, 패턴 기반 차단의 한계인지 훅 프로토콜 문제인지 권한 모델 문제인지 분류한다.

## 어떤 팀에 적합한가

dcg류 통제는 AI 코딩 에이전트가 실제 개발자 워크스테이션에서 파일과 Git을 다루고, 여러 CLI를 호출하지만 모든 작업을 일회용 샌드박스에 넣을 수 없는 팀에 유용하다. 온보딩 중인 개발자, 큰 모노레포, 로컬에 미커밋 변경이 자주 남는 연구 환경, IaC와 운영 CLI를 함께 다루는 플랫폼팀은 작은 비용으로 실수 방지 지점을 만들 수 있다.

반대로 적대적 입력을 처리하는 자율 에이전트, 다중 테넌트 코드 실행 서비스, 프로덕션 관리자 권한을 가진 무인 작업의 핵심 방어선으로는 부족하다. 이 경우 명령 패턴 차단보다 짧은 수명의 자격증명, 명시적 API allowlist, 별도 계정, 보호된 배포 파이프라인, 네트워크 egress 통제, 샌드박스가 먼저다. dcg는 그 위에 추가할 수 있지만 권한 경계를 대신할 수 없다.

결국 위험 명령 차단의 목표는 에이전트를 “믿을 수 있게” 만드는 것이 아니다. 에이전트가 틀릴 것을 전제로 복구 불가능한 동작 앞에 독립적인 마찰을 두는 것이다. dcg는 그 마찰을 여러 에이전트 훅과 규칙 팩으로 제품화했다는 점에서 주목할 만하다. 다만 fail-open 위협 모델, 우회 경로, 오탐 운영비, 훅 무결성, 수정된 라이선스를 함께 검토해야 한다. 좋은 도입 결정은 차단 데모 한 번이 아니라 **어떤 상태 손실을 막았고, 어떤 위험은 여전히 IAM·샌드박스·사람 승인에 남아 있는지**를 명확히 설명할 수 있어야 한다.
