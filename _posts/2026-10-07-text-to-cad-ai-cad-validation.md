---
title: "AI CAD 자동화: text-to-cad 형상 검증과 제조 경계"
description: "text-to-cad의 에이전트·CAD 커널·DFM 흐름을 분해하고, 생성된 STEP·메시를 제조에 넘기기 전 형상 정확성·보안·재현성을 검증하는 기준을 제시한다."
author: heracles-jo
date: 2026-10-07 08:35:00 +0900
categories: [AI Engineering, Developer Tools]
tags: [text-to-cad, cad-automation, ai-agents, design-for-manufacturing, 3d-printing, geometry-validation]
image:
  path: https://heracles-jo.github.io/assets/img/posts/text-to-cad-ai-cad-validation/cover.svg
  alt: "자연어 요구사항이 AI 에이전트와 CAD 커널을 거쳐 검증된 제조 산출물로 변환되는 과정"
---

자연어로 브래킷이나 기어박스 하우징을 설명하고 몇 분 뒤 STEP 파일을 얻는 장면은 매력적이다. 그러나 CAD 자동화의 병목은 모델을 한 번 만들어 내는 데 있지 않다. 홀 간격이 요구사항과 일치하는지, 얇은 벽과 공구 접근 불가능 영역을 놓치지 않았는지, STL로 바꾼 뒤 메시가 닫혀 있는지, 같은 입력과 도구 버전으로 다시 만들 수 있는지까지 증명해야 비로소 제조 흐름에 들어갈 수 있다.

[earthtojake/text-to-cad](https://github.com/earthtojake/text-to-cad)는 AI 에이전트에 CAD·DXF·로봇 기술 파일·DFM·슬라이싱 skill과 로컬 뷰어를 제공한다. 공식 README에 따르면 STEP을 중심으로 GLB·STL·3MF를 생성하고, 치수 도면과 제조 가능성 검사, 3D 프린팅·판금·CNC 서비스 연결까지 다룬다. 기반에는 Python `cadgen`, build123d와 Open CASCADE가 있고, Claude Code·Codex·Cursor·Gemini·Grok 같은 여러 에이전트에서 plugin 또는 skill 형태로 실행된다.

중요한 질문은 “프롬프트로 CAD를 만들 수 있는가”가 아니다. **에이전트의 해석, 정확 형상 커널, 메시 변환, 제조 규칙과 사람의 승인을 분리해 각 단계의 오류를 추적할 수 있는가**다.

2026년 10월 7일 08시 42분 KST 전후 GitHub Trending daily에서 text-to-cad는 **620 stars today**로 표시됐다. GitHub API 기준 저장소는 **17,957 stars**, 1,799 forks, MIT 라이선스였고, 최신 릴리스 `v0.7.15`는 10월 6일 공개됐다. 같은 날까지 plugin 배포 채널, CI 선택 실행, 메시 watertight 결함 수정과 설치 경량화 관련 변경이 이어졌다. 수치와 활동은 확인 시점의 공개 스냅샷이며 제품 품질이나 제조 적합성을 보증하지 않는다. 이번 실행 환경에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근할 수 없어 선정 근거로 사용하지 않았다.

## 후보 다섯 개 중 CAD를 고른 이유

오늘 daily 상위권은 에이전트 skill·memory와 자동화 도구가 강했다. 기존 글의 제목·description·저장소 링크뿐 아니라 중심 검색 의도를 대조했다. 에이전트 메모리와 오케스트레이션, GPU 커널, 브라우저 E2E는 이미 사이트 안에 가까운 클러스터가 있다. text-to-cad도 3D 파이프라인 글과 접점은 있지만, **정확 형상에서 제조 산출물로 넘어갈 때 무엇을 검증해야 하는가**라는 독립 질문이 남는다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [earthtojake/text-to-cad](https://github.com/earthtojake/text-to-cad) | daily 620, 17,957 stars, MIT, v0.7.15 | 자연어 생성 자체보다 B-rep·메시·DFM 사이의 검증 계약을 다룰 수 있어 선택했다. |
| [tester-army/e2e](https://github.com/tester-army/e2e) | daily 1,720, 6,265 stars, Apache-2.0, kernel 0.2.0 | 웹·모바일 통합 테스트는 가치가 있지만 기존 Cypress 거버넌스와 컴퓨터 사용 에이전트 평가 글에 인접한다. |
| [morluto/rea](https://github.com/morluto/rea) | daily 2,963, 9,253 stars, MIT, rea-agents 4.1.0 | 에이전트 기반 역공학은 별도 의도가 있으나 악성 입력·권한 경계 검증에 더 긴 조사가 필요하다. |
| [deepseek-ai/DeepGEMM](https://github.com/deepseek-ai/DeepGEMM) | daily 363, 8,681 stars, MIT | GPU GEMM 최적화는 장기 가치가 높지만 TileLang·양자화·이기종 추론 클러스터와 검색 의도가 가깝다. |
| [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | daily 536·weekly 1,759, 97,150 stars, Apache-2.0 | 세션 간 에이전트 기억은 이미 코드베이스 메모리·RAG·감사 로그 글과 직접 경쟁한다. |

text-to-cad는 7월 후보 조사에서도 등장했지만 전용 글로 다루지 않았다. 당시에는 CAD·로보틱스용 에이전트 skill이라는 넓은 가능성만 확인했다. 이번에는 `v0.7.15`의 메시 결함 수정과 설치·릴리스 경계가 함께 드러나면서, 생성 기능 소개가 아니라 **형상 검증과 제조 승인**을 중심으로 분석할 근거가 생겼다.

## 프롬프트에서 제조 파일까지는 하나의 모델이 아니라 네 개의 계약이다

사용자가 “M4 볼트 네 개로 고정되는 3mm 두께의 모터 브래킷”이라고 말하면 에이전트는 치수와 제약을 해석해 스크립트나 도구 호출로 바꾼다. CAD 커널은 이 명령을 정밀한 곡면과 솔리드로 계산하고 STEP 같은 B-rep 산출물을 만든다. 뷰어와 3D 프린팅 경로에서는 이를 삼각 메시인 STL·3MF·GLB로 변환한다. DFM 단계는 벽 두께, draft, undercut, 공구 접근, overhang과 support 같은 공정별 규칙을 적용한다.

![text-to-cad의 자연어 요구사항, 에이전트, CAD 커널, 형상·제조 검증 계층](https://heracles-jo.github.io/assets/img/posts/text-to-cad-ai-cad-validation/architecture.svg)

이 네 층은 실패 방식이 다르다.

1. **요구사항 계약**: “좌우 대칭”, “M4 clearance”, “하중 방향”처럼 자연어에 숨어 있는 가정을 치수·단위·공차·재료·공정으로 명시해야 한다.
2. **정확 형상 계약**: boolean, fillet, shell, sweep 뒤에도 유효한 solid인지, face·edge 연결과 질량 특성이 예상 범위인지 확인한다.
3. **표현 변환 계약**: STEP에서 STL로 갈 때 chord·angular tolerance가 형상을 얼마나 바꾸는지, watertight·winding·non-manifold 조건을 만족하는지 측정한다.
4. **제조 계약**: 기하학적으로 유효하다는 사실과 실제 공정에서 만들 수 있다는 사실을 구분한다. 프린팅, 판금, CNC, 사출은 서로 다른 규칙과 비용 함수를 가진다.

[AI 아키텍처 다이어그램 자동화 글](/posts/ai-architecture-diagram-automation-diagram-design/)에서 시각적으로 그럴듯한 그림과 사실에 맞는 시스템 문서를 분리했듯, CAD도 “렌더링이 그럴듯하다”와 “형상·공차가 맞다”를 분리해야 한다. 이미지나 브라우저 뷰어는 리뷰 인터페이스이지 기하학적 증명서가 아니다.

## 정확한 STEP도 STL 변환에서 망가질 수 있다

`v0.7.15` 릴리스의 핵심 수정은 이 경계를 잘 보여 준다. 공식 변경 기록은 fillet이 적용된 회전체와 sweep handle로 구성된 teacup 예제를 STEP에서 STL로 변환할 때 구멍, 중복 삼각형과 non-manifold edge가 생기던 문제를 다룬다. STEP은 유효한 단일 solid였지만 tessellation 과정의 sliver, 매우 좁은 planar strip, Float32 정밀도 문제가 메시를 손상시켰다.

수정 전 기본 설정 결과는 40,430개 삼각형에서 중복 58개, boundary edge 16개, non-manifold edge 254개였다고 보고됐다. 수정 후에는 39,266개 삼각형에서 세 결함이 모두 0이었고 watertight·winding consistency 검사도 통과했다. 저장소는 tessellation version을 올려 이전 캐시가 재사용되지 않도록 했다. 이는 특정 릴리스의 자체 검증 결과이지 모든 모델에 대한 보장은 아니지만, 운영 설계에는 중요한 교훈을 준다.

- 원본 STEP의 solid validity와 내보낸 메시의 topology를 각각 검사한다.
- 메시 알고리즘이 바뀌면 캐시 키에 tessellation version과 tolerance를 포함한다.
- triangle 수가 줄거나 늘었다는 사실보다 volume·surface deviation과 열린 edge를 함께 본다.
- 한 개 예제 대신 얇은 벽, 작은 fillet, tangent face, sweep, thread, 큰 좌표를 포함한 회귀 corpus를 유지한다.

[AutoRemesher의 쿼드 리메싱 파이프라인](/posts/github-trending-autoremesher-quad-remeshing-3d-pipeline/)은 이미 만들어진 고밀도 메시를 편집 가능한 자산으로 정리하는 문제를 다뤘다. text-to-cad의 경계는 그보다 앞에 있다. 정확 형상에서 처음 메시를 만드는 순간 결함이 생기면 후단 리메싱은 원래 의도를 복원할 수 없다. 제조용 master는 STEP과 파라메트릭 source로 유지하고, STL·GLB는 목적별 파생 artifact로 취급하는 편이 안전하다.

## DFM 보고서는 판정기가 아니라 반증 가능한 근거여야 한다

README의 skill 표는 DFM이 판금·CNC·사출 부품에서 draft, undercut, projected area를 측정하고 각 발견 사항에 규칙과 근거를 붙인다고 설명한다. 별도의 DfAM 검사는 벽 두께, overhang, support volume과 build orientation을 측정한다. 이런 분리는 올바르다. “제조 가능”이라는 단일 점수는 공정, 재료, 장비와 수량이 달라지면 의미가 바뀌기 때문이다.

예를 들어 1.2mm 벽은 FDM 시제품에는 충분할 수 있지만 알루미늄 CNC pocket에서는 공구 떨림과 변형 위험이 크고, 사출품에서는 수지 흐름과 냉각 수축을 함께 봐야 한다. 45도 overhang 규칙도 프린터, 노즐, 층 높이와 재료에 따라 달라진다. 에이전트가 일반 규칙을 적용했다면 보고서에는 최소한 다음 정보가 남아야 한다.

- 검사한 artifact hash와 CAD·cadgen·규칙 버전
- 단위, 재료, 공정, 장비 envelope와 사용한 threshold
- 위반 위치를 재현할 수 있는 face·edge 또는 좌표 참조
- 계산값과 규칙 출처, 심각도, 사람이 승인하거나 예외 처리한 이유
- 수정 전후 volume·bounding box·critical dimension 차이

[PLFM 오픈 하드웨어 검증 글](/posts/plfm-radar-open-hardware-validation/)에서 회로·FPGA·기구 산출물의 provenance를 분리했듯, AI CAD에서도 프롬프트, 생성 스크립트, STEP, 메시, 도면과 DFM report를 한 덩어리로 저장하면 안 된다. 어느 단계의 변경이 제조 결과를 바꿨는지 추적할 수 있도록 manifest로 연결해야 한다.

## 로컬 실행은 데이터 경계를 줄이지만 공급망 경계는 남는다

text-to-cad는 `uv`를 통해 `cadgen`을 실행하고 로컬 MCP server와 브라우저 viewer를 제공한다. 설계 파일과 프롬프트를 외부 CAD SaaS에 직접 올리지 않아도 된다는 점은 기밀 설계에 유리하다. 하지만 “로컬”은 “격리됨”과 같은 말이 아니다. 에이전트는 파일을 만들고, 외부 부품을 찾고, 제조 서비스와 연결하고, 설치 과정에서 Python·Node 패키지와 native Open CASCADE binding을 내려받는다.

공식 README는 첫 실행에 네트워크가 필요하며, Windows 11 Smart App Control이 서명되지 않은 OCP native module을 차단할 수 있다고 설명한다. 또한 익명 사용 분석은 opt-in이며 install ID, 버전, OS, agent app과 도구 사용 횟수 등을 보낼 수 있고 `DO_NOT_TRACK=1`로 끌 수 있다고 명시한다. 조직 배포에서는 이 설정을 사용자 개인 판단에 맡기지 말고 다음을 정책으로 고정해야 한다.

- plugin·skill은 `latest` 같은 이동 branch만 신뢰하지 말고 승인한 release와 package digest를 lock한다.
- `uv` cache와 native wheel을 사내 registry에서 검사하고 SBOM·라이선스·서명을 기록한다.
- CAD 작업 프로세스에는 저장소의 필요한 디렉터리만 노출하고 shell·network 권한을 기본 거부한다.
- 부품 검색, 업로드, 프린터 전송은 별도 승인 단계와 allowlist를 둔다.
- telemetry와 update check의 허용 여부를 환경 변수와 egress policy로 강제한다.

`v0.7.15` 직전 변경은 `main`에서 unreleased pin이 먼저 배포되는 간격을 줄이기 위해 PyPI 업로드 뒤 `latest` branch를 갱신하는 흐름을 도입했다. 배포 순서를 개선한 것은 긍정적이지만, 조직이 이동 branch를 그대로 생산 환경의 source of truth로 삼아도 된다는 뜻은 아니다. release tag, PyPI version, wheel hash, plugin manifest와 skill source가 서로 같은 버전을 가리키는지 검증해야 한다.

## FreeCAD·상용 CAD·메시 생성 도구와의 선택 기준

text-to-cad를 기존 CAD를 대체하는 범용 설계 시스템으로 보면 기대가 과도해진다. 현재 강점은 에이전트가 반복 가능한 script와 검사 도구를 이용해 비교적 명확한 부품·도면·로봇 기술 파일을 빠르게 만들고 검토하게 하는 데 있다.

| 선택지 | 잘하는 일 | 운영상 주의점 | 적합한 사용 |
|---|---|---|---|
| text-to-cad | 자연어→scripted CAD, 여러 agent 연결, STEP·메시·DFM·도면 흐름 | 해석 오류, native 공급망, 빠른 버전 변화, 공정 규칙 검증 | 지그·브래킷·fixture·로봇 부품의 초안과 자동 검사 |
| FreeCAD·build123d 직접 자동화 | 명시적 script와 파라메트릭 제어, CI 통합 | 사용자 의도 해석과 리뷰 UX를 별도로 구축 | CAD 지식이 있는 팀의 재현 가능한 자동 설계 |
| 상용 CAD와 PDM/PLM | 성숙한 assembly·drawing·revision·권한·vendor 지원 | 비용, API·라이선스 제약, 에이전트 통합 경계 | 규제·복잡 assembly·장기 제품 수명주기 |
| text/image-to-3D mesh | 빠른 concept와 시각 자산 생성 | 치수·solid·공차·제조 의미가 약함 | 렌더링, 게임, 형태 탐색의 초기 시안 |

[ArmorPaint의 PBR 텍스처 파이프라인](/posts/armorpaint-pbr-texture-pipeline/)처럼 최종 목적이 시각 자산이면 메시와 재질 품질이 중심이 된다. 반대로 치수와 공차가 구매·가공·조립에 직접 연결된다면 exact B-rep, drawing revision과 승인 기록이 우선이다. 두 흐름이 같은 GLB나 STL을 볼 수 있어도 품질 계약은 다르다.

## 2주 PoC는 생성 속도보다 수정 비용을 측정한다

![AI CAD 자동화의 확대·보류·중단을 결정하는 검증 게이트](https://heracles-jo.github.io/assets/img/posts/text-to-cad-ai-cad-validation/decision-gates.svg)

PoC 대상은 형상이 단순하지만 검증 기준이 분명한 부품 10~20개가 적당하다. 예를 들어 L 브래킷, bearing mount, enclosure, spacer, shaft coupler, sheet-metal plate를 고르고 기존 승인 도면이나 사람이 만든 CAD를 기준선으로 둔다. 프롬프트를 바꿔 가며 예쁜 결과만 고르지 말고 요구사항 template과 도구 버전을 고정한 채 반복 실행한다.

| 검증 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 요구사항 해석 | 누락·임의 가정 수, 단위·공차 오류, 질문 왕복 횟수 | 안전·조립 critical dimension을 묻지 않고 임의 결정 |
| 정확 형상 | valid solid 비율, boolean·fillet 실패, volume·bounding box 차이 | 성공으로 보고했지만 invalid body 또는 self-intersection이 남음 |
| 메시 변환 | watertight, boundary·non-manifold edge, volume deviation, triangle 수 | 같은 STEP·설정에서 결과가 비결정적이거나 결함을 통과 |
| 제조성 | rule precision·recall, 검토자가 뒤집은 판정, 수동 분석 시간 | 공정·재료가 다른 규칙을 하나의 점수로 섞거나 근거를 남기지 않음 |
| 변경 관리 | prompt·script·artifact hash, 재생성 성공률, diff 설명 가능성 | 승인한 STEP을 같은 source와 version으로 재현할 수 없음 |
| 보안·공급망 | network call, package digest, native module·plugin 권한, telemetry | 설계 파일이 미승인 endpoint로 전송되거나 이동 버전이 자동 유입 |
| 경제성 | 초안 시간, 수정 시간, scrap 위험, reviewer 병목 | 생성 시간은 줄지만 검증·재작업 총시간과 위험이 증가 |

가장 중요한 지표는 첫 산출물까지의 시간이 아니라 **승인 가능한 산출물까지의 총시간**이다. 에이전트가 5분 만에 모델을 만들었지만 숙련 엔지니어가 치수와 feature history를 다시 만드는 데 두 시간이 걸리면 자동화 효과는 낮다. 반대로 반복 fixture에서 요구사항 질문, 스크립트, 형상 검사와 도면 생성이 표준화되어 검토자가 변경점만 확인할 수 있다면 가치가 커진다.

text-to-cad의 장기 가능성은 CAD를 대화형으로 만든 데만 있지 않다. 에이전트가 자연어를 구조화하고, 정확 형상 커널이 계산하며, 메시·도면·DFM 도구가 서로 다른 증거를 남기는 **검증 가능한 설계 파이프라인**을 한 작업 흐름으로 묶으려는 데 있다. 다만 제조는 그럴듯한 출력에 관대하지 않다. 도입 기준은 “이 모델이 보이는가”가 아니라 **어떤 요구사항과 버전으로 생성됐고, 형상 변환에서 무엇이 달라졌으며, 누가 어떤 공정 기준으로 승인했는가를 다시 설명할 수 있는가**다.

> 1차 자료: [text-to-cad 저장소와 README](https://github.com/earthtojake/text-to-cad), [MIT LICENSE](https://github.com/earthtojake/text-to-cad/blob/main/LICENSE), [`v0.7.15` release](https://github.com/earthtojake/text-to-cad/releases/tag/v0.7.15), [CAD skill](https://github.com/earthtojake/text-to-cad/tree/main/skills/cad), [DFM skill](https://github.com/earthtojake/text-to-cad/tree/main/skills/dfm), [DfAM Check skill](https://github.com/earthtojake/text-to-cad/tree/main/skills/dfam-check), [최근 commits](https://github.com/earthtojake/text-to-cad/commits/main/), [공개 issues](https://github.com/earthtojake/text-to-cad/issues), [공개 pull requests](https://github.com/earthtojake/text-to-cad/pulls). Trending·저장소 수치는 2026년 10월 7일 08시 42분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
