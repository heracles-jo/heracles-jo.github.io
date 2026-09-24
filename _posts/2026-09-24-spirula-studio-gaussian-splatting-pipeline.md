---
title: "3D Gaussian Splatting 파이프라인: Spirula Studio 도입 기준"
description: "Spirula Studio의 영상·사진 입력부터 SfM, 3DGS 학습, 메시 변환까지를 분석하고 Vulkan 이식성, 품질 회귀, VRAM, 라이선스와 PoC 기준을 정리한다."
author: heracles-jo
date: 2026-09-24 08:40:00 +0900
categories: [AI Infrastructure, Developer Tools]
tags: [spirula-studio, gaussian-splatting, 3d-reconstruction, vulkan, gpu-portability, 3d-pipeline]
image:
  path: https://heracles-jo.github.io/assets/img/posts/spirula-studio-gaussian-splatting-pipeline/cover.svg
  alt: "사진과 영상이 Spirula Studio의 SfM과 Gaussian Splatting 학습을 거쳐 메시로 변환되는 파이프라인"
---

3D Gaussian Splatting 데모를 만드는 일과 반복 가능한 3D 자산 파이프라인을 운영하는 일은 다르다. 사진에서 카메라 자세를 복원하고, 움직이는 사람과 하늘을 가리고, 학습 파라미터를 정하고, GPU 메모리를 맞추고, 결과를 메시와 텍스처로 넘기는 단계 중 하나만 흔들려도 최종 장면은 보기 좋지만 다시 만들 수 없는 산출물이 된다.

[harry7557558/spirula-studio](https://github.com/harry7557558/spirula-studio)는 이 긴 경로를 단일 C++ 애플리케이션으로 묶는다. 공식 README 기준으로 사진·영상 입력, 프레임 추출, AI 마스킹, native SfM, 3D Gaussian Splatting 학습, 뷰어, depth·normal, meshing을 GUI와 CLI에서 제공한다. CUDA만 전제하지 않고 Vulkan을 통해 NVIDIA·AMD·Intel·Apple GPU를 지원하며, Python·PyTorch와 별도 COLMAP 설치 없이 실행하는 구성을 지향한다. 중요한 질문은 기능 수가 아니다. **분리된 전문 도구를 하나로 합친 편의가 입력 계보, 수치 정확성, 하드웨어별 재현성과 실패 격리까지 실제로 개선하는가**다.

2026년 9월 24일 08시 49분 KST 전후 GitHub Trending daily에서 Spirula Studio는 **99 stars today**로 표시됐다. GitHub API 기준 저장소는 **726 stars**, 56 forks, GPL-3.0 라이선스였고, 열린 이슈 30건과 열린 PR 4건을 확인했다. 최신 릴리스는 9월 20일의 `v2026.9.20`이며 adaptive frame extraction, 360 카메라 SfM 개선, 기존 3DGS PLY에서의 warm start, batch preset, GPU 선택, RGBA 학습과 대형 모델 meshing 오류 수정을 포함한다. 9월 23일까지 mask editor, fisheye border detection, SfM alignment 수정이 이어졌다. 관심도와 저장소 상태는 확인 시점의 스냅샷이며 품질이나 성능을 보증하지 않는다. 이번 실행 환경에서는 Search Console·Analytics의 실제 검색어와 유입 데이터에 접근하지 못해 선정 근거로 사용하지 않았다.

## 후보를 비교하니 남은 질문은 “3DGS를 누가 끝까지 운영하는가”였다

오늘 daily·weekly 후보는 에이전트 프레임워크와 업무 플러그인에 크게 치우쳐 있었다. 기존 글 126개의 제목, 저장소 링크, 태그와 중심 논지를 대조하면 같은 에이전트 검색 의도를 반복할 가능성이 높았다. Spirula Studio도 3D 재구성이라는 큰 범주에서는 기존 글과 닿지만, 스트리밍 지도 모델이나 후처리 도구가 아니라 **장면별 최적화 기반 3DGS의 전체 제작 런타임**이라는 별도 질문이 남는다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [Spirula Studio](https://github.com/harry7557558/spirula-studio) | daily 99, 726 stars, GPL-3.0, v2026.9.20 | 영상→SfM→3DGS→메시를 한 런타임에서 재현하고 여러 GPU에서 검증하는 운영 의도가 분명해 선택했다. |
| [Claude for Financial Services](https://github.com/anthropics/financial-services) | daily 665, 36,926 stars, Apache-2.0, 정식 release 없음 | 기업 금융 에이전트의 인간 승인·문서 격리는 중요하지만 기존 에이전트형 금융 거버넌스 글과 독자 질문이 인접한다. |
| [Univer](https://github.com/dream-num/univer) | daily 1,140, 16,312 stars, Apache-2.0, v0.25.2 | 오피스 문서용 agent harness는 장기 가치가 있으나 OfficeCLI의 문서 자동화·검증 의도와 가깝다. |
| [Harness SDK](https://github.com/strands-agents/harness-sdk) | daily 96, 7,829 stars, Apache-2.0, harness-cli/v0.1.2 | 모델·도구·세션을 묶는 agent harness는 전날 Google AX의 실행 제어면과 비교 가치가 있지만 연속 주제로는 중복 위험이 크다. |
| [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | daily 266, 44,552 stars, MIT, v0.11.0 | 이미 영속 지식 그래프와 코드베이스 기억 계층을 전용 글로 다뤘다. |

[긴 비디오를 feed-forward 모델로 누적하는 LingBot-Map](/posts/github-trending-lingbot-map-streaming-3d-reconstruction/)은 지속적인 공간 이해와 drift를 다뤘다. Spirula Studio는 한 장면을 반복 최적화해 렌더링 가능한 Gaussian 집합과 메시로 만드는 제작 경로다. 입력이 영상이라는 공통점만으로 같은 도구로 보면 안 된다.

## 단일 바이너리는 설치를 줄이지만 단계 경계를 없애지 않는다

전통적인 포토그래메트리·3DGS 작업은 영상 프레임 추출, 마스킹, 특징 추출과 매칭, camera pose와 sparse point cloud 복원, 학습, 평가, 메시 추출을 여러 스크립트와 프로그램으로 연결한다. 이 구조는 조합 자유도가 높지만 Python 환경, CUDA extension, COLMAP, ffmpeg, 모델 checkpoint와 파일명 규칙이 서로 다른 실패 지점을 만든다.

Spirula Studio의 아키텍처 문서는 CLI와 ImGui GUI가 같은 `TrainerCore`를 사용하고, dataset parser·image cache·training driver를 C++ 구현 하나로 수렴시켰다고 설명한다. engine은 CUDA-free C++ 계층으로 유지하고, backend API 아래에 CUDA kernel과 Vulkan launcher·Slang shader를 배치한다. COLMAP·Nerfstudio·Metashape dataset도 native parser가 공통으로 읽는다.

![Spirula Studio에서 입력 계보와 GPU backend가 만나는 아키텍처](https://heracles-jo.github.io/assets/img/posts/spirula-studio-gaussian-splatting-pipeline/architecture.svg)

이 통합의 실무 가치는 “설치 명령이 짧다”보다 **같은 설정과 parser를 GUI·CLI·batch가 공유한다**는 데 있다. GUI에서 성공한 값을 운영 batch에 옮길 때 별도 Python wrapper가 다른 기본값을 적용하는 문제를 줄일 수 있다. `TrainConfig.h` 한곳에서 구조체, CLI parser, help, GUI editor와 `config.json`을 확장하도록 만든 것도 설정 drift를 막으려는 선택이다.

하지만 단일 프로세스가 모든 상태를 안전하게 격리한다는 뜻은 아니다. 공식 architecture 문서는 engine이 process-global singleton이며 dataset을 바꿀 때 `engine_reset()`이 필요하다고 명시한다. 여러 장면을 한 프로세스에서 처리하는 batch는 이전 camera table, optimizer state, viewer state가 남지 않는지 확인해야 한다. 장면별 subprocess를 쓰는 benchmark가 존재하는 이유도 이 경계 때문이다. 운영자는 “하나의 바이너리”와 “하나의 실패 도메인”을 혼동하지 말고, batch row마다 입력 manifest·config·exit status·artifact hash를 남겨야 한다.

## Vulkan 지원은 체크박스가 아니라 수치 동등성 계약이다

이 프로젝트의 가장 흥미로운 부분은 CUDA 기능을 Vulkan으로 단순 번역하는 방식이 아니다. 공통 device math를 Slang source에서 CUDA header와 SPIR-V로 각각 컴파일하고, 장치 capability에 따라 native atomic, 64-bit integer, 8-bit storage의 variant를 선택한다. AMD wave64와 Intel의 가변 subgroup을 고려해 subgroup size를 32로 가정하지 않는다. Vulkan 1.2의 `bufferDeviceAddress`와 `timelineSemaphore`가 baseline이다.

이 설계는 [MAX의 이기종 AI 추론](/posts/modular-max-hardware-portable-ai-inference/)과 같은 교훈을 준다. 상위 API를 통일해도 driver와 memory model, atomic order, compiler codegen의 차이는 사라지지 않는다. 공식 backend 문서는 AMD의 amdvlk와 RADV가 일부 kernel에서 한 자릿수 배가 아니라 **한 order** 차이 날 수 있다고 경고한다. 같은 GPU 이름만 기록하고 driver를 빼면 benchmark가 재현되지 않는다.

프로젝트는 CUDA와 Vulkan 양쪽에 kernel을 구현하고 parity test를 추가하도록 요구한다. 문서상 Apple Silicon에서도 17개 parity tool이 CUDA reference와 비교를 통과하지만, 일부 loss·optimizer·meshing 검사는 MoltenVK fast-math를 끈 조건에 의존한다. 반대로 과거 Python golden test를 제거한 뒤 native dataset parser와 training step schedule을 직접 대체하는 회귀 검사가 아직 없다는 공백도 공식 testing 문서에 적혀 있다. 즉 kernel 수치 동등성은 비교적 강하게 관리하지만, **입력 장면 해석과 장기 학습 스케줄의 의미 동등성은 추가 검증이 필요하다.**

PoC에서는 결과 이미지 한 장 대신 다음 세 층을 분리한다.

- **입력 동등성**: backend와 OS가 달라도 frame set, intrinsics, distortion, pose, mask와 seed point가 같은가.
- **학습 동등성**: 고정 seed와 config에서 loss curve, Gaussian 수, densification 시점, checkpoint resume 결과가 허용 오차 안인가.
- **산출물 동등성**: novel-view PSNR·SSIM, 기하 오차, mesh topology, texture와 viewer 결과가 목표 업무 기준을 만족하는가.

## 8GB에서 1천만 Gaussian은 용량 신호이지 처리량 보장이 아니다

공식 README는 quantized training으로 8GB VRAM에서 SH3 Gaussian 1천만 개까지 학습할 수 있다고 설명한다. 유용한 상한 신호지만 장면의 이미지 해상도, frame 수, 활성 correction, mask·depth·normal, driver와 batch 설정이 빠진 채 일반화하면 안 된다. 프로젝트 문서도 training 종료 시 pool capacity, scratch buffer, driver process memory와 큰 buffer 목록을 출력하도록 한다.

[AirLLM의 저VRAM 추론](/posts/airllm-low-vram-layer-streaming/)에서 모델이 메모리에 들어가는 것과 업무가 제시간에 끝나는 것을 구분했듯, 3DGS도 peak VRAM과 학습 완료 시간을 함께 봐야 한다. quantization이 Gaussian당 메모리를 줄여도 frame decode, image cache, sorting, rasterization과 meshing 비용은 남는다. GUI가 끊김 없이 반응하는지, checkpoint 저장이 얼마나 걸리는지, 대형 장면에서 mesh 단계가 별도 메모리 peak를 만드는지도 측정해야 한다.

학습 속도 비교는 동일 장면에서도 trajectory가 달라질 수 있다. 공식 testing 문서는 atomic order가 학습 경로를 움직여 rasterization·sort kernel workload가 실행마다 달라질 수 있다고 경고한다. 평균 training FPS 하나만 비교하지 말고 고정 workload benchmark와 실제 장면의 end-to-end 시간을 나눈다. kernel microbenchmark가 빨라도 SfM alignment가 실패해 사람이 다시 작업하면 파이프라인 생산성은 낮다.

## 품질 실패는 학습보다 촬영과 SfM에서 먼저 시작된다

최근 공개 이슈에는 평균 reprojection error가 낮은데도 정렬이 잘못된 사례, GPS prior를 썼을 때 training과 UI가 느려지는 사례, SfM extract fatal error, large model meshing access violation이 보였다. 이슈가 모든 환경의 결함을 증명하지는 않지만, 3D 파이프라인이 단일 품질 점수로 승인될 수 없다는 신호다.

카메라 pose가 틀린 장면은 학습을 오래 돌려도 정확한 공간으로 회복되지 않는다. 움직이는 사람·차량·나뭇잎, 반사면, 반복 무늬, 저조도, fisheye border, 360 seam과 노출 bracket은 서로 다른 실패를 만든다. 최신 릴리스가 360 rig constraint와 HDR·RGBA, mask feature point 보존을 개선한 이유도 입력 종류가 늘수록 전처리 계약이 중요해지기 때문이다.

결과를 mesh로 넘긴 뒤에도 작업은 끝나지 않는다. [AutoRemesher의 쿼드 리메싱 기준](/posts/github-trending-autoremesher-quad-remeshing-3d-pipeline/)에서 다뤘듯 3DGS에서 추출한 고밀도·불규칙 mesh는 편집·LOD·애니메이션에 바로 적합하지 않을 수 있다. [ArmorPaint의 PBR 텍스처 파이프라인](/posts/armorpaint-pbr-texture-pipeline/)까지 이어진다면 mesh hash, 좌표계, 단위, UV, normal 방향과 texture channel 계약을 manifest로 넘겨야 한다. Spirula Studio가 end-to-end라고 해도 downstream DCC·engine의 품질 게이트를 대신하지 않는다.

## 라이선스와 binary 배포는 기능 설정에 따라 달라진다

루트 라이선스는 GPL-3.0이다. 내부에서 실행하는 것과 수정 binary를 제품·고객에게 배포하는 것은 검토 범위가 다르므로 실제 배포 형태를 기준으로 오픈소스 의무를 확인해야 한다. 단일 실행 파일이라는 편의 때문에 포함된 component의 조건까지 하나로 단순화해서는 안 된다.

특히 `SS_ENABLE_PATENTED`는 기본으로 꺼져 있다. 공식 build 문서는 이를 켜면 H.264·H.265 관련 parser와 Vulkan Video decode·encode가 포함되고 frame extraction이 크게 빨라질 수 있지만, 지역과 배포 방식에 따른 특허 검토 책임이 사용자에게 있다고 명시한다. 끈 상태에서는 외부 ffmpeg 경로를 사용한다. 성능 benchmark와 법무 승인 binary가 서로 다른 build option을 쓰면 같은 제품을 검증한 것이 아니다.

마스킹용 SAM checkpoint도 별도 공급망이다. README는 checkpoint를 binary에 넣지 않고 사용자가 내려받게 하며, SAM 2.1과 SAM 3의 라이선스가 같지 않다고 설명한다. 운영 registry에 승인한 모델 digest를 mirror하고, 자동 다운로드 URL·checksum·라이선스 기록을 build manifest에 남긴다. Windows Defender가 최신 ZIP을 탐지했다는 공개 이슈도 있으므로 release asset을 무조건 차단하거나 무조건 예외 처리하지 말고, source build 재현, hash, 서명·SBOM, 다중 scanner와 행위 분석을 통해 판정해야 한다.

## PoC는 한 장면의 감탄보다 변환 손실을 센다

![Spirula Studio를 제작 파이프라인에 넣기 전 확인할 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/spirula-studio-gaussian-splatting-pipeline/decision-gates.svg)

PoC dataset은 잘 촬영된 정적 실내 한 건으로 끝내지 않는다. 일반 렌즈 실내, 넓은 실외, 360 카메라, 반사·유리, 움직이는 객체, 노출 bracket, 낮은 texture, 대형 장면을 나누고 각 장면에 기준 거리나 camera pose 일부를 둔다. CUDA와 Vulkan, 가능하면 서로 다른 vendor GPU에서 같은 commit·config를 실행한다.

| 검증 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 입력·SfM | 등록 frame 비율, reprojection error 분포, pose jump, scale·orientation 오차 | 평균값은 낮지만 부분 장면이 접히거나 camera 순서가 뒤집힘 |
| 학습 품질 | fixed-view PSNR·SSIM, 사람 검수 결함, floater·hole·blur 비율 | iteration을 늘려도 기준 view와 novel view가 동시에 개선되지 않음 |
| 자원·성능 | 단계별 wall time, peak VRAM·RAM, GPU utilization, checkpoint·resume 시간 | 8GB 적재는 되지만 deadline을 넘기거나 UI·batch가 불안정함 |
| backend 동등성 | CUDA·Vulkan artifact diff, driver별 실패와 성능, parity test | 특정 vendor에서만 geometry·color가 허용 오차를 벗어남 |
| mesh handoff | 좌표계·단위, non-manifold, triangle 수, UV·normal, engine import | mesh가 열려도 downstream 편집·텍스처·LOD 계약을 충족하지 못함 |
| 운영·공급망 | commit·config·model digest, build option, SBOM, 재실행 성공률 | 입력과 binary를 고정해도 같은 산출물을 재현하거나 설명할 수 없음 |

도입이 잘 맞는 팀은 여러 GPU를 가진 소규모 3D·VFX·디지털 트윈 조직이면서, Python 환경을 줄이고 GUI 탐색과 CLI batch를 같은 runtime에서 운영하려는 경우다. 특히 Apple Silicon workstation과 Windows·Linux GPU를 함께 쓰는 팀에는 Vulkan backend가 실제 선택권이 될 수 있다.

반대로 정밀 측량 결과가 법적·안전 판단에 직접 쓰이거나, 이미 검증된 COLMAP·nerfstudio·gsplat·상용 도구 조합을 안정적으로 운영하고 있고, GPL 배포 조건과 자체 binary 검증을 감당하기 어렵다면 통합의 편의가 전환 비용보다 작을 수 있다. 기존 파이프라인을 한 번에 교체하지 말고 dataset 생성, 학습, meshing 중 한 경계부터 shadow run으로 비교하는 편이 낫다.

Spirula Studio의 장기 가치는 3DGS 알고리즘 하나를 더 제공하는 데 있지 않다. 촬영 데이터에서 재구성 자산까지 흩어진 도구를 한 C++ runtime과 두 GPU backend로 묶고, parity test와 batch interface를 운영 계약으로 만들려는 데 있다. 다만 통합은 검증 책임을 없애지 않는다. **SfM이 공간을 올바르게 풀었는지, CUDA와 Vulkan이 같은 의미의 결과를 내는지, 낮은 VRAM이 실제 완료 시간으로 이어지는지, build option과 모델 라이선스가 배포 형태에 맞는지**를 따로 증명해야 한다. 이 네 질문에 답할 수 있을 때 단일 바이너리는 데모 단축키가 아니라 3D 제작 인프라가 된다.

> 1차 자료: [Spirula Studio 저장소와 README](https://github.com/harry7557558/spirula-studio), [architecture](https://github.com/harry7557558/spirula-studio/blob/master/docs/architecture.md), [backend 설계](https://github.com/harry7557558/spirula-studio/blob/master/docs/backends.md), [dataset 규약](https://github.com/harry7557558/spirula-studio/blob/master/docs/datasets.md), [testing과 parity gate](https://github.com/harry7557558/spirula-studio/blob/master/docs/testing.md), [build·특허 옵션](https://github.com/harry7557558/spirula-studio/blob/master/docs/build.md), [v2026.9.20 릴리스](https://github.com/harry7557558/spirula-studio/releases/tag/v2026.9.20), [GPL-3.0 LICENSE](https://github.com/harry7557558/spirula-studio/blob/master/LICENSE), [공개 이슈](https://github.com/harry7557558/spirula-studio/issues), [공개 Pull Requests](https://github.com/harry7557558/spirula-studio/pulls). Trending·저장소 수치는 2026년 9월 24일 08시 49분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
