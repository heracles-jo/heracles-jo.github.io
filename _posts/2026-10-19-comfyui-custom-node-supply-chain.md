---
title: "ComfyUI 커스텀 노드 보안: 워크플로 공급망 운영 기준"
description: "ComfyUI 워크플로를 팀 제작 파이프라인으로 운영할 때 커스텀 노드·모델·버전의 신뢰 경계를 나누고, 재현성과 GPU 비용까지 검증하는 도입 기준을 정리한다."
author: heracles-jo
date: 2026-10-19 08:38:00 +0900
categories: [AI Infrastructure, Security]
tags: [comfyui, custom-nodes, workflow, ai-infrastructure, supply-chain, gpu-operations]
image:
  path: https://heracles-jo.github.io/assets/img/posts/comfyui-custom-node-supply-chain/cover.svg
  alt: "ComfyUI 워크플로와 커스텀 노드, 모델을 검증 가능한 공급망으로 운영하는 구조"
---

ComfyUI 워크플로를 파일로 받으면 복잡한 생성 과정을 곧바로 재현할 수 있다. 이미지 안의 메타데이터나 JSON에는 노드 연결, seed, 모델과 파라미터가 남고, 부족한 커스텀 노드는 Manager에서 찾아 설치할 수 있다. 개인 실험에서는 이 편의성이 강점이지만 팀 파이프라인에서는 질문이 달라진다. **워크플로를 연다는 것, 노드를 설치한다는 것, 모델을 내려받는다는 것이 각각 어느 권한을 실행하는가**를 설명할 수 있어야 한다.

[Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI)는 2026년 10월 19일 08시 40분 KST 전후 GitHub Trending daily에서 `155 stars today`로 표시됐다. GitHub API 확인 시점에는 138,585 stars, 16,502 forks, 열린 issue와 PR을 합쳐 5,256개, GPL-3.0 라이선스였으며 최신 릴리스 `v0.42.0`은 10월 19일 KST 오전에 공개됐다. README는 이미지뿐 아니라 비디오·오디오·3D·텍스트 워크플로, 부분 그래프 재실행, 비동기 weight streaming, API 연동과 커스텀 노드 확장을 지원한다고 설명한다. 이 수치는 공개 정보의 시점별 스냅샷이며 안정성이나 보안성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어 데이터에 접근하지 않았으므로 선정 근거로 사용하지 않았다.

## 후보 비교: 새 에이전트보다 성숙한 생성 파이프라인의 운영 문제가 남았다

오늘 daily·weekly 상위 후보는 에이전트 플러그인과 메모리, 창작 도구에 집중됐다. 저장소 이름이 달라도 최근 글이 이미 다룬 검색 의도와 겹치는지 먼저 확인했다.

| 후보 | 확인 시점 신호 | 기존 글 중복과 장기 가치 판단 |
|---|---|---|
| [ComfyUI](https://github.com/Comfy-Org/ComfyUI) | daily 155, 138,585 stars, GPL-3.0, v0.42.0 | 이미지 생성 소개가 아니라 **워크플로·커스텀 노드·모델을 팀 공급망으로 운영하는 문제**는 독립적이며 장기 검색 가치가 있다. |
| [claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | daily 1,187, 42,656 stars, Apache-2.0 | 공식 디렉터리 신뢰 모델은 Cursor Plugins, Android Skills, 에이전트 스킬 공급망 글과 중심 질문이 겹친다. |
| [ai-memory](https://github.com/akitaonrails/ai-memory) | daily 513, 10,456 stars, MIT | 장기 메모리와 공급자 간 handoff는 claude-mem·Context Mode·에이전트 메모리 글과 검색 의도가 가깝다. |
| [CLI-Anything](https://github.com/HKUDS/CLI-Anything) | daily 582, 54,572 stars, Apache-2.0 | GUI 소프트웨어를 agent-native CLI로 감싸는 논지는 기존 에이전트 네이티브 도구 클러스터와 중복된다. |
| [Jasna](https://github.com/Kruk2/jasna) | daily 115, 2,382 stars, AGPL-3.0 | GPU 영상 복원 구조는 흥미롭지만 모자이크 제거가 핵심 사용례라 권리·동의 위험이 크고 일반 조직의 적용 범위가 좁다. |

ComfyUI는 이전 [Prompt as Code 이미지 생성 거버넌스](/posts/github-trending-prompt-as-code-image-generation-governance/)에서 비교 대상으로 언급했지만, 당시 중심은 프롬프트 템플릿과 브랜드 승인 절차였다. 이번 글은 그 다음 계층인 **실행 그래프의 재현성, 제3자 Python 코드, 모델 artifact, GPU 런타임**을 다룬다. 같은 생성형 이미지 영역이어도 검색자가 해결하려는 문제는 다르다.

## 워크플로 JSON은 레시피이지 실행 환경 전체가 아니다

ComfyUI의 그래프는 입력과 출력 의존성을 명시하고, 변경된 부분만 다시 계산한다. 결과 이미지에서 workflow와 seed를 복구할 수 있다는 점도 실험 추적에 유용하다. 그러나 JSON 하나만 저장해서는 같은 결과를 다시 만들기 어렵다.

그래프 밖에는 다음 상태가 남는다.

- ComfyUI core와 frontend의 정확한 버전
- 각 custom node 저장소의 commit과 Python dependency
- checkpoint, VAE, LoRA, ControlNet, upscaler의 파일 hash와 라이선스
- PyTorch·CUDA·ROCm·Metal, GPU driver와 attention kernel
- API node가 호출한 외부 모델 버전과 계정 정책
- 입력 asset, prompt template, 환경 변수와 실행 옵션

공식 README도 stable tag 밖 commit은 불안정하고 많은 custom node를 깨뜨릴 수 있다고 경고한다. Python 3.14에서 일부 custom node dependency 문제가 있을 수 있다는 안내도 있다. 따라서 “워크플로 파일을 Git에 넣었다”는 것은 source를 보존한 것이지 실행 환경을 보존한 것이 아니다.

![ComfyUI 워크플로를 그래프, 노드 코드, 모델, 런타임, 산출물 계층으로 나눈 재현성 아키텍처](https://heracles-jo.github.io/assets/img/posts/comfyui-custom-node-supply-chain/architecture.svg)

팀에서 재현 가능한 단위는 workflow JSON과 별도 manifest의 조합이어야 한다. manifest에는 core·frontend tag, node pack commit, dependency lock, model SHA-256, 실행 backend, VRAM 정책과 출력 검증값을 기록한다. 모델 파일이 너무 커서 Git에 넣지 못한다면 내부 registry나 object storage의 immutable digest를 참조한다. URL만 저장하면 upstream 교체나 삭제 후 같은 artifact인지 증명할 수 없다.

## 커스텀 노드는 플러그인이 아니라 같은 프로세스에서 실행되는 코드다

ComfyUI의 `SECURITY.md`는 커스텀 노드를 arbitrary Python code로 정의하고, 사용자가 설치한 다른 소프트웨어와 같은 수준으로 신뢰한다고 명시한다. 공식 위협 모델도 신뢰하지 않는 custom node를 설치하지 않았다는 조건을 둔다. 이는 워크플로의 시각적 모양과 실제 권한 사이에 큰 간극이 있다는 뜻이다.

노드는 모델을 읽고 tensor를 변환하는 데 그치지 않는다. 예제 확장만 보아도 frontend JavaScript를 로드하고 HTTP route를 추가할 수 있다. ComfyUI-Manager 문서는 node pack의 `requirements.txt`를 자동 설치하고 `install.py`를 자동 실행한다고 설명한다. 결국 “없는 노드 설치” 버튼은 다음 작업을 한 번에 허용할 수 있다.

1. Git 저장소의 코드를 내려받는다.
2. Python package와 native wheel을 설치한다.
3. 설치 스크립트를 실행한다.
4. ComfyUI 프로세스 안에서 파일·네트워크·GPU 권한을 얻는다.
5. frontend 확장과 API endpoint를 추가한다.

이 경계는 [AI 에이전트 위험 명령 차단 글](/posts/ai-agent-destructive-command-guard/)에서 다룬 사전 실행 훅보다 넓다. 셸 명령 하나를 막는 문제가 아니라 장기간 로드되는 확장 코드를 승인하는 문제다. 노드를 설치한 뒤 workflow 실행만 제한해도 이미 늦을 수 있다.

실무에서는 제작 workstation과 검토 환경을 분리한다. 외부 workflow는 네트워크와 비밀이 없는 disposable 환경에서 먼저 열고, 요구 node 목록만 추출한다. 각 node pack의 owner, commit, release, dependency, install script, native binary, 라이선스를 검토한 뒤 내부 mirror로 승격한다. 운영 환경에서는 registry의 이름이 아니라 승인한 digest만 설치한다.

## Manager의 보안 수준은 출발점이지 완전한 샌드박스가 아니다

ComfyUI-Manager는 security level, network mode, pip blacklist, snapshot과 설치 제어 옵션을 제공한다. 현재 문서는 임의 Git URL 설치와 standalone `pip install`을 `allow_git_url_install`, `allow_pip_install`이라는 별도 기본 거부 옵션으로 분리한다. flagged node pack 설치도 listener와 별도 override를 검사한다. 과거보다 통제 지점이 구체적이다.

하지만 이 정책을 sandbox로 오해하면 안 된다. default channel에 등록된 custom node도 설치되면 Python 코드로 실행된다. catalog 등록은 악성 행위가 없다는 영구 보증이 아니며, maintainer 계정 탈취와 dependency 교체, tag 이동, 설치 후 update를 막지 못한다. snapshot 역시 Git으로 관리되지 않는 node의 복원이 불완전하다고 문서화돼 있다.

권장 기준은 다음과 같다.

- `security_level = strong`을 기본으로 두고 예외는 변경 요청으로 남긴다.
- 임의 Git URL과 standalone pip 설치 플래그는 production에서 끈다.
- node catalog를 그대로 신뢰하지 않고 내부 allowlist와 commit pin을 둔다.
- `requirements.txt`, `install.py`, wheel, frontend script를 변경 diff에 포함한다.
- Manager snapshot과 별도로 환경 lockfile·model digest·container image를 보관한다.
- 인터넷이 필요 없는 제작 lane은 `network_mode = offline`과 core의 `--offline`을 함께 검증한다.

[Trivy 공급망 보안 기준](/posts/github-trending-trivy-supply-chain-security/)처럼 소스 저장소만 스캔해서는 부족하다. Python dependency, 다운로드 모델, native extension과 실행 image를 하나의 SBOM·승인 단위로 묶어야 한다.

## localhost 기본값과 사내 서비스는 다른 제품이다

ComfyUI core는 기본적으로 `127.0.0.1`에 bind한다. 공식 보안 정책은 URL에 접근할 수 있는 사람을 신뢰하며, `--listen`으로 비기본 네트워크 노출을 선택한 배포의 인증·방화벽·reverse proxy는 운영자 책임이라고 선을 긋는다.

개인 PC에서는 합리적인 기본값이지만 팀이 공유 GPU 서버로 옮기는 순간 전제가 깨진다. ComfyUI API는 파일 입력과 모델 실행, GPU queue, 결과 조회를 다루므로 인증 없는 내부 URL도 안전하지 않다. 다른 사용자의 workflow·prompt·output을 볼 수 있고, 큰 모델이나 반복 작업으로 GPU와 디스크를 고갈시킬 수 있다. partner/API node를 쓰면 로컬 그래프에서 외부 서비스로 prompt와 asset이 이동할 수도 있다.

공유 서비스라면 최소한 다음 계층이 필요하다.

- SSO 또는 workload identity가 있는 gateway
- 사용자·프로젝트별 input/output 경로 격리
- model·node allowlist와 workflow 사전 검증
- GPU queue quota, timeout, 동시 실행 제한
- egress allowlist와 API credential 분리
- prompt·asset·결과의 보존 기간과 감사 로그

이 구조는 [VoiceStudio 로컬 음성 제작 스택](/posts/github-trending-voicestudio-local-voice-production-governance/)에서 로컬 API 노출을 따로 잠가야 했던 이유와 같다. 로컬 우선은 데이터 경계를 줄이지만 다중 사용자 인증과 자원 격리를 대신하지 않는다.

## 업데이트가 빠를수록 production lane은 느려야 한다

ComfyUI는 모델 지원과 성능 개선이 빠르다. `v0.42.0` 릴리스만 해도 새 이미지 모델, workflow template, quantization 문서, ARM Linux 테스트, Qwen 성능과 3D remeshing 수정이 함께 들어갔다. 장점인 동시에 회귀 표면이 넓다는 뜻이다. 공개 이슈에는 model reload, dynamic VRAM streaming, OOM과 backend별 문제가 장기간 논의되고 있다.

production에서 `master`와 모든 node를 한 번에 update하면 어느 계층이 결과를 바꿨는지 알 수 없다. core, frontend, custom node, model, driver를 독립된 변경 축으로 관리해야 한다.

1. **탐색 lane**은 새 모델과 node를 빠르게 시험한다.
2. **검증 lane**은 승인 workflow corpus를 재실행해 오류와 출력 차이를 측정한다.
3. **production lane**은 통과한 manifest만 받아 immutable image로 배포한다.
4. 실패하면 package downgrade보다 직전 환경 전체로 rollback한다.

이미지는 byte-for-byte 동일하지 않을 수 있으므로 검증 기준도 한 종류로 두지 않는다. graph load 성공, missing node 0건, deterministic fixture hash, 허용 범위의 perceptual diff, 얼굴·문자·브랜드 금지 요소 검사, peak VRAM, 처리 시간과 비용을 함께 본다. [ArmorPaint PBR 파이프라인 글](/posts/armorpaint-pbr-texture-pipeline/)에서 viewport가 아니라 엔진 round-trip으로 승인했듯, ComfyUI도 canvas가 열리는지만 보고 배포해서는 안 된다.

## 2주 PoC의 산출물은 멋진 이미지가 아니라 재현 가능한 실행 계약이다

![ComfyUI 도입 시 워크플로 출처부터 노드 승인, 모델 검증, 격리 실행, 승격까지 판단하는 게이트](https://heracles-jo.github.io/assets/img/posts/comfyui-custom-node-supply-chain/decision-gates.svg)

PoC는 실제 반복 제작물 5~10개와 실패하기 쉬운 workflow를 고른다. 공식 node만 쓰는 baseline, 승인 custom node를 추가한 candidate, 관리형 API 대안을 같은 품질 기준으로 비교한다.

- **재현성**: 새 머신에서 manifest만으로 missing node·model 없이 복구되는가.
- **공급망**: 모든 node·dependency·model의 source, commit, hash, license를 찾을 수 있는가.
- **보안**: 설치 과정의 파일 쓰기·subprocess·network egress를 기록하고 미승인 목적지가 0인가.
- **품질**: 대표 seed와 입력에서 사람 승인률, perceptual diff, 문자·얼굴 오류가 허용 범위인가.
- **성능**: workflow별 queue time, 처리 시간, peak VRAM/RAM, model reload 횟수를 측정했는가.
- **복구**: core·node·driver update 실패 후 직전 환경과 진행 중 작업을 복원할 수 있는가.
- **비용**: 로컬 GPU 감가·전력·운영 시간과 cloud/API 단가를 같은 작업량으로 비교했는가.

도입 중단 조건도 먼저 정한다. 검토되지 않은 `install.py`가 필요한 경우, 모델 라이선스나 hash를 확인할 수 없는 경우, workflow가 외부 endpoint로 민감 asset을 보내는 경우, update 후 승인 corpus의 품질·VRAM 회귀를 설명할 수 없는 경우에는 production 승격을 멈춘다.

ComfyUI의 강점은 시각적 그래프 자체보다 모델과 전처리·후처리를 조합해 반복 가능한 제작 공정을 만들 수 있다는 데 있다. 그 공정이 개인 PC를 벗어나면 JSON은 코드가 되고, custom node는 dependency가 되며, 모델 파일은 배포 artifact가 된다.

따라서 도입 판단은 “원하는 이미지를 만들 수 있는가”에서 끝나지 않는다. **누가 만든 그래프인지, 어떤 코드를 어떤 권한으로 실행하는지, 같은 환경을 다시 만들 수 있는지, 업데이트가 품질과 GPU 비용을 어떻게 바꿨는지**를 증명할 수 있어야 한다. 이 계약을 만들 수 있는 팀에게 ComfyUI는 유연한 생성 도구를 넘어 통제 가능한 미디어 실행 플랫폼이 된다.

> 1차 출처: [ComfyUI 저장소와 README](https://github.com/Comfy-Org/ComfyUI), [Security Policy](https://github.com/Comfy-Org/ComfyUI/blob/master/SECURITY.md), [v0.42.0 릴리스](https://github.com/Comfy-Org/ComfyUI/releases/tag/v0.42.0), [ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager), [ComfyUI Registry 문서](https://docs.comfy.org/registry/overview), [공개 issues](https://github.com/Comfy-Org/ComfyUI/issues), [공개 pull requests](https://github.com/Comfy-Org/ComfyUI/pulls), [GPL-3.0 License](https://github.com/Comfy-Org/ComfyUI/blob/master/LICENSE). Trending·저장소 수치는 2026년 10월 19일 08시 40분 KST 전후의 공개 스냅샷이며 이후 달라질 수 있다.
