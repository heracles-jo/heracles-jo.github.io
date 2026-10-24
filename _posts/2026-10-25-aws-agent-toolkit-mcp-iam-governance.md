---
title: "AWS Agent Toolkit 권한 설계: MCP·IAM·감사 기준"
description: "AWS Agent Toolkit의 스킬·MCP·IAM 계층을 분리해 에이전트의 클라우드 변경 권한, 자격 증명, CloudTrail 감사와 단계적 도입 기준을 정리한다."
author: heracles-jo
date: 2026-10-25 08:32:00 +0900
categories: [Cloud, Security]
tags: [aws-agent-toolkit, aws-mcp-server, iam, cloudtrail, ai-agent, cloud-security]
image:
  path: https://heracles-jo.github.io/assets/img/posts/aws-agent-toolkit-mcp-iam-governance/cover.svg
  alt: "AWS Agent Toolkit에서 에이전트 스킬, MCP 도구, IAM 정책과 감사 로그를 분리해 통제하는 구조"
---

AI 코딩 에이전트가 AWS 문서를 찾아주는 단계와 실제 계정의 리소스를 바꾸는 단계 사이에는 큰 간격이 있다. S3 버킷을 만들고, Lambda 설정을 고치고, CloudFormation 배포를 실행하는 순간 에이전트는 조언 도구가 아니라 클라우드 운영 주체가 된다. 이때 프롬프트에 “조심해서 작업하라”고 쓰는 것만으로는 부족하다. 잘못된 서비스 선택, 과도한 IAM 권한, 다른 계정·리전에서의 실행, 반복 재시도, 파괴적 변경을 기술적으로 막고 사후에 추적할 수 있어야 한다.

이번에 살펴볼 [aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws)는 Claude Code, Codex, Cursor, Devin, Kiro 같은 기존 에이전트에 AWS 스킬과 관리형 MCP 연결을 제공한다. 중요한 점은 이것이 새로운 에이전트나 모델이 아니라 **에이전트와 AWS 사이의 실행 계층**이라는 사실이다. 따라서 도입 질문도 “답변 품질이 좋아지는가”보다 **어떤 지침을 읽고, 어떤 도구를 노출하며, 어느 IAM 주체로 서명하고, 어떤 호출을 거부·기록하는가**에서 시작해야 한다.

2026년 10월 25일 08시 42분 KST 전후 GitHub Trending daily에는 이 저장소가 표시됐다. 당시 화면은 `11 stars today`, GitHub API는 3,120 stars와 397 forks, 열린 issue 40개와 PR 24개, Apache-2.0 라이선스, 10월 23일 최신 push를 보여 줬다. GitHub Releases의 latest endpoint는 릴리스를 반환하지 않았고, 최근 변경은 Bedrock Knowledge Base 마이그레이션, 데이터 카탈로그 접근, ECS Gateway, Lambda 배포 지침처럼 서비스별 스킬 보강에 집중돼 있었다. 수치와 상태는 확인 시점의 공개 스냅샷이며 이후 달라질 수 있다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근하지 못해 선정 근거로 사용하지 않았다.

## 후보 비교: 새 도구보다 독립적인 검색 질문을 골랐다

오늘 후보에는 디자인 스킬과 범용 코딩 에이전트가 많았다. 하지만 최근 글의 제목과 태그뿐 아니라 중심 논지를 비교하면 상당수가 이미 다룬 검색 의도와 겹쳤다. AWS Agent Toolkit은 “에이전트 플러그인을 어떻게 설치하는가”가 아니라 **클라우드 변경 권한을 지침·도구·IAM·감사 계층으로 어떻게 나누는가**라는 별도 질문을 만들 수 있었다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Agent Toolkit for AWS](https://github.com/aws/agent-toolkit-for-aws) | daily 11, API 3,120 stars, Apache-2.0, 최근 AWS 서비스 스킬 갱신 | MCP 호출을 IAM 조건 키와 CloudTrail에 연결하는 클라우드 권한 설계가 독립적이며 장기 운영 가치가 높다. |
| [Hallmark](https://github.com/Nutlope/hallmark) | daily 570, API 32,111 stars, MIT | AI가 만든 UI의 상투성을 줄이는 디자인 스킬은 흥미롭지만 디자인 자동화·스킬 검증 글과 독자가 겹친다. |
| [Impeccable](https://github.com/pbakaus/impeccable) | daily 733, API 86,378 stars, Apache-2.0, engine v0.1.17 | 디자인 언어와 에이전트 지침이라는 중심 논지가 Hallmark 및 기존 디자인 도구 클러스터와 가깝다. |
| [OpenCode](https://github.com/anomalyco/opencode) | weekly 6,765, API 221,082 stars, MIT, v1.19.4 | 범용 코딩 에이전트 비교는 메모리·리뷰·병렬 실행·컨텍스트 글을 다시 묶을 가능성이 크다. |
| [Hyperframes](https://github.com/heygen-com/hyperframes) | weekly 5,553, API 71,472 stars, Apache-2.0, v0.8.193 | HTML 기반 영상 렌더링은 기존 AI 비디오 제작 글과 같은 저장소·검색 의도가 중복된다. |

AWS 공식 README는 Agent Toolkit을 AWS MCP Server, skills, plugins, rules files로 나눈다. 이 구분은 단순한 패키징 방식이 아니다. 각 요소가 제공하는 보장 수준이 다르다. 스킬은 에이전트가 따라야 할 절차이고, MCP 도구는 실행 가능한 능력이며, IAM은 허용·거부를 결정하는 강제 경계이고, CloudTrail은 실제 호출의 증거다. 이 네 층을 섞으면 “스킬에 금지라고 적었으니 안전하다”거나 “IAM이 있으니 에이전트가 올바른 순서로 작업할 것”이라는 잘못된 확신이 생긴다.

## 스킬은 런북이고 IAM은 안전장치다

Agent Toolkit의 core skill은 인증, IAM, CDK·CloudFormation, 배포, 관측성, 비용, 서버리스, 컨테이너, 데이터베이스 같은 넓은 경로를 안내한다. specialized skill은 데이터 레이크 테이블 생성, Lambda timeout 진단, VPC endpoint 구성처럼 더 좁은 작업 절차를 제공한다. 플러그인은 이런 스킬과 MCP 설정을 에이전트별 설치 단위로 묶는다.

스킬의 가치는 모델의 오래된 학습 데이터나 즉흥적인 서비스 조합을 줄이는 데 있다. 예를 들어 인프라 변경 전에 관련 스킬을 찾고, 최신 공식 문서를 확인하고, 직접 CLI 명령을 늘어놓기보다 CDK나 CloudFormation을 우선하도록 유도할 수 있다. 그러나 스킬은 정책 문서다. 에이전트가 지침을 잘못 해석하거나, 다른 플러그인의 지시와 충돌하거나, 사용자가 직접 도구를 호출하면 그 문장 자체가 AWS API를 차단하지는 못한다.

[Android Skills를 빌드·테스트 게이트와 연결한 글](/posts/android-skills-agent-workflow-validation/)에서도 같은 문제를 다뤘다. 지침 파일은 재현 가능한 작업 순서를 만드는 데 유용하지만, 실제 품질은 빌드와 테스트가 강제한다. AWS에서는 그 강제 계층이 IAM, 조직 SCP, permission boundary, session policy, IaC review, 배포 승인이다. 스킬은 이 경계를 대체하지 않고 올바르게 사용하도록 돕는 상위 런북이어야 한다.

![AWS Agent Toolkit에서 스킬, MCP 도구, 인증, IAM과 감사 로그가 서로 다른 보장을 제공하는 아키텍처](https://heracles-jo.github.io/assets/img/posts/aws-agent-toolkit-mcp-iam-governance/architecture.svg)

운영자는 최소한 다음 네 질문을 분리해야 한다.

1. **지식 경계**: 에이전트가 어떤 스킬과 문서를 읽고 서비스·절차를 선택하는가.
2. **도구 경계**: 문서 검색만 가능한가, AWS API와 sandboxed script 실행도 가능한가.
3. **권한 경계**: 어떤 계정·role·리전·리소스·action에 IAM이 허용되는가.
4. **증거 경계**: 요청 주체, 호출 경로, 변경 전후 상태와 승인 기록을 어디서 재구성하는가.

이 중 하나라도 빠지면 장애 분석이 어려워진다. 에이전트가 잘못된 작업을 제안했는지, 도구가 예상 밖 API를 호출했는지, IAM이 너무 넓었는지, 승인 후 사람이 별도 변경했는지 구분할 수 없기 때문이다.

## AWS MCP Server는 편의 기능이 아니라 정책 경로다

공식 문서에 따르면 AWS MCP Server는 문서·스킬 검색, 리전과 서비스 가용성 확인, AWS API 접근이 가능한 sandboxed Python 실행, S3 presigned URL 생성, 장기 작업 상태 조회 같은 도구를 제공한다. 복수의 API를 묶어 조회하고 재시도하는 기능은 에이전트 작업을 단순화하지만, 동시에 단일 자연어 요청이 여러 AWS 호출로 확장될 수 있다는 뜻이다.

여기서 가장 중요한 장치는 모든 요청에 붙는 `aws:ViaAWSMCPService`와 `aws:CalledViaAWSMCP` IAM condition key다. 조직은 같은 IAM role이라도 MCP를 거친 에이전트 호출에만 별도 제한을 둘 수 있다. README가 설명하는 대표적인 사용법은 사용자의 기본 role에 쓰기 권한이 있어도 MCP 경로에는 읽기 전용 정책을 적용하는 것이다. CloudTrail에는 호출이 기록되므로 에이전트 경로와 일반 CLI·콘솔 경로를 구분해 조사할 수 있다.

이 구조는 [OpenShell의 에이전트 정책 런타임 글](/posts/openshell-agent-policy-runtime/)과 닮았지만 적용 지점이 다르다. OpenShell은 로컬·샌드박스 실행, egress, 자격 증명 주입을 통제하는 런타임 경계에 가깝다. AWS MCP Server는 AWS API 요청이 클라우드 제어면에 도착했을 때 IAM과 감사 체계로 통제하는 경계다. 둘 중 하나만으로는 충분하지 않다. 로컬 에이전트가 저장소 비밀이나 다른 SaaS 토큰을 읽는 문제는 AWS IAM이 막지 못하고, 반대로 로컬 sandbox가 강해도 과도한 AWS role을 받으면 클라우드 리소스는 위험하다.

## OAuth와 SigV4는 편의가 아니라 운영 모델 선택이다

공식 설정 문서는 OAuth와 SigV4 두 인증 경로를 제시한다. OAuth는 브라우저·웹 클라이언트와 단일 계정의 빠른 시작에 유리하다. SigV4는 AWS CLI 자격 증명과 로컬 MCP proxy를 사용하며, 여러 AWS 계정을 한 세션에서 다루거나 read-only mode로 쓰기 가능 도구를 아예 숨기고, 기본 리전을 정교하게 제어하려는 터미널·IDE 환경에 더 적합하다.

팀 운영에서는 “연결이 쉬운가”보다 자격 증명 수명주기와 계정 전환의 가시성을 본다.

- 개인 장기 access key 대신 IAM Identity Center나 짧은 세션을 사용하고 만료·재인증을 정상 흐름으로 만든다.
- production role은 개발 role과 분리하고, 에이전트가 계정 별칭·account ID·region을 실행 전에 출력하게 한다.
- 여러 profile을 허용하더라도 자연어로 profile을 추측하게 두지 않고 작업 티켓이나 저장소 환경에 명시한다.
- read-only 조사와 변경 실행을 서로 다른 session·role·승인 단계로 나눈다.
- 로컬 MCP proxy 설정과 plugin 버전을 코드 리뷰 가능한 형태로 고정하고 `latest` 의존을 production 경로에서 피한다.

자격 증명은 모델 컨텍스트에 들어가면 안 된다. 저장소의 AWS rules 파일도 secret 작업에서 값을 직접 조회하지 않고 런타임 해석 방식을 사용하도록 지시한다. 그러나 이 역시 지침만으로 끝내지 말고 secret retrieval 권한, CloudTrail 경보, shell history·CI log 마스킹과 canary credential로 검증해야 한다. [OpenBao 전환 글](/posts/openbao-secrets-management-migration/)에서 정리했듯 비밀 관리의 기준은 저장 위치보다 발급·사용·회수·감사 전체 수명주기다.

## 가장 흔한 실패는 “사람 권한을 그대로 에이전트에 전달”하는 것이다

에이전트는 사람보다 빠르게 여러 API를 호출하고 실패를 재시도한다. 그래서 같은 role을 사용하더라도 위험 프로파일이 다르다. 관리자 권한을 가진 개발자가 콘솔에서 한 번 확인하는 행동과, 에이전트가 탐색 과정에서 수십 개 서비스를 나열하고 script를 실행하는 행동을 같은 정책으로 취급하면 blast radius가 커진다.

첫 번째 실패 모드는 **읽기와 쓰기의 혼합**이다. 인벤토리 조사 중 생성·수정 도구가 노출되면 프롬프트 오해나 tool selection 오류가 변경으로 이어질 수 있다. read-only 세션에서는 도구 목록과 IAM을 모두 읽기 전용으로 제한해야 한다. UI에서 쓰기 버튼을 숨기는 것과 backend가 거부하는 것을 함께 적용하는 셈이다.

두 번째는 **IaC와 직접 API 변경의 혼합**이다. Agent Toolkit의 rules는 인프라 생성에 CDK나 CloudFormation을 우선하도록 권장한다. production에서는 이 원칙을 더 강하게 적용해 plan·diff·review·deployment role을 분리해야 한다. 에이전트가 장애를 조사하다 즉시 보안 그룹이나 Lambda 환경 변수를 고치면 빠르지만, 변경 이유와 rollback artifact가 남지 않는다.

세 번째는 **범용 role의 계정 횡단 사용**이다. 여러 profile 지원은 편리하지만 계정·리전 오선택을 더 비싸게 만든다. role 이름을 모든 계정에서 동일하게 쓰는 조직은 account ID 검증, resource tag 조건, region 제한, session tag 없이는 로그만 보고 의도를 복원하기 어렵다.

네 번째는 **감사 로그를 성공 로그로 오해하는 것**이다. CloudTrail은 호출 증거를 제공하지만 변경 전 상태, 에이전트의 계획, 사람의 승인 이유까지 자동으로 보존하지 않는다. 작업 ID, prompt 요약, IaC diff, 승인자, CloudTrail event와 배포 결과를 하나의 evidence chain으로 묶어야 한다. [Cloudflare Security Audit Skill 글](/posts/cloudflare-security-audit-skill-validation-pipeline/)에서 다룬 독립 반증 원칙처럼, 에이전트가 “성공했다”고 보고한 결과는 별도 read-back과 정책 검사로 확인해야 한다.

## PoC는 생성 성공보다 거부와 복구를 측정한다

초기 PoC를 production 계정에서 “간단한 S3 버킷 하나 만들어 봐”로 시작하면 정상 경로만 확인하게 된다. 더 좋은 방법은 폐기 가능한 sandbox account에서 권한을 의도적으로 좁히고, 에이전트가 제한을 어떻게 인식하고 중단하는지 보는 것이다.

![AWS Agent Toolkit PoC를 문서 전용, 읽기 전용, IaC 변경, 제한적 운영으로 승격하는 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/aws-agent-toolkit-mcp-iam-governance/decision.svg)

| 검증 영역 | 측정할 증거 | 중단 조건 예시 |
|---|---|---|
| 도구 노출 | 세션별 tool inventory, read-only mode, write tool 부재 | 조사 세션에서 생성·수정 도구가 보이거나 우회 호출 가능 |
| 인증 | account ID, role ARN, region, session duration, 재인증 로그 | production role을 자동 선택하거나 장기 key가 필요함 |
| IAM | 허용·명시적 deny, MCP condition key, resource·tag·region 범위 | 사람 권한과 동일한 broad policy만으로 동작함 |
| IaC | CDK/CloudFormation diff, 승인, artifact hash, rollback | 직접 API 변경만 남고 재현 가능한 변경 집합이 없음 |
| 감사 | CloudTrail event, 작업 ID, 승인자, 전후 상태 read-back | 에이전트 보고와 실제 resource 상태를 연결할 수 없음 |
| 실패 처리 | AccessDenied, throttling, 부분 성공, 재시도 횟수 | 거부를 권한 확대 요청으로만 해석하거나 무한 재시도함 |
| 비용 | API 호출량, 생성 자원 비용, 로그·관측 비용, cleanup | 예산·TTL·tag가 없는 리소스를 만들거나 삭제 검증이 없음 |

권장 승격 순서는 네 단계다.

1. **문서 전용**: 자격 증명 없이 공식 문서와 스킬 검색만 사용해 서비스 선택과 IaC 초안을 평가한다.
2. **읽기 전용**: sandbox account에서 inventory와 장애 진단을 수행하고 MCP condition key·CloudTrail 기록을 확인한다.
3. **검토 가능한 변경**: 에이전트는 IaC diff까지만 만들고 사람이 승인한 별도 deployment role이 적용한다.
4. **제한적 운영**: 반복성이 높고 rollback이 검증된 작업만 좁은 resource·action·time window 안에서 자동 실행한다.

각 단계에서 허용 범위를 넓히기 전에 deny path를 시험한다. 다른 리전, 허용되지 않은 tag, production account, 비승인 서비스, 파괴적 action, 만료된 session을 입력해 실제로 거부되는지 확인한다. rollback도 문서만 보지 말고 생성 자원 제거, CloudFormation 실패 복구, 부분 성공 후 reconciliation을 실행해야 한다. [Google AX 운영 글](/posts/google-ax-agent-orchestration/)에서 장기 실행 에이전트의 suspend·resume과 workspace 격리를 분리했듯, AWS 작업도 모델 세션이 끊겨도 현재 상태와 다음 안전한 행동을 복원할 수 있어야 한다.

Agent Toolkit for AWS의 장점은 수많은 AWS 명령을 에이전트에게 외우게 하는 데 있지 않다. 최신 문서와 검증된 절차를 찾는 지식 계층, 복잡한 API 작업을 실행하는 MCP 계층, 에이전트 경로를 구별하는 IAM 조건, 기존 CloudTrail 감사 체계를 하나의 흐름으로 연결하는 데 있다. 동시에 바로 그 연결 때문에 지침 파일 설치만으로 production 준비가 끝났다고 착각해서는 안 된다.

도입 판단은 세 문장으로 압축할 수 있다. **스킬은 올바른 절차를 제안하지만 권한을 강제하지 않는다. MCP는 작업을 단순화하지만 한 요청의 실행 반경을 넓힌다. IAM과 감사 로그는 경계를 만들지만, 좁은 role·IaC 승인·상태 read-back·복구 시험이 없으면 그 경계도 운영되지 않는다.** 이 구분을 유지할 수 있는 팀에게 Agent Toolkit은 편리한 플러그인이 아니라 관리 가능한 클라우드 에이전트 제어면이 된다.

> 1차 자료: [Agent Toolkit for AWS 저장소와 README](https://github.com/aws/agent-toolkit-for-aws), [AWS 공식 사용자 가이드](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/what-is-agent-toolkit.html), [AWS MCP Server 설정](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html), [MCP Server 도구](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/understanding-mcp-server-tools.html), [IAM 안내](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/security-iam.html), [skills](https://github.com/aws/agent-toolkit-for-aws/tree/main/skills), [rules](https://github.com/aws/agent-toolkit-for-aws/tree/main/rules), [최근 commits](https://github.com/aws/agent-toolkit-for-aws/commits/main/), [공개 issues](https://github.com/aws/agent-toolkit-for-aws/issues), [공개 pull requests](https://github.com/aws/agent-toolkit-for-aws/pulls), [Apache-2.0 License](https://github.com/aws/agent-toolkit-for-aws/blob/main/LICENSE). Trending·저장소 수치는 2026년 10월 25일 08시 42분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
