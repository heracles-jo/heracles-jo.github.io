---
title: "금융 시계열 파운데이션 모델: Kronos K선 예측 검증 기준"
description: "Kronos의 계층형 K선 토큰화와 자기회귀 예측을 해부하고, 데이터 누수·백테스트·거래비용·체크포인트 계보를 중심으로 금융 시계열 모델의 도입 기준을 제시한다."
author: heracles-jo
date: 2026-10-21 08:05:00 +0900
categories: [AI Infrastructure, Data Engineering]
tags: [kronos, financial-time-series, foundation-model, backtesting, data-leakage, quantitative-finance]
image:
  path: https://heracles-jo.github.io/assets/img/posts/kronos-financial-kline-foundation-model/cover.svg
  alt: "Kronos 금융 K선 파운데이션 모델의 토큰화와 검증 경계를 표현한 개념도"
---

금융 시계열에 파운데이션 모델을 적용할 때 가장 위험한 질문은 “내일 가격을 맞히는가”가 아니다. **모델이 보지 않은 미래에서, 비용과 제약을 포함한 의사결정 품질이 반복되는가**가 먼저다. 예측 곡선이 실제 차트와 비슷해 보여도 학습 데이터의 종료 시점이 불명확하거나 정규화 과정에 미래 값이 섞였다면 그 결과는 투자 신호가 아니라 누수된 재구성일 수 있다.

[shiyu-coder/Kronos](https://github.com/shiyu-coder/Kronos)는 이 문제를 금융 K선 자체의 표현 학습으로 풀려는 오픈소스 프로젝트다. 2026년 10월 21일 08시 15분 KST 전후 GitHub Trending daily에서 `719 stars today`로 표시됐고, GitHub API 확인 시점에는 42,330 stars, 7,010 forks, 열린 issue와 PR을 합친 283개, MIT 라이선스를 보였다. 저장소의 마지막 병합 커밋은 2026년 4월 13일이며 정식 GitHub release는 없지만, 공개 모델과 fine-tuning 예제, Qlib 기반 단순 백테스트가 제공된다. 수치와 활동은 확인 시점의 공개 스냅샷이고 모델 성능이나 수익성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 데이터에 접근하지 못해 주제 선정 근거로 사용하지 않았다.

## 후보 비교: 에이전트 도구 대신 금융 모델의 검증 문제를 택했다

오늘 Trending 상위권은 코딩 에이전트, 멀티 에이전트, 도구 출력 압축에 편중돼 있었다. 저장소 이름뿐 아니라 기존 글이 답한 중심 질문까지 비교하면 대부분은 최근 클러스터와 겹친다.

| 후보 | 확인 시점 신호 | 중복·장기 가치 판단 |
|---|---|---|
| [Kronos](https://github.com/shiyu-coder/Kronos) | daily 719, 42,330 stars, MIT, AAAI 2026 채택 공지 | 일반 시계열 모델 소개보다 좁은 **금융 K선 토큰화와 누수 없는 백테스트** 의도가 독립적이다. |
| [Ruflo](https://github.com/ruvnet/ruflo) | daily 683, 77,811 stars, MIT, v3.59.1 | 멀티 에이전트 오케스트레이션은 Orca·Google AX·에이전트 런타임 글과 중심 논지가 겹친다. |
| [Graphify](https://github.com/Graphify-Labs/graphify) | daily 906, 130,180 stars, Apache-2.0, v0.9.93 | 코드 지식 그래프는 codebase-memory-mcp와 XERJ 검색 계층에서 이미 다뤘다. |
| [Headroom](https://github.com/headroomlabs-ai/headroom) | daily 555, 76,731 stars, Apache-2.0, v0.41.0 | 도구 출력 압축은 Context Mode의 세션 I/O 최적화 검색 의도와 직접 충돌한다. |
| [OpenCode](https://github.com/anomalyco/opencode) | daily 1,256, 218,869 stars, MIT, 당일 커밋 활발 | 오픈소스 코딩 에이전트라는 넓은 주제는 기존 권한·메모리·리뷰 글을 다시 묶는 데 그칠 가능성이 크다. |

Kronos도 [TimesFM과 시계열 파운데이션 모델](/posts/github-trending-timesfm-time-series-foundation-model/) 글과 가까워 보인다. 차이는 검색자의 다음 행동이다. TimesFM 글은 수요·용량·IoT 등 여러 업무 지표에 zero-shot baseline을 도입하는 운영 문제를 다뤘다. 여기서는 금융 K선의 전용 토큰화, 사전학습 종료 시점, 종목 횡단 평가, 거래비용과 체크포인트 계보를 묻는다. “시계열 모델이 무엇인가”가 아니라 **금융 예측을 믿지 않기 위해 무엇을 검증해야 하는가**가 중심이다.

## 연속 가격을 언어처럼 바꾸는 두 단계

Kronos 논문은 Open·High·Low·Close·Volume·Amount로 이뤄진 OHLCVA 레코드를 하나의 연속 벡터로 직접 회귀하지 않는다. 먼저 Transformer autoencoder와 Binary Spherical Quantization을 이용해 각 K선을 coarse subtoken과 fine subtoken으로 나눈다. coarse token은 큰 구조를, fine token은 남은 세부를 복원하도록 학습한다. 그다음 decoder-only Transformer가 과거 token을 보고 다음 coarse token, 이어서 fine token을 자기회귀적으로 생성한다.

공개 논문은 45개 글로벌 거래소, 7개 시간 해상도, 120억 개가 넘는 K선 레코드로 사전학습했다고 보고한다. 일반 TSFM에서 금융 데이터 비율이 작아 금융 특유의 낮은 신호대잡음비, 비정상성, 가격·거래량 결합 구조가 희석된다는 문제의식이다. Kronos는 금융 데이터만으로 표현 공간을 만들고 가격·수익률·실현 변동성 예측과 합성 K선 생성에 같은 backbone을 사용한다.

![Kronos가 원천 K선에서 계층형 토큰과 확률 경로를 생성한 뒤 검증·의사결정 계층으로 전달되는 아키텍처](https://heracles-jo.github.io/assets/img/posts/kronos-financial-kline-foundation-model/architecture.svg)

이 접근의 장점은 명확하다. 연속값 회귀보다 이산 상태 공간에서 극단치 영향을 제한할 수 있고, 여러 미래 경로를 샘플링해 분포와 불확실성을 다룰 수 있다. 논문도 가격·수익률 예측에는 낮은 temperature와 여러 trajectory 평균을 사용하고, 합성 데이터에는 더 높은 다양성을 허용한다. 그러나 언어 모델과 닮은 생성 방식은 새로운 운영 변수도 만든다. `temperature`, `top_p`, sample count를 바꾸면 예측값뿐 아니라 지연과 GPU 비용이 함께 달라진다. 같은 모델 이름으로도 추론 정책이 다르면 서로 다른 전략으로 봐야 한다.

또한 token이 시장의 원인을 설명하지는 않는다. 금리 발표, 실적, 거래정지, 액면분할, 규제 변화가 K선에 흔적을 남길 수는 있지만 모델은 사건의 법적·경제적 의미를 직접 보지 않는다. tokenization은 압축된 시장 상태를 만드는 방법이지 인과 모델이 아니다. 따라서 설명이 필요한 리스크 결정에서는 뉴스·기업행동·포지션·유동성 데이터를 별도 계층으로 유지해야 한다.

## 가장 먼저 볼 것은 점수가 아니라 시간 경계다

논문은 사전학습 데이터가 2024년 6월까지라고 밝히고 모든 평가를 2024년 7월부터 시작한다. 이 원칙은 올바르지만 downstream 팀은 논문의 문장을 그대로 자신의 실험 보증으로 가져오면 안 된다. 어떤 공개 checkpoint가 어느 코드·데이터 snapshot으로 만들어졌는지, 데이터 종료 시점이 model card에 기계적으로 연결돼 있는지 확인해야 한다.

저장소의 공개 이슈가 이 경계를 잘 보여 준다. 2026년 3월에는 fine-tuning dataset이 lookback과 forecast horizon 전체로 평균·표준편차를 계산해 미래 정보를 정규화에 섞는다는 지적이 올라왔다. 해당 코드는 과거 구간만 사용하도록 수정됐고 이슈는 닫혔다. 하지만 별도 이슈에서는 현재 Hugging Face checkpoint가 수정 전 파이프라인으로 학습됐는지, 수정 후 재학습됐는지가 공개 metadata만으로 명확하지 않다고 질문한다. 코드가 고쳐졌다는 사실과 배포된 가중치가 깨끗하다는 사실은 다르다.

이 때문에 model registry에는 최소한 다음이 함께 있어야 한다.

- 사전학습 데이터의 시작·종료 시점과 거래소·자산·주기별 범위
- tokenizer와 predictor의 checkpoint hash, 학습 코드 commit SHA
- normalization 범위와 corporate action 처리 규칙
- fine-tuning 데이터 split과 embargo·purge 기간
- 추론 `temperature`, `top_p`, sample count, random seed
- 모델이 생성한 신호부터 주문까지의 변환식과 비용 가정

[Marin의 오픈 모델 학습 재현성](/posts/marin-open-model-training-reproducibility/)에서 데이터 lineage와 checkpoint를 의사결정 기록으로 연결했듯, 금융 모델은 “어떤 가중치인가”를 넘어 “어느 날짜까지 무엇을 보았는가”를 artifact의 일부로 취급해야 한다. 이를 재구성할 수 없다면 새 기간에서 좋은 결과가 나와도 진짜 일반화와 기억을 구분하기 어렵다.

## 예측 오차와 투자 성과는 같은 목표가 아니다

Kronos 논문은 IC·RankIC, 변동성 MAE·R², 합성 데이터의 fidelity·usefulness, 투자 시뮬레이션의 Annualized Excess Return과 Information Ratio를 함께 사용한다. 이 구분은 중요하다. 종목 하나의 종가 경로를 가깝게 맞히는 모델이 종목 간 수익률 순위를 잘 정한다는 보장은 없고, 순위를 잘 정해도 회전율과 비용을 감당하지 못하면 전략은 손실이 된다.

공개 이슈의 독립 실험도 같은 교훈을 준다. 한 기여자는 논문이 밝힌 사전학습 종료 이후 기간에서 미국 주식 182개를 대상으로 횡단 순위 평가를 수행했고, 양의 IC를 관찰했지만 통계적으로 강하지 않았으며 거래비용 후에는 유지되지 않았다고 보고했다. 단일 커뮤니티 실험이 모델 전체를 반증하지는 않는다. 오히려 논문 평균과 다른 시장·구간·universe에서 성과가 얼마나 빨리 약해질 수 있는지를 보여 주는 유용한 반증 자료다.

[에이전트형 금융 리서치의 거버넌스](/posts/github-trending-vibe-trading-agentic-finance-governance/)에서도 강조했듯, 예측 생성과 주문 실행 사이에는 포트폴리오 구성, 노출 제한, 승인, 감사 로그가 있어야 한다. Kronos 출력은 완성된 거래 전략이 아니라 확률적 feature 또는 ranking candidate에 가깝다. production에서는 다음 baseline과 같은 비용 조건으로 비교해야 한다.

| 비교 대상 | 확인할 질문 | Kronos가 이겨야 하는 기준 |
|---|---|---|
| 최근값·이동평균 | 복잡한 모델 없이도 같은 방향성을 얻는가 | 순수 예측 지표와 비용 후 효용 모두 개선 |
| ARIMA·GARCH | 단일 자산과 변동성에서 고전 모델보다 안정적인가 | regime별 평균뿐 아니라 tail error 감소 |
| LightGBM·선형 factor | 가격·거래량 feature를 직접 쓴 모델보다 나은가 | 동일 universe·동일 split에서 RankIC와 turnover 개선 |
| TimesFM·Chronos | 범용 TSFM 대비 금융 전용 사전학습 가치가 있는가 | 여러 거래소·주기에서 일관된 OOS 우위 |
| 기존 운영 전략 | 새 신호가 이미 가진 factor와 중복되는가 | 중립화 후에도 유의한 incremental IC 유지 |

## 실패 모드는 데이터 피드와 운영 계층에서 먼저 나온다

논문은 가격 급변, 무거래, 장기 정체 구간을 주기별 threshold로 정리하고, 가격 결측은 시계열 경계로 나누며 volume·amount 결측은 0으로 처리한다. 연구 corpus를 만들기 위한 합리적인 규칙이지만 실시간 운영에서는 같은 변환이 다른 의미를 가질 수 있다. 거래소 장애와 진짜 무거래를 구분하지 못하거나, 액면분할을 이상치로 삭제하거나, 해외 시장의 휴장·시간대를 잘못 정렬하면 모델 입력은 정상 범위 안에서도 잘못된다.

보안과 공급망도 무시하기 어렵다. 모델은 Hugging Face checkpoint, Python 의존성, 시장 데이터 공급자, fine-tuning pickle, Qlib pipeline에 의존한다. 가중치 hash와 `safetensors` 여부만 확인해서는 부족하다. 데이터 수정본이 소급 적용됐는지, 심볼 매핑이 바뀌었는지, delisted 종목이 제거돼 생존편향이 생겼는지, vendor의 adjusted price 정책이 달라졌는지를 함께 추적해야 한다.

운영 서비스라면 모델 프로세스에 브로커 자격증명을 주지 않는 편이 기본이다. 예측기는 서명된 forecast artifact를 만들고, 별도 risk engine이 포지션·한도·시장 상태·중복 주문을 검사하며, execution service가 승인된 주문만 전송해야 한다. 모델 timeout이나 NaN, 오래된 데이터, 예상 밖의 token distribution은 “직전 신호 재사용”이 아니라 fail-closed로 이어져야 한다.

![Kronos 금융 모델을 배포하기 전에 데이터 시간 경계, 가중치 계보, 통계 검증, 비용, 실행 권한을 차례로 확인하는 검증 게이트](https://heracles-jo.github.io/assets/img/posts/kronos-financial-kline-foundation-model/validation-gates.svg)

## PoC는 수익률 차트보다 반증 실험으로 설계한다

첫 PoC에서 자동매매를 목표로 잡으면 모델 오류와 전략 오류, 주문 오류가 한꺼번에 섞인다. 더 나은 순서는 좁은 universe와 한 가지 horizon을 정하고, 예측 artifact만 생성해 기존 연구 환경에서 shadow evaluation을 수행하는 것이다.

1. **시간 분리**: 공식 종료 시점 이후 데이터만 쓰되, 자신의 fine-tuning과 feature 계산에도 purge·embargo를 적용한다.
2. **점진적 baseline**: 최근값, 선형 factor, LightGBM, 전용 deep model, 범용 TSFM을 같은 split과 비용으로 비교한다.
3. **횡단·시계열 분리**: 종목별 오차와 날짜별 종목 순위를 따로 측정한다. 평균 하나로 합치지 않는다.
4. **비용 스트레스**: 수수료·spread·slippage·market impact를 1배, 2배, 3배로 바꾸고 break-even turnover를 계산한다.
5. **regime slice**: 상승·하락·고변동·저유동성·이벤트 기간을 나눠 손실 집중 구간을 찾는다.
6. **재현성**: checkpoint hash, 데이터 snapshot, seed, inference sampling 설정으로 같은 결과를 다시 만든다.
7. **shadow 운영**: 실제 주문 없이 지연, stale feed, 결측, 장중 장애, 재시작 후 중복 신호를 관찰한다.

중단 조건도 미리 정해야 한다. baseline 대비 우위가 특정 거래소나 짧은 기간에만 존재하거나, 거래비용을 조금 높였을 때 사라지거나, 공개 checkpoint의 학습 계보를 확인할 수 없거나, seed와 sampling 변화에 종목 순위가 과도하게 흔들리면 production 승격을 멈춘다. [NVIDIA Model Optimizer의 양자화 배포 검증](/posts/nvidia-modelopt-llm-quantization-pipeline/)에서 정확도와 artifact 완전성을 함께 봤듯, 금융 모델도 점수와 가중치 계보를 분리할 수 없다.

Kronos의 가치가 “AI가 주가를 예측한다”는 주장에 있는 것은 아니다. 연속적인 금융 K선을 계층형 이산 token으로 바꾸고, 여러 금융 작업을 하나의 생성 모델로 연결한 설계는 연구 가치가 충분하다. 동시에 누수 수정, 불명확한 checkpoint 재학습 여부, 시장별 독립 검증, 거래비용 후 성과는 파운데이션 모델이 금융 시스템에 들어갈 때 어디에서 신뢰가 끊기는지 보여 준다.

도입 판단은 논문 표의 최고 점수보다 네 가지 질문에서 시작해야 한다. **가중치가 본 데이터의 마지막 날짜를 증명할 수 있는가, 동일 비용 조건에서 단순 baseline을 이기는가, 시장 regime이 바뀌어도 손실 경계를 설명할 수 있는가, 모델이 틀려도 주문 권한과 자본이 격리되는가.** 이 질문에 답하지 못하면 Kronos는 흥미로운 연구 모델이다. 답을 artifact와 운영 로그로 입증할 수 있을 때 비로소 금융 시계열 인프라의 후보가 된다.

> 1차 자료: [Kronos 저장소와 README](https://github.com/shiyu-coder/Kronos), [Kronos 논문](https://arxiv.org/abs/2508.02739), [모델 구현](https://github.com/shiyu-coder/Kronos/blob/master/model/kronos.py), [fine-tuning 파이프라인](https://github.com/shiyu-coder/Kronos/tree/master/finetune), [미래 정보 정규화 수정 이슈](https://github.com/shiyu-coder/Kronos/issues/227), [사전학습 종료 시점 질의](https://github.com/shiyu-coder/Kronos/issues/265), [공개 checkpoint 재학습 여부 질의](https://github.com/shiyu-coder/Kronos/issues/307), [미국 주식 횡단 평가](https://github.com/shiyu-coder/Kronos/issues/375). Trending·저장소 수치는 2026년 10월 21일 08시 15분 KST 전후의 공개 스냅샷이며 이후 달라질 수 있다. 이 글은 투자 권유나 금융 자문이 아니다.
