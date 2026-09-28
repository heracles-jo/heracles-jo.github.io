---
title: "오픈소스 위상배열 레이더: PLFM 하드웨어 검증 기준"
description: "AERIS-10의 LFM·빔포밍·FPGA 처리 구조를 따라 시뮬레이션과 실측의 간극, RF 안전, 캘리브레이션, 라이선스, PoC 중단 조건을 정리한다."
author: heracles-jo
date: 2026-09-29 08:03:00 +0900
categories: [Hardware, Security]
tags: [plfm-radar, phased-array, fpga, rf-engineering, open-hardware, hardware-validation]
image:
  path: https://heracles-jo.github.io/assets/img/posts/plfm-radar-open-hardware-validation/cover.svg
  alt: "오픈소스 위상배열 레이더의 RF 프런트엔드와 FPGA 신호 처리, 실측 검증 게이트를 표현한 표지"
---

오픈소스 하드웨어 저장소를 볼 때 가장 위험한 착시는 파일의 양을 완성도로 읽는 것이다. 회로도, Gerber, BOM, FPGA RTL, MCU 펌웨어, GUI가 모두 공개되어 있어도 실제 장비가 목표 거리와 탐지 성능을 내는지는 별개의 문제다. 특히 레이더는 디지털 코드만 맞으면 끝나는 시스템이 아니다. 클록 위상 잡음, RF 경로 손실, 안테나 소자 편차, 전원 순서, 열, 기구 공차, 주변 반사와 전파 규제가 함께 결과를 만든다.

[AERIS-10 PLFM RADAR](https://github.com/NawfalMotii79/PLFM_RADAR)는 이 간극을 살펴보기 좋은 사례다. 저장소는 10.5GHz Pulse Linear Frequency Modulated 위상배열 레이더를 표방하며, 8×16 패치 배열을 쓰는 단거리형과 더 큰 도파관 배열·외부 전력 증폭기를 전제로 한 장거리형을 설명한다. FPGA에서 DDC, pulse compression, Doppler FFT, MTI, CFAR를 처리하고 STM32가 전원 순서, 주파수 합성기, 위상 천이기, PA bias, GPS·IMU를 관리한다. 공개 범위가 넓다는 점은 분명한 장점이다. 다만 프로젝트 자체도 상태를 alpha와 work in progress로 표시하며, bring-up 문서는 여러 RF·아날로그 동작이 아직 실제 보드에서 확인되어야 한다고 적는다.

이번 실행 환경에서는 Search Console과 Analytics의 실제 검색어·노출·클릭 데이터에 접근할 수 없었다. 접근했다고 가정하지 않았고, 기존 129개 글의 제목·description·저장소 링크·중심 논지와 `_data/written_topics.yml`을 비교했다. [ESP32 Bit Pirate 글](/posts/github-trending-esp32-bit-pirate-hardware-security/)은 저가 MCU를 이용한 버스·무선 보안 워크벤치와 사용 통제를 다뤘다. 이번 글의 질문은 다르다. **복합 RF 시스템에서 공개 설계와 시뮬레이션을 어떤 증거 순서로 실제 하드웨어 주장까지 끌어올릴 것인가**가 중심이다.

## 오늘 후보에서 레이더를 고른 이유

2026년 9월 29일 08시 09분 KST 전후 GitHub Trending daily·weekly와 GitHub API를 확인했다. Trending 수치는 후보 발굴 신호일 뿐이며 아래 별·포크·릴리스·활동 상태는 조회 시점의 스냅샷이다.

| 후보 | 공개 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---:|---|
| [PLFM_RADAR](https://github.com/NawfalMotii79/PLFM_RADAR) | daily 145, 25,738 stars, 5,885 forks, 최신 태그 v2.0.2-p0-audit | 공개 RF 설계를 제작 가능성, 검증 증거, 안전과 라이선스 경계로 평가하는 검색 의도가 기존 글과 분리된다. |
| [openrig](https://github.com/mvschwarz/openrig) | daily 781, 1,680 stars, Apache-2.0, v0.6.0 | Claude Code와 Codex를 함께 쓰는 하네스는 Orca·Google AX·장기 실행 에이전트 글의 오케스트레이션 의도와 가깝다. |
| [WeKnora](https://github.com/Tencent/WeKnora) | weekly 2,705, 30,935 stars, v0.8.2 | RAG·지식 플랫폼은 LiteParse, MarkItDown, 오프라인 지식 서버의 문서 인입·검색 의도와 경쟁한다. |
| [financial-services](https://github.com/anthropics/financial-services) | weekly 2,606, 38,047 stars, Apache-2.0 | 금융 에이전트의 데이터·승인·감사 경계는 Vibe-Trading 글에서 이미 중심적으로 다뤘다. |
| [CS 341 Coursebook](https://github.com/cs341-illinois/coursebook) | daily 316, 2,484 stars, 9월 26일 최근 커밋 | 시스템 프로그래밍 교육 자료로 장기성은 있지만 오늘 후보 중 운영·검증 의사결정의 깊이는 레이더가 더 크다. |

PLFM_RADAR의 기본 브랜치 최근 push는 2026년 6월 17일이지만, 8~9월에도 FFT 테스트 수정, GUI, chirp timing과 RX/TX 동기화 관련 PR·이슈 활동이 이어졌다. 최근 공개 PR의 CI가 실패한 기록도 있다. 따라서 별 증가를 “완제품이 검증됐다”는 증거로 해석하기보다, 설계 공개가 큰 관심을 얻었지만 통합 검증과 유지보수는 계속 진행 중이라는 신호로 읽는 편이 정확하다.

## 레이더 성능은 한 개의 파이프라인이 아니라 네 개의 계약이다

![AERIS-10형 위상배열 레이더의 RF·제어·FPGA·호스트 검증 경계](https://heracles-jo.github.io/assets/img/posts/plfm-radar-open-hardware-validation/architecture.svg)

AERIS-10의 공개 구조는 네 계층으로 나누어 보는 것이 좋다.

첫째는 **파형과 RF 프런트엔드**다. DAC가 LFM chirp를 만들고 mixer와 주파수 합성기가 신호를 10.5GHz 대역으로 옮긴다. 위상 천이기와 송수신 프런트엔드가 배열 소자의 위상·이득을 조절한다. 여기서는 schematic correctness만으로 충분하지 않다. 실제 PCB의 stack-up, 전송선 임피던스, connector·cable loss, LO phase noise, 채널 간 위상·이득 편차, 안테나 mutual coupling이 빔 모양과 pulse compression 결과를 바꾼다.

둘째는 **전원·열·안전 제어**다. STM32는 단순 peripheral controller가 아니라 전원 sequencing과 PA bias를 책임진다. 공개 bring-up 문서는 RF 송신 경로를 끈 상태에서 가장 안전한 구성으로 전류를 기록하고, clock·LO·beamformer readback을 확인한 뒤에만 PA calibration과 고위험 RF 활성화로 넘어가라고 요구한다. 비정상 rail current, regulator 불안정, 예상 밖의 온도 상승, LO lock 불일치, beamformer readback 실패는 즉시 중단 조건이다. 이는 레이더 PoC의 첫 성공 지표가 “목표가 화면에 찍혔다”가 아니라 **에너지가 의도한 순서와 범위 안에서 통제되는가**임을 보여 준다.

셋째는 **FPGA 신호 처리 계약**이다. ADC capture 뒤에 DDC, decimation, matched filter, range bin, Doppler, MTI, CFAR가 이어진다. 프로젝트의 reports 문서는 Build 25에서 timing constraint 충족, RTL regression과 MCU test, Python golden model과의 co-simulation 결과를 공개한다. 이런 증거는 중요하다. fixed-point 폭, saturation, frame boundary, clock-domain crossing 같은 디지털 오류를 실제 RF 측정 전에 제거할 수 있기 때문이다. 그러나 exact co-simulation은 “RTL이 주어진 디지털 입력에 대해 기준 모델과 같다”는 뜻이지, 안테나와 RF 체인이 올바른 입력을 만들어 냈다는 뜻은 아니다.

넷째는 **호스트·운영 계약**이다. USB framing, backpressure, packet boundary, GUI timestamp, GPS·IMU 보정, 설정 readback이 탐지 결과의 재현성을 결정한다. 화면에 점이 보였더라도 어떤 firmware·bitstream·설정·보정 테이블·온도에서 나온 결과인지 남지 않으면 다시 검증할 수 없다. [scriptc 배포 검증 글](/posts/scriptc-typescript-native-compiler/)에서 컴파일 성공과 의미 동등성을 분리했듯, 레이더에서도 bitstream 생성과 센서 성능 검증을 분리해야 한다.

## 시뮬레이션 PASS가 현장 탐지 성능을 보장하지 않는 이유

PLFM_RADAR에는 안테나 pattern, openEMS 기반 모델, matched-filter·Doppler·CFAR testbench, 실제 데이터 형식의 co-simulation 자료가 폭넓게 들어 있다. 이 정도의 디지털 검증 자산은 초기 프로젝트에서 드문 장점이다. 문제는 증거의 적용 범위를 과장할 때 생긴다.

안테나 시뮬레이션은 재료 상수, 동박·도금, 기판 두께, 급전 구조, enclosure, connector, 주변 금속, 조립 편차가 모델과 같다는 전제 위에 있다. 제작된 배열은 소자별 S-parameter와 방사 pattern을 측정해 simulation과 비교해야 한다. 빔 조향도 phase register에 원하는 값을 썼다는 사실만으로 검증되지 않는다. 실제 far-field 또는 적절한 측정 환경에서 주엽 방향, beamwidth, sidelobe, steering angle별 gain 저하를 확인해야 한다.

디지털 신호 처리도 마찬가지다. 합성 표적에서 range FFT와 CFAR가 통과하더라도 실제 ADC에는 DC offset, IQ imbalance, LO leakage, phase noise, clipping, thermal drift, coupling과 multipath가 들어온다. MTI는 정지 clutter를 줄이지만 느린 표적까지 지울 수 있고, CFAR는 훈련 셀·보호 셀·threshold 계수가 환경에 맞지 않으면 오탐 또는 미탐을 만든다. 처리 블록별 PASS 뒤에는 반드시 RF loopback, attenuator를 둔 유선 주입, 정지 표적, 제어된 이동 표적, clutter 환경이라는 증거 사다리가 필요하다.

이 점은 [Spirula Studio의 3DGS 파이프라인 글](/posts/spirula-studio-gaussian-splatting-pipeline/)에서 CUDA·Vulkan backend parity와 실제 자산 품질을 따로 본 이유와 같다. 모델·testbench 동등성은 구현 오류를 줄이지만 물리 세계의 오차까지 흡수하지 않는다. 하드웨어 시스템은 simulation, bench, chamber 또는 통제된 필드, 실제 운영 환경을 건너뛸 수 없다.

## 최대 탐지 거리보다 먼저 확인할 숫자

README에는 단거리형 3km, 장거리형 20km라는 목표가 제시된다. 이 수치는 검증 결과라기보다 시스템 설계 목표로 읽어야 한다. 레이더 거리는 송신 전력 하나로 결정되지 않는다. 안테나 이득, 파형 대역폭과 pulse compression gain, 수신 noise figure, 총 경로 손실, 표적의 radar cross section, coherent integration, 탐지 확률과 false-alarm rate, 대기·지형·clutter가 함께 영향을 준다.

따라서 PoC 보고서에서 “몇 km에서 보였다”만 기록하면 비교가 불가능하다. 최소한 다음 조건을 함께 남겨야 한다.

- 사용한 commit, bitstream, MCU firmware, GUI와 register profile
- 실제 송신 출력과 duty cycle, 채널별 위상·이득 보정값
- 안테나 구성, 조향각, 설치 높이와 측정 환경
- 표적 종류와 대략적인 RCS 조건, 이동 속도와 경로
- 대역폭, chirp 수, integration window, MTI·CFAR 설정
- noise floor, saturation 여부, detection probability와 false alarm
- 보정 전후 결과, 반복 측정 분산, 온도와 전원 상태

장거리형이 16개의 10W PA를 사용한다는 공개 설명은 “멀리 볼 수 있다”보다 “검증과 안전 책임이 급격히 커진다”는 신호다. 채널 하나의 bias나 phase가 틀리면 배열 이득이 떨어질 수 있고, 냉각·전원·interlock 문제가 생기면 장비와 주변 환경에 위험을 준다. 조직의 첫 PoC는 고출력 장거리 구성보다 송신을 억제한 digital chain, 저전력 loopback과 수신 중심 검증부터 시작하는 편이 맞다.

## 오픈 하드웨어에서도 라이선스 경계는 자동으로 정리되지 않는다

README는 hardware documentation에 CERN-OHL-P-2.0, software와 firmware에 MIT를 적용한다고 설명한다. 저장소 루트의 `Licence` 파일은 실제로 CERN Open Hardware Licence Version 2 – Permissive 전문이다. 하지만 확인 시점에 GitHub API는 저장소 라이선스를 `NOASSERTION`으로 반환했고, 루트에는 별도의 MIT 전문 파일이 보이지 않았다. README 선언만으로 개별 FPGA·MCU·Python 파일의 적용 조건과 외부에서 가져온 코드·CAD library·datasheet의 재배포 권리가 모두 명확해지는 것은 아니다.

또 README의 CERN-OHL-P 설명 중 “수정 설계를 같은 라이선스로 배포하고 Source를 공개해야 한다”는 문장은 permissive variant의 실제 조건과 함께 법무 검토가 필요하다. 루트 전문은 디자인·문서를 배포할 때 Source 형식과 modification notice, 라이선스 고지를 요구하지만, 물리 제품 유통과 설계 문서 재배포의 의무를 구분한다. 제품화 팀은 README 요약을 계약으로 삼지 말고 root license, 파일별 header, third-party component 출처, 제조 산출물과 소프트웨어의 경계를 목록화해야 한다.

특히 저장소에는 제조사 datasheet와 CAD library, vendor reference 계열 코드가 함께 있다. “GitHub에서 clone된다”와 “우리 제품 저장소에 재배포할 수 있다”는 같은 말이 아니다. PoC 단계부터 design source, upstream third-party, generated artifact, vendor-confidential 자료를 분리하고 SBOM에 해당하는 **hardware bill of materials와 design provenance**를 유지해야 한다.

## 가장 현실적인 PoC는 수신기에서 시작한다

![PLFM 레이더를 안전하게 검증하기 위한 단계별 증거와 중단 게이트](https://heracles-jo.github.io/assets/img/posts/plfm-radar-open-hardware-validation/validation-workflow.svg)

전체 시스템을 한 번에 조립하고 야외에서 목표물을 찾는 방식은 실패 원인을 분리하지 못한다. 아래 순서가 더 느려 보이지만 실제로는 재작업을 줄인다.

| 단계 | 확인할 증거 | 다음 단계로 가지 않는 조건 |
|---|---|---|
| 설계 동결 | BOM·schematic·Gerber revision, connector·전원·clock 표, license inventory | 제조 파일과 schematic revision이 맞지 않거나 대체 부품 영향이 검토되지 않음 |
| 무전원 검사 | short·polarity·impedance, 조립 사진, 채널별 continuity | rail 간 저항이나 방향성이 기준에서 벗어남 |
| 저위험 전원 인가 | current limit, rail ramp, clock·reset, thermal baseline | 비정상 전류·발열, reset 반복, clock lock 불일치 |
| 디지털 체인 | golden vector, RTL·MCU regression, USB framing, 설정 readback | bitstream·설정 조합을 재현할 수 없거나 packet 손실 원인을 설명하지 못함 |
| 수신·유선 RF | calibrated source/attenuator, gain·noise·linearity, ADC clipping | 채널 편차와 noise floor가 예산 밖이거나 보호 없이 포화됨 |
| 배열 보정 | 소자별 phase·gain, 조향각별 pattern, 온도 재측정 | 보정값이 반복 측정에서 안정되지 않거나 특정 채널이 수렴하지 않음 |
| 제한적 송신 | 승인된 장소·대역·출력, interlock, 로그, 비상 정지 | 규제·안전 승인 부재, PA bias 이상, 예상치 못한 방사·열 상승 |
| 탐지 평가 | Pd/Pfa, range·velocity error, clutter·weather 반복 | 한 번의 데모만 성공하고 조건 변화에서 결과를 재현하지 못함 |

[ESP32 Bit Pirate 글](/posts/github-trending-esp32-bit-pirate-hardware-security/)에서 읽기 전용 기준선과 위험 기능 통제를 먼저 둔 원칙은 여기서 더 엄격하게 적용된다. RF 송신은 소유한 장비와 통제된 실험 환경에서도 국가별 주파수 할당, 출력, 점유 대역폭, 안테나와 실험 장소 규정을 확인해야 한다. 연구 목적이라는 이유로 전파 규제와 인체 노출 안전이 사라지지 않는다.

운영 비용도 BOM 합계보다 크다. 10GHz대 계측에는 적절한 대역의 spectrum analyzer, signal source, power meter, attenuator·coupler, VNA와 calibration kit가 필요할 수 있다. 배열 pattern을 제대로 보려면 측정 공간과 fixture가 필요하고, FPGA build에는 특정 Vivado 버전과 target board가 필요하다. 대체 부품은 단순 구매 문제가 아니라 phase noise, gain, package parasitic, thermal design을 다시 검증하게 만든다. “저비용 레이더”의 비용은 부품 가격이 아니라 **측정 불확실성을 줄이는 장비·공간·인력·반복 시간**까지 포함해야 한다.

## 도입 판단: 설계를 복제할 팀보다 증거를 운영할 팀이 필요하다

AERIS-10은 학습과 연구 관점에서 가치 있는 공개 자산이다. 아날로그·RF·전원·FPGA·MCU·GUI가 하나의 센서로 연결되는 모습을 볼 수 있고, testbench와 bring-up 문서가 어떤 순서로 위험을 줄이는지도 확인할 수 있다. 완성품 데이터시트만 보는 것보다 시스템 경계를 이해하기 좋다.

그러나 저장소의 풍부함을 제품 준비 상태로 바꾸는 책임은 도입팀에 있다. 현재 문서가 공개한 timing closure와 co-simulation은 디지털 구현의 강한 증거지만, 프로젝트 스스로 남긴 open risk처럼 LO sync, phase behavior, beamformer control, PA calibration과 실제 I/O는 보드 검증이 필요하다. 최근 PR CI 실패와 미병합 reliability 수정도 main branch와 제안 변경을 구분해 평가해야 함을 보여 준다.

적합한 팀은 RF 측정 장비와 안전 절차를 갖춘 대학 연구실, 센서·SDR 팀, FPGA와 아날로그를 함께 디버깅할 수 있는 조직이다. 반대로 완성된 드론 탐지 제품을 빠르게 구매하려는 팀, RF 계측 없이 PCB 제작만 외주화하려는 팀, 규제 승인과 interlock을 나중에 생각하려는 팀에는 맞지 않는다.

오픈소스 위상배열 레이더의 핵심 질문은 “설계 파일이 공개됐는가”가 아니다. **각 주장에 대응하는 증거가 어디까지 공개됐고, 시뮬레이션에서 벤치와 현장으로 넘어갈 때 누가 위험과 불확실성을 소유하는가**다. 이 질문에 commit·artifact·측정 조건·중단 기준으로 답할 수 있을 때 공개 설계는 흥미로운 파일 모음에서 재현 가능한 연구 플랫폼으로 발전한다.

> 1차 자료: [PLFM_RADAR 저장소와 README](https://github.com/NawfalMotii79/PLFM_RADAR), [Architecture](https://nawfalmotii79.github.io/PLFM_RADAR/docs/architecture.html), [Hardware Bring-Up Plan](https://nawfalmotii79.github.io/PLFM_RADAR/docs/bring-up.html), [Reports](https://nawfalmotii79.github.io/PLFM_RADAR/docs/reports.html), [Release Notes](https://nawfalmotii79.github.io/PLFM_RADAR/docs/release-notes.html), [CERN-OHL-P-2.0 전문](https://github.com/NawfalMotii79/PLFM_RADAR/blob/main/Licence), [v2.0.2-p0-audit release](https://github.com/NawfalMotii79/PLFM_RADAR/releases/tag/v2.0.2-p0-audit), [이슈와 PR](https://github.com/NawfalMotii79/PLFM_RADAR/issues). Trending·저장소 수치는 2026년 9월 29일 08시 09분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
