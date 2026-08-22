---
title: "MAX 이기종 AI 추론: CUDA 종속성을 줄일 때의 비용"
description: "Modular MAX와 Mojo의 통합 추론 스택을 분석해 NVIDIA·AMD·Apple 간 이식성, 성능 검증, 라이선스와 운영 전환 비용의 판단 기준을 정리한다."
author: heracles-jo
date: 2026-08-23 07:40:00 +0900
categories: [AI Infrastructure, Platform Engineering]
tags: [modular-max, mojo, llm-inference, gpu-programming, hardware-portability, platform-engineering]
image:
  path: https://heracles-jo.github.io/assets/img/posts/modular-max-hardware-portable-ai-inference/cover.svg
  alt: "Modular MAX가 하나의 모델 서빙 경로를 NVIDIA, AMD, Apple 하드웨어로 연결하는 모습"
---

LLM 추론 플랫폼이 NVIDIA GPU 한 종류에서만 돌아갈 때 CUDA는 제약보다 강력한 기본값이다. 문제는 비용·조달·엣지 요구가 달라져 AMD GPU나 Apple Silicon까지 평가해야 하는 순간 시작된다. 모델 API는 같아 보여도 커널, 양자화, 메모리 할당, 그래프 컴파일, 관측성 도구가 하드웨어마다 갈라진다. 이때 “멀티 GPU 지원”은 장치 이름을 하나 더 추가하는 기능이 아니라 **성능과 장애 대응 방식을 여러 번 운영하는 문제**가 된다.

2026년 8월 23일 07:45 KST 공개 스냅샷에서 [modular/modular](https://github.com/modular/modular)는 GitHub Trending daily에 **395 stars today**, weekly에 **1,643 stars this week**로 표시됐다. GitHub API에서는 약 **28.8k stars**, **3.1k forks**, **1.1k open issues/PR**, 8월 22일의 최신 push를 확인했다. 최신 안정 릴리스는 8월 11일 공개된 [MAX 26.5 / Mojo 1.0.0](https://github.com/modular/modular/releases/tag/max/v26.5.0)이다. 수치와 상태는 확인 시점 이후 달라질 수 있다.

이 글은 “Mojo가 CUDA보다 빠른가”를 단정하지 않는다. 질문은 더 실무적이다. **MAX가 제안하는 모델 서빙·그래프·커널의 통합 스택이 하드웨어 선택권을 실제 운영 자산으로 바꿀 수 있는가, 그리고 그 이식성을 얻기 위해 무엇을 다시 검증해야 하는가**다.

![MAX 이기종 추론 스택의 계층과 검증 경계](https://heracles-jo.github.io/assets/img/posts/modular-max-hardware-portable-ai-inference/architecture.svg)

## 후보 비교: 반복되는 에이전트 글보다 하드웨어 이식성을 택했다

이번 실행 환경에서는 Search Console과 Analytics의 검색어·노출·CTR 데이터에 접근할 수 없었다. 따라서 접근했다고 가정하지 않고 GitHub Trending daily·weekly 후보와 기존 94개 글의 제목, description, 저장소 링크, 중심 논지를 대조했다.

| 후보 | 확인 시점 신호 | 검색 의도와 장기 가치 판단 |
|---|---:|---|
| [openai/codex](https://github.com/openai/codex) | daily 1,978 stars today | 코딩 에이전트 운영은 스킬·CLI·병렬 에이전트 글과 중심 의도가 겹친다. |
| [mattpocock/skills](https://github.com/mattpocock/skills) | daily 2,684 stars today | 에이전트 스킬 절차화와 공급망 보안은 이미 독립 글로 다뤘다. |
| [makeplane/plane](https://github.com/makeplane/plane) | daily 263 stars today | 셀프호스팅 프로젝트 관리는 최근 Kaneo 글과 같은 도입 의도다. |
| [Tencent/AI-Infra-Guard](https://github.com/Tencent/AI-Infra-Guard) | daily 161 stars today | AI 인프라 스캔은 유효하지만 Strix·SkillSpector 보안 글과 독자 질문이 인접한다. |
| [modular/modular](https://github.com/modular/modular) | daily 395, weekly 1,643 stars | 이기종 GPU 추론과 커널 이식성은 기존 저VRAM·CPU/GPU 분할·Apple 서빙과 다른 **플랫폼 선택** 의도에 답한다. |

MAX는 앞선 글의 대체 주제가 아니라 그 아래 공통 기반 후보다. [KTransformers의 CPU·GPU 이기종 추론](/posts/github-trending-ktransformers-heterogeneous-llm-inference/)은 한 모델의 가중치와 연산을 서로 다른 자원에 나눠 VRAM 한계를 넘는 문제를 다뤘다. 이 글의 이기종성은 NVIDIA·AMD·Apple처럼 **서로 다른 가속기 계열에 같은 운영 모델을 적용할 수 있는가**에 가깝다. [OMLX의 Apple Silicon 서빙](/posts/github-trending-omlx-apple-silicon-llm-server/) 역시 Mac에 최적화된 선택이고, MAX는 더 넓은 하드웨어 포트폴리오를 하나의 스택으로 묶으려는 선택이다.

## MAX와 Mojo를 한 제품명으로 뭉뚱그리면 안 된다

공식 [저장소 README](https://github.com/modular/modular/blob/main/README.md)는 공개 구성 요소를 Mojo compiler의 `KGEN`, Mojo 표준 라이브러리, MAX accelerator library의 커널, OpenAI 호환 MAX inference server, Python 기반 model pipeline으로 나눈다. 즉 MAX는 단순한 서버 바이너리도, Mojo는 “빠른 Python” 문법만도 아니다.

운영 관점에서는 네 층으로 이해하는 편이 정확하다.

1. **서빙 인터페이스**는 OpenAI 호환 endpoint로 애플리케이션과 모델 런타임을 분리한다.
2. **모델 파이프라인**은 Python API로 모델 구조와 가중치 로딩, 그래프 구성을 표현한다.
3. **컴파일·실행 계층**은 그래프를 대상 하드웨어에서 실행 가능한 형태로 내린다.
4. **가속기 라이브러리와 Mojo 커널**은 attention, GEMM, 메모리 이동 같은 성능 임계 경로를 구현한다.

이 구조의 가치는 상단 API가 같다는 데만 있지 않다. 모델 bring-up 과정에서 Python graph와 하위 커널을 같은 저장소·릴리스 흐름 안에서 추적할 수 있다는 데 있다. 반대로 네 층 중 하나라도 대상 모델이나 장치를 지원하지 않으면 “한 번 설치해 모든 플랫폼”이라는 경험은 끊긴다. OpenAI 호환 API는 클라이언트 이식성을 높이지만, 모델 출력의 동일성이나 커널 성숙도를 보장하지 않는다.

[Mojo 1.0 매뉴얼](https://mojolang.org/docs/manual/)은 CPU와 GPU용 고성능 시스템 프로그래밍, 값 소유권, 수명과 참조, 컴파일 타임 평가, Python·C 상호운용을 언어의 핵심 범위로 둔다. MAX 26.5 릴리스에서는 GPU 프로그래밍 API가 Mojo 표준 라이브러리에서 상위 `max` 패키지로 이동했다. `std.algorithm`이 `max.algorithm`으로, GPU compute·host·memory·sync API가 `max.gpu.*`로 옮겨진 변화는 경계가 선명해졌다는 뜻이지만, 기존 코드에는 migration 비용이다. 릴리스 노트가 deprecated alias와 compiler fix-it을 제공한다고 해도 테스트 없이 안정화됐다고 볼 수는 없다.

## CUDA를 제거하는 것과 하드웨어 종속성을 제거하는 것은 다르다

MAX 공식 문서는 같은 패키지가 NVIDIA, AMD, Apple Silicon에서 실행되고 PyTorch, CUDA, ROCm에 의존하지 않는다고 설명한다. 이는 배포 이미지와 버전 조합을 단순화할 가능성이 있다. 그러나 애플리케이션이 CUDA 라이브러리를 직접 묶지 않는다고 해서 물리적 차이가 사라지는 것은 아니다.

NVIDIA와 AMD는 지원하는 dtype, tensor core 계열, collective 통신, graph capture, profiler가 다르다. Apple Silicon은 통합 메모리라는 장점과 별개로 데이터센터 GPU와 메모리 대역폭·동시성·운영 도구가 다르다. 같은 Mojo source가 컴파일돼도 타깃별 최적 커널 경로와 fallback이 같을 이유가 없다. 26.5 릴리스가 M1까지 Apple GPU 지원을 넓히고 M5에 hardware-MMA flash-attention prefill을 추가한 사실도 **이식성 아래에는 세대별 최적화가 계속 필요하다**는 증거다.

공개 이슈는 이 경계를 더 현실적으로 보여준다. 확인 시점에는 4×H100에서 특정 Qwen 모델 build가 실패한다는 보고, DGX Spark GB10의 device graph capture 중 allocator가 실패한다는 보고, float16·bfloat16·float32의 특정 거듭제곱 표현이 compiler pass error를 낸다는 보고가 열려 있었다. 이는 프로젝트의 품질을 단정하는 목록이 아니다. “지원 GPU”라는 체크박스보다 **모델×정밀도×GPU 세대×병렬화 방식**의 조합이 실제 검증 단위라는 뜻이다.

따라서 플랫폼 팀은 vendor lock-in을 두 종류로 나눠야 한다. CUDA API에 직접 결합된 **코드 종속성**은 MAX가 줄일 수 있다. 특정 GPU에서만 비용 목표를 만족하는 **경제적 종속성**, 특정 profiler와 장애 지식에 축적된 **운영 종속성**은 별도로 남는다. 추상화 계층은 차이를 없애기보다 차이를 한곳에서 관리하도록 돕는다.

## 성능 표보다 먼저 workload 계약을 고정해야 한다

MAX 홈페이지는 자체 벤치마크 결과와 함께 vLLM 대비 처리량 수치를 제시하고, 공개·사용자 데이터셋을 사용하는 benchmarking CLI와 재현 가능한 YAML 설정을 강조한다. 이런 결과는 후보를 탐색하는 신호로는 유용하지만 다른 모델, GPU, prompt 분포에 그대로 옮길 수 없다. 성능 비교에서 먼저 고정해야 할 것은 제품명이 아니라 workload 계약이다.

- 모델과 정확한 revision, tokenizer, quantization을 고정한다.
- 입력·출력 토큰 길이의 p50/p95와 동시 요청 분포를 실제 트래픽에 맞춘다.
- TTFT, inter-token latency, end-to-end p95, request throughput을 함께 기록한다.
- warm 상태뿐 아니라 model load, graph compile, cold start, scale-out 시간을 잰다.
- structured output, tool calling, 긴 context처럼 실제 기능의 성공률을 분리한다.
- 전력, GPU 시간당 비용, 인스턴스 가용성, 운영 인력까지 총비용에 넣는다.

[LMCache의 KV 캐시 계층](/posts/github-trending-lmcache-kv-cache-llm-serving/)에서 본 것처럼 긴 공통 prefix가 반복되는 서비스는 cache hit와 TTFT가 핵심이고, 창의적 단발 요청은 캐시 효과가 낮다. MAX와 vLLM, SGLang을 비교하면서 캐시 정책·scheduler·quantization을 다르게 두면 엔진보다 설정 차이를 측정하게 된다. 동일한 요청 trace와 품질 gate, cache 조건을 사용해야 한다.

성능 회귀도 평균 하나로 감추지 말아야 한다. NVIDIA에서는 decode throughput이 좋아도 AMD에서 긴 prefill이 느릴 수 있고, Apple에서 단일 사용자는 빨라도 동시 요청이 늘면 메모리 압박이 급격히 커질 수 있다. 장치별 결과를 하나의 “MAX 평균”으로 합치면 하드웨어 선택권을 검증한 것이 아니다.

## 공개 저장소와 MAX 사용권의 경계를 배포 전에 읽어야 한다

GitHub API는 저장소 라이선스를 `NOASSERTION`으로 반환하지만 루트 LICENSE와 README는 저장소 및 contribution이 **Apache License 2.0 with LLVM Exceptions**라고 명시한다. 여기까지만 보고 MAX 전체를 표준 Apache-2.0 제품으로 분류하면 안 된다. 같은 README는 **MAX의 사용과 배포는 Modular Community License**를 따른다고 별도로 밝히며, Hugging Face 등에서 내려받는 제3자 모델·라이브러리의 라이선스 검증 책임도 사용자에게 둔다.

즉 source component, 컴파일 결과에 포함되는 부분, MAX 패키지 사용·재배포, 모델 가중치에는 서로 다른 조건이 적용될 수 있다. 사내 PoC에서 package를 설치하는 행위와 고객 환경에 container image를 배포하는 행위도 같지 않다. 법무·오픈소스 검토에는 최소한 다음 artifact를 따로 올려야 한다.

- 사용한 저장소 commit과 source directory
- 설치한 MAX package 및 정확한 버전
- 수정·배포하는 Mojo kernel과 컴파일 산출물
- container에 포함한 runtime 파일
- 모델 가중치, tokenizer, dataset 각각의 라이선스

“오픈소스 커널이 보인다”는 사실과 “전체 상용 배포 조건이 Apache-2.0이다”라는 결론은 다르다. SPDX 자동 승인만으로 처리하지 말고 실제 배포 형태를 기준으로 검토해야 한다.

![MAX 도입 여부를 가르는 검증 게이트](https://heracles-jo.github.io/assets/img/posts/modular-max-hardware-portable-ai-inference/decision.svg)

## 전환 전략: 기존 추론 엔진을 한 번에 교체하지 않는다

MAX를 검토할 때 가장 위험한 계획은 기존 vLLM·SGLang endpoint를 곧바로 대체하고 모든 GPU pool을 한 control plane으로 묶는 것이다. 모델 지원 범위, 관측 지표, scheduler semantics, 오류 형식이 다르면 API 호환만으로 롤백 가능성이 확보되지 않는다.

첫 단계에서는 [Switchyard의 LLM 라우팅 게이트웨이](/posts/github-trending-switchyard-llm-routing-governance/)처럼 클라이언트와 backend 사이에 라우팅 경계를 유지한다. 동일한 요청의 일부를 MAX canary로 보내되, 사용자에게 이중 응답을 노출하지 않고 품질·지연·오류를 비교한다. 모델 revision과 prompt template를 같게 고정하고, 결과 차이는 task-specific evaluator나 golden set으로 측정한다.

두 번째 단계에서는 가장 강한 이식성 가설 하나만 시험한다. 예를 들어 “NVIDIA 공급 부족 시 AMD pool로 30분 안에 전환” 또는 “개발자가 Apple Silicon에서 같은 모델 pipeline을 재현”처럼 복구 목표를 정의한다. 세 장치를 모두 지원한다는 데모보다 **실제 대체 경로가 SLO 안에서 작동하는지**가 중요하다.

세 번째 단계에서 운영 surface를 비교한다. Prometheus metric의 label cardinality, request ID와 trace 연결, GPU memory OOM 분류, compile cache 무효화, rolling upgrade 중 in-flight request 처리, model load 실패의 rollback을 확인한다. endpoint가 HTTP 200을 반환하는 것만으로 운영 준비가 끝나지 않는다.

마지막으로 커널을 직접 수정할 팀과 서빙 패키지만 쓸 팀을 구분한다. Mojo 커널 최적화까지 소유하면 하드웨어 차이를 빠르게 흡수할 수 있지만 compiler·성능 엔지니어링 역량과 회귀 테스트가 필요하다. 그 역량이 없다면 공개 커널은 투명성을 높여도 실질적인 유지보수 권한이 되지 않을 수 있다.

## 2주 PoC의 종료 기준

MAX PoC는 “샘플 모델이 실행됐다”가 아니라 다음 질문에 수치로 답하면 끝난다.

1. **호환성**: 운영 후보 모델의 generation, streaming, structured output, tool calling, 긴 context가 기준 엔진과 같은 기능 계약을 만족하는가.
2. **품질**: 고정 평가셋에서 task success와 출력 형식 오류가 허용 범위 안인가. 커널·양자화 차이로 품질이 변하지 않는가.
3. **지연과 처리량**: workload별 TTFT, TPOT, p95 latency, requests/sec가 각 장치의 목표를 충족하는가.
4. **이식성**: 같은 pipeline revision을 NVIDIA·AMD·Apple에 올릴 때 바뀐 코드와 설정은 무엇이며, 전환 시간이 복구 목표 안인가.
5. **장애 복구**: OOM, compile 실패, GPU reset, 잘못된 model revision에서 health check가 트래픽을 차단하고 이전 backend로 돌아가는가.
6. **관측성**: request·model·device·revision 단위 지표와 trace를 기존 대시보드·알림에 연결할 수 있는가.
7. **공급망**: package, container, model artifact를 digest로 고정하고 SBOM·취약점·출처를 재현할 수 있는가.
8. **라이선스**: source, MAX package, compiled artifact, model을 실제 배포 형태 기준으로 승인받았는가.
9. **업그레이드**: stable release 한 차례를 재현해 breaking change, compile cache, 성능 회귀, rollback 시간을 기록했는가.
10. **총비용**: GPU 비용뿐 아니라 porting, benchmark, incident 대응, 커널 유지보수 시간을 포함해 기준 엔진보다 유리한가.

[Needle의 온디바이스 도구 호출](/posts/github-trending-needle-tiny-on-device-tool-calling/)처럼 작은 모델을 제품 단말에 넣는 경우에도 하드웨어 이식성은 유용하다. 다만 중앙 LLM 서버와 단말은 전력·패키지 크기·오프라인 업데이트라는 다른 제약을 가진다. MAX 하나로 두 환경을 지원할 수 있다는 가능성과 하나의 운영 정책으로 관리할 수 있다는 결론을 혼동하면 안 된다.

## 판단 기준은 “어디서나 실행”보다 “어디서나 검증”이다

Modular MAX의 장기 가치는 NVIDIA, AMD, Apple을 지원 목록에 적는 데 있지 않다. 모델 pipeline과 커널, server를 한 공개 코드베이스에서 연결하고 Mojo로 하드웨어별 성능 경로를 확장해 **플랫폼 팀이 이식성에 투자할 단일 지점**을 제안한다는 데 있다. Mojo 1.0과 MAX 26.5는 그 경계가 제품화되고 있다는 중요한 신호다.

그러나 통합 스택은 검증 책임까지 제거하지 않는다. 타깃별 커널 성숙도, 모델 coverage, compiler 회귀, 관측성, 라이선스, 운영자의 디버깅 역량은 남는다. 특히 공개 benchmark를 제품 workload의 성능 보증으로 읽거나, Apache 라이선스 저장소를 MAX 전체의 배포 조건으로 읽는 순간 추상화가 오히려 위험을 가린다.

따라서 도입 결정은 간단한 질문으로 압축할 수 있다. 우리에게 실제로 두 번째 하드웨어 경로가 필요한가, 같은 평가 trace로 장치별 품질과 SLO를 반복 검증할 수 있는가, 문제가 났을 때 통합 추상화 아래의 커널·컴파일러 경계까지 조사할 역량이 있는가. 세 답이 모두 명확할 때 MAX는 vendor 선택권을 운영 전략으로 바꿀 수 있다. 그렇지 않다면 성숙한 단일 vendor 스택을 잘 운영하는 편이 더 낮은 총비용일 수 있다.

> 1차 출처: [modular/modular](https://github.com/modular/modular), [README](https://github.com/modular/modular/blob/main/README.md), [루트 LICENSE](https://github.com/modular/modular/blob/main/LICENSE), [MAX 공식 문서](https://max.modular.com/), [Mojo 1.0 Manual](https://mojolang.org/docs/manual/), [MAX 26.5 / Mojo 1.0.0 릴리스](https://github.com/modular/modular/releases/tag/max/v26.5.0), [공개 이슈](https://github.com/modular/modular/issues). Trending·저장소 수치는 2026년 8월 23일 07:45 KST 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
