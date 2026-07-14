---
title: "CubeSandbox와 AI 코드 실행 샌드박스의 인프라화"
description: "GitHub Trending에 오른 TencentCloud/CubeSandbox를 중심으로 KVM MicroVM, RustVMM, eBPF, L7 egress, Copy-on-Write 스냅샷 기반 AI 코드 실행 샌드박스가 왜 플랫폼 인프라 의제가 되었는지 분석한다."
author: heracles-jo
date: 2026-07-02 07:09:00 +0900
categories: [Cloud Infrastructure, Platform Engineering]
tags: [github-trending, cubesandbox, microvm, ai-sandbox, kvm, rustvmm, ebpf, egress-control, copy-on-write, platform-engineering, secure-code-execution, e2b, daytona]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-cubesandbox-microvm-ai-sandbox/cover.svg
  alt: "CubeSandbox를 중심으로 KVM MicroVM, eBPF 네트워크 격리, L7 egress 프록시, Copy-on-Write 스냅샷이 AI 코드 실행 샌드박스 운영 평면을 구성하는 흐름"
---

GitHub Trending daily에서 [TencentCloud/CubeSandbox](https://github.com/TencentCloud/CubeSandbox)가 눈에 띈 이유는 “AI 에이전트를 위한 또 하나의 실행 도구”가 등장했기 때문만은 아니다. 2026년 7월 2일 KST 오전 확인 시점의 공개 스냅샷 기준으로 CubeSandbox 저장소는 약 6.7천 개의 스타, 560개 이상의 포크, 90개대 공개 이슈, 2026년 6월 15일 공개된 [v0.4.0 릴리스](https://github.com/TencentCloud/CubeSandbox/releases/tag/v0.4.0), 그리고 7월 1일까지 이어진 커밋 활동을 보였다. README는 이 프로젝트를 RustVMM과 KVM 기반의 고성능 보안 샌드박스 서비스로 소개하며, E2B SDK 호환 API, 60ms 미만 샌드박스 생성, 5MB 미만 메모리 오버헤드, 하드웨어 수준 격리, egress 보안 프록시를 전면에 둔다. 수치는 프로젝트가 주장하는 설계 목표이므로 실제 운영 환경에서는 별도 검증이 필요하지만, 어떤 문제가 시장의 관심을 끌고 있는지는 분명하다.

오늘의 기술 흐름은 **AI 에이전트 자체가 아니라 AI가 생성하거나 선택한 코드를 안전하게 실행하는 런타임이 별도 플랫폼 인프라로 분리되는 현상**이다. 최근 많은 팀이 LLM에게 Python 스크립트 실행, 브라우저 자동화, 데이터 분석, 테스트 생성, 파일 변환, 외부 API 호출을 맡기고 있다. 문제는 이 코드가 완전히 신뢰할 수 있는 코드가 아니라는 점이다. 프롬프트 인젝션, 패키지 설치, 임시 파일, 네트워크 호출, 비밀정보 접근, 무한 루프, 과도한 리소스 사용이 모두 실행 계층의 리스크가 된다. 따라서 “모델이 얼마나 똑똑한가”만큼이나 “그 모델이 무언가를 실행할 때 어떤 격리와 관측, 네트워크 정책을 적용할 것인가”가 플랫폼팀의 핵심 질문이 되었다.

모든 저장소 수치와 활동 상태는 위 확인 시점의 스냅샷이다. GitHub Trending 순위, 스타 증가, 이슈 수, 릴리스 상태는 시간에 따라 바뀔 수 있으며, 이 글은 특정 제품의 보안성·성능·비용 효과를 보장하지 않는다.

## 오늘의 후보 비교: 왜 CubeSandbox를 선택했나

이번 조사에서는 GitHub Trending daily와 weekly를 함께 확인하고 최근 블로그에서 다룬 주제와의 중복을 피했다. daily에는 AI 침투 테스트 도구 [usestrix/strix](https://github.com/usestrix/strix), 오픈 디자인 시스템 [facebook/astryx](https://github.com/facebook/astryx), PDF 선형화 도구 [allenai/olmocr](https://github.com/allenai/olmocr), 일본어 입력기 [togatoga/karukan](https://github.com/togatoga/karukan), 셀프호스티드 비주얼 CMS [CoreBunch/Instatic](https://github.com/CoreBunch/Instatic), 그리고 CubeSandbox가 보였다. weekly에는 이미 다룬 프라이버시 메시징, 코드베이스 메모리 MCP, 에이전트 네이티브 프레임워크 계열과 함께 [google-labs-code/design.md](https://github.com/google-labs-code/design.md), [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes), [calesthio/OpenMontage](https://github.com/calesthio/OpenMontage) 같은 후보가 있었다.

최근 글에서 에이전트 네이티브 소프트웨어, 토큰 절감형 AI 코딩 도구, 로컬 벡터 인덱스, LLM KV 캐시, AI 영상 편집, 인증·인가 인프라 등을 다뤘기 때문에 오늘은 애플리케이션 레벨의 에이전트 기능보다 **실행 격리 런타임**에 초점을 맞췄다. CubeSandbox는 AI 에이전트라는 키워드를 쓰지만, 핵심은 LLM 기능이 아니라 KVM MicroVM, RustVMM, eBPF, L7 egress, XFS reflink, E2B 호환 API로 구성된 인프라 계층이다. 이 점이 기존 글과 차별화된다.

| 후보 저장소 | 확인 시점 신호 | 이번 글에서의 판단 |
|---|---:|---|
| [TencentCloud/CubeSandbox](https://github.com/TencentCloud/CubeSandbox) | 약 6.7k stars, Rust, v0.4.0, 7월 1일 커밋 | 비신뢰 코드 실행 인프라라는 논지가 명확해 선택 |
| [usestrix/strix](https://github.com/usestrix/strix) | 약 2.9만 stars, Python, v1.0.4 | AI 보안 도구 자체보다 실행 격리 인프라 흐름을 우선 |
| [facebook/astryx](https://github.com/facebook/astryx) | 약 2.5k stars, TypeScript, v0.1.2 | 디자인 시스템·에이전트 협업 주제는 흥미롭지만 코딩 에이전트 각도와 일부 중복 |
| [allenai/olmocr](https://github.com/allenai/olmocr) | 약 1.8만 stars, Python, PDF 선형화 | 문서 AI 파이프라인은 기존 문서 파서 글과 중복 위험 |
| [togatoga/karukan](https://github.com/togatoga/karukan) | 약 560 stars, Rust, 입력기·Kana-Kanji 변환 | 기술적으로 흥미롭지만 기업 플랫폼 의사결정 글로 확장 폭이 제한적 |
| [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes) | 약 4.7k stars, Go, 빈번한 릴리스 | Git 안전장치 단일 도구에 가까워 장문 인프라 분석 후보로는 보류 |

## 왜 지금 AI 코드 실행 샌드박스가 중요해졌나

과거의 코드 실행 샌드박스는 주로 온라인 저지, 교육용 노트북, 데이터 과학 플랫폼, CI/CD 격리 환경에서 논의되었다. 사용자는 비교적 명확했고, 실행 단위도 사람이 제출한 코드나 사전에 정의된 빌드 작업이었다. 지금은 상황이 다르다. LLM이 사용자의 자연어 요청을 해석해 코드를 만들고, 그 코드를 즉시 실행하며, 실행 결과를 다시 해석해 다음 행동을 결정한다. 사람이 직접 작성하지 않은 코드가 사람의 권한을 빌려 움직이는 구조가 된 것이다.

이 구조에서는 세 가지 리스크가 동시에 커진다. 첫째, 코드의 의도가 불명확하다. 모델은 유용한 스크립트를 만들 수도 있지만, 프롬프트 인젝션이나 잘못된 도구 설명 때문에 의도하지 않은 파일 읽기, 네트워크 호출, 패키지 설치를 시도할 수 있다. 둘째, 실행 환경이 장기 상태를 갖기 시작한다. 단발성 코드 인터프리터라면 매번 초기화하면 되지만, 에이전트가 브라우저 세션, 개발 서버, 임시 데이터베이스, 테스트 상태를 유지하려면 스냅샷·롤백·포크가 필요하다. 셋째, 외부 API와 내부 시스템 접근이 늘어난다. 코드가 Slack, GitHub, 사내 문서, 클라우드 스토리지, 결제 API를 호출하기 시작하면 네트워크 egress와 자격증명 주입이 핵심 통제 지점이 된다.

이 때문에 단순 컨테이너만으로 충분한지, 별도 커널을 갖는 MicroVM이 필요한지, 관리형 서비스에 맡길지, 자체 운영할지를 판단해야 한다. Docker 컨테이너는 빠르고 생태계가 성숙했지만 커널을 공유한다. Firecracker 계열 MicroVM은 격리 강도를 높일 수 있지만 운영 복잡도가 증가한다. 관리형 코드 인터프리터 서비스는 빠른 PoC에 유리하지만 데이터 경계, 네트워크 정책, 비용 예측성에서 제약이 생길 수 있다. CubeSandbox가 Trending에 오른 배경은 이 선택지가 더 이상 연구실 문제가 아니라 제품팀과 플랫폼팀의 실제 구매·구축 의제로 올라왔다는 신호로 해석할 수 있다.

![CubeSandbox 아키텍처 개념도](https://heracles-jo.github.io/assets/img/posts/github-trending-cubesandbox-microvm-ai-sandbox/architecture.svg)

## CubeSandbox의 핵심 구조: MicroVM, 제어 평면, 데이터 평면

CubeSandbox 문서의 [Architecture Overview](https://github.com/TencentCloud/CubeSandbox/blob/master/docs/architecture/overview.md)를 보면 구조는 비교적 명확하다. 클라이언트는 E2B 호환 REST API를 통해 CubeAPI에 요청하고, CubeAPI는 내부 gRPC로 CubeMaster에 전달한다. CubeMaster는 샌드박스 생성·삭제·일시정지·재개를 조율하고 노드를 선택한다. 실제 실행은 각 노드의 Cubelet, CubeShim, CubeHypervisor가 맡으며, Hypervisor는 RustVMM과 KVM을 사용해 MicroVM을 부팅한다. 스토리지는 CubeCoW가 XFS reflink를 활용해 스냅샷과 클론을 빠르게 처리하고, 네트워크는 CubeVS와 CubeEgress가 담당한다.

이 구조에서 중요한 구분은 제어 평면과 데이터 평면이다. CubeAPI, CubeMaster, WebUI, Redis는 샌드박스 메타데이터와 스케줄링을 다루는 제어 평면이다. Cubelet, CubeShim, CubeHypervisor, CubeCoW, CubeVS, CubeEgress, CubeProxy는 노드 로컬에서 실행되는 데이터 평면이다. 문서는 제어 평면을 상태 비저장에 가깝게 설계하고 Redis를 조율 지점으로 사용한다고 설명한다. 이는 수평 확장을 단순화하는 장점이 있지만, Redis와 메타데이터 저장소의 가용성·백업·네트워크 분리가 운영상 중요해진다는 뜻이기도 하다.

MicroVM 접근의 가장 큰 목적은 공유 커널 공격면을 줄이는 것이다. 일반 컨테이너는 네임스페이스와 cgroup, seccomp, AppArmor/SELinux로 격리를 강화하지만 호스트 커널을 공유한다. 비신뢰 코드 실행에서는 커널 취약점이나 런타임 설정 실수가 치명적일 수 있다. CubeSandbox는 각 샌드박스가 독립 Linux 커널을 갖는 KVM MicroVM에서 실행된다는 점을 강조한다. 물론 MicroVM도 만능은 아니다. KVM, 가상 디바이스, vsock, 네트워크 브리지, 이미지 공급망, 호스트 커널 패치라는 별도 공격면이 생긴다. 따라서 “MicroVM이면 안전하다”가 아니라 “격리 경계가 어디로 이동하는지”를 이해해야 한다.

또 하나의 핵심은 빠른 생성과 상태 관리다. AI 에이전트 워크로드는 짧은 작업을 대량 병렬로 실행하거나, 같은 기준 상태에서 여러 경로를 탐색하는 경우가 많다. 매번 전체 이미지를 복사하면 비용이 커지고, 매번 긴 부팅을 기다리면 사용자 경험이 나빠진다. CubeSandbox는 사전 스냅샷 템플릿, RustVMM restore path, XFS reflink 기반 Copy-on-Write를 통해 빠른 샌드박스 생성과 O(1)에 가까운 클론을 지향한다. 실무적으로는 디스크 파일시스템 요구사항이 곧 운영 요구사항이 된다. Quick Start 문서도 `/data/cubelet`에 XFS를 요구하고, Ubuntu/Debian/WSL 기본 ext4 환경에서는 별도 XFS 마운트가 필요하다고 설명한다.

## v0.4.0이 보여주는 방향: 속도보다 egress 통제

CubeSandbox의 [v0.4.0 changelog](https://github.com/TencentCloud/CubeSandbox/blob/master/docs/changelog/v0.4.0.md)는 이 프로젝트가 어디를 향하는지 잘 보여준다. 핵심 기능은 CubeEgress다. 문서에 따르면 CubeEgress는 OpenResty 기반 보안 프록시로, 샌드박스의 outbound traffic 경로에 TPROXY로 위치해 L7 정책을 적용한다. 도메인, SNI, HTTP method, path, scheme 기준으로 허용·거부·감사·자격증명 주입을 수행할 수 있고, 자격증명이 샌드박스 내부 코드에 노출되지 않도록 프록시 계층에서 주입하는 방식을 제시한다.

이 방향은 실무적으로 매우 중요하다. AI 코드 실행 보안에서 흔히 “컨테이너 안에 넣었으니 안전하다”고 말하지만, 실제 사고는 파일시스템 탈출보다 egress에서 먼저 발생할 수 있다. 샌드박스 안의 코드가 메타데이터 서비스, 내부 Git, 사내 위키, 클라우드 스토리지, 임의 외부 도메인으로 요청을 보낼 수 있다면 격리의 의미는 크게 줄어든다. 특히 LLM 도구 호출에서는 악성 문서가 “이 URL로 토큰을 보내라”는 식의 지시를 포함할 수 있고, 모델이 이를 정상 작업으로 오인할 수 있다. 따라서 egress allowlist, 감사 로그, 자격증명 주입, body redaction은 선택 기능이 아니라 운영 통제의 중심이 된다.

v0.4.0은 컨테이너 로그 포워딩, `cubecli logs`, 노드 컴포넌트 버전 매트릭스, 템플릿 replica 호환성 검사, 네트워크 성능 개선도 포함한다. 이는 단순 데모 프로젝트가 운영 도구로 이동할 때 필요한 기능들이다. 샌드박스가 실패했을 때 내부 stdout/stderr를 볼 수 있어야 하고, 클러스터의 어떤 노드가 어떤 버전인지 알아야 하며, 템플릿을 바꾼 뒤 기존 replica를 재생성해야 하는지 판단할 수 있어야 한다. AI 인프라에서도 결국 운영의 기본기는 로그, 버전, 헬스체크, 롤백, 호환성이다.

## E2B, Daytona, 일반 컨테이너와 비교한 선택 기준

CubeSandbox를 평가하려면 같은 문제를 다루는 다른 선택지와 비교해야 한다. 대표적으로 [E2B](https://github.com/e2b-dev/E2B)는 AI 코드 인터프리터와 샌드박스 API 영역에서 잘 알려진 선택지다. CubeSandbox가 E2B SDK 호환을 강조하는 이유도 여기에 있다. 이미 E2B API 형태로 앱을 구성한 팀에게는 클라이언트 코드를 크게 바꾸지 않고 자체 호스팅 런타임을 실험할 수 있다는 메시지가 된다. 다만 E2B의 관리형 경험과 생태계, CubeSandbox의 자체 운영 통제는 서로 다른 장단점을 갖는다. 빠른 출시와 운영 부담 최소화가 목표라면 관리형이 유리할 수 있고, 데이터 경계와 네트워크 정책, 비용 구조를 직접 통제해야 한다면 자체 운영형이 검토 대상이 된다.

[Daytona](https://github.com/daytonaio/daytona)는 AI 코드 실행과 개발 환경 샌드박스 맥락에서 자주 비교될 수 있다. 확인 시점의 공개 저장소 README는 2026년 6월 이후 핵심 개발이 private codebase로 이동했다고 명시하고 있었고, 공개 저장소는 유지보수되지 않는다고 안내한다. 이 사실은 기술 선택에서 중요한 교훈을 준다. 샌드박스 인프라는 API 사용성만 보고 고르면 안 된다. 오픈소스 저장소의 유지보수 정책, 라이선스, 릴리스 지속성, 기업의 제품 전략 변화까지 장기 운영 리스크로 봐야 한다.

일반 Kubernetes 기반 컨테이너 격리도 여전히 유효한 대안이다. 신뢰된 내부 코드, 제한된 데이터 처리, 네트워크가 폐쇄된 배치 작업에는 컨테이너가 단순하고 비용 효율적이다. Kata Containers, gVisor, Firecracker 기반 런타임 같은 중간 선택지도 있다. 핵심은 “AI니까 무조건 MicroVM”이 아니다. 비신뢰 코드, 외부 입력 기반 코드 생성, 인터넷 접근, 고객별 데이터 격리, 대량 병렬 실행, 강한 감사 요구가 겹칠수록 MicroVM과 egress 통제의 가치가 커진다.

![AI 샌드박스 도입 판단 매트릭스](https://heracles-jo.github.io/assets/img/posts/github-trending-cubesandbox-microvm-ai-sandbox/decision-matrix.svg)

## 실무 도입 장점: 격리 경계와 운영 경계를 명확히 한다

CubeSandbox 같은 인프라를 도입할 때 가장 먼저 보이는 장점은 비신뢰 코드 실행의 격리다. 사용자가 업로드한 노트북, LLM이 생성한 Python, 크롤러 스크립트, 브라우저 자동화, 테스트 러너를 동일한 호스트에서 실행하면서도 샌드박스마다 독립 커널을 부여할 수 있다. 특히 고객 데이터가 섞이면 “컨테이너 네임스페이스로 충분한가”라는 질문에 보안팀이 쉽게 동의하지 않을 수 있다. MicroVM은 이 논의를 조금 더 명확한 하드웨어 가상화 경계로 이동시킨다.

두 번째 장점은 스냅샷과 포크 기반의 실행 모델이다. AI 에이전트는 같은 기준 환경에서 여러 경로를 탐색하고 실패한 상태를 되돌리는 일이 많다. 예를 들어 코드 수정 에이전트가 세 가지 패치를 병렬 실험하거나, 데이터 분석 에이전트가 서로 다른 전처리 방법을 비교하거나, 브라우저 자동화 에이전트가 특정 로그인 상태를 보존한 채 여러 작업을 나눠 실행할 수 있다. 스냅샷·롤백·클론이 빠르면 에이전트 품질뿐 아니라 비용과 지연시간에도 영향을 준다.

세 번째 장점은 egress와 자격증명 통제를 런타임 계층으로 내릴 수 있다는 점이다. 애플리케이션 코드에서만 API 키를 관리하면 샌드박스 내부 코드가 실수로 키를 로그에 남기거나 외부로 전송할 수 있다. 프록시 계층에서 도메인과 경로를 검사하고, 허용된 요청에만 자격증명을 주입하면 최소 권한 설계가 쉬워진다. 물론 이를 제대로 쓰려면 정책 모델과 비밀정보 저장소, 감사 로그 파이프라인이 함께 설계되어야 한다.

## 한계와 리스크: 설치보다 운영이 어렵다

첫 번째 리스크는 인프라 전제 조건이다. CubeSandbox Quick Start는 x86_64 서버, root 권한, 인터넷 접근, glibc 2.31 이상, 충분한 디스크, XFS reflink 요구사항을 제시한다. 클라우드 VM에서 KVM 사용이 제한되거나 nested virtualization이 맞지 않으면 배포 방식이 복잡해질 수 있다. 멀티노드 문서는 compute node가 물리 머신 또는 bare-metal server이고 KVM이 활성화되어야 한다고 설명한다. 이는 Kubernetes 앱 하나 배포하는 것과는 다른 운영 난이도다.

두 번째 리스크는 네트워크 노출면이다. [Network Hardening](https://github.com/TencentCloud/CubeSandbox/blob/master/docs/guide/network-hardening.md) 문서는 개발·평가용 배포에서 여러 관리 서비스가 기본적으로 `0.0.0.0`에 바인드될 수 있고, 일부 관리 엔드포인트에 인증이나 TLS가 없다고 경고한다. 실제 운영에서는 CubeMaster, CubeAPI, Cubelet gRPC/HTTP, WebUI, CubeProxy의 바인드 주소와 방화벽을 명확히 분리해야 한다. 샌드박스를 안전하게 만들려다 관리 평면을 인터넷에 노출하면 더 큰 문제가 된다.

세 번째 리스크는 관측성과 비용 예측이다. MicroVM을 대량으로 띄우면 CPU steal, 메모리 오버커밋, 디스크 CoW 파편화, 이미지 캐시, 네트워크 프록시 지연, 로그 저장 비용이 모두 문제가 된다. README의 “60ms 미만”이나 “5MB 미만” 같은 수치는 관심을 끄는 지표지만, 실제 PoC에서는 템플릿 크기, 패키지 설치, 동시 실행 수, egress 정책, 스토리지 종류, 워크로드 지속시간에 따라 달라진다. 운영팀은 평균 지연시간보다 P95/P99, 실패율, 노드별 밀도, 복구 시간, 로그·메트릭 비용을 봐야 한다.

네 번째 리스크는 프로젝트 성숙도다. CubeSandbox는 2026년 4월 생성된 비교적 새 저장소이고, 릴리스와 커밋이 빠르게 진행 중이다. 빠른 변화는 장점이지만 API 안정성, 업그레이드 경로, 보안 패치 정책, 장기 지원 버전, 라이선스 해석, 커뮤니티 응답성을 확인해야 한다. 특히 비신뢰 코드 실행 인프라는 보안 사고의 blast radius가 크므로, “스타가 많다”는 이유만으로 프로덕션 핵심 경로에 바로 넣어서는 안 된다.

## PoC 체크리스트: 무엇을 검증해야 하나

CubeSandbox 또는 유사 MicroVM 샌드박스를 검토한다면 PoC는 기능 데모가 아니라 운영 가설 검증이어야 한다. 다음 항목을 최소 기준으로 권한다.

1. **격리 요구 정의**: 실행할 코드가 내부 신뢰 코드인지, 고객 입력 기반 코드인지, LLM 생성 코드인지 구분한다. 고객별 데이터와 비밀정보가 섞이는지 명확히 한다.
2. **노드 전제 조건 확인**: KVM, glibc, XFS reflink, 디스크 용량, 네트워크 라우팅, 방화벽, 커널 버전을 실제 배포 대상에서 점검한다.
3. **시작 시간과 밀도 측정**: 템플릿별 cold start, warm start, clone, rollback, pause/resume의 P50/P95/P99를 측정한다.
4. **egress 정책 검증**: 허용 도메인, 차단 도메인, HTTP method/path 정책, DNS 처리, 감사 로그, body redaction, 자격증명 주입을 실제 공격 시나리오로 테스트한다.
5. **리소스 제한 검증**: CPU, 메모리, 디스크, 네트워크 대역폭, 프로세스 수, 실행 시간 제한이 우회되지 않는지 확인한다.
6. **관리 평면 보호**: CubeAPI, CubeMaster, Cubelet, WebUI가 사설망 또는 인증된 경로로만 접근 가능한지 점검한다.
7. **로그·감사 파이프라인**: 샌드박스 stdout/stderr, egress 로그, 관리 이벤트, 템플릿 변경 이력을 SIEM 또는 로그 저장소로 보낸다.
8. **업그레이드와 롤백**: v0.4.0 같은 릴리스 업그레이드에서 템플릿 replica 호환성, 노드 버전 불일치, 데이터 마이그레이션을 검증한다.
9. **비용 모델링**: 동시 샌드박스 수, 평균 실행 시간, 노드당 밀도, 로그 저장, egress 비용을 실제 트래픽으로 추정한다.
10. **장애 주입**: Redis 장애, 노드 장애, 프록시 장애, 스토리지 full, egress 프록시 지연을 넣고 복구 절차를 문서화한다.

## 어떤 팀에 적합하고 어떤 경우 피해야 하나

CubeSandbox류의 MicroVM 샌드박스는 LLM 기반 코드 실행을 제품 핵심 기능으로 제공하는 팀, 고객별 격리가 중요한 데이터 분석 플랫폼, 브라우저 자동화나 크롤링을 대규모로 운영하는 팀, 비신뢰 플러그인·확장 코드를 실행하는 SaaS, 규제 산업에서 egress 감사와 자격증명 통제가 필요한 조직에 적합하다. 특히 이미 E2B 스타일 API로 프로토타입을 만들었고, 다음 단계에서 자체 호스팅과 정책 통제를 검토하는 팀이라면 PoC 가치가 있다.

반대로 단순 내부 배치 작업이나 신뢰된 사내 코드 실행, 낮은 동시성의 실험 기능, 플랫폼 운영 인력이 거의 없는 초기 제품팀에는 과할 수 있다. 이 경우 관리형 코드 인터프리터, 제한된 컨테이너 실행, 서버리스 잡, 기존 CI 런타임을 먼저 검토하는 편이 현실적이다. 보안 요구가 높더라도 KVM·스토리지·네트워크 운영 역량이 없다면 자체 구축은 리스크가 더 클 수 있다. 보안 인프라는 강력한 도구를 설치하는 일이 아니라, 계속 패치하고 모니터링하고 정책을 갱신하는 운영 체계다.

## 앞으로 관찰할 지표와 전망

앞으로는 AI 샌드박스 시장에서 세 가지 지표를 관찰해야 한다. 첫째, API 호환성이다. E2B 호환처럼 사실상 표준 API가 형성되면 애플리케이션은 관리형과 자체 호스팅을 오갈 수 있고, 런타임 공급자 간 경쟁이 촉진된다. 둘째, egress와 자격증명 정책의 정교함이다. 단순 인터넷 차단을 넘어 도메인·경로·메서드·본문 레벨 감사와 비밀정보 주입이 제품의 차별점이 될 것이다. 셋째, 운영 성숙도다. 샌드박스 생성 속도보다 중요한 것은 업그레이드, 장애 복구, 버전 매트릭스, 템플릿 호환성, 취약점 대응이다.

CubeSandbox가 GitHub Trending에 오른 것은 AI 에이전트 열풍의 또 다른 표면 현상으로 볼 수도 있다. 하지만 더 깊게 보면, 소프트웨어 산업이 “모델에게 무엇을 시킬 것인가”에서 “모델이 실행하는 행위를 어떤 운영 경계 안에 둘 것인가”로 이동하고 있다는 신호다. AI 기능이 제품의 주변 기능일 때는 관리형 API와 단순 컨테이너로 충분할 수 있다. 그러나 AI가 코드를 만들고, 실행하고, 네트워크를 호출하고, 고객 데이터를 다루기 시작하면 샌드박스는 부가 기능이 아니라 플랫폼의 보안·운영 핵심 계층이 된다. 오늘 CubeSandbox를 주목해야 하는 이유는 바로 그 전환점에 있다.
