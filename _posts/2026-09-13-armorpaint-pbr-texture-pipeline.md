---
title: "ArmorPaint PBR 텍스처 파이프라인: Substance 대안 도입 기준"
description: "ArmorPaint 1.0을 모델 임포트부터 베이킹·채널 패킹·엔진 검수까지 연결해 보고, 오픈소스 3D 텍스처 도구의 호환성·GPU·운영 리스크를 짚는다."
author: heracles-jo
date: 2026-09-13 08:27:00 +0900
categories: [Software Engineering, Developer Tools]
tags: [armorpaint, pbr, texture-painting, 3d-pipeline, game-development, open-source]
image:
  path: https://heracles-jo.github.io/assets/img/posts/armorpaint-pbr-texture-pipeline/cover.svg
  alt: "3D 메시가 ArmorPaint를 거쳐 PBR 텍스처 세트로 변환되는 제작 파이프라인"
---

3D 텍스처 페인팅 도구를 바꾸면 UV와 high-poly mesh, 레이어·마스크, normal·AO, 엔진 채널 패킹까지 함께 움직인다. 화면에서 그럴듯해도 ORM 순서나 normal 방향이 틀리면 최종 빌드는 다른 자산이 된다.

2026년 9월 13일 08시 40분 KST 전후 GitHub Trending daily에서 [armory3d/armorpaint](https://github.com/armory3d/armorpaint)는 **237 stars today**였다. GitHub API 확인 시점에는 약 **4.9k stars**, **547 forks**, 열린 이슈 108개였고 최신 릴리스 `26.09`의 이름은 `1.0`이다. 저장소는 개발 tree가 불안정할 수 있다고 경고하고 공식 매뉴얼도 `1.0alpha`로 표기한다. 따라서 1.0을 파이프라인 안정성 보증으로 읽어서는 안 된다.

이 글은 “무료 Substance Painter”라고 단정하지 않는다. 검색 의도는 **PBR 텍스처 제작 도구를 ArmorPaint로 바꿀 때 어떤 입출력 계약과 품질 게이트를 먼저 고정해야 하는가**다. 실제 검색어 데이터에는 접근할 수 없어 트래픽을 선정 근거로 쓰지 않았다.

## 후보 비교에서 남은 것은 새 도구보다 새 파이프라인 질문이었다

오늘 daily·weekly 후보 중 5개를 README, 라이선스, 릴리스, 최근 commit과 공개 이슈·PR 기준으로 비교했다. 인기 수치는 발견 신호일 뿐 채택 근거가 아니다.

| 후보 | 확인 시점 신호 | 중복과 장기 검색 의도 판단 |
|---|---|---|
| [ArmorPaint](https://github.com/armory3d/armorpaint) | daily 237, 약 4.9k stars, zlib/libpng, 1.0 | 기존 글에는 리메싱은 있지만 PBR 페인팅·베이킹·엔진 export 계약은 없다. 3D 자산 파이프라인이라는 독립 의도가 남는다. |
| [OpenFlux](https://github.com/p1neappleXpress/OpenFlux) | daily 355, 약 1.4k stars, GPL-3.0, 0.0.1 | pluggable transport 연구는 흥미롭지만 외부 서비스 계정과 제한 우회 위험이 크고, Iroh·Tailcat 네트워킹 글과 가깝다. |
| [worktrunk](https://github.com/max-sixty/worktrunk) | daily 137, 약 7.2k stars, MIT OR Apache-2.0, v0.77.0 | worktree 수명주기 자동화 의도는 분명하지만 이미 병렬 AI 에이전트와 Git worktree 운영을 직접 다뤘다. |
| [YuE](https://github.com/multimodal-art-projection/YuE) | daily 193, 약 7.3k stars, Apache-2.0, yue2-v0.1.6 | 장곡 생성의 GPU·저작권 운영은 가치가 있으나 음성 제작·생성 이미지 거버넌스 클러스터와 인접하고 법적 판단 비중이 크다. |
| [Pentagi](https://github.com/vxcontrol/pentagi) | daily 193, 약 23.4k stars, MIT, v2.1.0 | 자율 침투 테스트는 Strix와 공개 exploit PoC 거버넌스 글의 중심 의도와 겹친다. |

ArmorPaint를 고른 이유는 1.0 출시 자체보다 **저장소가 구현한 변환 경계가 구체적이기 때문**이다. 여러 mesh 형식을 받아 node material과 layer를 거치고, map을 bake한 뒤 엔진별 packed texture를 내보낸다. UV 변경, ORM 검증, 로컬 AI 모델 통제처럼 재사용 가능한 검색 질문도 분명하다.

## ArmorPaint는 페인터가 아니라 변환 구간이다

공식 매뉴얼의 기본 흐름은 간단해 보인다. UV가 있는 mesh를 불러오고, node로 material과 brush를 구성하고, layer·mask 위에 칠한 뒤 texture를 export한다. 파이프라인 관점에서는 topology·UV 같은 기하 상태, PBR channel과 색 공간, `.arm` 작업 상태, channel swizzle과 엔진 import 설정이 함께 움직인다.

![ArmorPaint를 중심으로 한 PBR 텍스처 제작·검수 아키텍처](https://heracles-jo.github.io/assets/img/posts/armorpaint-pbr-texture-pipeline/architecture.svg)

ArmorPaint는 OBJ를 최대 약 4GB까지 지원한다고 문서화하고 FBX·BLEND·STL·glTF·GLB도 읽는다. UDIM 분리, UV unwrap, normal 재계산과 mesh export도 제공한다. 편리하지만 페인팅 단계에서 UV를 다시 펴면 기존 texture 좌표는 더 이상 같은 자산을 가리키지 않는다. 공식 매뉴얼도 수정된 UV를 썼다면 texture와 수정 mesh를 함께 export해야 한다고 명시한다.

따라서 원본 DCC의 mesh를 무조건 권위 있는 원본으로 둘지, ArmorPaint가 내보낸 mesh를 downstream 기준으로 승격할지 먼저 정해야 한다. 두 파일을 사람이 수동으로 골라 전달하게 두면 잘못된 세대의 mesh와 texture가 섞인다. [AutoRemesher를 3D 파이프라인에 넣는 기준](/posts/github-trending-autoremesher-quad-remeshing-3d-pipeline/)에서 topology 변경 뒤 UV와 downstream 호환성을 따로 검증해야 했던 이유가 여기서 그대로 이어진다. 리메싱과 페인팅 사이에는 mesh hash, UV layout version, bake cage 설정을 묶는 manifest가 필요하다.

## Substance Painter 대안이라는 비교가 놓치는 것

ArmorPaint와 Adobe Substance 3D Painter를 가격표로만 비교하면 틀리기 쉽다. 공식 배포 페이지 기준 desktop binary는 확인 시점 19달러이고 전체 소스는 zlib/libpng 라이선스로 공개돼 있다. 직접 빌드할 권리와 검증·서명·지원을 받는 서비스는 다른 제품이다.

핵심 smart material과 기존 프로젝트를 다시 만들 비용이 크거나 공식 지원이 필수라면 상용 도구 유지가 낫다. 반면 custom export, Linux workstation, source patch가 중요하고 내부 owner가 build·issue triage·version pinning을 맡을 수 있다면 ArmorPaint의 exit option이 강해진다. fork 이후에는 upstream 반영과 binary 서명·배포 비용도 내부가 부담한다.

## PBR 품질은 viewport가 아니라 왕복 결과로 승인한다

공식 매뉴얼은 Generic preset 외에 Unreal용 occlusion-roughness-metallic, Unity용 metallic-occlusion-smoothness, Minecraft용 metallic-emission-roughness channel packing을 제공한다. custom preset은 JSON으로 texture slot과 RGBA swizzle을 정할 수 있다. 이 기능은 export 작업을 줄이지만, preset 이름이 downstream 계약을 자동으로 증명하지 않는다.

roughness와 smoothness는 보통 반전 관계이고 normal map은 tangent basis와 Y 방향 규약이 다를 수 있다. base color는 sRGB, roughness·metallic·normal은 linear data인데 engine이 파일명으로 이를 추정하면 rename 하나로 결과가 달라진다.

그래서 화면 캡처 대신 **round-trip fixture**가 필요하다. 작은 기준 mesh에 비대칭 normal, roughness gradient, metallic 경계, AO patch, UV seam과 투명 영역을 의도적으로 넣는다. ArmorPaint에서 export하고 실제 목표 엔진에 import한 뒤 다음을 자동 검사한다.

- RGBA 기준 pixel과 normal tangent가 preset 계약과 같은가
- sRGB/linear flag와 compression이 채널 용도에 맞는가
- UV padding·mipmap에서 seam이 없고 UDIM assignment가 유지되는가
- 재export 결과가 같은 버전에서 허용 오차 안에 드는가

최근 공개 이슈에는 export의 R/B channel 교환과 mask·alpha 관련 crash 제보가 보였다. 모든 환경에서 재현된다고 단정할 수는 없지만 channel fixture와 비정상 입력 corpus가 필요한 신호다.

## 베이킹은 GPU 작업인 동시에 데이터 계보 작업이다

`Bake Texture` node는 AO, curvature, lightmap, bent normal, thickness, normal, height와 ID map 등을 만든다. 일부 mode는 ray tracing GPU나 Metal device 조건을 탄다.

high-poly source, low-poly target, cage·offset, sample 수, tool version과 GPU backend가 달라지면 bake 결과도 바뀐다. `.arm`에 외부 asset을 pack할 수 있어도 단일 binary project만 원본으로 두면 diff와 batch 검증이 어렵다.

프로젝트 옆 manifest에 source hash, ArmorPaint tag, preset hash, bake parameter, 목표 engine version과 측정 결과를 기록한다. 이 설계는 [다이어그램 자동화에서 원본과 렌더링을 분리한 방식](/posts/ai-architecture-diagram-automation-diagram-design/)과 같다. 산출물과 그 산출물을 만든 설정의 source of truth를 분리해야 한다.

## 로컬 neural node도 모델 공급망을 가진다

매뉴얼은 FLUX 2 klein, DA3MONO image-to-PBR, Real-ESRGAN, Hunyuan3D와 Qwen node를 설명한다. 모델을 받은 뒤 처리는 로컬에서 실행되며 일반적으로 최소 6GB VRAM을 권장한다.

로컬 실행은 미공개 자산이 외부 inference API로 나가는 경로를 줄일 뿐 권리 문제를 해결하지 않는다. model weight의 출처·digest·개별 라이선스를 검토해야 하며, repository의 zlib 라이선스가 다운로드되는 모든 weight와 생성물을 포괄한다고 가정해서는 안 된다.

운영 환경에서는 검토한 model을 registry로 mirror하고 digest allowlist를 둔다. neural output은 물리 재질의 측정값이 아니라 추정값이므로 금속 분류, height-normal 일관성, tile seam과 권리 위험을 사람이 검토한다. [Prompt as Code 이미지 생성 거버넌스](/posts/github-trending-prompt-as-code-image-generation-governance/)처럼 model version과 입력 provenance도 manifest에 남긴다.

## 플러그인과 복합 파일은 별도 신뢰 경계다

ArmorPaint는 mesh, image, project와 `.c`·`.zip` plugin을 연다. 복잡한 parser와 외부 plugin은 공격면이므로 협력사가 보낸 asset을 신뢰된 workstation에서 바로 열지 않는다.

![3D 자산 입력부터 배포까지 ArmorPaint 도입 시 확인할 위험 체크리스트](https://heracles-jo.github.io/assets/img/posts/armorpaint-pbr-texture-pipeline/risk-checklist.svg)

ingest worker에서 크기, 압축 해제량, 외부 경로와 실제 signature를 확인한다. plugin은 검토한 source와 hash만 허용한다. source build의 dependency, compiler, build log, 서명과 rollback binary를 보관한다. [Trivy 공급망 보안 기준](/posts/github-trending-trivy-supply-chain-security/)처럼 포함된 codec·AI runtime도 SBOM 대상이다.

## 2주 PoC에서 한 장의 멋진 자산보다 변환 손실을 센다

PoC는 쉬운 sphere 대신 hard-surface, 유기체, mirrored UV, 여러 UV set, UDIM, 투명 소재와 high-poly bake를 섞은 실제 asset으로 구성한다. 첫 주에는 layer·mask, normal·AO bake와 한 engine preset만 통과시키고, 둘째 주에는 실패 자산 재생, crash recovery와 새 workstation 설치를 시험한다.

측정값은 다음처럼 잡을 수 있다.

- **정확성·재현성**: channel·normal·색 공간·UV 오류 수, manifest 재실행 pixel diff
- **생산성·안정성**: 첫 승인과 재export 시간, crash·손상 빈도, peak VRAM/RAM
- **운영·보안**: 새 좌석 설치와 upgrade 시간, 외부 요청, 미승인 plugin/model 수

합격선은 도구를 설치하기 전에 정한다. 예를 들어 기준 fixture의 channel 오류 0건, 모든 production preset의 엔진 round-trip 통과, 프로젝트 손상 시 마지막 autosave로 복구, 승인되지 않은 plugin·model 0개처럼 정의할 수 있다. 숫자는 ArmorPaint의 보장값이 아니라 각 팀이 정할 계약이다.

전면 전환만이 답은 아니다. 신규 project나 특정 asset class부터 시작하고 기존 Substance project는 원래 도구에서 유지하면 migration 위험을 낮출 수 있다. custom pipeline과 Linux workstation, source patch가 중요한 팀이라면 공개 소스의 가치가 더 커진다.

## 도입 결정은 `.arm` 파일 밖에서 완성된다

ArmorPaint 1.0과 공개 소스는 독립적인 3D 제작 파이프라인에 선택지를 주지만 upstream도 개발 tree와 alpha manual의 거친 경계를 알리고 있다. 도입 판단은 “그릴 수 있는가”보다 “같은 자산을 다시 만들고 목표 엔진에서 같은 의미로 읽는가”에 달려 있다. mesh·UV version, bake·export parameter를 manifest로 남기고 engine round-trip으로 검사해야 한다.

계약이 갖춰지면 ArmorPaint는 통제 가능한 PBR 변환 단계가 된다. 앱만 바꾸면 절약한 라이선스 비용보다 큰 재작업 비용이 숨어든다.

> 1차 자료: [ArmorPaint 저장소와 README](https://github.com/armory3d/armorpaint), [공식 매뉴얼](https://armorpaint.org/manual), [공식 다운로드 페이지](https://armorpaint.org/download), [zlib/libpng 라이선스](https://github.com/armory3d/armorpaint/blob/main/license.md), [ArmorPaint 1.0 릴리스](https://github.com/armory3d/armorpaint/releases/tag/26.09), [공개 이슈](https://github.com/armory3d/armorpaint/issues), [공개 Pull Requests](https://github.com/armory3d/armorpaint/pulls). Trending 및 GitHub 저장소 수치는 2026년 9월 13일 08시 40분 KST 전후 공개 페이지·API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
