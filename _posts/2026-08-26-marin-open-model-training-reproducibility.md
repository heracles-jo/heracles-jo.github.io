---
title: "오픈 모델 학습 재현성: Marin 도입 판단과 실패 비용"
description: "Marin의 데이터·학습·평가 DAG와 공개 회고를 바탕으로 오픈 모델 학습을 재현 가능한 실험 자산으로 만드는 방법, 비용·보안 경계와 PoC 기준을 정리한다."
author: heracles-jo
date: 2026-08-26 07:30:00 +0900
categories: [AI Infrastructure, Open Source]
tags: [marin, foundation-model, model-training, reproducibility, mlops, open-source]
image:
  path: https://heracles-jo.github.io/assets/img/posts/marin-open-model-training-reproducibility/cover.svg
  alt: "Marin이 데이터, 학습, 평가, 실패 기록을 연결해 오픈 모델 학습 재현성을 만드는 흐름"
---

파운데이션 모델을 직접 학습하려는 조직이 가장 먼저 부딪히는 문제는 GPU나 TPU를 확보하는 일이 아니다. 어떤 원천 데이터를 어떤 규칙으로 정제했는지, 실험마다 무엇이 달랐는지, 중단된 작업을 어디서 재개했는지, 좋은 점수가 데이터 오염 때문은 아닌지를 나중에도 설명할 수 있어야 한다. 모델 가중치만 공개하거나 체크포인트만 보관해서는 이 질문에 답할 수 없다. **오픈 모델 학습의 핵심 자산은 최종 모델이 아니라 데이터부터 실패까지 이어지는 재현 가능한 의사결정 기록**이다.

2026년 8월 26일 07:39 KST에 확인한 GitHub Trending daily 화면에서 [marin-community/marin](https://github.com/marin-community/marin)은 277 stars today로 노출됐다. 같은 시점 GitHub API 스냅샷은 2,076 stars, 190 forks, 584 open issues, Apache-2.0 라이선스, 8월 25일 최신 push를 보여줬다. 최근 커밋에는 TPU 실행 환경, CI, Grafana, 강화학습 오류 반환, H100 확장 실험이 함께 나타났다. 이 수치들은 품질 순위가 아니라 관심과 개발 활동을 보여주는 시점 한정 신호다.

## 후보를 비교하니 남은 질문은 ‘에이전트’가 아니라 ‘학습 증거’였다

오늘 daily/weekly 후보는 대부분 이미 이 블로그가 다룬 검색 의도와 가까웠다. 그래서 저장소 이름이 다른지만 보지 않고, 독자가 해결하려는 문제가 실제로 다른지를 비교했다.

| 후보 | 확인 시점 신호 | 기존 글과의 중복 | 검색 의도와 장기 가치 |
|---|---:|---|---|
| [marin-community/marin](https://github.com/marin-community/marin) | daily 277 stars today, API 2,076 stars, Apache-2.0, 당일 커밋 활동 | 낮음 | 오픈 모델 학습 재현성·실험 추적·실패 자산화라는 독립 의도가 분명함 |
| [anthropics/claude-plugins-community](https://github.com/anthropics/claude-plugins-community) | daily 350, weekly 877 stars, API 1,714 stars | 높음 | 플러그인 공급망은 기존 Agent Skills·MCP 보안 글과 직접 인접 |
| [AgriciDaniel/claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) | daily 810 stars, API 12,669 stars | 높음 | 로컬 지식 그래프·에이전트 메모리 검색 의도를 반복할 가능성이 큼 |
| [tinyhumansai/openhuman](https://github.com/tinyhumansai/openhuman) | daily 541 stars, API 37,735 stars, GPL-3.0 | 높음 | 로컬 메모리와 에이전트 오케스트레이션이 기존 클러스터와 겹침 |
| [asciimoo/hister](https://github.com/asciimoo/hister) | daily 166 stars, API 2,747 stars, AGPL-3.0 | 중간 | 개인 검색 엔진은 별도 의도가 있으나 이번 후보군에서는 학습 운영 주제가 더 깊은 1차 자료를 제공 |

Marin을 선택한 이유는 단순히 아직 쓰지 않은 프로젝트여서가 아니다. README는 Marin을 파운데이션 모델 연구·개발을 위한 연구 프로그램, 소프트웨어 플랫폼, 커뮤니티로 정의한다. 범위도 데이터 큐레이션·변환·필터링·토큰화에서 사전학습, 후학습, 평가까지 이어진다. 특히 성공한 레시피만이 아니라 원시 데이터에서 최종 모델까지의 과정과 실패한 실험을 함께 기록한다는 원칙이 명시돼 있다. 이는 “어떤 모델을 내려받을까”가 아니라 **“우리 조직의 모델 학습 결정을 어떻게 감사하고 재현할까”**를 찾는 독자에게 답이 된다.

## Marin은 학습 스크립트보다 실험 의존성 그래프에 가깝다

Marin의 기본 실행 모델은 Makefile과 비슷하다. 데이터 토큰화, 학습, 평가 같은 step이 서로의 산출물을 의존하고, `StepRunner`가 위상 순서대로 그래프를 실행한다. 공식 학습 튜토리얼에 따르면 import 시점에는 아무 작업도 실행하지 않으며, lazy artifact를 실행 그래프로 낮춘 뒤 캐시를 확인한다. 이미 성공한 step은 건너뛰고 누락되거나 강제로 지정된 step만 실행한다.

![Marin의 데이터에서 평가까지 이어지는 lazy artifact DAG](https://heracles-jo.github.io/assets/img/posts/marin-open-model-training-reproducibility/architecture.svg)

이 구조의 가치는 세 가지다. 첫째, **실험 정체성**이 코드에 남는다. 모델 구조, optimizer, 데이터 혼합비, batch size, sequence length, 학습 step, 평가 묶음처럼 결과를 바꾸는 인자는 명시적으로 전달된다. 공식 문서는 하드웨어 자원을 fingerprint에서 제외하지만, 모델과 데이터에 관한 결정은 artifact 이름과 version에 연결한다. 같은 실험을 다른 가속기에서 실행하더라도 연구 가설과 실행 자원을 구분하려는 설계다.

둘째, **중간 산출물을 재사용**할 수 있다. 토큰화가 끝났는데 학습이 실패했다면 원천 데이터를 다시 처리할 필요가 없다. `${MARIN_PREFIX}`는 로컬 경로나 GCS 같은 `fsspec` 경로가 될 수 있고 체크포인트와 산출물이 그 아래에 쌓인다. 대규모 학습에서 재현성은 철학만이 아니라 중복 계산을 줄이는 비용 통제다.

셋째, **작은 실험과 클러스터 실행이 같은 개념 모델을 공유**한다. 공식 설치 문서는 Python 3.12 이상과 `uv`를 요구하고 CPU·GPU·TPU별 JAX 의존성을 나눈다. TinyStories를 CPU에서 학습하는 경로와 Iris를 통해 TPU/GPU 작업을 제출하는 경로가 같은 step graph에서 출발한다. 단, 이것이 로컬 PoC를 그대로 대규모 학습으로 확대하면 된다는 뜻은 아니다. 스토리지 처리량, collective 통신, 선점 복구, 체크포인트 시간, 데이터 locality는 규모가 커질수록 별도의 설계 문제가 된다.

## 공개 회고가 보여준 진짜 가치: 실패를 삭제하지 않는 것

Marin 8B와 32B 회고는 이 플랫폼의 장점을 성공 점수보다 더 잘 보여준다. 8B 회고에는 Llama 2 방식 rotary embedding 설정을 뒤늦게 발견한 일, 낮은 learning rate 구간에서 `lm_head` norm이 커진 문제, z-loss를 추가해 이를 다룬 과정이 적혀 있다. 소위 고품질 데이터만 과하게 섞었을 때 검증 loss는 좋아졌지만 일반 task 성능이 나빠졌다는 관찰도 공개한다. “고품질”이라는 라벨이 실제 업무 성능을 보장하지 않는다는 의미다.

32B 회고는 더 직접적이다. 8B 레시피를 확장했지만 70k~80k step 부근에서 loss spike가 발생했고 gradient clipping, update norm clipping, bad step skip, optimizer 교체가 근본 해결책이 되지 못했다. 이후 QK-Norm을 포함한 Qwen3 계열 구조로 전환해 안정성을 회복했다고 기록한다. 또 cooldown 데이터 캐시에 GSM8K test 항목이 섞인 오염과, 저렴한 선형 permutation이 데이터 상관 구간을 만든 shuffle 문제도 공개했다. 오염된 실험을 조용히 버리는 대신 원인, 영향, 수정된 Feistel shuffle까지 연결한다.

이 사례의 교훈은 Marin이 실수를 막아 주는 도구라는 것이 아니다. **실수를 재현 가능한 조사 대상으로 바꾸는 플랫폼**이라는 점이 더 중요하다. 모델 학습은 장시간·고비용 작업이라 실패를 숨기고 싶은 유인이 크다. 하지만 설정 diff, 데이터 lineage, 체크포인트, metric, issue, 회고가 연결돼 있으면 실패한 계산도 다음 실험의 사전 조건이 된다.

이는 [TimesFM의 시계열 예측 운영](/posts/github-trending-timesfm-time-series-foundation-model/)에서 강조한 rolling backtest와 데이터 누수 통제의 확장판이다. 예측 모델 하나를 검증할 때도 데이터 cut-off가 중요한데, 파운데이션 모델에서는 수십 개 corpus, tokenizer, 중복 제거, 포맷 변환, 평가 harness가 모두 오염 경로가 된다. 또한 [NVIDIA Cosmos의 Physical AI 검증](/posts/github-trending-nvidia-cosmos-physical-ai/)처럼 안전이나 물리 세계와 연결되는 모델이라면 “어떤 체크포인트가 어떤 데이터와 코드에서 나왔는가”는 연구 편의가 아니라 책임성의 기반이다.

## 도입 비용은 프레임워크 설치가 아니라 운영 경계에서 생긴다

Marin은 Apache-2.0이지만, 이를 사용한 모델 학습 전체가 자동으로 라이선스 문제에서 자유로워지는 것은 아니다. 원천 문서, 코드, 합성 데이터, tokenizer, 평가 데이터, 사전학습 체크포인트는 서로 다른 조건을 가질 수 있다. artifact graph에 데이터 ID를 넣는 것만으로는 부족하며, 원천 URL·스냅샷·라이선스·삭제 요구·PII 처리·지역 제한을 데이터 계약으로 관리해야 한다.

보안 경계도 분명히 나눠야 한다. 설치 문서는 W&B API key와 Hugging Face token을 환경 변수로 사용하고, Iris의 capability URL은 특정 endpoint에 접근하는 credential이므로 공유하지 말라고 경고한다. 실무에서는 다음을 별도로 통제해야 한다.

- 데이터 수집 계정과 학습 실행 계정의 권한을 분리한다.
- W&B 같은 외부 관측 서비스에 sample text, prompt, 파일 경로, 비밀 값이 전송되지 않는지 검사한다.
- 체크포인트와 optimizer state를 일반 로그보다 높은 등급의 지식재산으로 취급한다.
- capability URL, cloud credential, Hugging Face token을 job spec이나 Git diff에 남기지 않는다.
- 외부 기여 실험은 격리된 bucket·cluster·service account에서 실행하고 산출물 승격 절차를 둔다.

비용 모델 역시 accelerator 시간만 보면 틀린다. 데이터 변환과 deduplication의 CPU·스토리지 비용, 토큰화 산출물 보관, 빈번한 체크포인트 쓰기, 평가용 추론, 실패 작업의 유휴 자원, egress, 관측 데이터 보존이 총비용에 들어간다. [Modular MAX와 Mojo의 런타임 이식성](/posts/github-trending-modular-ai-runtime-portability/)이 추론 하드웨어 선택권을 다뤘다면, Marin은 학습 단계에서 실험 정의와 실행 자원을 분리하는 방향을 보여준다. 그러나 GPU와 TPU에서 같은 graph를 실행할 수 있다는 사실이 결과 동일성을 보장하지는 않는다. backend, kernel, precision, collective, seed와 비결정적 연산을 함께 기록해야 한다.

## 무엇과 비교해야 하나: 모델이 아니라 운영 방식이다

Marin PoC를 범용 MLOps 도구나 학습 라이브러리 하나와 단순 비교하면 판단이 흐려진다. 비교 단위는 다음 네 가지 운영 방식이어야 한다.

| 방식 | 장점 | 숨은 비용 | 적합한 상황 |
|---|---|---|---|
| 노트북·개별 스크립트 | 시작이 빠르고 연구 자유도가 높음 | lineage, 재시작, 리뷰, 재현성이 사람 기억에 의존 | 하루 안에 폐기할 작은 가설 |
| 사내 workflow + 학습 라이브러리 | 기존 IAM·관측성·비용 정책과 결합하기 쉬움 | 데이터·모델 artifact 규약을 직접 설계해야 함 | 이미 성숙한 ML 플랫폼이 있는 조직 |
| 관리형 학습 플랫폼 | 자원 할당과 운영 지원이 단순함 | vendor 종속, egress, 세밀한 실험 구조 제약 | 인프라 인력이 적고 표준 모델을 학습하는 팀 |
| Marin형 open-development stack | 데이터부터 평가·실패까지 코드와 공개 기록으로 연결 | 빠른 변화, 큰 저장소, 클러스터 통합과 보안 운영 부담 | 학습 방법 자체가 연구 자산이며 외부 재현성이 중요한 팀 |

특히 Marin의 open issue 수가 확인 시점 584개라는 사실은 활발함과 동시에 큰 운영 표면을 뜻한다. 최신 commit이 CI, 스케줄러, Grafana, RL, 가속기 설정을 동시에 건드린다는 점도 같다. 안정된 제품 SDK라기보다 연구와 플랫폼 개발이 빠르게 맞물린 저장소다. 조직이 upstream 변화 추적, 버전 고정, patch 관리, 재현성 회귀 테스트를 감당하지 못한다면 전체 도입보다 개념만 가져오는 편이 낫다.

## PoC는 작은 모델의 정확도보다 ‘재실행 가능한 실패’를 측정해야 한다

![Marin 도입 의사결정에서 재현성, 비용, 보안, 운영 성숙도를 평가하는 매트릭스](https://heracles-jo.github.io/assets/img/posts/marin-open-model-training-reproducibility/decision.svg)

2~4주 PoC라면 거대한 모델을 학습할 이유가 없다. TinyStories나 조직이 사용 권리를 명확히 가진 작은 corpus로 CPU 또는 단일 GPU 실험을 만들고 아래 항목을 측정하는 편이 낫다.

1. **정체성 재현성**: 새 환경에서 같은 commit, lockfile, 데이터 snapshot, config로 graph를 다시 만들 수 있는가.
2. **부분 재실행률**: 토큰화 이후 학습 실패를 주입했을 때 이미 성공한 step을 건너뛰고 정확한 지점부터 재개하는가.
3. **lineage 완결성**: 임의 체크포인트에서 원천 데이터 버전, tokenizer, model config, optimizer, 평가 결과까지 역추적 가능한가.
4. **오염 방지**: 평가 데이터 hash나 split 규칙이 training mixture에 들어오면 CI가 차단하는가.
5. **비용 가시성**: step별 accelerator-hour, CPU-hour, storage 증가량, checkpoint 시간, 재시도 비용이 산출되는가.
6. **비밀 격리**: 실행 로그와 W&B artifact에 token, sample PII, capability URL이 남지 않는가.
7. **변경 검토성**: 데이터 혼합비 1개를 바꾼 PR에서 어떤 downstream artifact가 무효화되는지 리뷰어가 이해할 수 있는가.
8. **복구 훈련**: worker 선점, bucket 일시 장애, 손상된 checkpoint를 넣었을 때 중복 계산과 잘못된 승격 없이 복구하는가.

성공 기준은 작은 모델의 benchmark가 높게 나오는 것이 아니다. 팀원이 바뀌고 일주일이 지나도 같은 실험을 설명하고, 의도적으로 만든 실패를 제한된 비용으로 복구하며, 결과가 바뀌었을 때 원인을 좁힐 수 있어야 한다. 에이전트 실행 이력을 append-only event로 남기는 [Apache Maka 감사 로그 설계](/posts/apache-maka-agent-runtime-event-log/)와도 원리는 통한다. 고비용 AI 시스템에서는 최종 출력보다 **결정과 실행의 계보**가 먼저 운영 자산이 된다.

Marin이 모든 팀의 기본 학습 플랫폼이 될 필요는 없다. 기존 ML 플랫폼이 데이터 lineage와 캐시, 체크포인트, 평가, 비용, 보안을 이미 잘 다룬다면 전면 교체의 이득은 작다. 반대로 모델 학습이 여러 노트북과 bucket, 개인 W&B project, 구두 결정에 흩어져 있다면 Marin의 lazy artifact DAG와 공개 회고 방식은 강력한 기준점이다. 당장 대규모 클러스터를 붙이기보다 **실패한 실험 하나를 다른 사람이 재현하고 설명할 수 있는가**부터 시험하는 것이 맞다. 오픈 모델의 신뢰는 가중치를 내려받을 수 있다는 사실이 아니라, 그 가중치가 만들어진 과정을 반박하고 다시 실행할 수 있다는 데서 시작한다.
