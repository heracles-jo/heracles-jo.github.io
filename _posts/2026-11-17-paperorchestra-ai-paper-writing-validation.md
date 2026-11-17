---
title: "AI 논문 작성 자동화: PaperOrchestra 검증 기준"
description: "PaperOrchestra의 문헌 검색·인용 검증·LaTeX 생성 구조를 분석하고, 연구 근거 오염과 시각 자료 환각을 막는 사람 승인·재현성·PoC 기준을 정리한다."
author: heracles-jo
date: 2026-11-17 08:10:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [paperorchestra, human-in-the-loop, research-agent, ai-paper-writing]
image:
  path: https://heracles-jo.github.io/assets/img/posts/paperorchestra-ai-paper-writing-validation/cover.svg
  alt: "PaperOrchestra AI 논문 작성 파이프라인의 근거 추적과 사람 승인 경계"
---

연구 아이디어와 실험 로그가 이미 있어도 논문 초안으로 바꾸는 일은 오래 걸린다. 관련 연구를 다시 찾고, 각 주장에 맞는 인용을 배치하고, 표와 그림을 설명하며, 학회 형식에 맞춘 LaTeX를 반복 수정해야 한다. 이 과정에 AI 에이전트를 넣으면 작성 속도는 빨라질 수 있다. 동시에 존재하지 않는 인용, 실험 로그보다 강한 주장, 그럴듯하지만 틀린 그림을 더 빠르게 만들어 낼 수도 있다.

[google-research/paper-orchestra](https://github.com/google-research/paper-orchestra)는 아이디어 문서와 실험 로그를 입력받아 개요, 문헌 조사, 본문 작성, 시각 자료 생성, 내용 개선을 거쳐 제출 가능한 LaTeX 원고를 만드는 멀티 에이전트 프레임워크다. 핵심은 “논문을 한 번에 써 주는 프롬프트”보다 역할과 중간 산출물을 분리했다는 점이다. 그러나 연구 조직이 실제로 필요한 것은 자동 생성 자체가 아니라 **주장·실험·인용·그림이 원본 근거로 되돌아갈 수 있는 작성 시스템**이다.

2026년 11월 17일 08시 17분 KST 전후 GitHub Trending daily에서 PaperOrchestra는 `306 stars today`로 표시됐다. GitHub API 확인 시점에는 1,444 stars, 236 forks, Apache-2.0 라이선스였고 11월 15일까지 커밋이 이어졌다. 정식 GitHub Release는 없으며, README는 평가에 사용한 데이터셋이 현재 저장소에 포함되지 않았고 나중에 별도 공개될 예정이라고 밝힌다. 이 수치는 공개 페이지의 시점별 스냅샷이며 논문 품질이나 재현성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 유입 데이터에 접근하지 못했으므로 선정 근거로 사용하지 않았다.

## 후보 비교: 또 하나의 코딩 에이전트보다 연구 근거의 추적 문제가 남았다

오늘 daily·weekly 상위권은 에이전트 UI, 코드 리뷰, 스킬 평가와 오피스 SDK에 집중됐다. 기존 글의 저장소뿐 아니라 중심 검색 의도를 대조하면 대부분 이미 다룬 승인·평가·스킬 공급망 클러스터와 가까웠다. PaperOrchestra는 연구 작성이라는 별도 업무에서 **원자료를 논문 주장으로 변환할 때 근거를 어떻게 보존할 것인가**라는 질문이 남았다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [PaperOrchestra](https://github.com/google-research/paper-orchestra) | daily 306, API 1,444 stars, Apache-2.0, 정식 release 없음 | 실험 로그→문헌 조사→LaTeX 원고 변환에서 인용·주장·그림의 근거를 검증하는 독립 검색 의도가 있어 선택했다. |
| [Univer](https://github.com/dream-num/univer) | daily 1,878, API 27,746 stars, Apache-2.0, v1.5.2 | AI 오피스 SDK는 장기 가치가 크지만 OfficeCLI·문서 자동화·협업 워크스페이스 글과 중심 독자가 인접한다. |
| [SkillEvaluator](https://github.com/NVIDIA/SkillEvaluator) | daily 953, API 2,638 stars, Apache-2.0, v0.9.0 | 스킬 품질·중복·live agent 평가가 선명하지만 Android Skills·Cua Bench·스킬 보안 글과 직접 경쟁한다. |
| [AG-UI](https://github.com/ag-ui-protocol/ag-ui) | daily 790, API 18,921 stars, MIT | 에이전트와 프런트엔드의 이벤트 프로토콜은 중요하지만 OpenBot·AG-UI·승인 UI 클러스터와 중복 위험이 높다. |
| [Plannotator](https://github.com/backnotprop/plannotator) | daily 689, API 12,520 stars, Apache-2.0, v0.28.66 | 계획·주석·코드 리뷰의 사람 개입 UX는 Elephant-Goldfish 설계 리뷰와 Open Code Review 글에 가깝다. |

기존 [컴퓨터 사용 에이전트 평가 글](/posts/cua-computer-use-agent-evaluation/)은 태스크·환경·평가기·trajectory를 분리해 성공률을 재현하는 문제를 다뤘다. [Android Skills 검증 글](/posts/android-skills-agent-workflow-validation/)은 최신 지침도 빌드와 테스트를 대체하지 못한다고 봤다. PaperOrchestra에서는 같은 원칙이 연구 산출물로 이동한다. 모델의 자연어 자신감이 아니라 **어떤 입력에서 어떤 주장과 인용이 생성됐고, 독립 검토자가 이를 다시 확인할 수 있는가**가 최종 계약이다.

## 한 번의 생성이 아니라 다섯 개 역할의 증거 흐름이다

공개 코드의 기본 파이프라인은 다음과 같다.

1. `OutlineAgent`가 아이디어, 실험 로그, 학회 가이드와 LaTeX 템플릿을 읽어 구조화된 개요를 만든다.
2. `HybridLiteratureAgent`가 개요별 후보 문헌을 찾고 Semantic Scholar로 제목·연도·서지정보를 확인해 `citation_map.json`과 `references.bib`를 만든다.
3. 선택적으로 `PlottingAgent`가 실험 자료를 바탕으로 플롯과 개념도를 만들고 비전 모델의 비평을 받아 수정한다.
4. `SectionWritingAgent`가 개요, 원자료, 인용 맵, 그림 정보를 한데 모아 전체 LaTeX 초안을 작성한다.
5. `ContentRefinementAgent`가 최대 세 번 원고를 평가·수정하고 컴파일된 PDF를 최종 결과로 복사한다.

문헌 조사와 그림 생성은 병렬로 돌지만, 인용 후보 검증은 Semantic Scholar의 처리 한도를 고려해 순차적으로 수행한다. 논문 부록은 전체 과정에 대략 60~70회의 LLM 호출이 들고, 10개 논문 표본에서 단일 worker 평균 39.6분이 걸렸다고 보고한다. 이는 저자들의 특정 모델·데이터·네트워크 조건에 대한 측정값이지 일반적인 SLA가 아니다.

![PaperOrchestra의 원자료·문헌·그림·LaTeX·사람 승인 아키텍처](https://heracles-jo.github.io/assets/img/posts/paperorchestra-ai-paper-writing-validation/architecture.svg)

역할 분리는 단일 프롬프트보다 진단하기 쉽다. 인용이 틀리면 문헌 단계, 실험 수치가 왜곡되면 원자료와 작성 단계, 그림이 과장되면 plotting과 caption 단계로 범위를 좁힐 수 있다. 반대로 중간 파일을 단순 캐시로 보고 덮어쓰면 분리의 이점이 사라진다. `outline.json`, 검색 후보, 검증 응답, `citation_map.json`, `references.bib`, 원본 그림, 생성 그림, 초안과 수정본을 실행 ID와 함께 보존해야 어느 단계에서 의미가 바뀌었는지 추적할 수 있다.

[Apache Maka 런타임 이벤트 로그 글](/posts/apache-maka-agent-runtime-event-log/)에서 canonical event와 사람이 읽는 projection을 구분한 이유와 같다. 완성 PDF는 읽기 좋은 projection이다. 감사와 재현성의 원본은 입력 파일의 해시, 모델·프롬프트·코드 revision, 검색 결과, 인용 판정, LaTeX diff와 사람 승인 기록이어야 한다.

## 인용 검증은 “실재하는 논문”과 “이 주장에 맞는 논문”을 나눠야 한다

PaperOrchestra는 검색된 제목을 Semantic Scholar API로 다시 조회하고, fuzzy title match와 연도·cutoff를 사용해 후보를 확인한다. 평가 코드도 생성 논문의 인용을 Semantic Scholar paper ID로 정규화해 원본 논문의 참고문헌과 precision·recall·F1을 비교한다. 저자들은 baseline보다 문헌 리뷰 품질이 좋아졌다고 보고하며, 논문 초록의 사람 비교 평가에서는 문헌 리뷰 절대 승률 차이가 50~68%포인트, 전체 원고 품질은 14~38%포인트라고 제시한다.

이 장치는 유용하지만 세 가지를 구분해야 한다.

- **서지 실재성**: 제목, 저자, 연도, venue, paper ID가 실제 문헌과 일치하는가
- **주장 적합성**: 해당 문헌이 문장에 적힌 성능·방법·한계를 실제로 뒷받침하는가
- **인용 완전성**: 직접 사용한 데이터셋·baseline·metric·방법을 빠뜨리지 않았는가

API에서 제목을 찾았다는 사실은 첫 번째만 일부 확인한다. 논문의 결론을 반대로 해석하거나, abstract의 제한된 결과를 일반화하거나, 동일 이름의 다른 버전을 인용하는 문제는 남는다. 특히 fuzzy match 임계값과 LLM 기반 P0/P1 분류는 편리하지만 최종 증거가 될 수 없다. DOI·arXiv ID·공식 proceedings URL을 고정하고, 핵심 주장에는 원문 page·section·table까지 연결하는 claim-evidence matrix가 필요하다.

또한 벤치마크 자체의 경계를 읽어야 한다. PaperWritingBench는 CVPR 2025와 ICLR 2025 논문 200편에서 아이디어와 실험 로그를 역으로 추출해 만든 데이터셋이다. 논문은 입력을 비식별화하고 문맥을 줄여 오염을 완화했다고 설명하지만, foundation model의 사전학습 데이터에 원 논문이 포함됐을 가능성을 완전히 제거할 수는 없다고 인정한다. 모든 baseline이 같은 기반 모델을 사용해 상대 비교의 공정성을 높였다는 주장은 가능하지만, 새로운 비공개 연구에서도 같은 품질이 나온다는 증명은 아니다.

더 직접적인 운영 문제도 있다. README 기준 벤치마크 데이터는 저장소에 아직 없다. 따라서 외부 팀은 공개 코드만으로 논문의 전체 실험을 그대로 재현할 수 없다. 벤치마크 수치를 제품 채택 근거로 삼기 전에 데이터 공개, exact model revision, prompt, 평가자 구성, random seed, 실패 run 처리와 비용을 다시 확인해야 한다.

## 그림 생성은 설명 보조와 실험 증거를 엄격히 분리해야 한다

PaperOrchestra는 데이터 플롯뿐 아니라 개념도도 생성할 수 있다. 시각 자료는 논문 전달력을 높이지만, 사실과 디자인이 섞이기 쉬운 지점이다. 저자들도 한계 섹션에서 외부 시각 생성 프레임워크에 의존하기 때문에 figure hallucination을 직접 통제하기 어렵고, 전용 비전 모델과 사람 평가가 더 필요하다고 밝힌다.

실무에서는 그림을 세 종류로 나눠 승인하는 편이 안전하다.

| 그림 유형 | 허용 가능한 자동화 | 필수 검증 |
|---|---|---|
| 데이터 플롯 | 검토된 CSV·JSON·실험 artifact에서 코드로 재생성 | 원자료 해시, 축·단위·표본 수, 집계식, error bar, 재실행 결과 |
| 정량 표 | 구조화된 평가 결과에서 값과 포맷 생성 | 원본 로그와 셀 단위 대조, 반올림·누락·최적값 강조 규칙 |
| 개념도 | 방법의 구성요소와 흐름을 시각적으로 정리 | 논문 본문·코드와 노드·화살표 의미 대조, 실험 결과처럼 보이는 표현 금지 |

이미지 모델이 만든 막대 높이, 숫자, heatmap, 축은 원자료가 아니다. 실험 결과를 나타내는 그림은 코드와 데이터로 재생 가능해야 하고, 생성 모델은 레이아웃 초안이나 설명 보조에만 제한하는 편이 낫다. 개념도도 실제 시스템에 없는 모듈이나 양방향 흐름을 추가하면 방법론을 바꾼다. 캡션 검토만으로 끝내지 말고 그림의 각 요소를 설계 문서나 코드 위치에 연결해야 한다.

## 현재 코드는 보조 도구로 보기에도 운영 가드가 부족하다

저장소는 빠르게 움직이는 연구 코드다. 정식 release가 없고, README의 dataset은 미공개다. 11월 16일 공개 issue와 pull request에는 잘못된 image MIME type, 실패한 원고 생성의 exit status 전파, LaTeX compile timeout 시 부분 결과 제거, peer review 실패 때 마지막 검토본 보존, 문헌 cutoff 적용, 비라틴 제목 보존, double-blind template 같은 수정이 열려 있었다. 열린 PR은 이미 반영된 기능이 아니라 **현재 사용자가 직접 방어해야 할 실패 모드의 목록**으로 보는 편이 맞다.

코드에서 확인되는 구체적인 경계도 있다.

- 전체 작성은 실패 시 최대 세 번 재시도한다. 외부 API 호출이 부분 성공한 뒤 재실행되면 비용과 중간 산출물 상태를 별도로 관리해야 한다.
- 시작 시 일부 출력 디렉터리를 삭제하고 다시 만든다. 원본과 생성물을 같은 작업 경로에 섞지 말고 immutable input과 run별 output을 분리해야 한다.
- 기본 모델 이름은 preview 계열이다. 모델 alias가 바뀌면 같은 코드와 입력에서도 결과를 재현하기 어렵다.
- 아이디어·실험 로그·그림은 외부 모델 API로 전송될 수 있다. 미공개 연구, 개인정보, embargo 자료, 공동연구 계약의 데이터 처리 조건을 먼저 확인해야 한다.
- `scholar_utils.py`는 환경에서 읽은 Semantic Scholar API key 값을 로그에 출력한다. production log에 secret이 남지 않도록 이 출력을 제거하고 redaction test를 넣어야 한다.
- `.env`에 모델·Semantic Scholar·SMTP 자격증명을 함께 둘 수 있다. 최소 권한, run별 secret 주입, 네트워크 egress 제한, 로그와 artifact의 비밀 스캔이 필요하다.

[Codex Security를 CI 게이트로 다룬 글](/posts/codex-security-ci-gate/)에서 AI 판정과 결정론적 검사를 분리했듯, 논문 생성에서도 모델 reviewer가 모델 writer의 출력을 다시 읽는 것만으로 독립 검증이 되지 않는다. LaTeX compile, reference resolution, figure source check, 숫자 대조, plagiarism·license 검토, 저자 승인처럼 모델과 다른 실패 원리를 가진 게이트가 필요하다.

![AI 논문 초안을 연구 산출물로 승격하기 위한 근거·보안·사람 승인 워크플로](https://heracles-jo.github.io/assets/img/posts/paperorchestra-ai-paper-writing-validation/evidence-workflow.svg)

## PoC는 더 좋은 문장보다 더 빨리 틀린 근거를 찾는지 측정한다

처음부터 실제 투고 원고 전체를 맡기지 않는다. 이미 출판됐고 원자료와 최종 논문을 모두 가진 내부 연구 3~5건을 골라 retrospective test를 하는 편이 안전하다. 원 논문은 생성 단계에서 숨기고, 아이디어·실험 로그·검토된 표와 그림 원본만 제공한다. 생성이 끝난 뒤 독립 검토자가 원 논문과 비교한다.

| 측정 영역 | 최소 측정값 | 중단 또는 보완 조건 |
|---|---|---|
| 주장 충실도 | 실험 로그로 직접 뒷받침되는 주장 비율, 과장·누락 수 | 원자료에 없는 성능·인과·일반화 주장이 핵심 결론에 남음 |
| 인용 품질 | 실재성, claim entailment, P0 누락, cutoff 위반 | 존재하는 문헌이지만 해당 문장을 지지하지 않는 인용을 자동 통과시킴 |
| 숫자·표·그림 | 원자료 대조 오류율, 재생성 성공률 | 수치 또는 그림을 원본 artifact와 코드로 재현할 수 없음 |
| 재현성 | code·model·prompt 고정 후 결과 차이, run manifest 완전성 | 같은 입력의 핵심 결론과 인용이 설명 없이 크게 바뀜 |
| 사람 비용 | reviewer가 오류를 찾고 승인하는 시간 | 작성 시간은 줄지만 검증 시간이 수동 작성보다 늘어남 |
| 보안·거버넌스 | 외부 전송 필드, secret 노출, artifact 접근권, 삭제 증거 | embargo 데이터나 API key가 승인되지 않은 로그·provider로 전송됨 |
| 운영 비용 | LLM 호출 수, latency, 실패·재시도율, 문헌 API quota | 품질 개선보다 비용·재시도·수동 복구 부담이 큼 |

승격 기준은 자동 평가 점수 하나가 아니다. 핵심 claim마다 원자료 또는 검증된 문헌이 연결되고, 숫자와 그림을 재생성할 수 있으며, 실패한 검색·compile·review가 성공처럼 보고되지 않아야 한다. 최종 저자는 diff와 evidence bundle을 검토하고 승인해야 한다. 논문 투고 시스템에 올리는 권한은 생성 agent와 분리한다.

대안도 함께 비교해야 한다. 문헌 검색과 서지 정리만 자동화하고 본문은 사람이 쓰는 방식은 속도 향상이 작지만 책임 경계가 단순하다. 사람이 만든 outline을 기준으로 section draft만 생성하는 방식은 원고 구조의 통제력이 높다. 반면 PaperOrchestra처럼 end-to-end 파이프라인을 쓰면 반복 작업을 크게 줄일 수 있지만 모델·검색 API·LaTeX·시각 생성·평가자의 실패를 모두 운영해야 한다. 연구량보다 검증 인력이 적은 팀이라면 자동화 범위를 좁히는 것이 오히려 throughput을 높일 수 있다.

PaperOrchestra의 가치가 없는 것은 아니다. 원자료와 학회 템플릿을 받아 문헌 조사, 인용 맵, 그림, LaTeX, refinement를 분리한 구조는 단일 채팅형 작성기보다 훨씬 나은 출발점이다. PaperWritingBench도 “문장 품질”만 보지 않고 인용과 전체 원고를 비교할 수 있는 평가 문제를 제시했다.

다만 현재 단계에서 이를 독립 저자로 취급하면 안 된다. 더 적절한 역할은 **근거가 명시된 초안과 검토 대기열을 만드는 연구 작성 빌드 시스템**이다. 입력을 immutable artifact로 고정하고, claim-evidence matrix와 figure source를 보존하며, 모델과 다른 결정론적 검사와 사람 승인을 통과시켜야 한다. 자동화의 성공은 PDF가 만들어졌다는 사실이 아니라, 잘못된 주장과 인용을 투고 전에 더 빨리 찾아내고 같은 원고를 다시 재현할 수 있다는 증거로 판단해야 한다.

> 1차 자료: [PaperOrchestra 저장소와 README](https://github.com/google-research/paper-orchestra), [PaperOrchestra 논문](https://arxiv.org/abs/2604.05018), [논문 HTML과 한계·비용 부록](https://arxiv.org/html/2604.05018), [paper writing CLI](https://github.com/google-research/paper-orchestra/blob/main/paper_writing_cli.py), [기본 writing pipeline](https://github.com/google-research/paper-orchestra/blob/main/methods/paper_writer.py), [plotting 포함 pipeline](https://github.com/google-research/paper-orchestra/blob/main/methods/paper_writer_with_plotting.py), [Semantic Scholar 검증 코드](https://github.com/google-research/paper-orchestra/blob/main/utils/scholar_utils.py), [citation F1 evaluator](https://github.com/google-research/paper-orchestra/blob/main/autoraters/citation_f1.py), [Apache-2.0 LICENSE](https://github.com/google-research/paper-orchestra/blob/main/LICENSE), [최근 commits](https://github.com/google-research/paper-orchestra/commits/main/), [공개 issues](https://github.com/google-research/paper-orchestra/issues), [공개 pull requests](https://github.com/google-research/paper-orchestra/pulls). Trending·저장소 수치는 2026년 11월 17일 08시 17분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.