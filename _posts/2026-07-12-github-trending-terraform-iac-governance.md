---
title: "GitHub Trending으로 보는 Terraform과 IaC 거버넌스의 재평가"
description: "GitHub Trending에 다시 오른 Terraform을 OpenTofu, Pulumi, Terragrunt와 비교하며 선언형 인프라 코드, 상태 관리, 라이선스, 운영 리스크 관점에서 실무 도입 기준을 정리한다."
author: heracles-jo
date: 2026-07-12 07:39:00 +0900
categories: [Infrastructure, DevOps]
tags: [github-trending, terraform, opentofu, pulumi, terragrunt, infrastructure-as-code, iac, devops, platform-engineering]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-terraform-iac-governance/cover.svg
  alt: "Terraform이 GitHub Trending에 다시 오른 흐름을 계기로 IaC 거버넌스와 대체 도구 선택 기준을 분석하는 이미지"
---

GitHub Trending daily에서 [HashiCorp Terraform](https://github.com/hashicorp/terraform)이 다시 상위권에 올라온 것은 단순히 오래된 인프라 자동화 도구가 한 번 더 주목받았다는 사건으로 보기 어렵다. 2026년 7월 12일 오전 KST 확인 시점의 공개 스냅샷 기준으로 Terraform 저장소는 약 49.3k stars, 10.6k forks, daily trending 표시 229 stars today를 보였고, 같은 날 C++ 테스트 프레임워크 [Catch2](https://github.com/catchorg/Catch2), [Abseil C++](https://github.com/abseil/abseil-cpp), JavaScript 런타임 [Bun](https://github.com/oven-sh/bun), MCP 계열 도구 [DesktopCommanderMCP](https://github.com/wonderwhy-er/DesktopCommanderMCP)와 함께 노출됐다. 그러나 기존 글에서 이미 C++ 기반 라이브러리 스택, 로컬 AI, 에이전트 CLI, 샌드박스, 보안 운영 주제를 다뤘기 때문에 오늘의 의미 있는 기술 흐름은 다른 곳에 있다. 바로 **인프라 코드(IaC)가 다시 ‘도구 선택’이 아니라 ‘조직 거버넌스’ 문제로 이동하고 있다는 점**이다.

Terraform은 새롭지 않다. 오히려 너무 널리 쓰여서 기술 블로그에서는 다소 낡은 주제로 보일 수 있다. 그런데 바로 그 지점이 중요하다. 인프라가 Kubernetes, SaaS API, 데이터 플랫폼, 보안 정책, ID 권한, AI 워크로드까지 확장되면서 조직은 더 이상 “클라우드 리소스를 코드로 만들 수 있는가”만 묻지 않는다. 이제 질문은 “누가 어떤 정책으로 변경을 승인하는가”, “상태 파일과 권한은 어떻게 분리되는가”, “벤더 라이선스와 오픈소스 대안은 장기 운영에 어떤 비용을 만드는가”, “수백 개 워크스페이스와 계정을 사람이 이해 가능한 방식으로 관리할 수 있는가”로 바뀌고 있다.

이 글은 Terraform을 중심으로 [OpenTofu](https://github.com/opentofu/opentofu), [Pulumi](https://github.com/pulumi/pulumi), [Terragrunt](https://github.com/gruntwork-io/terragrunt)를 비교하며, 실무 의사결정자가 IaC 스택을 재검토할 때 봐야 할 구조와 리스크를 정리한다. 수치와 저장소 상태는 모두 2026년 7월 12일 KST 확인 시점의 공개 정보 스냅샷이며, 이후 변경될 수 있다.

## 오늘의 후보 저장소 비교: 왜 Terraform인가

GitHub Trending은 순간적인 관심을 보여줄 뿐 장기적 기술 가치를 보장하지 않는다. 그래서 오늘은 단순히 1위 저장소를 요약하지 않고, 최근 글과 중복되지 않으면서도 실무 파급력이 큰 후보를 비교했다.

| 후보 저장소 | Trending 신호 | 선택 판단 |
|---|---:|---|
| [catchorg/Catch2](https://github.com/catchorg/Catch2) | daily 상위, 약 21.0k stars | 전날 C++ 기반 라이브러리 스택을 다뤄 중심 각도가 중복된다. |
| [abseil/abseil-cpp](https://github.com/abseil/abseil-cpp) | daily 상위, 약 17.8k stars | 역시 C++ 기반 라이브러리 안정성 주제와 겹친다. |
| [wonderwhy-er/DesktopCommanderMCP](https://github.com/wonderwhy-er/DesktopCommanderMCP) | daily/weekly 모두 강한 스타 증가 | MCP·로컬 에이전트·CLI 주제는 최근 여러 글과 중복된다. |
| [oven-sh/bun](https://github.com/oven-sh/bun) | daily 654 stars today, 약 94.5k stars | 웹 런타임 재편이라는 가치가 있지만 오늘의 비교 관점에서는 IaC보다 중복 회피 효과가 낮다. |
| [hashicorp/terraform](https://github.com/hashicorp/terraform) | daily 상위, 약 49.3k stars, 최근 릴리스 v1.15.8 | 오래된 표준 도구가 다시 주목받는 현상 자체가 조직의 IaC 거버넌스 재평가를 설명하기 좋다. |

Terraform 저장소의 README는 Terraform을 “building, changing, and versioning infrastructure safely and efficiently” 하는 도구로 설명한다. 핵심 기능도 명확하다. 고수준 구성 언어로 인프라를 기술하고, `plan` 단계에서 실행 계획을 만들며, 리소스 그래프를 구성해 의존성이 없는 작업을 병렬화한다. 확인 시점에 최신 릴리스는 [v1.15.8](https://github.com/hashicorp/terraform/releases/tag/v1.15.8)(2026년 7월 8일 게시), 최신 커밋도 7월 10일에 존재해 저장소 활동이 계속되고 있었다.

비교 대상 역시 활동성이 높다. OpenTofu는 약 29.4k stars, MPL-2.0 라이선스, 최신 릴리스 [v1.12.3](https://github.com/opentofu/opentofu/releases/tag/v1.12.3)을 보였고, README에서 스스로를 “OSS tool for building, changing, and versioning infrastructure”라고 설명한다. Pulumi는 약 25.4k stars, Apache-2.0, 최신 릴리스 [v3.251.0](https://github.com/pulumi/pulumi/releases/tag/v3.251.0)이며 README 첫 문구가 “Infrastructure as Code for Humans and Agents”로 바뀐 점이 흥미롭다. Terragrunt는 약 9.7k stars, MIT 라이선스, [v1.1.0](https://github.com/gruntwork-io/terragrunt/releases/tag/v1.1.0)을 최신 릴리스로 제공하며 OpenTofu/Terraform 기반 IaC를 스케일시키는 오케스트레이션 도구라고 설명한다.

## Terraform이 다시 보이는 배경: 선언형 IaC의 ‘2라운드’

초기 IaC의 가치는 명확했다. 콘솔에서 클릭하던 작업을 코드로 바꾸고, 변경 이력을 Git에 남기며, 재현 가능한 환경을 만드는 것이다. 하지만 많은 조직이 Terraform을 몇 년 이상 운영하면서 다른 문제가 드러났다. 모듈이 많아질수록 입력 변수와 출력 값의 의미가 불명확해지고, 상태 파일은 점점 민감 정보와 운영 권한이 결합된 핵심 자산이 된다. 클라우드 계정은 늘어나고, 팀별 워크스페이스와 환경별 백엔드는 증가하며, 변경 승인을 누가 책임지는지 애매해진다.

이런 상황에서 Terraform이 Trending에 다시 등장하는 것은 “Terraform이 갑자기 새로워졌다”는 뜻이 아니라, 조직이 다시 기본기를 확인하고 있다는 신호에 가깝다. 특히 최근 몇 년간 Terraform 라이선스 변화 이후 OpenTofu가 분기했고, 플랫폼 엔지니어링 팀은 Pulumi처럼 일반 프로그래밍 언어 기반의 IaC도 검토하기 시작했다. 대규모 운영에서는 Terragrunt 같은 계층을 얹어 모듈 재사용, 계정 분리, 스택 실행 순서를 관리하려 한다. 즉, 오늘의 핵심은 **Terraform 대 OpenTofu 대 Pulumi 중 무엇이 더 멋진가**가 아니라, **조직의 변경 통제 모델에 맞는 IaC 실행 평면을 어떻게 설계할 것인가**다.

![Terraform 실행 구조](https://heracles-jo.github.io/assets/img/posts/github-trending-terraform-iac-governance/architecture.svg)

## 핵심 아키텍처: 코드보다 상태와 계획이 중요하다

Terraform을 처음 접하면 HCL 문법과 provider 설정에 주목하기 쉽다. 그러나 실무에서 사고를 줄이는 핵심은 문법이 아니라 상태와 계획의 운영 방식이다.

Terraform의 실행 흐름은 크게 네 단계로 볼 수 있다.

1. **선언형 코드 작성**: HCL 파일에 리소스, 데이터 소스, 모듈, 변수, 출력 값을 정의한다.
2. **상태 조회와 비교**: 원격 backend에 저장된 state와 실제 provider API에서 확인한 리소스를 비교한다.
3. **실행 계획 생성**: Terraform은 의존성 그래프를 만들고 생성, 수정, 삭제 작업을 `plan`으로 제시한다.
4. **Provider API 호출**: 승인된 `apply` 단계에서 클라우드·SaaS·내부 API를 호출해 실제 리소스를 변경한다.

여기서 가장 위험한 지점은 `apply` 명령 자체가 아니라 그 전에 누락된 통제다. 예를 들어 S3 backend와 DynamoDB lock을 쓰는 AWS 환경에서 state 접근 권한이 너무 넓으면, 인프라 변경 권한을 갖지 않아야 할 사용자도 민감한 출력 값이나 리소스 식별자를 볼 수 있다. Provider 버전 고정이 느슨하면 동일한 코드가 다른 시점에 다른 API 동작을 유발할 수 있다. `plan` 결과가 PR에 자동으로 첨부되지 않으면 코드 리뷰어는 실제 변경 영향을 확인하지 못한 채 승인하게 된다.

따라서 Terraform 운영 설계에서 중요한 질문은 다음과 같다.

- state backend는 팀, 계정, 환경 단위로 분리되어 있는가?
- `plan` 결과가 PR·머지 요청·변경 승인 시스템에 연결되어 있는가?
- `apply` 권한은 사람 계정이 아니라 제한된 CI/CD 주체에 위임되어 있는가?
- provider와 module 버전은 잠금 파일 및 릴리스 정책으로 관리되는가?
- drift 탐지는 정기적으로 수행되며, 수동 변경을 조직적으로 금지하거나 예외 처리하는 절차가 있는가?

이 질문에 답하지 못하면 IaC는 코드화된 운영 체계가 아니라 “콘솔 클릭을 CLI 클릭으로 바꾼 것”에 머물 가능성이 높다.

## Terraform, OpenTofu, Pulumi, Terragrunt 비교

![IaC 도구 선택 매트릭스](https://heracles-jo.github.io/assets/img/posts/github-trending-terraform-iac-governance/selection-matrix.svg)

도구 선택은 팀의 기술 취향보다 조직의 제약 조건에서 출발해야 한다. 아래 비교는 어느 도구가 절대적으로 우수하다는 판단이 아니라, 실무 의사결정자가 검토해야 할 축을 정리한 것이다.

| 도구 | 강점 | 한계와 리스크 | 적합한 상황 |
|---|---|---|---|
| Terraform | 가장 넓은 provider·module 생태계, 풍부한 레퍼런스, 채용 시장의 인력 풀 | 라이선스와 상용 제품 정책 검토 필요, 대규모 모듈 관리 복잡도 | 표준화와 안정성을 우선하는 대부분의 조직 |
| OpenTofu | MPL-2.0 기반 오픈소스 거버넌스, Terraform 경험과 유사한 사용성 | 장기 호환성, provider·module 검증, 조직 내 마이그레이션 비용 | 오픈소스 라이선스 정책이 엄격하거나 벤더 중립성이 중요한 조직 |
| Pulumi | TypeScript, Python, Go 등 일반 언어 사용, 테스트와 추상화가 자연스러움 | 런타임·SDK·패키지 관리 복잡도, 개발자 역량 편차가 인프라 코드 품질에 직접 반영 | 플랫폼 엔지니어링 팀이 내부 추상화를 강하게 설계하는 조직 |
| Terragrunt | 멀티 계정·멀티 환경 오케스트레이션, 반복 설정 제거, 스택 운영 보조 | Terraform/OpenTofu 위의 추가 계층이므로 디버깅과 온보딩 비용 증가 | 계정과 환경이 많고 모듈 재사용을 체계화해야 하는 대규모 팀 |

Terraform은 여전히 기본값에 가깝다. provider 생태계와 문서, 예제, 운영 경험이 압도적이기 때문이다. 하지만 기본값이라는 이유만으로 자동 선택해서는 안 된다. 라이선스 정책, 조직의 공급망 보안 기준, 상용 지원 필요성, 사내 표준 도구와의 통합성을 함께 봐야 한다.

OpenTofu는 Terraform 경험을 유지하면서도 오픈소스 거버넌스를 중시하는 팀에게 현실적인 대안이다. 다만 “명령어가 비슷하다”는 이유로 전환을 가볍게 보면 안 된다. provider 호환성, backend 동작, 모듈 레지스트리 사용 방식, CI/CD 이미지, 정책 엔진 연동을 실제 워크로드로 검증해야 한다.

Pulumi는 프로그래밍 언어 기반 추상화가 필요한 팀에게 매력적이다. 복잡한 조건문, 반복, 테스트, 패키지화를 일반 개발 워크플로 안에서 처리할 수 있다. 반대로 말하면 인프라 코드가 애플리케이션 코드처럼 복잡해질 수 있다. 간단한 네트워크·계정·IAM 기준선을 선언하는 팀에게는 과한 자유도가 오히려 위험이 된다.

Terragrunt는 Terraform이나 OpenTofu 자체를 대체하지 않는다. 운영 규모가 커졌을 때 반복되는 backend 설정, provider 구성, dependency, 환경별 변수 구조를 정리하는 보조 계층이다. 그러나 추상화는 항상 비용을 만든다. 장애 시 원인이 Terraform 코드인지 Terragrunt 구성인지, provider 이슈인지, state 문제인지 분해할 수 있는 운영 역량이 없다면 도입 효과보다 디버깅 비용이 클 수 있다.

## 실무 도입 장점: 표준화, 감사 가능성, 변경 예측성

잘 설계된 Terraform 기반 IaC는 세 가지 장점을 제공한다.

첫째, **변경의 표준화**다. 인프라 리소스 생성 방식이 모듈과 코드 리뷰로 통제되면 팀마다 다른 네이밍, 태그, 보안 그룹, IAM 정책을 만드는 일이 줄어든다. 특히 FinOps와 보안팀이 요구하는 비용 태그, 데이터 분류 태그, 소유자 태그를 모듈에 강제할 수 있다.

둘째, **감사 가능성**이다. 콘솔에서 누가 무엇을 바꿨는지 사후 추적하는 것보다, PR·plan·apply 로그를 연결하는 편이 훨씬 명확하다. 규제가 있는 산업에서는 변경 요청, 승인자, 실행자, 결과 로그가 분리되어야 하는데 Terraform은 이 구조를 CI/CD와 결합하기 쉽다.

셋째, **변경 예측성**이다. `plan`은 완벽한 보증은 아니지만, 코드 변경이 실제 리소스에 어떤 영향을 줄지 사전에 드러낸다. 데이터베이스 삭제, 로드밸런서 교체, IAM 권한 확대 같은 위험 변경을 자동으로 감지해 승인 절차를 강화할 수 있다.

다만 이 장점은 자동으로 생기지 않는다. Terraform을 로컬 노트북에서 수동 실행하고 state를 개인 권한으로 관리한다면 오히려 통제되지 않은 슈퍼 권한 도구가 된다. 실무 도입의 성패는 도구 설치가 아니라 운영 설계에 달려 있다.

## 보안·운영·성능·유지보수 리스크

Terraform 계열 IaC의 주요 리스크는 다음과 같다.

### 1. State 파일의 민감도

State에는 리소스 ID, 속성, 때로는 민감 출력 값이 포함될 수 있다. `sensitive = true`는 CLI 출력 억제에 도움을 주지만 state 자체를 암호화된 비밀 저장소로 바꾸지는 않는다. 따라서 원격 backend 암호화, 접근 제어, 감사 로그, 백업 정책이 필수다. state 접근 권한은 인프라 변경 권한과 별개로 설계해야 한다.

### 2. Provider 공급망 리스크

Terraform provider는 클라우드 API와 직접 통신한다. provider 버전이 바뀌면 리소스 diff 계산이나 API 호출 방식이 달라질 수 있다. `.terraform.lock.hcl` 관리, 사내 provider mirror, 검증된 버전 승격 절차가 필요하다. 특히 폐쇄망이나 규제가 있는 조직에서는 외부 레지스트리 의존성을 그대로 두기 어렵다.

### 3. 모듈 추상화의 부채

좋은 모듈은 반복을 줄이지만, 과도한 모듈은 이해하기 어려운 내부 DSL이 된다. 모든 옵션을 변수로 노출하면 모듈은 표준화를 제공하지 못하고, 너무 적게 노출하면 팀이 우회 코드를 만들게 된다. 모듈은 API처럼 버전 관리하고, breaking change 정책과 마이그레이션 가이드를 제공해야 한다.

### 4. Drift와 수동 변경

운영 장애 상황에서 콘솔 수동 변경이 발생할 수 있다. 문제는 그 이후다. IaC 코드와 실제 인프라가 어긋나면 다음 `apply`가 예기치 않은 롤백이나 삭제를 유발할 수 있다. 정기 `plan` 기반 drift 탐지, 예외 변경 등록, 사후 코드 반영 절차가 필요하다.

### 5. 성능과 실행 시간

대규모 state는 plan 시간을 늘리고, provider API rate limit에 걸릴 수 있다. 모든 리소스를 하나의 거대한 root module로 관리하면 작은 변경에도 전체 그래프를 확인해야 한다. 계정·도메인·수명주기 단위로 state를 분리하고, 의존성은 명시적으로 관리해야 한다.

## PoC 체크리스트: 도구 평가보다 운영 시나리오를 검증하라

Terraform 또는 대체 IaC 도구를 검토할 때는 “샘플 VPC 만들기” 수준의 PoC로는 부족하다. 다음 항목을 실제 조직 환경과 비슷하게 검증해야 한다.

- [ ] 최소 2개 환경(dev/prod)과 2개 계정 또는 프로젝트를 분리해 state backend를 설계한다.
- [ ] PR 생성 시 `plan`을 자동 실행하고 결과를 리뷰 화면에 표시한다.
- [ ] `apply`는 승인된 브랜치와 제한된 CI/CD 주체에서만 실행한다.
- [ ] provider와 module 버전을 고정하고, 업그레이드 PR을 별도 절차로 만든다.
- [ ] IAM, 네트워크, 데이터베이스처럼 위험도가 다른 리소스에 승인 정책을 다르게 적용한다.
- [ ] 수동 변경을 일부러 만든 뒤 drift 탐지와 복구 절차를 검증한다.
- [ ] state 백업·복구·잠금 충돌·동시 실행 실패 시나리오를 테스트한다.
- [ ] OpenTofu 또는 Pulumi 대안을 같은 리소스 범위로 구현해 학습 비용과 운영 로그 품질을 비교한다.
- [ ] 보안팀, 플랫폼팀, 애플리케이션팀이 각각 어떤 권한을 갖는지 RACI를 작성한다.

이 체크리스트를 통과하지 못한 상태에서 전사 표준 도구로 선포하면, IaC는 자동화가 아니라 병목이 될 가능성이 높다.

## 어떤 팀에 적합하고, 어떤 경우 피해야 하는가

Terraform 중심 접근은 다음 조직에 적합하다.

- 클라우드 리소스가 여러 계정·프로젝트·환경에 분산되어 있고, 변경 이력과 승인 절차가 중요한 조직
- 네트워크, IAM, 데이터베이스, Kubernetes, SaaS 설정을 일관된 방식으로 관리하려는 플랫폼팀
- 개발팀이 직접 인프라를 요청하되, 보안·비용·운영 기준은 중앙에서 강제해야 하는 조직
- 기존 Terraform 모듈과 인력 풀이 이미 존재해 전환 비용보다 표준화 효과가 큰 조직

반대로 다음 상황에서는 신중해야 한다.

- 인프라 규모가 작고 변경 빈도가 낮아 수동 절차와 문서만으로 충분한 초기 팀
- state, backend, CI/CD, 권한 모델을 설계할 운영 역량이 아직 없는 조직
- 모든 팀이 서로 다른 방식으로 모듈을 만들 가능성이 높고, 중앙 플랫폼 표준을 합의하지 못한 조직
- 리소스 생성보다 런타임 오케스트레이션이나 애플리케이션 배포가 핵심인데 IaC에 과도한 기대를 거는 경우

특히 “Terraform을 도입하면 클라우드 운영이 자동으로 표준화된다”는 기대는 위험하다. Terraform은 조직의 운영 규칙을 코드로 표현하는 도구이지, 규칙 자체를 만들어 주는 도구가 아니다.

## 향후 관찰 지표와 전망

앞으로 IaC 생태계에서 관찰해야 할 지표는 네 가지다.

첫째, Terraform과 OpenTofu의 호환성 및 분기 속도다. 기능 차이가 커질수록 조직은 단순한 명령어 전환이 아니라 생태계 선택을 해야 한다. provider와 module 작성자가 어느 쪽을 우선 지원하는지도 중요하다.

둘째, Pulumi처럼 일반 언어 기반 IaC가 플랫폼 엔지니어링 내부 도구와 얼마나 결합하는지다. AI 코딩 도구가 인프라 코드를 생성하는 일이 늘수록 타입 시스템, 테스트, 패키지 관리가 장점으로 작동할 수 있다. 동시에 복잡한 추상화를 남발하면 인프라 코드 리뷰가 더 어려워질 수 있다.

셋째, 정책 엔진과 CI/CD 통합이다. Open Policy Agent, Sentinel, Checkov, tfsec 같은 도구가 plan 단계와 결합해 위험 변경을 자동 분류하는 방식이 더 중요해질 것이다. 단순 lint를 넘어 “이 변경은 운영 데이터베이스 삭제 가능성이 있으므로 보안 책임자 승인이 필요하다”는 수준의 정책화가 필요하다.

넷째, drift 탐지와 운영 관측성이다. IaC 실행 결과가 로그, 비용, 보안 이벤트, CMDB와 연결되지 않으면 인프라 변경의 실제 영향이 보이지 않는다. 앞으로의 IaC 플랫폼은 코드 저장소와 클라우드 API 사이의 얇은 CLI가 아니라, 변경 통제와 운영 관측을 연결하는 관리 평면에 가까워질 가능성이 높다.

## 결론: Terraform Trending의 의미는 ‘오래된 표준의 생존’이 아니라 운영 모델의 재설계다

오늘 GitHub Trending에서 Terraform이 다시 보인 것은 레거시 도구의 일시적 회귀가 아니다. 인프라가 더 복잡해지고, 오픈소스 라이선스와 벤더 종속성에 대한 민감도가 높아지며, 플랫폼 엔지니어링이 조직의 핵심 역량으로 부상한 결과다. Terraform은 여전히 강력한 기본 선택지지만, OpenTofu는 오픈소스 거버넌스 대안을 제공하고, Pulumi는 언어 기반 추상화의 가능성을 보여주며, Terragrunt는 대규모 운영에서 반복과 스택 관리 문제를 해결하려 한다.

실무 의사결정자가 지금 해야 할 일은 특정 도구를 유행에 따라 바꾸는 것이 아니다. 현재 조직의 state 관리, 권한 분리, plan 리뷰, apply 승인, provider 공급망, drift 탐지, 모듈 버전 정책을 점검해야 한다. 그 결과 Terraform을 유지할 수도 있고, OpenTofu를 검토할 수도 있으며, 일부 플랫폼 영역에서는 Pulumi나 Terragrunt를 병행할 수도 있다.

중요한 것은 IaC를 “인프라를 만드는 코드”로만 보지 않는 것이다. 성숙한 조직에서 IaC는 변경 통제, 보안 기준, 비용 관리, 감사 가능성, 운영 회복력을 담는 실행 계약이다. Terraform이 다시 Trending에 오른 오늘의 신호는 바로 그 계약을 다시 설계할 때가 되었다는 뜻으로 읽을 수 있다.
