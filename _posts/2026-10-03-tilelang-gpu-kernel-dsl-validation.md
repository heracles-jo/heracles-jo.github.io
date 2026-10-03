---
title: "TileLang GPU 커널 DSL: Triton 대안 검증 기준"
description: "TileLang의 Python DSL·TVM 컴파일러·멀티 백엔드 구조를 분해하고 Triton·CUDA와 비교해 성능, 이식성, 회귀 테스트와 도입 중단 기준을 정리한다."
author: heracles-jo
date: 2026-10-03 08:30:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [tilelang, gpu-kernel, triton, tvm, compiler, ai-infrastructure]
image:
  path: https://heracles-jo.github.io/assets/img/posts/tilelang-gpu-kernel-dsl-validation/cover.svg
  alt: "TileLang으로 하나의 GPU 커널을 여러 가속기 백엔드에 컴파일하고 검증하는 흐름"
---

AI 추론 비용을 줄이려다 보면 결국 모델 서버보다 아래 계층을 만나게 된다. FlashAttention, 양자화 GEMM, MoE routing, fused activation처럼 처리량을 좌우하는 연산은 범용 framework 호출만으로 최적화되지 않는다. CUDA C++로 직접 내려가면 제어권은 커지지만 GPU 세대별 instruction, memory hierarchy, synchronization과 build toolchain을 팀이 떠안는다. 반대로 고수준 compiler에 모두 맡기면 빠르게 시작할 수 있어도 어떤 layout과 kernel이 선택됐는지 설명하기 어려워진다.

[tile-ai/tilelang](https://github.com/tile-ai/tilelang)은 이 간극을 Python 문법의 tile 기반 DSL과 TVM 위 compiler infrastructure로 좁히려 한다. 개발자는 global·shared·fragment memory, pipelined copy, GEMM과 병렬 loop를 명시하고, compiler는 target별 lowering과 code generation을 수행한다. CUDA만이 아니라 ROCm, Metal, Ascend 950을 main repository에서 다루고 CPU·CuTe DSL·WebGPU는 experimental로 구분한다. 핵심 질문은 “TileLang이 Triton보다 빠른가”가 아니다. **우리 workload의 병목 kernel을 읽고 수정할 수 있는 수준으로 표현하면서, target별 성능과 정확성을 반복 검증할 수 있는가**다.

2026년 10월 3일 08시 41분 KST 전후 GitHub Trending weekly에서 TileLang은 **481 stars this week**로 표시됐다. GitHub API 기준 저장소는 **8,240 stars**, 829 forks, 열린 이슈와 PR을 합친 423개였고, 최신 안정 릴리스는 9월 30일의 `v0.1.15`였다. 10월 3일 KST 자정 무렵까지 BF16 scalar parameter 지원 커밋과 CUDA stream·autotuner 관련 PR 활동이 이어졌다. 루트 `LICENSE`와 `pyproject.toml`은 MIT를 명시하지만 GitHub license API는 `NOASSERTION`을 반환했다. 이 수치와 상태는 확인 시점의 공개 스냅샷이며 성능·호환성·장기 유지보수를 보증하지 않는다. 이번 실행 환경에서는 Search Console과 Analytics의 실제 검색어·노출·CTR 데이터에 접근할 수 없어 선정 근거로 사용하지 않았다.

## 후보 비교에서 남은 것은 커널을 소유하는 방법이었다

오늘 daily·weekly 목록은 에이전트 관리, 학습형 메모리, 디자인 skill과 context 절감 도구에 강하게 치우쳤다. 그러나 최근 글의 제목·description·저장소·중심 논지를 대조하면 대부분 기존 에이전트 클러스터와 직접 경쟁했다. TileLang도 AI 인프라 글과 접점이 있지만, 기존 글이 모델 serving·양자화 artifact·하드웨어 runtime을 다뤘다면 이번 검색 의도는 **custom GPU kernel을 작성하고 compiler 회귀를 승인하는 방법**이다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [tile-ai/tilelang](https://github.com/tile-ai/tilelang) | weekly 481, 8,240 stars, v0.1.15, MIT 명시 | kernel DSL의 표현력·target 이식성·성능 회귀를 검증하는 독립 질문이 있어 선택했다. |
| [paperclipai/paperclip](https://github.com/paperclipai/paperclip) | weekly 14,335, 96,282 stars, MIT | 업무용 agent 관리 제어면은 Google AX·Orca의 orchestration 의도와 가깝다. |
| [vectorize-io/hindsight](https://github.com/vectorize-io/hindsight) | weekly 17,403, 44,688 stars, MIT | 학습형 agent memory는 Supermemory·codebase memory 글과 검색 의도가 겹친다. |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | daily 717·weekly 2,704, 74,300 stars, Apache-2.0 | AI 디자인 규약은 유효하지만 design system·diagram 자동화 글과 독자 문제가 인접한다. |
| [mksglu/context-mode](https://github.com/mksglu/context-mode) | daily 276, 25,023 stars, license API `NOASSERTION` | tool output 격리는 구체적이지만 기존 context·memory·agent workflow 클러스터와 경쟁할 가능성이 높다. |

[Modular MAX의 이기종 추론](/posts/modular-max-hardware-portable-ai-inference/)이 모델 pipeline과 runtime을 여러 하드웨어에 올리는 플랫폼 선택을 다뤘다면, TileLang은 그보다 아래에서 **하나의 연산을 어떤 memory movement와 tile schedule로 구현할지**를 다룬다. [Model Optimizer의 양자화 배포](/posts/nvidia-modelopt-llm-quantization-pipeline/)가 checkpoint와 runtime kernel의 계약을 검증했다면, 여기서는 그 low-precision kernel 자체가 검증 대상이다.

## Python 함수 하나 아래에는 target별 compiler 계약이 있다

공식 quick start의 GEMM+ReLU 예제는 짧지만 표현하는 내용은 저수준이다. `T.Kernel`로 program grid와 thread 수를 정하고, `T.alloc_shared`와 `T.alloc_fragment`로 memory scope를 구분한다. `T.Pipelined`는 global-to-shared copy와 compute를 겹치게 하며, `T.gemm`은 tile 연산을 target backend의 tensor 연산으로 내린다. `T.Parallel`은 epilogue의 elementwise ReLU를 표현한다. `@tilelang.jit`는 입력 shape와 compile-time argument를 기준으로 kernel을 specialization하고 처음 호출할 때 compile한다.

![TileLang 소스가 compiler와 target dialect를 거쳐 실행 artifact가 되는 구조](https://heracles-jo.github.io/assets/img/posts/tilelang-gpu-kernel-dsl-validation/architecture.svg)

이 추상화는 “Python이 GPU에서 실행된다”는 의미가 아니다. Python frontend가 kernel intent를 intermediate representation으로 만들고, layout inference·scheduling·lowering·code generation을 거쳐 target code와 launch wrapper를 만든다. 저장소가 TVM을 기반으로 한다는 점도 중요하다. 사용자는 간결한 surface를 보지만 실제 장애는 frontend tracing, symbolic shape, layout legality, target dialect, native compiler, JIT cache와 runtime adapter 중 어느 층에서도 발생할 수 있다.

운영자는 source와 binary 사이에 최소 다섯 개의 계약을 둬야 한다.

1. **의미 계약**: reference PyTorch 구현과 허용 오차 안에서 같은 결과를 내야 한다.
2. **layout 계약**: shape·stride·alignment·dtype가 바뀌어도 compiler가 불법 layout이나 silent fallback을 만들지 않아야 한다.
3. **target 계약**: 같은 source가 CUDA·ROCm·Metal에서 compile된다는 사실과 같은 성능 특성을 가진다는 사실을 분리해야 한다.
4. **artifact 계약**: compiler·driver·architecture가 바뀌면 cache를 안전하게 무효화하고 재생성해야 한다.
5. **관측 계약**: 선택된 kernel, compile 시간, fallback, register·shared memory 사용량과 실행 latency를 추적할 수 있어야 한다.

`v0.1.15`가 cached kernel parameter를 cloudpickle 대신 JSON으로 저장하고, CUDA binary와 metadata를 immutable cache directory에 원자적으로 publish하며 hash verification을 mandatory로 바꾼 것은 마지막 두 계약과 직접 연결된다. JIT cache는 단순 성능 최적화가 아니라 **실행할 binary의 출처와 일관성을 지키는 배포 구성 요소**다.

## 멀티 백엔드는 한 소스보다 여러 검증표를 뜻한다

TileLang README의 support matrix는 CUDA를 primary, ROCm·Ascend 950·Metal을 supported, LLVM CPU·CuTe DSL·WebGPU를 experimental로 구분한다. 생태계 adapter인 Ascend A2/A3, MetaX, MUSA, HYGON, TANG은 별도 저장소와 독립 compatibility schedule을 가진다. “지원”이라는 한 단어 안에서도 release wheel, CI hardware, source build, 외부 SDK와 유지보수 주체가 다르다.

CUDA 경로는 SM70부터 SM120까지를 적고 TMA·WGMMA·TMEM 같은 기능은 GPU architecture에 따라 달라진다. ROCm은 Linux wheel에 포함되지만 host ROCm runtime이 필요하고 공개 README는 self-hosted MI300X CI와 아직 CI가 없는 gfx950 경로를 구분한다. Metal은 Apple silicon wheel과 CI가 있으나 Metal 4 cooperative tensor는 지원되는 M5 system에 한정된다. Ascend 950은 source build, CANN과 `torch_npu`가 필요하다. 같은 decorator를 썼다는 이유만으로 dependency·debugger·profiler·fallback이 같아지지 않는다.

따라서 porting 목표는 “source diff 0줄”보다 **backend별 승인 envelope를 명시하는 것**이 현실적이다. 예를 들어 CUDA H100의 FP16 GEMM, MI300X의 BF16 attention, M5의 cooperative tensor GEMM처럼 모델·dtype·shape·device를 각각 고정한다. 어느 backend에서든 compile되는 범용 경로와 특정 architecture instruction을 쓰는 최적 경로를 따로 관리하고, 최적 경로가 깨졌을 때 generic fallback이 조용히 SLO를 악화시키지 않도록 한다.

[GPU·CPU에 MoE expert를 나누는 KTransformers](/posts/github-trending-ktransformers-heterogeneous-llm-inference/)에서도 hardware matrix가 실제 검증 단위였다. TileLang은 더 낮은 계층이라 matrix가 driver, compiler flag, architecture capability와 layout까지 확장된다. 이 복잡도를 감당할 플랫폼팀이 없다면 vendor library나 framework 기본 kernel을 쓰는 편이 총비용이 낮다.

## Triton·CUDA·vendor library와 비교할 때 추상화 높이를 맞춰야 한다

TileLang 도입 검토에서 흔한 오류는 cuBLAS, Triton, CUDA C++와 TileLang을 하나의 순위표에 놓는 것이다. 네 선택지는 서로 다른 소유권을 제공한다.

| 선택지 | 팀이 직접 소유하는 범위 | 유리한 경우 | 주요 비용 |
|---|---|---|---|
| vendor library | 호출 shape·algorithm 선택·integration | 표준 GEMM·attention이 충분하고 안정성이 우선 | 특수 fusion과 새 연산 표현이 제한됨 |
| framework compiler | graph와 일부 fusion hint | 모델 전체 최적화가 목표이고 custom kernel 인력이 적음 | generated kernel의 설명·세밀한 제어가 어려움 |
| Triton·TileLang 같은 DSL | tile, memory movement, schedule hint, benchmark | 반복되는 custom op와 kernel engineer가 있음 | compiler 변화와 backend별 회귀를 지속 검증해야 함 |
| CUDA/HIP C++ | instruction·memory·synchronization까지 직접 제어 | 최고 성능이나 특수 hardware feature가 핵심 | 개발·porting·검증 비용과 인력 의존이 가장 큼 |

TileLang의 차별점은 Pythonic syntax 자체보다 TVM 기반 compiler와 명시적 tile language, 빠르게 넓어지는 backend dialect에 있다. Triton과의 비교도 “문법이 더 짧다”가 아니라 필요한 operator를 양쪽으로 구현해 compile time, correctness, generated code, peak performance, shape sensitivity, debugging 시간을 재야 한다. 프로젝트 README의 benchmark graph는 후보 탐색에는 유용하지만 H100·A100·RTX 4090·MI300X의 특정 setting을 다른 workload의 보증으로 읽으면 안 된다.

특히 attention이나 dequant GEMM에서 benchmark 하나가 이겨도 운영 우위는 확정되지 않는다. 실제 service는 여러 shape와 batch, 긴 tail, cold compile, cache eviction, concurrent stream을 가진다. [LMCache의 KV cache 계층](/posts/github-trending-lmcache-kv-cache-llm-serving/)에서 cache hit 조건이 throughput 해석을 바꿨듯, kernel 비교도 input distribution과 surrounding runtime을 고정해야 한다.

## 정확성 실패는 crash보다 조용한 수치 오염이 더 위험하다

GPU kernel은 compile 성공과 실행 성공 사이에도 실패할 수 있다. alignment assumption이 틀리면 일부 shape에서만 잘못된 값을 만들고, reduction order가 바뀌면 허용 오차를 넘으며, NaN 처리나 atomics가 architecture별로 달라질 수 있다. FP8·FP4와 block-scaled GEMM은 scale layout과 accumulation dtype이 추가된다. 빠른 kernel이 reference와 조금 다른 것이 허용되는지 업무별 기준이 없다면 benchmark 경쟁이 품질 회귀를 숨긴다.

최근 release와 공개 PR 제목은 검증 지점을 구체적으로 보여준다. `v0.1.15`에는 dynamic reduction tail guard, NaN-propagating clamp, atomics vectorization, async copy, WGMMA·UMMA stride, Metal buffer offset, BF16 CPU arithmetic 수정이 포함됐다. 확인 시점의 열린 PR에는 current CUDA stream 보존, NVRTC wrapper parameter identity, autotuner input tensor reuse, Hopper WGMMA layout fallback warning이 있었다. 이는 프로젝트가 나쁘다는 증거가 아니라 **kernel compiler의 정확성이 dtype·layout·stream·wrapper·cache 경계를 모두 포함한다**는 뜻이다.

테스트는 random tensor 몇 개로 끝내지 않는다. 최소한 다음 축을 조합한다.

- 0·1·tile 경계 전후·prime number를 포함한 shape
- contiguous, transposed, sliced tensor와 alignment 변화
- FP32·BF16·FP16·FP8·INT 계열의 dtype와 accumulation 조합
- NaN·Inf·subnormal·큰 값·0과 같은 수치 경계
- 여러 CUDA stream과 동시 kernel launch
- warm cache, cold compile, process restart와 cache corruption
- target architecture와 driver·native compiler version 변화

Reference와 `assert_close`를 수행하되 elementwise max error만 보지 말고 task-level metric도 연결한다. Attention kernel이면 긴 sequence에서 model output과 perplexity·task success가 유지되는지 보고, quantized GEMM이면 calibration과 실제 배포 checkpoint에서 품질을 확인한다.

## 라이선스와 공급망은 `pip install tilelang`보다 넓다

루트 `LICENSE`는 MIT 전문 앞에 2024년 12월 1일부터 2025년 3월 14일까지 Microsoft Corporation과의 추가 collaboration terms가 적용됐다는 문구를 둔다. 현재 배포 조건을 임의로 확대 해석할 이유는 없지만 GitHub API가 license를 `NOASSERTION`으로 반환하는 만큼 자동 SPDX 결과만 승인 근거로 쓰지 말고 원문과 법무 판단을 남기는 편이 안전하다. `pyproject.toml`은 MIT를 명시한다.

실제 build에는 TVM 계열 코드, native compiler, CUDA·ROCm·CANN·Metal SDK, PyTorch와 architecture별 library가 결합된다. 저장소도 `THIRDPARTYNOTICES.txt`와 submodule을 포함한다. 따라서 SBOM은 Python wheel 하나가 아니라 source commit, submodule SHA, wheel hash, build flag, native toolchain, driver와 target architecture를 묶어야 한다. Nightly wheel은 최신 기능을 빨리 주지만 stable release보다 변동성이 크므로 production artifact와 같은 channel로 취급하면 안 된다.

Compiler cache도 공급망 경계다. Shared cache를 여러 user나 tenant가 쓰면 다른 process가 artifact를 바꿀 수 없는지, cache key가 compiler·target·flags를 충분히 포함하는지 확인한다. `v0.1.15`의 immutable publish와 mandatory hash verification을 사용하더라도 cache directory 권한, remote cache transport, 오래된 artifact 정리 정책은 운영자가 정해야 한다.

## 2주 PoC는 최고 기록보다 반복 가능한 kernel ownership을 본다

![TileLang 도입을 계속하거나 중단하는 PoC 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/tilelang-gpu-kernel-dsl-validation/decision.svg)

PoC 대상은 서비스에서 비용이 큰 custom op 하나로 제한한다. 이미 cuBLAS나 framework 기본 kernel이 충분한 GEMM을 억지로 다시 쓰지 않는다. Profile에서 실제 GPU 시간을 차지하고, fusion이나 layout specialization으로 개선 가설이 있으며, reference 구현과 실제 trace를 확보한 연산이 적합하다.

| 검증 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 정확성 | shape·dtype별 오차, NaN·tail·stride, task metric | 특정 경계 입력에서 silent mismatch 또는 기준 품질 하락 |
| 성능 | p50/p95 latency, throughput, compile time, warm/cold cache | 최고값만 빠르고 실제 shape 분포나 tail이 개선되지 않음 |
| 자원 | register, shared memory, occupancy, binary·cache 크기 | 성능 이득보다 occupancy 저하·cache 팽창이 큼 |
| 이식성 | target별 compile·correctness·fallback, source diff | 두 번째 target이 사실상 별도 kernel rewrite를 요구 |
| 디버깅 | compile error·runtime fault의 원인 파악 시간 | generated code와 compiler layer를 팀이 추적할 수 없음 |
| 회귀 | compiler·driver update 전후 결과, perf gate | minor update가 정확성·성능을 바꾸지만 자동 차단 불가 |
| 공급망 | commit·wheel·submodule·toolchain digest, SBOM | artifact 출처나 cache key를 재현할 수 없음 |
| 운영 비용 | kernel당 유지 시간, reviewer 수, 장애 대응 | 한 명의 전문가에게만 지식이 집중되거나 총비용이 절감액 초과 |

첫 주에는 reference, baseline과 benchmark harness를 먼저 만든다. Vendor library, 기존 Triton/CUDA kernel 또는 framework 기본 경로 중 현실적인 대안을 하나 둔다. 두 번째 주에 TileLang 구현과 한 개의 추가 target을 검증하고, compiler·driver version을 한 번 바꿔 regression gate와 rollback을 시험한다. 결과는 가장 빠른 숫자가 아니라 source·environment manifest와 함께 재실행 가능한 report로 남긴다.

TileLang이 잘 맞는 팀은 custom attention·quantization·sparse kernel을 반복 개발하고, compiler IR와 GPU profiler를 읽을 수 있으며, 여러 accelerator 경로를 실제로 유지할 이유가 있는 조직이다. 반대로 표준 operator 중심의 모델을 한 종류 GPU에서 운영하거나 kernel engineer가 없고 managed inference로 SLO를 충족한다면 도입 이득이 작다. DSL을 추가하면 Python 생산성이 생기는 대신 compiler와 backend compatibility라는 새 제품을 운영하게 된다.

TileLang의 장기 가치는 CUDA를 감추는 데 있지 않다. Memory movement, tile schedule, target dialect를 읽을 수 있는 형태로 올려 **저수준 최적화의 소유권을 compiler와 개발자 사이에 재배치하는 것**에 있다. 그 선택이 성공하려면 같은 source가 compile된다는 데 만족하지 않고, target별 정확성·성능·artifact·fallback을 자동으로 승인해야 한다. 이 검증 체계를 만들 수 있을 때 TileLang은 benchmark용 DSL을 넘어 AI 인프라팀의 reusable kernel platform이 될 수 있다.

> 1차 자료: [tile-ai/tilelang 저장소와 README](https://github.com/tile-ai/tilelang), [MIT LICENSE](https://github.com/tile-ai/tilelang/blob/main/LICENSE), [THIRDPARTYNOTICES](https://github.com/tile-ai/tilelang/blob/main/THIRDPARTYNOTICES.txt), [v0.1.15 릴리스](https://github.com/tile-ai/tilelang/releases/tag/v0.1.15), [설치 문서](https://tilelang.com/get_started/Installation.html), [예제](https://github.com/tile-ai/tilelang/tree/main/examples), [benchmark 저장소](https://github.com/tile-ai/tilelang-benchmark), [최근 commits](https://github.com/tile-ai/tilelang/commits/main/), [공개 issues](https://github.com/tile-ai/tilelang/issues), [공개 pull requests](https://github.com/tile-ai/tilelang/pulls). Trending·저장소 수치는 2026년 10월 3일 08시 41분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
