---
title: "LZ4 압축 선택: Zstd 대비 지연시간·호환성 기준"
description: "LZ4 v1.11.0의 멀티스레드·소블록 개선을 바탕으로 Zstd·Snappy와 비교해 압축률보다 지연시간, 프레임 무결성, 메모리 예산으로 선택하는 기준을 정리한다."
author: heracles-jo
date: 2026-11-06 08:07:00 +0900
categories: [Data Engineering, Developer Tools]
tags: [lz4, data-compression, zstandard, latency, frame-format, performance-testing]
image:
  path: https://heracles-jo.github.io/assets/img/posts/lz4-compression-selection/cover.svg
  alt: "LZ4와 Zstd를 지연시간, 압축률, 프레임 호환성으로 비교하는 압축 선택 구조"
---

압축 알고리즘을 고르는 회의는 흔히 압축률 순위표로 시작한다. 저장 비용을 줄이는 작업이라면 자연스러운 출발이지만, 캐시 엔트리·데이터베이스 페이지·로그 레코드·네트워크 메시지처럼 읽고 쓰는 경로에 압축이 들어가면 질문이 달라진다. 절약한 바이트보다 압축과 해제에 쓴 CPU 시간이 더 비쌀 수 있고, 평균 처리량은 좋아도 작은 객체의 p99 지연시간이 악화될 수 있다. 프레임 옵션이나 사전이 맞지 않으면 압축률 문제가 아니라 복구 불가능한 호환성 문제가 된다.

[LZ4](https://github.com/lz4/lz4)는 이 지점에서 오래 살아남은 선택지다. 빠른 압축과 메모리 대역폭에 가까운 해제를 목표로 하며, 낮은 압축률을 감수하고 hot path의 CPU 시간을 줄인다. 2026년 11월 4일 공개된 `v1.11.0`은 `liblz4`의 프레임 API에 멀티스레드 압축을 넣고, 4~16KB 소블록과 사전 사용 성능을 개선했다. 이번 글의 핵심은 “LZ4가 Zstd보다 빠르다”는 단순 결론이 아니다. **어떤 데이터 경로에서 압축률보다 지연시간과 재현 가능한 프레임 계약이 더 중요한지**, 그리고 그 판단을 운영 지표로 어떻게 검증할지에 있다.

2026년 11월 6일 08시 17분 KST 전후 GitHub Trending daily에서 LZ4는 **16 stars today**로 표시됐다. GitHub API 기준 12,358 stars, 1,632 forks, 열린 issue·PR 13개였고 11월 6일 KST 아침까지 빌드와 CLI 관련 변경이 병합됐다. 라이브러리는 BSD 2-Clause, `lz4` CLI는 GPL-2.0-or-later로 구분된다. Trending 수치는 낮지만 새 메이저 업데이트, 10년 이상 유지된 포맷, 데이터 시스템 전반의 재사용성을 고려하면 단기 유행보다 장기 검색 가치가 큰 후보다. 이 실행에서는 Search Console·Analytics의 실제 검색어와 CTR에 접근하지 못했으므로 유입 데이터를 근거로 가장하지 않았다.

## 후보를 비교하면 새 에이전트 도구보다 데이터 경로의 오래된 병목이 남는다

오늘 daily·weekly 목록은 에이전트 스킬과 자동화 도구에 크게 치우쳤다. 최근 글의 저장소명뿐 아니라 독자가 해결하려는 문제를 대조하면 상당수는 이미 구축된 에이전트·브라우저·병렬 개발 클러스터와 경쟁한다. LZ4는 별 개수 신호는 작지만 **실시간 데이터 경로에서 압축을 언제 적용하고 언제 포기할 것인가**라는 독립적인 검색 의도가 분명하다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [lz4/lz4](https://github.com/lz4/lz4) | daily 16, 12,358 stars, `v1.11.0`, 당일 push | 압축률·지연시간·프레임 계약을 함께 판단하는 데이터 인프라 질문이 기존 글과 겹치지 않아 선택했다. |
| [D4Vinci/Scrapling](https://github.com/D4Vinci/Scrapling) | daily 1,661, 97,913 stars | stealth browser와 웹 수집 운영은 기존 Scrapling·Lightpanda 글의 검색 의도와 직접 경쟁한다. |
| [vercel-labs/agent-desktop](https://github.com/vercel-labs/agent-desktop) | daily 2,173, 16,775 stars | 접근성 트리 기반 데스크톱 자동화는 11월 3일 글에서 이미 중심 주제로 다뤘다. |
| [max-sixty/worktrunk](https://github.com/max-sixty/worktrunk) | daily 546·weekly 1,261, 11,491 stars | Git worktree 병렬 실행은 [Orca 병렬 코딩 에이전트](/posts/orca-parallel-ai-coding-agents/)와 중심 질문이 같다. |
| [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) | weekly 1,325, 40,357 stars | Wayland 데스크톱 운영은 [Omarchy 워크스테이션 표준화](/posts/github-trending-omarchy-opinionated-linux-workstation/)와 인접한다. |

LZ4는 새로운 범용 저장 포맷을 제안하는 프로젝트가 아니다. 오히려 이 오래된 성격이 선택 이유다. 성숙한 알고리즘도 CPU 세대, 컴파일러, 블록 크기, 체크섬, 스레드 수가 바뀌면 운영 결과가 달라진다. `v1.11.0`은 압축 선택이 한 번의 라이브러리 비교로 끝나지 않고 **workload와 버전별로 갱신되는 시스템 계약**임을 보여 준다.

## 블록은 빠르지만 스스로 복구 가능한 파일은 아니다

LZ4를 도입할 때 먼저 구분해야 할 것은 block format과 frame format이다. 블록 포맷은 LZ77 계열의 단순한 바이트 인코딩이다. 리터럴과 과거 64KB 안의 일치 구간을 token, 길이, offset으로 표현하며 별도의 entropy encoder를 두지 않는다. 구조가 단순한 만큼 빠르지만, 압축 블록 크기와 해제 결과의 상한 같은 메타데이터를 자체적으로 운반하지 않는다.

애플리케이션이 데이터베이스 페이지처럼 크기를 이미 알고 있다면 raw block API가 적합할 수 있다. 반대로 파일, 파이프, 길이가 긴 스트림을 다른 프로세스나 언어에서 읽어야 한다면 frame format이 필요하다. 프레임은 magic number, descriptor, 데이터 블록, end mark, 선택적 content checksum을 더한다. 블록 최대 크기는 64KB·256KB·1MB·4MB 중 하나이며, 독립 블록과 연결 블록도 선택할 수 있다.

![LZ4 블록과 프레임이 애플리케이션 메타데이터·체크섬·스토리지 경계와 결합되는 구조](https://heracles-jo.github.io/assets/img/posts/lz4-compression-selection/architecture.svg)

이 구분은 API 취향이 아니라 장애 복구 방식의 차이다.

- **raw block**은 헤더 비용이 작고 애플리케이션 포맷에 밀착할 수 있지만, 원본 크기·버전·사전 식별자·무결성 정보를 상위 계층이 책임져야 한다.
- **independent frame block**은 병렬 해제와 부분 처리에 유리하지만, 이전 블록을 사전처럼 활용하지 못해 압축률이 낮아질 수 있다.
- **linked frame block**은 앞선 최대 64KB를 참조해 소블록 압축률을 높이지만 순차 해제가 필요하고 임의 접근과 멀티스레드 해제에 불리하다.
- **content checksum**은 전체 순서와 해제 결과의 손상을 검출하지만, CPU와 메모리 대역폭을 추가로 사용한다. `v1.11.0` 릴리스 노트도 멀티스레드 압축의 상한 중 하나로 전체 입력에 대한 XXH32 체크섬을 지목한다.

따라서 “LZ4를 쓴다”는 설정만으로는 상호운용 계약이 완성되지 않는다. frame version, block independence, 최대 block size, checksum, content size, dictionary ID, concatenated frame 처리 방식을 함께 고정해야 한다. [XERJ 로컬 검색 엔진](/posts/xerj-agent-search-engine/)에서 snapshot과 index version이 복구 계약이었던 것처럼, 압축 포맷도 decoder가 실제로 재생할 수 있는 메타데이터까지 artifact로 봐야 한다.

## LZ4와 Zstd의 차이는 승패가 아니라 CPU를 어디에 쓸지다

공식 README의 단일 스레드 Silesia benchmark에서 LZ4 기본은 압축 계수 2.112, 압축 770MB/s, 해제 4,950MB/s로 제시된다. 같은 표의 Zstandard 1.5.7 level 1은 계수 2.896, 압축 510MB/s, 해제 1,570MB/s다. 이 숫자는 특정 CPU, 컴파일러, corpus의 프로젝트 제공 결과이며 일반적인 우승표가 아니다. 대신 선택 축을 선명하게 보여 준다. LZ4는 더 많은 바이트를 남기고 CPU 시간을 아끼며, Zstd는 더 많은 CPU를 써서 네트워크·스토리지 비용을 줄이는 쪽에 가깝다.

| 경로 | LZ4가 유리해질 가능성 | Zstd·다른 대안이 유리해질 가능성 |
|---|---|---|
| 메모리 캐시·페이지 | 해제가 매우 잦고 저장 수명이 짧음 | 메모리 절감이 지연시간보다 중요함 |
| 서비스 간 메시지 | CPU budget이 작고 payload가 중간 크기 | WAN 비용·대역폭 제한이 크고 batch 가능 |
| 로그 ingest | 쓰기 폭주를 CPU 병목 없이 흡수해야 함 | 장기 보관 비용과 전송량이 지배적 |
| 백업·아카이브 | 복구 속도가 최우선인 임시 snapshot | 압축 작업을 비동기로 처리하고 오래 보관 |
| 소블록 레코드 | 상태 재사용·사전으로 반복 prefix를 활용 | 학습된 dictionary와 높은 압축률이 비용 절감에 직접 연결 |

Snappy도 낮은 CPU 비용과 빠른 해제를 목표로 하므로 LZ4와 같은 후보군에 들어간다. 실제 선택에서는 언어별 구현 성숙도, 이미 사용 중인 파일 포맷, 하드웨어 가속, ecosystem compatibility가 알고리즘 미세 차이보다 중요할 수 있다. Parquet·Kafka·RocksDB·Redis 같은 상위 시스템이 제공하는 codec 옵션을 바꿀 때는 라이브러리 benchmark가 아니라 그 시스템의 block size, batching, compaction, replication 흐름으로 측정해야 한다.

[HTTP/3 전환 글](/posts/quiche-http3-rollout/)에서 UDP와 0-RTT 자체보다 실제 폴백·네트워크 조건이 중요했던 것처럼, 압축도 codec 단독 throughput보다 end-to-end 경로가 판단 단위다. 1GB 파일을 연속으로 압축하는 benchmark가 빠르더라도 서비스가 4KB 객체를 요청마다 처리한다면 allocator, context 초기화, checksum, syscall, queueing이 결과를 뒤집을 수 있다.

## v1.11.0 멀티스레드는 처리량을 늘리지만 지연시간을 자동으로 줄이지 않는다

`v1.11.0`의 가장 큰 변화는 `LZ4F_preferences_t.nbWorkers`로 `liblz4` frame compression에 worker를 지정할 수 있다는 점이다. 프로젝트가 공개한 EPYC Genoa 결과에서는 202MB Silesia 입력의 level 1 압축이 단일 스레드 522MB/s에서 4 workers 1,921MB/s, 16 workers 7,550MB/s로 증가했다. worker 수나 scheduling이 달라도 같은 데이터와 압축 parameter라면 출력이 같도록 설계됐다는 점은 재현성에 유리하다.

하지만 이 결과를 API 응답 지연시간 개선으로 바로 번역하면 안 된다. worker pool에 넣을 job이 충분해야 하고, 작은 payload는 분할·큐잉 비용이 이득을 먹을 수 있다. checksum, 읽기와 쓰기, 메모리 복사가 직렬 구간으로 남으면 스레드를 늘려도 상한에 도달한다. CLI의 `--memory`가 중요한 이유도 여기에 있다. 동시 job 수는 처리량뿐 아니라 압축 버퍼와 peak RSS를 늘린다.

또한 동적 라이브러리는 멀티스레드가 기본 활성화되지만 static library는 `-pthread` 의존성을 피하기 위해 기본 single-thread다. `nbWorkers`를 설정해도 빌드 형태에 따라 실제 병렬성이 다를 수 있다. 운영에서는 설정값보다 아래 항목을 읽어야 한다.

1. 실제 활성 worker 수와 queue depth
2. payload 크기별 compression p50·p95·p99
3. wall time과 CPU time, context switch
4. peak RSS와 memory budget 초과 횟수
5. checksum on/off에 따른 처리량과 손상 검출 범위
6. single-thread fallback이 발생한 build·platform

[TileLang 커널 DSL 검증](/posts/tilelang-gpu-kernel-dsl-validation/)에서 최고 benchmark보다 실제 shape 분포와 cold path를 측정했듯, LZ4도 큰 corpus 평균값보다 서비스 객체 크기 분포와 concurrency를 고정해야 한다.

## 소블록과 사전은 압축 알고리즘보다 데이터 모델에 민감하다

데이터베이스 페이지, cache entry, 로그 레코드는 수 KB 단위인 경우가 많다. 작은 입력은 압축할 중복이 적고 context 초기화 비용의 비중이 커진다. `v1.11.0`은 상태와 frame context 재사용, dictionary 경로를 최적화했고, 공식 릴리스 노트는 4KB block에서 재사용 state의 압축 속도와 dictionary 기반 해제가 크게 개선됐다고 보고한다. 다만 개선 폭은 block size와 compiler에 따라 달라지고 1KB dictionary 압축은 오히려 일부 조건에서 느려질 수 있었다.

여기서 사전은 단순한 tuning 파일이 아니다. encoder와 decoder가 정확히 같은 사전을 사용해야 하며, frame의 Dict-ID는 어떤 사전을 선택할지 돕는 식별자일 뿐 사전 내용 자체를 검증하지 않는다. 운영 계약에는 dictionary binary hash, 생성 데이터 범위, version, 배포 시점, rollback 가능 decoder를 포함해야 한다. 사전을 교체하면서 producer만 먼저 배포하면 정상적인 압축 데이터가 consumer에게 장애 입력이 된다.

데이터 대표성도 중요하다. 공통 JSON key, 로그 prefix, schema가 반복되는 소블록은 사전 효과가 크지만, 암호화되었거나 이미 압축된 이미지·영상·무작위 ID 중심 데이터는 거의 줄지 않는다. LZ4 block format은 비압축성 입력을 약 0.4% 팽창시킬 수 있고, frame은 압축 결과가 원본보다 불리한 block을 uncompressed로 저장할 수 있다. 압축률 평균만 보면 이런 객체별 손익과 CPU 낭비가 가려진다.

## 안전한 decoder와 checksum은 서로 대체하지 않는다

압축 데이터는 종종 외부 입력, 오래된 파일, 네트워크 전송, 손상 가능한 snapshot에서 들어온다. block format 문서는 길이 overflow, 입력·출력 buffer 경계, 유효하지 않은 offset 0, overlap match를 안전하게 처리하고 fuzzing과 sanitizer로 decoder를 검증하라고 권고한다. checksum이 맞지 않는 데이터를 거부하는 것과, 악의적으로 조작된 길이·offset을 메모리 손상 없이 거부하는 것은 다른 방어선이다.

`v1.11.0`은 잘못된 인자, `NULL`, 극단적인 parameter의 crash·overflow를 다수 수정했고 streaming ring buffer와 partial consumption의 드문 데이터 손상 사례도 고쳤다. `LZ4_decompress_safe()`는 malformed input, destination 부족, dictionary 누락을 구분하는 오류 코드를 제공한다. 이 변화는 “성숙한 라이브러리라 검증이 끝났다”가 아니라, 규모가 커질수록 드문 경계 조건도 결국 production에서 발생한다는 신호다.

라이브러리 업데이트 게이트에는 정상 압축·해제만 넣지 말아야 한다. truncated frame, concatenated frame, 잘못된 block size, dictionary mismatch, checksum corruption, output buffer 부족, process 중단 후 부분 파일, 구버전 producer fixture를 함께 재생한다. 파일을 덮어쓰거나 `--rm`을 쓰는 CLI 경로라면 입력과 출력이 같은 경우, write failure, source가 처리 중 변경된 경우도 테스트해야 한다.

## PoC는 압축률 하나가 아니라 비용 이동을 측정해야 한다

![LZ4·Zstd·무압축 경로를 workload별로 승인하는 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/lz4-compression-selection/decision.svg)

압축 PoC는 실제 데이터와 실제 읽기·쓰기 비율을 가져와야 한다. 최소 세 경로, 즉 무압축·LZ4·Zstd 또는 현재 codec을 같은 harness에서 비교한다. 데이터셋은 평균 객체만 뽑지 말고 크기, entropy, 반복 prefix, 이미 압축된 비율, 민감도, 보존 기간별로 층화한다.

| 검증 영역 | 측정할 값 | 중단 조건 예시 |
|---|---|---|
| 사용자 지연 | 요청 전체 p50·p95·p99, 압축·해제 비중 | 저장량은 줄었지만 hot read p99가 악화됨 |
| 자원 비용 | CPU time, cycles/byte, peak RSS, worker queue | 절감한 네트워크·스토리지보다 CPU·메모리 비용이 큼 |
| 압축 효과 | 객체 크기 구간별 ratio, 팽창 비율 | 소블록 다수가 줄지 않거나 이미 압축된 데이터에 CPU 낭비 |
| 처리량 | producer·consumer rate, backpressure, saturation | codec이 ingest 또는 restore의 새 병목이 됨 |
| 호환성 | 언어·버전·build별 fixture round trip | static·dynamic build나 구버전 decoder에서 동작이 달라짐 |
| 무결성 | checksum, truncation, corruption, partial write | 손상 데이터가 조용히 통과하거나 복구 원인을 구분 못함 |
| 사전 운영 | dictionary hit, hash·version, mixed rollout | producer·consumer 사전 불일치 시 안전한 rollback 불가 |
| 복구 | snapshot restore time, random/partial read | 저장은 줄지만 장애 복구 RTO를 넘김 |

판단은 workload별로 나눠도 된다. hot cache에는 LZ4, 서비스 간 WAN 전송에는 Zstd, 작은 암호문에는 무압축을 쓰는 혼합 정책이 단일 codec 표준보다 합리적일 수 있다. 다만 codec을 객체마다 자동 선택하면 헤더, 관측성, decoder 분기, 테스트 matrix가 늘어난다. 절감률이 작은데 정책 복잡도만 커지면 운영 비용이 이득을 상쇄한다.

[TurboVec 로컬 벡터 인덱스](/posts/github-trending-turbovec-local-vector-index/)에서 압축률이 recall·필터·복구 비용과 함께 평가돼야 했던 것처럼, 일반 데이터 압축도 저장 바이트만 최적화하면 안 된다. 압축은 비용을 없애는 기술이 아니라 **스토리지와 네트워크 비용을 CPU·메모리·호환성 책임으로 이동시키는 기술**이다.

## 선택 기준은 “더 많이 줄이는가”보다 “어느 경로를 지키는가”다

LZ4가 잘 맞는 곳은 읽기·쓰기 빈도가 높고, CPU 지연시간이 비용의 중심이며, 압축률이 조금 낮아도 전체 시스템의 tail latency와 복구 속도를 지킬 수 있는 경로다. `v1.11.0`의 멀티스레드 frame 압축과 소블록·사전 개선은 이 영역을 넓히지만, worker와 checksum, memory budget, build 방식까지 측정해야 실제 이득이 된다.

Zstd는 네트워크와 장기 저장 비용이 더 중요하거나, 비동기 batch로 압축 CPU를 흡수할 수 있을 때 강하다. 이미 압축된 데이터, 매우 작은 무작위 payload, decoder 생태계가 불명확한 경로에서는 무압축이 더 나은 선택일 수도 있다. 알고리즘 이름보다 먼저 데이터 수명주기와 병목 위치를 정해야 하는 이유다.

최종 결정은 세 질문으로 줄일 수 있다. **압축 해제가 hot path의 p99를 침범하지 않는가. 프레임·사전·checksum·버전 계약을 모든 producer와 consumer가 재현할 수 있는가. 절약한 바이트의 실제 비용이 추가 CPU·메모리·복구 복잡도보다 큰가.** 이 세 가지를 실제 workload로 증명할 수 있다면 LZ4는 단순히 빠른 codec이 아니라 데이터 경로의 예측 가능성을 지키는 운영 선택이 된다.

> 1차 자료: [lz4/lz4 저장소와 README](https://github.com/lz4/lz4), [v1.11.0 릴리스](https://github.com/lz4/lz4/releases/tag/v1.11.0), [LZ4 Frame Format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md), [LZ4 Block Format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Block_format.md), [LZ4 API header](https://github.com/lz4/lz4/blob/dev/lib/lz4.h), [LZ4 Frame API](https://github.com/lz4/lz4/blob/dev/lib/lz4frame.h), [LICENSE](https://github.com/lz4/lz4/blob/dev/LICENSE), [SECURITY.md](https://github.com/lz4/lz4/blob/dev/SECURITY.md), [최근 commits](https://github.com/lz4/lz4/commits/dev/), [공개 issues와 pull requests](https://github.com/lz4/lz4/issues). Trending·저장소 수치는 2026년 11월 6일 08시 17분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
