---
title: "Meetily와 로컬 회의 지식 파이프라인의 현실성"
description: "Meetily의 Tauri·Rust·로컬 전사·선택형 LLM 구조를 바탕으로 회의 데이터를 의사결정과 액션 아이템으로 전환하는 운영 모델, 프라이버시 경계, 도입 기준을 분석한다."
author: heracles-jo
date: 2026-07-04 07:30:00 +0900
categories: [AI Infrastructure, Productivity]
tags: [meetily, privacy, local-first, tauri, whisper, knowledge-management]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-meetily-local-meeting-knowledge-pipeline/cover.svg
  alt: "Meetily가 로컬 환경에서 회의 오디오를 전사하고 요약해 조직 지식 파이프라인으로 연결하는 흐름"
---

GitHub Trending에서 [Zackriya-Solutions/meetily](https://github.com/Zackriya-Solutions/meetily)가 눈에 띈 이유를 “무료 회의 녹취 앱이 인기를 얻었다”로만 설명하면 핵심을 놓친다. Meetily의 더 큰 의미는 회의의 오디오 캡처, 전사, 요약, 저장을 로컬 데스크톱 애플리케이션 안에 묶고, 필요한 경우에만 선택한 LLM provider를 사용하게 만든다는 데 있다. 회의 AI의 편의는 유지하면서 데이터 경계를 사용자가 결정하려는 local-first 접근이다.

현재 [공식 architecture 문서](https://github.com/Zackriya-Solutions/meetily/blob/main/docs/architecture.md)는 Meetily Community Edition을 Tauri 기반의 self-contained desktop app으로 설명한다. Next.js UI가 Tauri command를 통해 Rust core와 통신하고, Rust 계층이 마이크·시스템 오디오 캡처, Whisper 또는 Parakeet 전사, 로컬 SQLite 저장, 요약 엔진을 관리한다. [README](https://github.com/Zackriya-Solutions/meetily/blob/main/README.md)는 Ollama 같은 로컬 모델과 Claude, Groq, OpenRouter, OpenAI, custom OpenAI-compatible endpoint를 선택할 수 있다고 밝힌다. 따라서 “Meetily는 모든 처리를 항상 완전 로컬로 한다”보다 **로컬 전사를 기본으로 두고 요약의 데이터 경로를 선택할 수 있다**고 이해하는 편이 정확하다.

이 글은 특정 시점의 Trending 순위나 star 수를 품질 보증으로 사용하지 않는다. 저장소는 Community Edition과 별도 Pro 제품을 함께 소개하고 있고 기능 경계가 달라질 수 있다. 설치나 조직 도입을 결정할 때는 최신 [releases](https://github.com/Zackriya-Solutions/meetily/releases), [building guide](https://github.com/Zackriya-Solutions/meetily/blob/main/docs/BUILDING.md), [GPU acceleration guide](https://github.com/Zackriya-Solutions/meetily/blob/main/docs/GPU_ACCELERATION.md), [MIT license](https://github.com/Zackriya-Solutions/meetily/blob/main/LICENSE.md)를 다시 확인해야 한다.

![Meetily 로컬 회의 지식 파이프라인](https://heracles-jo.github.io/assets/img/posts/github-trending-meetily-local-meeting-knowledge-pipeline/architecture.svg)

## 받아쓰기 앱과 회의 지식 시스템은 목표가 다르다

개인 받아쓰기의 목표는 말한 내용을 빠르게 텍스트 입력으로 바꾸는 것이다. [FluidVoice와 로컬 음성 입력의 재가치화](/posts/github-trending-fluidvoice-offline-dictation/)에서 다룬 것처럼 이 영역에서는 지연시간, 단축키, 언어 정확도, 붙여넣기 경험이 중요하다. 반면 회의 시스템의 목표는 여러 사람의 대화에서 **무엇을 결정했고, 누가 무엇을 언제까지 하며, 어떤 전제가 남았는지**를 보존하는 것이다.

따라서 회의 AI는 음성 인식률만 높다고 완성되지 않는다. 같은 transcript를 두고도 고객 인터뷰 팀은 문제 인식, 구매 동기, 경쟁 제품, 인용 가능한 표현을 원한다. 장애 대응 팀은 timeline, impact, mitigation, root cause hypothesis, follow-up owner가 필요하다. 제품 설계 회의는 선택한 안뿐 아니라 기각한 대안과 이유가 중요하다. 녹취가 입력층이라면 지식 파이프라인은 schema와 승인 절차를 포함한 운영층이다.

Meetily를 평가할 때도 “한국어를 얼마나 잘 받아쓰는가”와 “조직 지식으로 얼마나 안전하게 연결되는가”를 분리해야 한다. 첫 번째는 모델, 하드웨어, 음질의 문제다. 두 번째는 동의, 저장, 접근 권한, 검토, export, 보존, 삭제, 업무 시스템 연계의 문제다. 후자가 준비되지 않으면 좋은 transcript가 오히려 민감정보가 축적된 새로운 데이터 사일로가 된다.

## 현재 지원 아키텍처: Tauri 안에 실행 경계를 모은다

Meetily의 현재 구조는 다음 다섯 계층으로 볼 수 있다.

1. **Next.js frontend**가 녹음 상태, transcript, meeting history, 요약 설정을 표시한다.
2. **Tauri command/event bridge**가 웹 UI와 로컬 Rust core 사이의 호출 경계가 된다.
3. **audio engine**이 마이크와 시스템 오디오를 캡처하고 전사 입력을 만든다.
4. **transcription·summary engine**이 로컬 ASR과 선택한 LLM provider를 실행한다.
5. **SQLite와 로컬 파일**이 회의 metadata, transcript, summary, 녹음 산출물을 보존한다.

이 구조의 장점은 사용자가 별도 FastAPI 서버나 Docker backend를 운영하지 않아도 된다는 점이다. [frontend README](https://github.com/Zackriya-Solutions/meetily/blob/main/frontend/README.md)는 현재 지원 경로에서 로컬 전사와 저장, 요약 workflow를 Rust/Tauri 앱이 담당하며, 독립적인 whisper-server가 필요하지 않다고 명시한다. 설치 복잡도와 로컬 네트워크 노출면을 줄이는 실용적인 선택이다.

동시에 저장소 안에는 오래된 Python/FastAPI backend 코드와 문서가 남아 있다. 하지만 [backend README](https://github.com/Zackriya-Solutions/meetily/blob/main/backend/README.md)는 이를 legacy archive로 명시하고 새 설치, 프로덕션 배포, 현재 앱의 security assessment에 사용하지 말라고 경고한다. 검색 결과나 오래된 블로그를 따라 legacy Docker flow를 운영 경로로 착각하면 안 된다. 오픈소스 도입에서는 저장소에 파일이 존재한다는 사실과 현재 지원되는 아키텍처를 구분해야 한다.

Tauri 선택은 회의 앱에 잘 맞는다. 오디오 장치, 파일시스템, OS 권한, 네이티브 모델 실행은 브라우저 앱만으로 다루기 까다롭고, 회의 목록과 편집 UI는 웹 기술로 빠르게 반복하기 좋다. 다만 “데스크톱 앱 하나”로 보인다고 운영 문제가 사라지는 것은 아니다. 기기마다 모델 파일, 드라이버, 마이크 권한, 저장 공간, SQLite 상태, 앱 버전이 달라지며 중앙 SaaS보다 지원 환경이 다양해진다.

## 데이터 흐름을 단계별로 보면 프라이버시 경계가 선명해진다

회의 한 건의 데이터 경로는 대략 다음과 같다.

| 단계 | 생성되는 데이터 | 기본 위치 | 외부 전송 가능 지점 |
|---|---|---|---|
| 녹음 | 마이크·시스템 오디오 | 로컬 장치 | 원격 회의 플랫폼 자체의 경로는 별도 |
| 전사 | segment, timestamp, transcript | 로컬 전사 엔진·로컬 저장소 | 모델 다운로드와 업데이트 경로는 별도 확인 |
| 요약 | transcript 입력, prompt, summary | Ollama 사용 시 로컬 가능 | Claude·Groq·OpenRouter·OpenAI·custom endpoint 선택 시 transcript 전송 가능 |
| 저장 | metadata, transcript, summary, recording | SQLite와 앱 데이터 디렉터리 | OS backup·동기화 도구가 복제할 수 있음 |
| export | Markdown, TXT, DOCX, PDF 등 | 사용자가 선택한 파일 경로 | 메일·메신저·문서 플랫폼으로 재전송 가능 |
| 연계 | action item, decision, ticket | 업무 시스템 | API·clipboard·수동 복사 경로 |

이 표가 보여주는 핵심은 “로컬 전사”와 “완전한 로컬 지식 파이프라인”이 같은 말이 아니라는 점이다. 공식 [privacy policy](https://github.com/Zackriya-Solutions/meetily/blob/main/PRIVACY_POLICY.md)는 녹음과 전사를 기기에서 처리하고 요약은 로컬 또는 사용자가 선택한 provider를 통할 수 있다고 설명한다. 다만 문서의 `Last updated`가 placeholder로 남아 있는 등, 정책 문서 자체가 법적·기술적 보증을 대신한다고 보기 어렵다. 실제 binary, 네트워크 통신, 설정 저장, OS backup을 조직이 직접 검증해야 한다.

“로컬”이라는 표현은 최소 네 가지로 나눠 확인해야 한다.

- 음성 파일이 외부 STT API로 전송되지 않는가.
- transcript가 요약 provider로 전송되는가.
- API key와 설정이 어떤 방식으로 저장되는가.
- SQLite, 녹음, export 파일이 iCloud Drive, OneDrive, Time Machine, 기업 backup agent에 의해 복제되는가.

로컬 처리는 SaaS 사업자에게 데이터를 보내는 위험을 줄이지만 endpoint 보안과 backup 거버넌스 책임을 사용자에게 돌린다. 디스크 암호화가 꺼진 개인 노트북에 인사 회의 transcript를 영구 보존하면 “클라우드가 아니다”라는 사실만으로 안전해지지 않는다.

## 전사 계층: 모델 정확도보다 장치별 운영 편차가 문제다

Meetily는 Whisper와 Parakeet 계열 로컬 전사를 제시한다. 공식 GPU 문서는 `whisper-rs` 기반에서 CUDA, Metal, Core ML, Vulkan, OpenBLAS 경로를 설명한다. 패키지와 source build의 가속 방식도 다르다. README 기준 macOS package는 Metal/Core ML, Windows package는 Vulkan-enabled Whisper를 사용하며, CUDA는 호환되는 toolchain으로 source build해야 한다. Linux는 환경에 맞춰 build configuration을 선택한다.

이 차이는 PoC 결과를 해석할 때 중요하다. 같은 모델 이름이어도 다음 요소가 end-to-end 지연과 품질을 바꾼다.

- CPU instruction set과 GPU backend
- 모델 크기와 quantization
- 마이크 품질, room echo, system audio mixing
- 언어 전환과 고유명사·제품명 비율
- 동시 발화와 화자 간 음량 차이
- segment 길이와 VAD 설정
- thermal throttling과 배터리 모드

따라서 한 명의 최신 MacBook에서 잘 작동했다는 결과를 조직 전체에 일반화하면 안 된다. Windows x64 패키지, Apple Silicon, Linux workstation처럼 실제 장비군을 나누고 realtime factor, peak memory, 녹음 누락, 모델 load time을 측정해야 한다. 전사 속도가 실시간을 따라가지 못하면 summary 품질 이전에 회의 경험이 무너진다.

전사 품질 측정도 전체 WER 하나로 끝내면 부족하다. 실무에서는 숫자, 날짜, 고객명, 약어, 부정 표현, owner 이름의 오류에 더 높은 비용을 부여해야 한다. “배포한다”와 “배포하지 않는다”의 한 단어 차이는 일반적인 문자 오류율보다 중요하다. 도메인별 gold transcript 10~20개를 만들고 critical entity error를 별도로 세는 편이 낫다.

## 요약 계층: provider 선택은 기능이 아니라 데이터 정책이다

Meetily가 Ollama와 여러 외부 provider를 지원하는 것은 유연성이다. 하지만 provider dropdown은 단순한 모델 취향 설정이 아니다. 로컬 Ollama를 선택하면 transcript와 prompt를 장비 안에 둘 수 있지만 모델 품질, RAM/VRAM, 시작 지연, 모델 업데이트를 사용자가 책임진다. 외부 provider를 선택하면 더 강한 모델과 쉬운 운영을 얻을 수 있지만 회의 내용이 해당 endpoint로 전송된다.

custom OpenAI-compatible endpoint는 조직이 관리하는 inference gateway나 사내 모델을 연결하는 데 유용하다. 이 경우에도 endpoint가 실제로 사내망 안에 있는지, request logging이 켜져 있는지, prompt가 observability vendor로 전달되는지, 보존 기간이 얼마인지 확인해야 한다. “self-hosted endpoint”라는 이름만으로 데이터가 조직 경계 안에 남는 것은 아니다.

요약은 사실 보존보다 구조 변환에 가깝다. 모델은 긴 대화를 짧게 만들면서 무엇을 버릴지 결정한다. 이 과정에서 다음 오류가 반복된다.

- 조건부 제안을 확정된 결정으로 바꾼다.
- 담당자가 명시되지 않은 일을 특정 사람에게 배정한다.
- 다음 주·다음 분기 같은 상대 날짜를 잘못 해석한다.
- 금액, 버전, 티켓 번호를 수정한다.
- 반대 의견과 보류 이유를 삭제한다.
- 여러 화자의 발언을 한 사람의 입장으로 합친다.

따라서 요약을 기록의 원본으로 두지 말고 transcript와 연결된 파생물로 취급해야 한다. 중요한 decision과 action item에는 원문 timestamp 또는 segment 링크를 남기고, 사람이 승인하기 전에는 공식 회의록이나 티켓을 생성하지 않는 편이 안전하다.

## 회의를 지식으로 바꾸려면 출력 schema가 필요하다

좋은 요약문은 읽기 편하지만 자동화하기 어렵다. 조직 지식으로 재사용하려면 최소한 다음 구조가 필요하다.

```text
meeting_id
meeting_type
participants
recording_consent
summary_status

decisions[]
  statement
  rationale
  alternatives_rejected
  evidence_timestamp
  approved_by

action_items[]
  task
  owner
  due_date
  dependency
  source_timestamp
  verification_status

open_questions[]
risks[]
retention_class
```

Meetily Community Edition이 이 모든 schema와 조직 workflow를 기본 제공한다고 말하는 것은 아니다. 핵심은 Meetily의 transcript와 summary를 출발점으로 삼더라도, 팀이 자신의 회의 유형에 맞는 계약을 추가해야 한다는 점이다. 고객 인터뷰, sprint planning, architecture review, incident retrospective를 같은 prompt와 같은 필드로 처리하면 정보 손실이 커진다.

예를 들어 장애 회고에서는 “누가 실수했는가”보다 탐지 시간, 영향 범위, 완화 조치, 원인 가설, 재발 방지 owner가 중요하다. 고객 인터뷰에서는 확정된 요구사항보다 직접 인용, 맥락, 대체 행동, 구매 장벽이 중요하다. 회의 유형을 먼저 분류하고 요약 template를 다르게 적용해야 모델 출력이 실제 프로세스와 연결된다.

## 저장·검색·export는 제품 기능이 아니라 lifecycle 문제다

공식 architecture 문서는 meeting metadata, transcript, summary를 로컬 SQLite에 저장한다고 설명한다. 이는 단일 사용자 데스크톱 앱에는 단순하고 견고한 선택이다. 하지만 조직 관점에서는 다음 질문이 생긴다.

- 데이터베이스와 오디오 파일의 실제 경로는 어디인가.
- 앱 삭제와 회의 삭제가 녹음, transcript, export 파일을 모두 지우는가.
- DB schema migration이 실패하면 rollback과 복구가 가능한가.
- 손상된 SQLite 파일에서 회의 데이터를 어떻게 복구하는가.
- backup을 암호화하고 복원 테스트하는가.
- 사용자 퇴사 시 장비의 회의 기록을 어떻게 회수·삭제하는가.
- 하나의 회의가 여러 export와 clipboard 복사본으로 퍼졌을 때 삭제 요청을 어떻게 처리하는가.

Meetily의 최신 문서 사이트에는 [summary와 transcript export](https://docs.meetily.ai/features/export-and-copy)를 Markdown, TXT, DOCX, PDF 또는 clipboard로 내보내는 흐름이 설명돼 있다. 다만 문서 사이트는 Pro 기능을 포함할 수 있으므로 Community Edition에서 실제 제공되는 형식과 버전을 확인해야 한다. export가 많을수록 지식 활용성은 좋아지지만 보존 정책을 우회하는 복사본도 늘어난다.

local-first 회의 기록은 중앙 검색과 권한 관리가 자동으로 생기지 않는다. 개인 사용자는 SQLite와 파일 export로 충분할 수 있지만, 팀이 공유하기 시작하면 중앙 지식 플랫폼의 ACL, 감사 로그, retention rule, legal hold와 연결해야 한다. 이 지점부터는 데스크톱 앱 도입이 아니라 정보 거버넌스 프로젝트가 된다.

## 다른 접근과 비교하면 Meetily의 위치가 보인다

| 접근 | 강점 | 운영 부담 | 주요 리스크 | 적합한 범위 |
|---|---|---|---|---|
| 클라우드 회의 비서 | 캘린더·회의 플랫폼 연동, 협업, 검색이 빠름 | 낮음 | 외부 전송, vendor retention, bot 참여 고지 | 빠른 조직 도입과 표준 회의 |
| Meetily Community Edition | 로컬 전사, 데스크톱 통제, 오픈소스 검토 가능 | 장치별 모델·업데이트·backup 관리 | endpoint 분산, 요약 provider 설정, 지원 편차 | 개인·소규모 팀 PoC, 민감 회의의 로컬 처리 |
| 로컬 Whisper CLI 조합 | 가장 단순하고 자동화 자유도가 높음 | capture·UI·저장·요약을 직접 구성 | 운영 파편화, 사용자 경험 부족 | 엔지니어링 중심 배치 전사 |
| 자체 회의 지식 플랫폼 | schema, ACL, 검색, retention을 조직에 맞춤 | 매우 높음 | 구축·보안·컴플라이언스 책임 | 규제 산업과 대규모 지식 운영 |
| 수동 회의록 | 사람의 맥락 판단, 녹음 최소화 | 작성 시간과 누락 비용 | 기억 편향, 검색성 부족 | 녹음이 부적절한 고위험 회의 |

Meetily는 클라우드 회의 비서의 완전한 대체품이라기보다 로컬 캡처와 전사를 중심으로 데이터 통제권을 높이는 선택지다. 캘린더 자동화, 팀 ACL, 중앙 관리, 감사, SLA가 핵심이면 Community Edition만으로는 간극이 클 수 있다. README가 별도 Pro codebase와 self-hosted/team 기능을 구분하는 이유도 여기에 있다. 오픈소스 Community Edition의 기능과 상용 Pro의 약속을 하나로 섞어 평가해서는 안 된다.

[Home Assistant와 로컬 우선 자동화](/posts/github-trending-home-assistant-local-first-automation/)에서 보듯 local-first 제품의 장점은 외부 서비스 장애와 데이터 전송 의존을 줄이는 것이다. 동시에 장치 discovery, 업데이트, backup, 권한 관리 책임이 사용자 쪽으로 이동한다. Meetily도 같은 경제를 가진다. SaaS 비용을 줄이는 대신 endpoint 운영 비용이 생긴다.

## 주요 리스크 1: 녹음 동의와 신뢰

회의 녹음은 기술보다 먼저 사람과 법의 문제다. 관할 지역, 고용 관계, 고객 계약에 따라 동의 요건이 다르고, 법적 허용과 조직 신뢰는 같은 기준이 아니다. 참가자가 “회의 bot은 없으니 녹음되지 않는다”고 생각하는데 누군가 로컬 시스템 오디오를 캡처하면 기술적으로 은밀한 기록이 가능하다.

조직은 최소한 다음 정책을 명시해야 한다.

- 녹음 시작 전에 시각·음성으로 알리고 동의를 받는다.
- 동의하지 않은 참가자가 있을 때 즉시 중단할 절차를 둔다.
- 녹음이 필요한 회의와 금지된 회의를 분류한다.
- 인사, 법무, 보안 사고, 의료·고객 민감정보 회의는 별도 승인한다.
- transcript와 요약의 사용 목적, 접근자, 보존 기간을 고지한다.
- AI 요약은 오류 가능성이 있으며 공식 기록 전에 검토된다는 점을 밝힌다.

법률 판단이 필요한 조직은 관할 법과 계약을 전문가에게 검토받아야 한다. “앱이 로컬에서 작동한다”는 사실은 녹음 동의 의무를 없애지 않는다.

## 주요 리스크 2: endpoint가 새로운 민감정보 저장소가 된다

로컬 SQLite, 녹음 파일, 모델 cache, export 문서는 공격자 입장에서 가치가 높은 데이터다. 중앙 SaaS보다 덜 노출될 수 있지만 endpoint malware, 계정 탈취, 수리·분실, backup 유출에 취약하다. 특히 개인 BYOD에서 사용하면 기업이 삭제와 접근 통제를 강제하기 어렵다.

도입 장비에는 FileVault·BitLocker·LUKS 같은 full-disk encryption, 자동 화면 잠금, OS patch, EDR, MDM, 최소 권한 계정, 암호화 backup이 필요하다. 앱 데이터 디렉터리를 일반 cloud sync 폴더에 두지 말고, 녹음 원본과 transcript에 서로 다른 retention을 적용할 수 있는지도 확인해야 한다. 전사는 남기되 원본 오디오는 짧게 보존하는 정책이 현실적인 경우가 많다.

API key도 점검해야 한다. UI에서 provider key를 저장할 수 있다는 사실만으로 OS keychain을 사용한다고 가정해서는 안 된다. 배포할 정확한 버전에서 key 저장 위치와 masking, 로그 노출, export 포함 여부를 직접 검사해야 한다. custom endpoint가 사내 gateway라면 짧은 수명의 token과 egress 제한을 사용하는 편이 좋다.

## 주요 리스크 3: 그럴듯한 요약이 조직의 사실로 굳어진다

자동 요약은 문장이 자연스러울수록 검토가 줄어드는 역설이 있다. 중요한 오류는 문법이 아니라 commitment의 왜곡이다. “검토해 볼 수 있다”가 “하기로 했다”로 바뀌거나, “금요일 전에는 어렵다”가 “금요일까지 완료”로 바뀌면 action item 시스템 전체가 오염된다.

따라서 다음 항목은 자동 승인하지 않는 편이 좋다.

- 금액과 수량
- 날짜와 deadline
- 사람 이름과 담당자
- 계약·법무·보안 판단
- 제품 출시·배포 결정
- 고객에게 약속한 범위
- 부정문과 조건부 합의

요약 UI에는 `draft`, `reviewed`, `approved` 상태가 필요하고, 승인자는 원문 timestamp를 빠르게 볼 수 있어야 한다. 오류를 수정한 데이터는 모델과 prompt 평가셋으로 남겨야 한다. 단순 만족도보다 critical field precision을 측정해야 개선 방향이 보인다.

![Meetily 도입 체크리스트](https://heracles-jo.github.io/assets/img/posts/github-trending-meetily-local-meeting-knowledge-pipeline/checklist.svg)

## 3단계 PoC: 앱 설치가 아니라 운영 가설을 검증한다

### 1단계: 개인 로컬 워크플로

5명 이내의 자발적 참여자로 시작해 스탠드업이나 내부 기술 회의처럼 위험이 낮은 회의만 다룬다. 기기별로 모델 load time, realtime factor, CPU/GPU 사용량, battery impact, 녹음 누락, 한국어 고유명사 오류를 측정한다. 요약은 Ollama 로컬 경로와 승인된 외부 provider 경로를 분리해 네트워크 흐름을 확인한다.

### 2단계: 지식 변환 품질

회의 유형별 10건 이상을 사람이 작성한 회의록과 비교한다. 전체 문장 유사도보다 decision recall, action owner accuracy, due-date accuracy, critical entity error, 사람이 수정한 시간으로 평가한다. 결과를 Jira·Linear·GitHub Issues·Notion·Confluence로 옮길 때 자동 생성하지 말고 draft 상태로 만든다.

### 3단계: 운영과 사고 대응

SQLite backup·restore, 앱 upgrade, 모델 변경, disk full, microphone permission 취소, GPU fallback, 외부 provider outage를 시험한다. 기기 분실, 직원 퇴사, 회의 삭제 요청, provider key 노출 시 대응 절차도 확인한다. 이 단계를 통과하지 못하면 팀 표준 도구로 확대하지 않는다.

PoC 지표는 다음 정도면 충분하다.

| 지표 | 측정 목적 |
|---|---|
| recording success rate | 회의 전체가 손실 없이 캡처되는가 |
| realtime factor / summary latency | 실제 업무 흐름을 방해하지 않는가 |
| critical entity accuracy | 이름·숫자·날짜·부정문이 보존되는가 |
| decision/action recall | 중요한 결론과 후속 작업을 놓치지 않는가 |
| human correction minutes | 자동화가 실제 편집 시간을 줄이는가 |
| external bytes/requests | 로컬 정책과 실제 네트워크 동작이 일치하는가 |
| storage growth per hour | 장기 보존 비용을 예측할 수 있는가 |
| restore success | 장비 장애 후 데이터를 복구할 수 있는가 |
| consent exception rate | 녹음 거부·중단 요구를 운영할 수 있는가 |

## 도입 체크리스트

1. **지원 경로를 확인한다.** Community Edition의 최신 release와 현재 Tauri architecture를 기준으로 설치하고 legacy FastAPI 문서를 사용하지 않는다.
2. **회의 분류를 만든다.** 녹음 허용, 추가 승인, 녹음 금지 회의를 구분한다.
3. **동의 절차를 표준화한다.** 회의 초대와 녹음 시작 시점에 고지한다.
4. **데이터 맵을 작성한다.** audio, transcript, summary, SQLite, model, cache, export, backup 위치를 기록한다.
5. **provider별 경계를 문서화한다.** Ollama와 외부 LLM의 endpoint, logging, retention, 계약을 분리한다.
6. **장치 매트릭스를 검증한다.** macOS package, Windows package, Linux source build의 가속과 성능을 각각 측정한다.
7. **요약 schema를 회의 유형별로 만든다.** decision, action, risk, open question을 분리하고 원문 timestamp를 남긴다.
8. **사람 승인 단계를 둔다.** 중요한 회의록과 티켓은 reviewed 상태를 거쳐야 한다.
9. **보존과 삭제를 테스트한다.** 앱 내부 삭제뿐 아니라 audio, export, backup 복사본까지 범위를 확인한다.
10. **upgrade를 고정한다.** release version과 모델 checksum을 기록하고 pilot group에서 먼저 업데이트한다.
11. **오류 데이터를 축적한다.** 숫자·날짜·담당자·부정문 오류를 별도 분류해 model/prompt 변경 전후를 비교한다.
12. **중단 기준을 정한다.** 무동의 녹음, 외부 전송 정책 위반, 복구 실패, 반복적인 critical summary error가 나오면 확대를 멈춘다.

## 어떤 팀에 맞고, 어떤 경우에는 과한가

Meetily Community Edition은 민감한 회의를 외부 STT SaaS로 보내고 싶지 않은 개인 전문가, 로컬 모델을 운영할 수 있는 소규모 엔지니어링 팀, 회의 데이터 경로를 직접 검증하려는 보안 중심 조직의 PoC에 잘 맞는다. 모든 것을 중앙 플랫폼으로 통합하기 전에 로컬 전사와 구조화된 회의록의 효과를 검증하는 실험대로도 유용하다. MIT license는 내부 수정과 배포를 검토하기 좋은 출발점이지만, 운영 지원과 보안 보증이 자동으로 제공되는 것은 아니다.

반대로 수백 명의 중앙 계정 관리, 역할 기반 접근 제어, 감사 로그, legal hold, 캘린더 자동화, SLA, 전사 검색이 즉시 필요한 기업에는 Community Edition만으로 부족할 가능성이 크다. 장치별 Rust/Tauri build와 GPU 차이를 지원할 인력이 없거나, BYOD 데이터를 회수할 수 없거나, 녹음 동의 문화가 정착되지 않은 조직도 도입을 서두르지 않는 편이 낫다.

모든 회의를 자동 기록해야 하는 것도 아니다. 민감도가 높고 후속 지식 가치가 낮은 회의는 녹음하지 않는 것이 최선의 데이터 최소화다. 로컬 AI는 더 많이 수집할 허가가 아니라, 필요한 데이터를 더 통제된 경로에서 처리하는 수단이다.

## 결론: Meetily의 가치는 로컬 전사보다 경계 선택권에 있다

Meetily가 보여주는 방향은 회의 AI가 반드시 중앙 SaaS와 회의 bot으로만 구현될 필요는 없다는 것이다. Tauri와 Rust core 안에서 오디오 캡처, 로컬 전사, SQLite 저장을 묶고, 요약 provider를 선택하게 만들면 사용자는 편의와 데이터 통제 사이의 경계를 더 세밀하게 조정할 수 있다. 이 점은 프라이버시가 중요한 개인과 팀에 분명한 가치가 있다.

하지만 local-first는 운영 책임을 없애지 않고 이동시킨다. 장치별 성능, 앱 업데이트, SQLite backup, 디스크 암호화, provider 설정, export 복사본, 퇴사자 데이터, 요약 오류를 사용자가 관리해야 한다. 회의 기록은 일반 생산성 데이터보다 민감하고, 그럴듯하게 틀린 action item은 실제 업무 충돌을 만든다.

따라서 도입 기준은 “회의를 자동 요약하는가”가 아니다. **동의를 얻은 대화를 통제된 경로에서 처리하고, 결정과 행동을 원문 근거와 연결하며, 필요한 기간만 보존하고, 사람이 승인한 뒤 실제 업무 시스템으로 넘길 수 있는가**가 기준이어야 한다. 그 운영 계약이 준비돼 있을 때 Meetily는 로컬 녹취 앱을 넘어 회의 지식 파이프라인의 현실적인 출발점이 된다.
