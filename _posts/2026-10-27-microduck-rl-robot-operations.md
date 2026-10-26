---
title: "강화학습 로봇 배포: MicroDuck 정책·안전·복구 기준"
description: "MicroDuck의 MuJoCo·ONNX 정책과 50Hz 안전 제어, 서명 업데이트·자동 롤백 구조를 통해 강화학습 로봇을 실기기에 배포할 검증 기준을 정리한다."
author: heracles-jo
date: 2026-10-27 08:40:00 +0900
categories: [AI Infrastructure, Hardware]
tags: [microduck, reinforcement-learning, robotics, sim2real, onnx, edge-ai]
image:
  path: https://heracles-jo.github.io/assets/img/posts/microduck-rl-robot-operations/cover.svg
  alt: "MicroDuck 강화학습 로봇의 정책, 50Hz 제어 루프, 서명 업데이트와 자동 복구 계층"
---

강화학습으로 걷는 로봇 데모는 이제 낯설지 않다. 시뮬레이터에서 PPO로 정책을 학습하고 ONNX로 내보낸 뒤, 소형 컴퓨터에서 추론해 관절을 움직이는 영상도 쉽게 볼 수 있다. 어려운 부분은 그다음이다. 모델이 잘못된 값을 내보내거나 추론이 제어 주기를 넘겼을 때 누가 모터를 멈추는가. 새 정책과 daemon을 원격으로 설치하다 실패하면 누가 이전 버전으로 돌아가는가. 시뮬레이션에서 성공한 동작이 배터리 전압, 관절 온도, 무선 손실과 바닥 마찰이 다른 실기기에서도 안전하다는 증거는 무엇인가.

[pollen-robotics/microduck](https://github.com/pollen-robotics/microduck)는 이 질문을 작은 이족보행 로봇의 실제 소프트웨어로 보여 준다. 공식 README 기준 로봇은 약 25cm, 800g이며 Rockchip RK3566 보드에서 15개 servo와 IMU를 50Hz로 제어한다. 보행 정책은 별도 [microduck_rl](https://github.com/pollen-robotics/microduck_rl) 저장소에서 MuJoCo·PPO·domain randomization으로 학습하고 ONNX로 내보낸다. 그러나 이 프로젝트의 더 흥미로운 부분은 학습 알고리즘보다 **정책을 물리 장치에 올리는 제어·검증·복구 구조**다.

2026년 10월 27일 08시 47분 KST 전후 GitHub Trending daily에서 MicroDuck는 `844 stars today`로 표시됐다. GitHub API 기준 12,394 stars, 1,546 forks, Apache-2.0 라이선스였고 최신 릴리스 `daemon-v0.17.9`는 10월 26일 공개됐다. 해당 릴리스에는 배터리가 소진될 때까지 열과 전원을 기록하는 endurance test, 카메라 화면 정지 후 재연결, 노출 제어 수정이 포함됐다. 수치와 저장소 상태는 확인 시점의 공개 스냅샷이며 이후 달라질 수 있다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근하지 못해 선정 근거로 사용하지 않았다.

## 후보 비교: 에이전트 도구 사이에서 물리 운영 문제를 골랐다

오늘 daily·weekly 상위권은 디자인 스킬, 범용 에이전트, 코딩 하네스와 메모리 도구 비중이 높았다. 기존 글의 저장소 이름뿐 아니라 검색 의도와 중심 논지를 대조하니 상당수가 이미 구축된 에이전트 스킬·메모리·보안 클러스터와 직접 경쟁했다. MicroDuck는 전날 후보에서 내부 연결성이 약하다는 이유로 보류했지만, 오늘은 강화학습 모델을 **실기기 제어와 안전한 업데이트로 승격하는 문제**가 별도 검색 의도로 남았다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [MicroDuck](https://github.com/pollen-robotics/microduck) | daily 844, 12,394 stars, Apache-2.0, `daemon-v0.17.9` | sim-to-real 일반론보다 정책 계약·제어 deadline·서명 업데이트·현장 복구를 함께 다뤄 독립 의도가 선명하다. |
| [Hallmark](https://github.com/Nutlope/hallmark) | daily 2,235, 36,243 stars, MIT | AI 생성 UI의 디자인 품질은 중요하지만 기존 다이어그램·디자인 스킬 후보와 중심 문제가 겹친다. |
| [ThinkRail](https://github.com/JetBrains/thinkrail) | daily 1,156, 2,863 stars, Apache-2.0, `v0.2.0` | 에이전트 중심 IDE는 컨텍스트·병렬 실행·AI 코딩 워크플로 글과 검색 의도가 인접한다. |
| [SkillSpector](https://github.com/NVIDIA/SkillSpector) | daily 203, 22,159 stars, Apache-2.0, `v2.13.1` | 설치 전 에이전트 스킬 공급망 검사를 이미 별도 글에서 다뤘다. |
| [AI Memory](https://github.com/akitaonrails/ai-memory) | weekly 3,254, 13,793 stars, MIT, `v3.2.6` | 코딩 에이전트 장기 기억과 handoff는 claude-mem·Context Mode·Supermemory 글과 직접 경쟁한다. |

MicroDuck의 가치가 “귀여운 오리 로봇”에만 있다면 검색 수명은 짧다. 반면 하나의 보드에서 제어 루프, 정책 런타임, 센서 daemon, Bluetooth·WebRTC 전송, signed update와 rollback을 어떻게 나누는지는 엣지 AI와 로보틱스 팀이 반복해서 만나는 설계 문제다. [NVIDIA Cosmos와 Physical AI](/posts/github-trending-nvidia-cosmos-physical-ai/)가 세계 모델과 시뮬레이션 데이터의 확장을 다뤘다면, MicroDuck는 그 결과물이 실제 모터를 움직일 때 필요한 마지막 운영 계층을 구체적으로 보여 준다.

## 정책은 모터 권한이 아니라 행동 후보를 만든다

MicroDuck에서 가장 중요한 경계는 `robotd`다. 공식 아키텍처 문서에 따르면 `robotd`만 15개 servo와 IMU가 공유하는 serial bus를 만진다. gamepad, BLE, 노트북 CLI와 WebRTC client는 모터 값을 직접 쓰지 않고 “이 속도로 가라”, “이 방향을 보라”, “일어서라” 같은 intent를 보낸다. 실제 실행 가능 여부는 50Hz loop 안의 safety 계층이 결정한다.

이 구조는 강화학습 정책을 신뢰하는 방식과 관련이 있다. 모델은 관측을 받아 action을 계산하지만 물리 장치의 최종 권한자는 아니다. 정책이 예상 범위를 벗어나거나 sensor가 끊기고 robot 상태가 바뀌면 런타임이 torque, posture, reset과 fallback을 관리해야 한다. 자연어 에이전트에서 모델의 제안을 IAM·policy engine이 제한해야 하는 것처럼, 로봇에서도 학습 정책과 actuator authority를 분리해야 한다.

![MicroDuck 입력, 50Hz 안전 제어, ONNX 정책과 복구 경로를 분리한 운영 아키텍처](https://heracles-jo.github.io/assets/img/posts/microduck-rl-robot-operations/architecture.svg)

프로세스 분리도 복구를 우선한다. `configd`, `updaterd`, `btd`는 `robotd`가 죽어도 살아남도록 설계됐다. 제어 루프가 시작되지 않는 로봇일수록 네트워크를 다시 설정하고 이전 릴리스로 되돌릴 경로가 필요하기 때문이다. 반대로 `padd`와 `mediad`는 gamepad와 camera·WebRTC 전송을 담당하는 대체 가능한 adapter다. 같은 JSON-RPC 계약을 Unix socket 위에서 사용하므로 앱, 콘솔, gamepad와 script가 서로 다른 비밀 제어 경로를 만들지 않는다.

이 설계가 만능 microservice 분리를 뜻하지는 않는다. 50Hz loop, motor bus와 안전 판정은 한 소유자에게 모아 timing과 상태를 명확히 했다. 반면 장애 시에도 필요한 구성·업데이트 경로는 별도 daemon으로 떼었다. 물리 시스템에서는 서비스를 많이 나누는 것보다 **어떤 기능이 고장 나도 복구 권한이 남아 있어야 하는지**가 분리 기준이 된다.

## ONNX 파일 하나에도 실행 계약과 상태 수명이 필요하다

MicroDuck runtime의 정책 계약은 구체적이다. feed-forward와 명시적 상태를 가진 LSTM policy는 61차원 observation을 받아 14개 joint action을 50Hz로 출력한다. tensor 이름·rank·type·폭을 검사하고, state 크기에 상한을 두며, warm-up에서 비정상 또는 non-finite output을 거부한다. recurrent policy는 `model_api: 2`를 선언해 이전 daemon이 설치 전에 거절하도록 한다.

여기서 manifest는 설명 파일보다 호환성 게이트에 가깝다. `obs_len`, `action_len`, `model_api`, `robot.model`이 실기기 계약과 다르면 정책을 받지 않는다. `kind`, `duration_s`, command encoding, entry pose, training commit과 evaluation 정보도 기록할 수 있다. 모델 artifact를 “파일이 열리니 배포 가능하다”고 보지 않고 **어떤 로봇·제어 주기·입출력 계약·학습 계보를 전제로 하는가**를 함께 이동시키는 방식이다. [Marin의 오픈 모델 학습 재현성](/posts/marin-open-model-training-reproducibility/)에서 데이터·checkpoint·실험 정의의 계보를 강조한 이유가 엣지 배포에서는 곧 호환성과 안전 문제로 이어진다.

LSTM state 수명은 더 조심해야 한다. MicroDuck는 inference 실패, network 전환, 명시적 disable, fall recovery 뒤 controller reset에서 hidden·cell state를 초기화한다. 같은 경로에 파일을 덮어써도 ONNX digest가 바뀌면 active model의 memory를 새로 시작한다. 그렇지 않으면 이전 정책의 내부 상태가 새 policy의 첫 action에 섞일 수 있다. 세션 메모리가 편의를 넘어 실행 상태가 되는 AI 시스템에서 **언제 기억을 지워야 하는지**가 모델 정확도만큼 중요하다는 사례다.

공식 offline rehearsal은 production Rust inference path로 1,000회 추론을 수행하고 p50·p95·p99·최대 latency와 20ms 초과 횟수를 기록한다. 다만 문서는 개발 PC 측정이 robot timing budget을 증명하지 않으며, 해당 수치도 sensor read, motor write와 scheduling delay를 제외한다고 명확히 한다. 따라서 PoC에서 봐야 할 것은 평균 inference 시간이 아니라 실기기 board의 end-to-end loop deadline과 tail latency다.

## 디지털 트윈은 같은 코드를 돌리되 현실의 나쁨을 모델링해야 한다

MicroDuck simulation의 좋은 선택은 mock용 별도 제어 프로그램을 만드는 대신 실제 `robotd`, `tofd`, `mediad`를 MuJoCo body에 연결한 점이다. seam은 `RobotIo` interface 한곳에 두고 그 위의 50Hz loop, ONNX policy, safety, fall detection과 odometry를 그대로 사용한다. 한 로봇뿐 아니라 container 안에 여러 로봇 daemon을 띄워 radio interaction도 시험할 수 있다.

하지만 같은 binary를 실행하는 것만으로 digital twin이 완성되지는 않는다. 공식 설계 문서도 완벽한 가상 radio에서는 실제 현장의 동기화 bug가 숨었다고 기록한다. 모든 로봇이 즉시, 손실 없이 서로를 발견하는 환경에서는 합창 동작이 항상 수렴했지만 현실의 packet loss와 비대칭 link가 빠져 있었다. 이후 loss·range·주소 회전 같은 조건을 조절 가능한 변수로 만들어야 했다.

이 사례는 sim-to-real gap을 물리 파라미터 오차로만 보면 안 된다는 뜻이다. 마찰, 질량, servo backlash와 sensor noise뿐 아니라 packet loss, reconnect, daemon restart, 오래된 simulator와 새 daemon 사이 protocol version도 실제 실패 원인이다. [Cua의 컴퓨터 사용 에이전트 평가](/posts/cua-computer-use-agent-evaluation/)에서 깨끗한 desktop image와 초기화 절차가 재현성을 좌우했듯, 로봇 twin에서도 몸체 모델과 함께 네트워크·프로세스·artifact 상태를 고정해야 한다.

## signed update가 있어도 rollback이 실제로 살아 있어야 한다

로봇은 현장에 배치되면 노트북처럼 쉽게 복구하기 어렵다. MicroDuck updater 설계는 daemon과 정책을 versioned directory에 설치하고 `current` symlink를 원자적으로 바꾼다. release artifact는 CI에서 minisign으로 서명하고 robot이 검증한다. 적용 뒤 unit을 재시작하고 `robot.health`를 통과하지 못하면 이전 release로 자동 rollback한다. boot 이후 crash loop는 별도 counter가 잡는다.

중요한 점은 `updaterd`가 자신이 업데이트하는 `robotd`와 분리돼 있다는 것이다. 실행 중인 process가 자기 binary를 안전하게 교체할 수 없고, 제어 daemon이 깨졌을 때도 rollback executor는 살아 있어야 한다. 네트워크가 없어도 disk에 남은 release로 rollback과 golden reset은 가능하게 했다. “오프라인이면 upgrade는 못하지만 recovery는 가능하다”는 실패 방향이 물리 장치에 맞다.

그렇다고 서명과 symlink만으로 충분하지 않다. 새 updater 자체가 기존 config를 읽지 못하거나 새 binary가 board architecture와 맞지 않으면 다음 업데이트를 수행할 주체가 사라질 수 있다. 설계 문서가 새 `updaterd`를 commit 전에 self-test하고, health gate와 deferred restart의 경계를 세밀하게 다루는 이유다. 업데이트 성공은 파일 복사가 끝난 시점이 아니라 **새 제어 loop와 복구 loop가 모두 작동한다는 증거가 생긴 시점**이어야 한다.

정책 artifact와 daemon source가 GitHub Releases와 Hugging Face Hub로 나뉘는 것도 운영 경계를 만든다. 각각의 tag, signature, manifest, commit과 rollback 단위를 기록해야 하며, daemon과 policy의 호환 조합을 재현할 수 있어야 한다. 로봇 fleet가 커지면 “모든 로봇에 최신 버전”만으로는 부족해져 hardware revision, 배터리 상태, 지역 네트워크와 canary group별 rollout이 필요해진다. MicroDuck updater가 fleet backend를 non-goal로 둔 만큼 대규모 상용 운영에서는 별도 control plane이 필요하다.

## 실패 모드는 모델 정확도보다 넓다

강화학습 로봇을 평가할 때 reward와 보행 성공률만 보면 다음 문제를 놓친다.

- **deadline miss**: 평균 추론은 빠르지만 p99에서 20ms를 넘고 sensor·motor I/O까지 합치면 50Hz loop가 흔들린다.
- **sim-to-real drift**: 바닥 재질, 무게 중심, servo 편차, 배터리 전압과 온도 변화가 관측 분포를 바꾼다.
- **상태 오염**: recurrent memory가 fall recovery·policy hot swap 뒤 제대로 초기화되지 않아 첫 동작이 튄다.
- **artifact 불일치**: model API·observation layout·action scaling·filter 설정이 학습 환경과 다르다.
- **복구 경로 상실**: update 도중 updater 또는 network config가 깨져 원격 rollback이 막힌다.
- **원격 공격면**: BLE, WebRTC, SSH, update source와 policy repository가 motor intent로 이어지는 입력면이 된다.
- **물리 열화**: 반복 시험에서 servo 온도, battery sag, gear·joint 충격이 누적되지만 짧은 데모에는 보이지 않는다.

최신 `daemon-v0.17.9`의 battery·heat endurance command는 마지막 항목이 실제 운영 문제임을 보여 준다. 안전성은 넘어지지 않는 한 번의 영상이 아니라, 배터리가 비워질 때까지 전압·열·제어 안정성이 어떻게 변하는지 측정하는 데서 시작한다. [text-to-CAD의 제조 검증 경계](/posts/text-to-cad-ai-cad-validation/)처럼 디지털 산출물의 형식 정확성과 물리 세계의 제조·내구성은 다른 승인 단계다.

## PoC는 걷기 성공이 아니라 승격과 복구를 시험한다

![강화학습 로봇 정책을 계약, 보드 리허설, 디지털 트윈, 제한 실기기와 복구 검증으로 승격하는 결정 흐름](https://heracles-jo.github.io/assets/img/posts/microduck-rl-robot-operations/decision.svg)

첫 PoC에서는 빠른 동작보다 작은 안전 envelope를 만드는 편이 낫다. 저속 policy, 지지대, 충격을 흡수하는 바닥, 물리 kill switch, network 격리와 짧은 세션으로 시작한다. 그 위에서 아래 증거를 수집한다.

| 검증 영역 | 측정할 증거 | 중단 조건 예시 |
|---|---|---|
| 정책 계약 | ONNX digest, manifest, training commit, shape·finite 검증 | artifact 계보가 없거나 daemon이 호환 불일치를 설치 전에 거절하지 못함 |
| 제어 timing | board end-to-end p50/p95/p99, missed tick, jitter | sensor·motor I/O 포함 deadline miss가 반복되거나 fallback이 없음 |
| twin 충실도 | 마찰·질량·sensor noise, packet loss, restart·version mismatch | perfect network·고정 초기 상태에서만 성공하고 현실 실패를 재현하지 못함 |
| 물리 안전 | 낙상률, 최대 관절 속도·전류·온도, battery sag | 온도·전압 저하에서 action이 불안정하거나 보호 한계가 정의되지 않음 |
| 업데이트 | signature 검증, health gate, rollback 시간, offline recovery | 실패 release가 자동 복귀하지 않거나 updater 손상 뒤 복구할 수 없음 |
| 보안 | remote API allowlist, key rotation, source pinning, 로그 | 인터넷 입력이 승인 없이 motor intent·policy 설치로 이어짐 |
| 운영성 | 장애 분류 시간, 현장 재현률, 로그·vetbook 완전성 | 사람 한 명의 SSH 수리 없이는 원인과 실행 artifact를 찾지 못함 |

승격 순서는 policy contract 검사, 실제 board의 motor 없는 rehearsal, 고장 조건을 넣은 digital twin, 제한된 실기기, 장시간 endurance, canary 장치 순이 적절하다. 각 단계에는 통과 기준뿐 아니라 즉시 이전 artifact로 돌아갈 절차가 있어야 한다. [ESP32 Bit Pirate 하드웨어 보안 워크벤치](/posts/github-trending-esp32-bit-pirate-hardware-security/)에서 읽기 전용 기준선과 랩 격리를 먼저 둔 것처럼, 로봇 PoC도 기능 탐색보다 물리·네트워크 경계를 먼저 고정해야 한다.

MicroDuck는 범용 산업 로봇 플랫폼도, 완성된 대규모 fleet manager도 아니다. 단일 hardware configuration을 목표로 하고 update backend도 의도적으로 단순하다. 바로 그 제한 덕분에 강화학습 로봇의 운영 계약이 선명하게 보인다. 정책은 action을 제안하고, 50Hz runtime이 물리 권한을 소유하며, simulation은 같은 code path에 현실의 나쁜 조건을 주입하고, updater는 제어 daemon과 독립적으로 서명·health·rollback을 집행한다.

강화학습 로봇 도입 여부는 “우리 모델이 걷는가”보다 세 질문으로 판단하는 편이 정확하다. 모델과 daemon의 호환성을 설치 전에 거절할 수 있는가. deadline·sensor·network·battery가 나빠질 때 안전 계층이 정책보다 우선하는가. 실패한 업데이트와 정책을 현장 방문 없이 검증된 이전 상태로 되돌릴 수 있는가. 이 세 가지를 반복 가능한 증거로 답할 수 있을 때 sim-to-real은 데모 이전이 아니라 운영 가능한 배포가 된다.

> 1차 자료: [MicroDuck 저장소와 README](https://github.com/pollen-robotics/microduck), [전체 아키텍처](https://github.com/pollen-robotics/microduck/blob/main/docs/design/architecture.md), [시뮬레이션 설계](https://github.com/pollen-robotics/microduck/blob/main/docs/design/simulation.md), [업데이트 시스템 설계](https://github.com/pollen-robotics/microduck/blob/main/docs/design/updater-design.md), [정책 manifest 계약](https://github.com/pollen-robotics/microduck/blob/main/docs/policy-manifest.md), [recurrent ONNX 정책](https://github.com/pollen-robotics/microduck/blob/main/docs/recurrent-policies.md), [`daemon-v0.17.9` 릴리스](https://github.com/pollen-robotics/microduck/releases/tag/daemon-v0.17.9), [Apache-2.0 LICENSE](https://github.com/pollen-robotics/microduck/blob/main/LICENSE), [최근 commits](https://github.com/pollen-robotics/microduck/commits/main/), [공개 issues](https://github.com/pollen-robotics/microduck/issues), [공개 pull requests](https://github.com/pollen-robotics/microduck/pulls). Trending·저장소 수치는 2026년 10월 27일 08시 47분 KST 전후 확인한 공개 스냅샷이다.
