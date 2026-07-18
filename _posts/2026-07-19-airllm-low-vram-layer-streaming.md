---
title: "저VRAM LLM 추론: AirLLM의 레이어 스트리밍이 맞는 경우"
description: "AirLLM이 거대 모델을 한 레이어씩 GPU에 올리는 원리와 디스크 I/O 병목, 처리량·보안 한계를 짚고 저사양 환경에서의 현실적인 도입 기준을 제시한다."
author: heracles-jo
date: 2026-07-19 02:40:00 +0900
categories: [AI Infrastructure, LLMOps]
tags: [airllm, llm-inference, gpu-memory, model-streaming, quantization, local-ai]
image:
  path: https://heracles-jo.github.io/assets/img/posts/airllm-low-vram-layer-streaming/cover.svg
  alt: "AirLLM이 모델 레이어를 디스크에서 GPU로 순차 전송해 적은 VRAM으로 추론하는 구조"
---

“70B 모델을 4GB GPU에서 실행한다”는 문장은 강력하지만, 실무 판단에 필요한 질문을 절반만 담고 있다. 모델이 메모리에 **들어가는가**와 사용자가 기다릴 만한 속도로 **서비스되는가**는 다른 문제다. VRAM을 줄이는 대신 매 생성 단계마다 가중치를 저장장치에서 읽는다면 용량 제약은 풀려도 지연시간과 처리량, SSD 수명, 장애 복구라는 새 제약이 생긴다.

[lyogavin/airllm](https://github.com/lyogavin/airllm)은 전체 모델을 GPU에 상주시켜야 한다는 전제를 바꾼다. 모델을 레이어 단위 shard로 나누고 한 번에 한 레이어만 GPU에 올려 순전파한 뒤 다음 레이어로 교체한다. 공식 README는 이 방식으로 full precision Llama 3 계열 70B를 약 4GB VRAM에서, DeepSeek-V3 671B를 약 12GB에서 실행할 수 있다고 설명한다. 이는 **최소 VRAM에 관한 프로젝트의 주장**이지, 특정 토큰 생성 속도나 대화형 SLA를 보장하는 수치가 아니다.

2026년 7월 19일 03시 KST 공개 스냅샷에서 저장소는 약 23.2k stars, 2.7k forks, Apache-2.0 라이선스를 표시했다. 최신 릴리스는 2026년 7월 1일 KST의 [v3.0.1](https://github.com/lyogavin/airllm/releases/tag/v3.0.1)로, clean install에서 누락됐던 `sentencepiece` 의존성과 선택적 모델 모듈 import 실패를 보완했다. 최근 코드 변경보다 문서·star chart 갱신 비중이 컸고, 열린 이슈에는 느린 실행, double buffering 제안, shard 삭제 오류, 원격 모델 코드 신뢰와 벤치마크 재현성 문제가 남아 있었다. 성숙도를 star 수 하나로 판단하면 안 되는 이유다.

Search Console과 Analytics 쿼리 데이터에는 이번 실행 환경에서 접근할 수 없었다. 따라서 노출·CTR을 확인했다고 가정하지 않았다. daily·weekly Trending의 AirLLM, code-review-graph, ui-skills, Hallmark, wigolo를 README·라이선스·릴리스·최근 활동 기준으로 비교했다. code-review-graph는 기존 [코드베이스 기억 계층](/posts/github-trending-codebase-memory-mcp-code-intelligence-layer/)과, Hallmark와 ui-skills는 [DESIGN.md 기반 디자인 시스템 운영](/posts/github-trending-design-md-design-system-ai-agents/)과 검색 의도가 겹쳤다. AirLLM은 기존의 KV cache나 벡터 검색 최적화와 달리 **모델 가중치 상주 메모리를 I/O로 교환하는 선택**이라는 독립적인 질문을 만든다.

## 4GB라는 숫자 뒤에서 실제로 일어나는 일

일반적인 GPU 추론은 모델 가중치, KV cache, activation과 런타임 workspace를 VRAM에 함께 둔다. 모델이 커지면 가장 먼저 가중치가 메모리 예산을 압박한다. tensor parallelism은 여러 GPU에 가중치를 나누고, 양자화는 각 가중치의 비트 수를 줄이며, CPU offload는 일부 가중치를 시스템 RAM으로 옮긴다. 세 방법 모두 “자주 쓸 가중치를 비교적 가까운 메모리에 둔다”는 성격은 유지한다.

AirLLM은 더 과감하다. 초기 준비 과정에서 Hugging Face 모델을 레이어별 파일로 분해해 저장한다. 추론할 때 첫 레이어를 디스크에서 CPU 쪽으로 읽고 GPU에 전송해 계산한 다음 내리고, 두 번째 레이어를 같은 방식으로 처리한다. 한 레이어의 크기와 실행 중 상태만 VRAM에 맞으면 전체 모델 크기가 GPU 메모리보다 훨씬 커도 순전파 자체는 가능해진다. README가 “VRAM은 전체 모델이 아니라 레이어 크기에 좌우된다”고 설명하는 이유다.

![AirLLM 레이어 스트리밍 추론 경로](https://heracles-jo.github.io/assets/img/posts/airllm-low-vram-layer-streaming/architecture.svg)

이 방식은 마법처럼 메모리를 없애지 않는다. 가중치의 보관 위치와 이동 시점을 바꾼다. 원본 모델을 내려받을 저장공간이 필요하고, 변환된 layer shard를 추가로 둘 공간이 필요하다. README도 최초 실행에서 모델을 분해해 Hugging Face cache에 저장하므로 충분한 디스크를 확보하라고 경고한다. `delete_original` 옵션은 원본을 지워 중복 공간을 줄일 수 있지만, 열린 이슈에는 shard를 잘못 삭제한 뒤 실패할 수 있다는 보고가 있다. 삭제 옵션은 일회성 노트북과 재현 가능한 운영 파이프라인에서 위험의 무게가 다르다.

### Prefetch가 물리 한계를 지우지는 않는다

AirLLM은 다음 레이어 읽기와 현재 레이어 계산을 겹치는 prefetch를 제공한다. I/O와 compute가 균형을 이루면 대기 일부를 숨길 수 있다. 그러나 계산보다 저장장치 읽기가 느리거나 PCIe 전송이 포화되면 GPU는 다음 레이어를 기다린다. 반대로 느린 GPU에서 레이어 계산이 충분히 길면 prefetch 효과가 더 커질 수 있다. “NVMe니까 빠르다”가 아니라 레이어별 bytes, 순차 읽기 대역폭, host-to-device 전송, kernel 시간을 같은 타임라인에서 측정해야 한다.

자동회귀 생성에서는 이 문제가 더 중요하다. 첫 토큰을 만들기 위해 모든 레이어를 한 번 통과하고, 다음 토큰에도 모델의 모든 레이어가 다시 필요하다. KV cache는 이전 토큰의 attention 상태를 재계산하지 않게 해주지만 가중치 자체를 생략하지는 않는다. 모델 전체에 해당하는 I/O가 토큰 생성 루프에서 반복될 수 있으므로, VRAM 절약 폭이 크다고 tokens/sec도 좋아지는 것은 아니다.

이는 [LMCache의 KV cache 재사용](/posts/github-trending-lmcache-kv-cache-llm-serving/)과 해결 대상이 다르다. LMCache는 반복 prompt의 prefill 상태를 저장해 이미 한 계산을 재사용하려는 계층이다. AirLLM은 애초에 가중치를 GPU에 모두 올릴 수 없는 환경에서 한 번의 순전파를 가능하게 한다. 둘을 함께 쓴다고 자동으로 빠른 저메모리 서버가 되는 것도 아니다. weight streaming I/O와 KV cache offload I/O가 같은 RAM·NVMe·PCIe를 경쟁할 수 있다.

## 양자화·CPU offload·분산 서빙과 비교해야 답이 보인다

AirLLM README 첫 문장은 quantization, distillation, pruning 없이 70B를 4GB GPU에서 실행할 수 있다고 강조한다. 동시에 프로젝트는 선택적 4bit·8bit block-wise compression도 제공한다. 압축의 목적은 VRAM만 줄이는 것이 아니라 디스크에서 읽는 가중치 양을 줄여 I/O 병목을 완화하는 데 있다. README는 최대 3배 속도 향상과 거의 무시할 정확도 손실을 제시하지만, 이는 프로젝트가 인용한 조건의 결과다. 모델·하드웨어·prompt별 품질과 속도를 독립적으로 재현해야 한다.

| 방식 | 주로 줄이는 제약 | 강점 | 놓치기 쉬운 비용 |
|---|---|---|---|
| AirLLM 레이어 스트리밍 | GPU 상주 가중치 | 매우 작은 VRAM에서도 큰 모델 실행 가능 | 반복 디스크 I/O, 낮은 tokens/sec, shard 공간 |
| 4/8bit 양자화 | 가중치 메모리와 대역폭 | 일반 엔진 생태계 활용, 처리량 개선 가능 | 모델별 정확도 손실, kernel·하드웨어 호환성 |
| CPU/RAM offload | VRAM 용량 | 디스크보다 가까운 계층에서 가중치 유지 | 큰 시스템 RAM, PCIe 병목, NUMA 영향 |
| 다중 GPU tensor parallel | 단일 GPU 용량 | 온라인 처리량과 batching에 유리 | GPU·interconnect 비용, 분산 장애와 운영 복잡성 |
| 관리형 모델 API | 자체 하드웨어·서빙 운영 | 빠른 도입, 탄력적 용량 | 데이터 경계, 종속성, 사용량 비용 |

가령 70B 모델을 반드시 평가해야 하지만 사용 가능한 GPU가 4GB뿐이고 하루에 몇 개의 응답만 생성한다면 레이어 스트리밍이 유효하다. 반면 동시 사용자에게 스트리밍 답변을 제공하거나 agent loop가 수십 번 모델을 호출한다면 작은 양자화 모델 또는 API가 더 나은 결과를 낼 수 있다. “가장 큰 모델을 실행했다”보다 **업무가 끝나는 시간과 비용**이 선택 기준이어야 한다.

로컬 인프라의 다른 계층도 같은 원칙을 보여준다. [TurboVec의 압축 로컬 벡터 인덱스](/posts/github-trending-turbovec-local-vector-index/)는 검색 메모리를 줄이지만 recall과 인덱스 수명주기를 함께 측정해야 한다. AirLLM 역시 메모리 한 지표를 극적으로 개선하는 대신 latency와 저장장치 운영을 새 예산으로 만든다. 로컬이라는 배치 위치가 자동으로 빠름·저렴함·안전함을 의미하지 않는다.

## 적합한 워크로드는 온라인 챗봇보다 좁고 분명하다

레이어 스트리밍이 설득력 있는 첫 번째 경우는 **모델 호환성 검사**다. 제한된 연구 장비에서 checkpoint가 로드되는지, tokenizer와 generation path가 동작하는지, 소수 prompt의 출력 형태를 확인하려는 작업이다. 고가 GPU를 예약하기 전에 smoke test를 통과시키는 용도로는 느린 속도를 감수할 수 있다.

두 번째는 **저빈도 배치 작업**이다. 야간에 문서 몇 건을 요약하거나 후보 모델의 정성 평가 샘플을 생성하고, 완료 시간이 수십 분 늘어도 GPU 조달 비용을 피하는 편이 나은 상황이다. 이때도 처리량보다 deadline, 에너지, SSD read bytes와 실패 후 재개 가능성을 본다.

세 번째는 **교육과 아키텍처 실험**이다. 레이어별 activation, 모델 구조, offload 정책을 관찰하고 메모리 계층의 trade-off를 학습하는 환경에서는 오히려 노출된 I/O 구조가 장점이다. 그러나 모델 출력의 상업적 품질을 비교하는 실험이라면 느린 backend 때문에 평가 샘플 수가 줄어 통계적 신뢰도가 낮아질 수 있다.

반대로 다음 워크로드에는 기본 선택으로 권하기 어렵다.

- 여러 사용자가 동시에 요청하는 API와 짧은 TTFT가 필요한 챗봇
- tool call마다 모델을 다시 실행하는 장기 에이전트
- 높은 batch throughput이 비용 구조를 결정하는 데이터 처리
- 저장장치 IOPS가 공유되거나 ephemeral disk 용량이 작은 클라우드 환경
- 모델 업데이트와 autoscaling이 잦아 shard 준비 비용을 반복 지불하는 서비스

[GPU 개발 환경의 재현성과 격리](/posts/github-trending-gstack-gpu-dev-environment/)가 중요한 이유도 여기에 있다. 같은 모델이라도 driver, PyTorch, CUDA, 저장장치 mount, container memory limit가 달라지면 결과가 달라진다. AirLLM PoC 결과를 개발자 노트북에서 한 번 얻은 뒤 운영 노드의 예상치로 일반화해서는 안 된다.

## 모델 파일은 데이터이면서 실행 공급망이다

거대 모델을 로컬에서 돌리면 prompt가 외부 API로 나가지 않는다는 장점이 있다. 하지만 다운로드한 모델과 Python 패키지를 신뢰해야 한다. AirLLM은 Hugging Face repo ID 또는 로컬 경로를 받아 모델 유형을 자동 선택한다. 공개 이슈 #293은 `trust_remote_code` 기본 동작에 따른 원격 코드 실행 위험을, #296은 `.bin` shard 처리 과정의 역직렬화 위험을 제기한다. 이슈 제기는 취약점 확정과 같지 않지만, 운영 도입 전 확인해야 할 위협 모델로는 충분하다.

최소한 다음 경계를 둬야 한다.

1. 모델 revision을 branch 이름이 아니라 commit hash로 고정하고 허용 목록을 운영한다.
2. 가능하면 `safetensors` 형식과 검증된 tokenizer를 사용하며 파일 checksum을 기록한다.
3. 모델 변환은 클라우드 자격증명과 홈 디렉터리 secret이 없는 격리된 worker에서 실행한다.
4. 인터넷 egress를 모델 registry와 필요한 패키지 저장소로 제한한다.
5. 원본과 shard의 라이선스·notice·접근 조건을 artifact metadata에 보존한다.
6. shard 경로를 사용자 입력과 분리하고 symlink, partial file, disk exhaustion을 실패 시나리오에 넣는다.

Git worktree만으로 프로세스 권한을 격리할 수 없듯이, “로컬 모델”이라는 라벨도 실행 안전을 보장하지 않는다. 비신뢰 모델을 다룬다면 [MicroVM 기반 AI 샌드박스](/posts/github-trending-cubesandbox-microvm-ai-sandbox/)에서 설명한 파일·프로세스·네트워크 경계를 별도로 적용해야 한다.

## PoC에서는 최대 모델 크기보다 유효 처리량을 측정한다

첫 실험은 70B 하나만 성공시키는 데모가 아니라 같은 업무를 수행하는 세 후보의 비교여야 한다. 예를 들어 AirLLM full precision, AirLLM 4bit compression, 일반 엔진의 더 작은 양자화 모델을 같은 prompt set과 출력 기준으로 실행한다. 가능하면 관리형 API도 비용 기준선에 넣는다.

![저VRAM LLM 추론 PoC 의사결정 기준](https://heracles-jo.github.io/assets/img/posts/airllm-low-vram-layer-streaming/decision.svg)

측정 항목은 다음처럼 나눈다.

- **준비 비용**: 모델 다운로드 시간, 원본·shard 최대 disk usage, 변환 시간, 재시작 시 재사용 여부
- **사용자 지연**: time to first token, inter-token latency, end-to-end latency, cold·warm run 차이
- **유효 처리량**: 단순 tokens/sec뿐 아니라 품질 기준을 통과한 응답 수/시간
- **자원 경로**: peak VRAM·RAM, NVMe read bytes/sec, PCIe throughput, GPU idle ratio, CPU utilization
- **품질 변화**: task success, exact match 또는 judge 기준과 사람이 확인한 오류 유형
- **운영 안정성**: disk full, 손상된 shard, 프로세스 중단, 모델 revision 변경, dependency rollback 후 복구
- **보안성**: 외부 코드 실행 여부, 다운로드 provenance, secret 접근, egress 기록
- **총비용**: GPU 시간뿐 아니라 SSD 용량·I/O, 실행 시간, 운영자 재시도와 실패 샘플 비용

특히 README의 최소 VRAM 숫자를 재현하려고 OS와 runtime의 여유 메모리를 무시하면 안 된다. CUDA context, allocator fragmentation, activation, KV cache와 긴 context가 추가 공간을 쓴다. prompt 길이와 생성 길이를 단계적으로 늘리고 OOM 경계를 기록해야 한다. MoE 모델도 전체 parameter와 token당 활성 parameter가 다르지만, 어떤 가중치를 언제 읽는지는 구현에 따라 달라지므로 “활성 파라미터가 작다”만으로 I/O를 추정해서는 안 된다.

PoC의 합격선은 업무별로 다르다. 배치 연구라면 “12시간 deadline 안에 100개 평가 응답, 95% 이상 성공, 재시작 후 shard 재사용”이 될 수 있다. 개인 대화형 도구라면 “warm TTFT 5초 이하, 일정한 inter-token latency”처럼 사용자 체감이 우선이다. 기준을 먼저 정하면 거대 모델 구동 스크린샷과 실제 도입 가능성을 분리할 수 있다.

## AirLLM은 GPU 대체재가 아니라 메모리 계층 선택지다

AirLLM이 보여주는 핵심은 거대 모델 추론의 하한을 GPU 용량만으로 정할 필요가 없다는 사실이다. 레이어 스트리밍은 불가능해 보이던 모델을 제한된 장비에서 실행하게 하고, model compatibility test·저빈도 배치·교육용 실험에 유용한 선택지를 제공한다. v3의 FP8·최신 모델 지원과 단일 `AutoModel` 경로도 탐색 비용을 낮춘다.

그러나 이 접근은 온라인 서빙의 물리 법칙을 우회하지 않는다. VRAM에서 빠진 가중치는 디스크와 RAM, PCIe를 통과해야 하며 이 비용은 토큰 생성 루프에서 반복된다. 압축은 이동량을 줄이지만 품질 검증이 필요하고, prefetch는 병목 일부를 겹칠 뿐 제거하지 않는다. 모델 shard와 원격 코드는 새로운 공급망·저장장치 운영 대상이 된다.

따라서 도입 질문은 “4GB에서 70B가 켜지는가”가 아니다. **우리 workload에서 더 작은 양자화 모델보다 충분히 나은 답을, 허용 가능한 완료 시간과 검증 가능한 보안 경계 안에서 만드는가**다. 그 비교에서 품질 이득이 I/O·운영 비용보다 클 때 AirLLM은 영리한 우회로가 된다. 그렇지 않다면 큰 모델을 실행했다는 사실보다 작은 모델을 안정적으로 서비스하는 편이 더 좋은 인프라 결정이다.

> 1차 자료: [AirLLM 저장소와 README](https://github.com/lyogavin/airllm), [v3.0.1 릴리스](https://github.com/lyogavin/airllm/releases/tag/v3.0.1), [열린 이슈 목록](https://github.com/lyogavin/airllm/issues), [AirLLM 논문](https://arxiv.org/abs/2308.16179). 저장소 수치와 활동은 2026년 7월 19일 03시 KST 공개 페이지·API 확인 시점의 스냅샷이다.
