---
title: "오프라인 지식 서버 설계: Project NOMAD의 운영 경계"
description: "Project NOMAD의 Kiwix·Kolibri·로컬 RAG 구성을 바탕으로 인터넷 단절에도 쓸 수 있는 지식 서버의 보안, 갱신, 복구와 도입 기준을 정리한다."
author: heracles-jo
date: 2026-09-15 08:05:00 +0900
categories: [Infrastructure, AI]
tags: [project-nomad, offline-first, self-hosting, knowledge-management, local-ai, disaster-recovery]
image:
  path: https://heracles-jo.github.io/assets/img/posts/project-nomad-offline-knowledge-server/cover.svg
  alt: "인터넷 단절 상황에 대비한 Project NOMAD 오프라인 지식 서버"
---

인터넷이 끊겼을 때 사라지는 것은 동영상 스트리밍만이 아니다. 재난 현장의 응급 지침, 원격 사업장의 정비 매뉴얼, 교실의 교육 과정, 지도와 사내 표준운영절차도 SaaS와 검색 엔진 뒤에 묶여 있다. 문서를 노트북에 복사해 두는 것만으로는 충분하지 않다. 무엇이 최신인지 알기 어렵고, 여러 형식을 한 번에 검색할 수 없으며, 장비가 고장 나면 다시 구성하는 절차도 없다.

[Crosstalk-Solutions/project-nomad](https://github.com/Crosstalk-Solutions/project-nomad)는 이 문제를 단일 앱이 아니라 **오프라인 지식 서비스를 운영하는 작은 플랫폼**으로 다룬다. Command Center가 Docker 기반 앱을 설치·갱신하고, Kiwix가 ZIM 지식 묶음을 제공하며, Kolibri가 교육 과정과 학습 진도를 맡는다. ProtoMaps 지도, FlatNotes, CyberChef를 함께 두고, 필요하면 Ollama와 Qdrant로 로컬 문서 질의응답을 붙인다. 중요한 질문은 “인터넷 없이 AI를 쓸 수 있는가”가 아니다. **연결이 가능한 동안 지식·소프트웨어·복구 절차를 준비해 두고, 연결이 사라진 뒤에도 신뢰할 수 있는 서비스를 유지할 수 있는가**다.

2026년 9월 15일 08시 KST 전후 GitHub Trending daily에서 Project NOMAD는 **26 stars today**로 표시됐다. GitHub API 기준 약 **36.9k stars**, **3.7k forks**, 열린 이슈와 PR을 합친 92개, Apache-2.0 라이선스, 9월 13일 UTC의 최근 push를 확인했다. 최신 정식 릴리스는 9월 2일의 `v1.34.1`, 최신 공개 릴리스 후보는 `v1.35.0-rc.1`이다. 이 수치는 관심도와 활동의 시점별 스냅샷이지 오프라인 가용성이나 의료 정보의 정확성을 보증하지 않는다. Search Console과 Analytics의 실제 검색어 데이터에는 이번 실행 환경에서 접근할 수 없어 주제 선정에 사용하지 않았다.

## 후보를 나란히 놓으면 ‘오프라인’의 목적이 갈린다

오늘 daily·weekly 후보 중 기존 글의 저장소, 검색 의도와 중심 논지를 먼저 대조했다. README, 라이선스, 릴리스와 최근 활동을 확인한 다섯 후보는 모두 활발했지만 해결하려는 단절이 달랐다.

| 후보 | 확인 시점 신호 | 중복·검색 의도 판단 |
|---|---|---|
| [Project NOMAD](https://github.com/Crosstalk-Solutions/project-nomad) | daily 26, 약 36.9k stars, Apache-2.0, v1.34.1 | 지식·교육·지도·로컬 AI를 하나의 단절 대비 서비스로 운영한다. ‘오프라인 지식 서버’라는 독립 의도가 분명해 선택했다. |
| [LocalSend](https://github.com/localsend/localsend) | daily 311, 약 91.3k stars, Apache-2.0, v1.18.2 | 로컬 네트워크 파일 전송은 장기 검색 가치가 있지만 오늘의 핵심인 지식 갱신·복구보다 장치 간 전송 프로토콜에 가깝다. |
| [OpenDisplay](https://github.com/peetzweg/opendisplay) | daily 258, 약 3.5k stars, GPL-3.0, v1.19.0 | iPad를 Mac 보조 모니터로 쓰는 검색 의도는 선명하지만 플랫폼 운영 클러스터와 연결성이 낮다. |
| [flowsint](https://github.com/reconurge/flowsint) | daily 279, 약 8.3k stars, Apache-2.0, v1.2.12 | 그래프형 조사는 유용하지만 이미 [Flowsint와 OSINT 그래프 조사 플랫폼](/posts/github-trending-osint-graph-flowsint/)에서 저장소와 중심 논지를 다뤘다. |
| [colibri](https://github.com/JustVugg/colibri) | daily 2,233, 약 32.0k stars, Apache-2.0, v1.11.0 | 디스크에서 MoE expert를 스트리밍하는 추론은 [AirLLM의 저VRAM 레이어 스트리밍](/posts/airllm-low-vram-layer-streaming/)과 검색 의도가 가깝다. |

Project NOMAD도 과거 Home Assistant 글의 후보 표에 등장했고, 오프라인 웹 보존도 이미 다뤘다. 그러나 [kage의 JavaScript 제거형 오프라인 웹 아카이브](/posts/github-trending-kage-offline-web-archive/)는 웹을 재현 가능한 정적 자료로 **만드는 앞단**이 중심이다. 이번 글은 만들어진 콘텐츠, 지도, 교육 앱과 모델을 현장 장비에서 **계속 서비스하고 갱신·복구하는 운영면**을 다룬다.

## 파일 모음이 아니라 로컬 서비스 묶음이다

NOMAD의 공식 README는 Command Center를 컨테이너형 도구와 리소스를 오케스트레이션하는 관리 UI·API로 설명한다. 기본 관리 Compose를 보면 `admin`, MySQL 8, Redis 7, 로그 뷰어인 Dozzle, updater, disk collector가 별도 서비스로 놓인다. Command Center는 호스트 Docker daemon을 제어하려고 `/var/run/docker.sock`을 마운트하고, 기본적으로 8080 포트를 연다. 여기서 다시 Kiwix, AI Assistant 같은 앱을 설치한다.

![Project NOMAD의 오프라인 지식 서비스 아키텍처](https://heracles-jo.github.io/assets/img/posts/project-nomad-offline-knowledge-server/architecture.svg)

이 구조는 USB 디스크에 PDF를 넣어 두는 방식과 세 가지가 다르다.

첫째, **콘텐츠 계층과 애플리케이션 계층이 분리된다.** Wikipedia·의학 참고 자료는 Kiwix가 읽는 ZIM으로, 강좌와 학습 진도는 Kolibri로, 지역 지도는 ProtoMaps로 제공한다. 각 형식에 맞는 검색과 UI가 있으므로 파일명을 기억하지 않아도 된다. 반면 구성 요소가 늘어난 만큼 데이터 경로와 백업 단위도 여러 개가 된다.

둘째, **로컬 AI는 전체 시스템이 아니라 선택적 소비 계층이다.** 문서를 올리면 Qdrant를 이용한 의미 검색과 Ollama 기반 대화를 붙일 수 있고, LM Studio나 llama.cpp처럼 OpenAI 호환 endpoint를 다른 호스트에 둘 수도 있다. 그러나 모델이 없더라도 Kiwix·Kolibri·지도는 쓸 수 있어야 한다. 검색 가능한 원문을 모델의 답변보다 아래에 두는 것이 맞다. 단절 상황에서 환각한 응급 처치 문장은 느린 검색보다 위험하다.

셋째, **준비 시점과 사용 시점이 분리된다.** 설치와 추가 콘텐츠 다운로드에는 인터넷이 필요하다. 오프라인이라는 말은 데이터가 저절로 최신 상태를 유지한다는 뜻이 아니다. 연결 가능한 정비 창구에서 이미지·ZIM·지도·모델을 받아 검증하고, 그 결과를 단절 구간으로 운반해야 한다.

[Meetily의 로컬 회의 지식 파이프라인](/posts/github-trending-meetily-local-meeting-knowledge-pipeline/)에서도 로컬 처리가 곧 안전을 뜻하지 않는다고 지적했다. NOMAD는 더 넓은 서비스와 데이터를 한 호스트에 모으므로 그 구분이 더 중요하다.

## 가장 큰 보안 경계는 로그인 화면보다 Docker 소켓이다

공식 README는 현재 NOMAD에 인증이 없으며 인터넷에 직접 노출하도록 설계되지 않았다고 명시한다. 다중 사용자 역할도 우선순위 기능이 아니다. 따라서 `http://DEVICE_IP:8080`을 사무실 LAN 전체나 공유 Wi-Fi에 열고 “로컬이니 안전하다”고 판단하면 안 된다. Command Center에는 앱 설치·갱신 기능이 있고 Docker socket까지 연결된다. 관리 UI 침해가 단순 문서 열람을 넘어 컨테이너와 호스트 데이터 경로에 영향을 줄 수 있는 구조다.

권장 경계는 역방향 프록시 하나를 더 붙이는 것으로 끝나지 않는다.

- **관리망과 열람망을 분리한다.** 일반 사용자는 Kiwix·Kolibri 같은 필요한 서비스만 접근하고 Command Center는 운영자 VLAN이나 물리 관리 단말에서만 연다.
- **인터넷 인바운드는 닫는다.** 원격 관리가 꼭 필요하면 인터넷 공개 포트 대신 MFA가 있는 VPN과 장치 인증을 둔다.
- **Docker socket proxy 또는 별도 관리 host를 검토한다.** 직접 socket mount가 필요한 기능을 목록화하고 허용 API를 줄인다. 범위를 줄일 수 없다면 Command Center를 고신뢰 관리면으로 취급한다.
- **외부 콘텐츠를 비신뢰 입력으로 본다.** ZIM, 문서, 모델, 사용자 정의 컨테이너는 다운로드 출처·digest·라이선스·악성코드 검사를 통과한 뒤 반입한다.
- **AI endpoint를 무심코 LAN 전체에 열지 않는다.** 공식 문서는 원격 Ollama 사용 시 `OLLAMA_HOST=0.0.0.0`을 안내하지만, 이는 모든 인터페이스 listen이지 인증 정책이 아니다. 방화벽과 endpoint 인증을 별도로 설계해야 한다.

의학·재난 자료에는 또 다른 안전 경계가 있다. 오래된 콘텐츠, 출처가 불명확한 문서, AI가 요약한 답변을 공식 절차와 같은 등급으로 보여 주면 안 된다. 문서 카드에 출처, 판본, 수집일, 검토일, 유효기간과 책임 부서를 표시하고, 고위험 질문은 원문을 강제로 함께 보여 주는 편이 낫다. NOMAD의 Apache-2.0 라이선스는 소프트웨어 사용 권한을 설명할 뿐, 탑재한 Wikipedia·책·강좌·지도·모델의 재배포 권리까지 한꺼번에 주지 않는다.

## 오프라인 가용성은 업데이트가 아니라 동기화 계약에서 나온다

공식 업데이트 문서는 core software, 설치 앱, 콘텐츠를 서로 다른 갱신 대상으로 나눈다. 자동 업데이트는 기본적으로 꺼져 있고 opt-in이며, 설정한 시간 창과 cool-off를 적용한다. major version은 자동 적용하지 않고 디스크 여유, 진행 중인 다운로드·설치 여부를 사전 확인한다. `v1.34.1`도 Kiwix catalog host 문제를 고친 패치다. 온라인일 때 콘텐츠 목록을 제대로 받지 못하면 오프라인일 때는 고칠 통로조차 없다.

자동화의 방향은 합리적이지만 운영 계약을 대신하지는 않는다. 현장 장비가 한 달에 한 번만 연결된다면 “매일 업데이트 확인”보다 다음 네 시간이 중요하다.

1. **신선도 예산**: 응급 지침, 규정, 지도, 교육 자료, 백과사전마다 허용 가능한 오래됨을 정한다.
2. **검증된 정비 창**: 연결 → manifest 수집 → 서명·digest 검사 → staging 장비 적용 → 핵심 질의 검사 → 현장 반입 순서를 고정한다.
3. **용량 예측**: 새 이미지와 콘텐츠를 동시에 보관할 여유, 모델·벡터 색인의 증가량, 외장 디스크 I/O를 계산한다.
4. **실패 시 보존**: 갱신이 실패해도 직전 정상 콘텐츠와 앱이 계속 열리고, 운영자가 어느 세대인지 확인할 수 있어야 한다.

최근 열린 이슈에는 다운로드 한 번의 stall이 재시도 설정을 우회해 작업을 영구 실패시키는 문제, embedding 작업 복구가 중복 vector를 쓸 수 있는 문제, RAG relevance 판정과 답변 truncation 문제가 있다. 열린 이슈는 결함 확정이나 운영 장애 빈도의 증거는 아니지만 PoC에서 어디를 깨뜨려야 하는지는 알려 준다. 대용량 ZIM 다운로드 중 회선을 끊고, 재부팅하고, 디스크를 채운 뒤 재개·중복·색인 일관성을 확인해야 한다.

## 백업은 `/opt/project-nomad/storage` 복사로 끝나지 않는다

기본 Compose는 `/opt/project-nomad/storage`를 주 데이터 위치로 사용하고 자식 앱도 같은 호스트 경로를 바라보게 한다. 주석은 경로의 대소문자나 `NOMAD_STORAGE_PATH`가 불일치하면 Docker가 빈 디렉터리를 만들어 콘텐츠가 사라진 것처럼 보일 수 있다고 경고한다. 외장·NFS·SMB 저장소도 가능하지만 공식 FAQ는 host 수준 구성이며 로컬 디스크를 성능상 권장한다.

복구 계획에는 적어도 네 묶음이 들어간다.

- **원본 콘텐츠**: ZIM, 지도, 업로드 문서, 노트, 교육 자료와 모델 파일
- **상태 데이터**: MySQL, Redis 의존 상태, Kolibri 진도, Qdrant collection, 앱별 metadata
- **구성·비밀**: Compose, 환경 변수, `APP_KEY`, 포트와 storage mapping, 방화벽 정책
- **공급망 증거**: 이미지 digest, 릴리스, 콘텐츠 manifest, 라이선스와 검수 기록

복구 시험은 동일 장비 재시작이 아니다. 빈 Debian host에 저장 매체와 runbook만 제공하고, 인터넷 없이 서비스를 올려 핵심 자료를 검색하게 해야 한다. Qdrant index가 없으면 원문에서 재구축할 수 있는지, 필요한 임베딩 모델이 로컬에 남았는지, DB와 파일 스냅샷의 시점이 맞는지도 본다. [Home Assistant의 로컬 우선 자동화](/posts/github-trending-home-assistant-local-first-automation/)과 마찬가지로 로컬 제어권을 되찾는 대신 백업·업데이트·수동 우회 책임도 함께 가져온다.

## 도입 판단은 단절 훈련으로 내린다

Project NOMAD는 상시 인터넷이 충분하고 Google Workspace·Microsoft 365·LMS에 이미 인증·감사·지원 계약이 갖춰진 조직에서 굳이 중앙 지식 플랫폼을 대체할 이유가 적다. 반대로 선박, 현장 공사, 연구 기지, 임시 교실, 재난 대응 거점처럼 **회선 품질이 업무 가능 여부를 결정하고 제한된 콘텐츠를 여러 사람이 브라우저로 이용해야 하는 곳**에는 맞는 문제가 있다.

![Project NOMAD 도입을 결정하는 단절 훈련과 운영 게이트](https://heracles-jo.github.io/assets/img/posts/project-nomad-offline-knowledge-server/decision.svg)

PoC는 기능 체크보다 72시간 단절 훈련으로 설계하는 편이 낫다.

| 측정 축 | 실제로 확인할 값 | 중단 조건 예시 |
|---|---|---|
| 콘텐츠 완전성 | 필수 문서·지도·강좌 manifest 충족률, 출처·판본 표시율 | 필수 항목 하나라도 누락되거나 판본을 식별할 수 없음 |
| 검색 품질 | 30~50개 현장 질의의 원문 검색 성공률, AI 답변의 인용 일치율 | 고위험 답변이 근거 없는 지침을 생성 |
| 단절 가용성 | DNS·WAN을 차단한 뒤 p95 응답, 재부팅 후 복구 시간 | 외부 API 때문에 핵심 UI가 열리지 않음 |
| 장애 복구 | 디스크 교체 후 RTO·RPO, 색인 재구축 시간 | 인터넷 없이는 복구할 수 없는 의존성 발견 |
| 운영 비용 | 월간 다운로드량, 저장 증가량, 정비 시간, 전력·예비 부품 | 현장 인력이 정해진 정비 창 안에 갱신하지 못함 |
| 보안 경계 | 열려 있는 포트, 관리면 접근자, image·content provenance | 비관리 단말이 Command Center나 Docker 제어 경로에 접근 |

최소 사양은 공식 README 기준 2GHz dual-core, RAM 4GB, 여유 공간 5GB지만 이는 관리 애플리케이션의 시작점이다. 로컬 AI까지 권장하는 구성은 RAM 32GB, RTX 3060 또는 AMD 동급 이상, SSD 250GB 이상이다. 이 수치를 구매 목록으로 복사하지 말고 콘텐츠 크기와 동시 사용자, 모델, 정전 시 지속 시간을 넣어 다시 산정해야 한다. 현장에서는 GPU 성능보다 저전력 CPU, 이중 SSD, UPS, 교체 가능한 팬, 여분 장비와 인쇄된 복구 runbook이 더 높은 가용성을 만들 수도 있다.

Project NOMAD의 가치는 Wikipedia와 로컬 LLM을 한 화면에 놓은 데만 있지 않다. 콘텐츠 수집, 서비스, 갱신, 검색을 하나의 운영 대상으로 보게 만든다는 점이 더 중요하다. 동시에 인증 없는 관리면, Docker socket, 여러 앱의 상태, 오래된 자료와 모델 환각이라는 위험도 한 장비에 모은다.

따라서 도입 기준은 “인터넷이 끊겨도 챗봇이 대답했다”가 아니다. **필수 지식을 판본과 출처까지 확인할 수 있고, 비관리 사용자가 관리면을 건드릴 수 없으며, 업데이트 실패 뒤에도 직전 세대가 남고, 빈 장비에서 제한 시간 안에 복구할 수 있는가.** 이 네 조건을 단절 훈련으로 입증할 수 있다면 NOMAD는 취미용 survival computer를 넘어 원격·교육·재난 현장의 작은 지식 인프라가 된다.

> 1차 자료: [Project NOMAD 저장소와 README](https://github.com/Crosstalk-Solutions/project-nomad), [기본 management Compose](https://github.com/Crosstalk-Solutions/project-nomad/blob/main/install/management_compose.yaml), [공식 FAQ](https://github.com/Crosstalk-Solutions/project-nomad/blob/main/FAQ.md), [업데이트 문서](https://github.com/Crosstalk-Solutions/project-nomad/blob/main/admin/docs/updates.md), [v1.34.1 릴리스](https://github.com/Crosstalk-Solutions/project-nomad/releases/tag/v1.34.1), [공개 이슈](https://github.com/Crosstalk-Solutions/project-nomad/issues), [Apache-2.0 LICENSE](https://github.com/Crosstalk-Solutions/project-nomad/blob/main/LICENSE). Trending·저장소 수치는 2026년 9월 15일 08시 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
