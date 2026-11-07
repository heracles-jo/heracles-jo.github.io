---
title: "Prometheus 3.16 업그레이드: 쿼리 비용 제한·TSDB 복구 검증"
description: "Prometheus 3.16의 query cost 제한과 TSDB·native histogram 수정 사항을 바탕으로 대시보드·룰 회귀, 데이터 복구, 단계적 업그레이드 기준을 정리한다."
author: heracles-jo
date: 2026-11-07 08:45:00 +0900
categories: [Cloud, Observability]
tags: [prometheus, promql, observability, tsdb, query-cost, upgrade]
image:
  path: https://heracles-jo.github.io/assets/img/posts/prometheus-316-query-cost-upgrade/cover.svg
  alt: "Prometheus 3.16 업그레이드에서 쿼리 비용, TSDB 복구, 히스토그램 호환성을 검증하는 구조"
---

Prometheus 장애는 수집 프로세스가 죽을 때만 발생하지 않는다. 대시보드 하나가 넓은 정규식과 긴 range를 조합해 수억 개 sample을 읽고, 같은 시각 recording rule과 알림 평가가 겹치면 서버는 살아 있어도 관측 기능을 잃는다. 반대로 무거운 쿼리를 일괄 차단하면 핵심 알림이 실패하거나 장애 분석에 필요한 장기 범위 질의가 사라진다. 업그레이드의 기준은 새 기능 수가 아니라 **관측 시스템이 자기 부하를 통제하면서도 필요한 질문에는 답할 수 있는가**다.

[Prometheus](https://github.com/prometheus/prometheus) `v3.16.0`은 2026년 11월 5일 공개됐다. 이번 버전은 실험적 `query-cost` 기능으로 실행 전 비용 추정과 실행 중 한도를 제공하고, PromQL·remote write·OTLP·native histogram·WAL/TSDB 복구 경계의 수정 사항을 포함한다. 특히 out-of-order sample 손실, restart 후 chunk 누락, compaction race처럼 평상시에는 보이지 않다가 장애 복구 때 드러나는 수정이 많다. 따라서 이 버전은 “새 PromQL 함수를 써 보기 위한 업데이트”보다 **쿼리 예산과 데이터 보존 계약을 다시 검증하는 운영 업데이트**로 보는 편이 정확하다.

2026년 11월 7일 08시 56분 KST 전후 GitHub Trending daily에서 Prometheus는 **140 stars today**로 표시됐다. 같은 시점 GitHub API에는 약 67.1k stars, 10.9k forks, 열린 issue·PR 약 1.1k개, 11월 7일 KST 새벽까지의 commit 활동이 확인됐다. 저장소는 Apache-2.0 라이선스를 사용한다. 이 수치는 공개 페이지 확인 시점의 스냅샷이며 순위 자체를 도입 근거로 사용하지 않았다. 이번 실행에서는 Search Console·Analytics의 실제 검색어, 노출, CTR 데이터에 접근하지 못했으므로 유입 성과를 확인했다고 가정하지 않았다.

## 후보 비교: 새 도구보다 이미 운영 중인 관측 계층의 변경이 더 오래 남는다

오늘 daily·weekly 후보에는 대형 프레임워크와 에이전트 스킬 저장소가 함께 올랐다. 최근 글의 저장소명만이 아니라 해결하려는 질문까지 비교하면 Google Skills는 [Android Skills 검증 글](/posts/android-skills-agent-workflow-validation/)과, Zed의 에이전트 기능은 다수의 AI 코딩 워크플로 글과 인접했다. Prometheus는 기존 PostHog 글의 제품 분석 관측성과 달리 **인프라 시계열 엔진의 쿼리 자원 통제와 복구**라는 독립적인 검색 의도가 있다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [prometheus/prometheus](https://github.com/prometheus/prometheus) | daily 140, `v3.16.0`, 당일 commit | 쿼리 폭주 방지, 룰 회귀, TSDB 복구라는 운영 질문이 명확해 선택했다. |
| [zed-industries/zed](https://github.com/zed-industries/zed) | daily 292, `v1.27.0` | 고성능 편집기보다 AI commit·agent panel 변경 비중이 커 기존 AI 개발 도구 클러스터와 경쟁한다. |
| [google/skills](https://github.com/google/skills) | daily 532, 약 22.8k stars | 공식 스킬 배포·검증은 Android Skills 및 에이전트 지침 표준화 글과 검색 의도가 겹친다. |
| [mpv-player/mpv](https://github.com/mpv-player/mpv) | daily 36, `v0.42.0` | HTTP/3·HDR·disc 재생 변경은 깊이 있지만 현재 핵심 클러스터와의 내부 연결성이 약하다. |
| [rails/rails](https://github.com/rails/rails) | daily 152, `8.1.4.1` | 보안 패치·업그레이드 의도는 유효하나 릴리스 단독보다 앱별 migration 조건에 더 의존한다. |

Prometheus는 화려한 신생 프로젝트가 아니다. 그러나 Kubernetes, VM, 데이터베이스, 네트워크, 애플리케이션의 공통 진단 계층이므로 작은 회귀도 여러 팀의 대응 능력에 동시에 영향을 준다. [Cilium eBPF 전환](/posts/cilium-ebpf-networking-migration/)에서 데이터패스 변경을 Hubble·drop metric·rollback과 함께 검증했듯, 관측 엔진 자체도 “대시보드가 열린다”가 아니라 수집·저장·질의·룰·remote 경로를 분리해 시험해야 한다.

## query-cost는 견적 API와 실행 중 차단을 구분해야 한다

`--enable-feature=query-cost`를 켜면 `/api/v1/query_cost`와 `/api/v1/query_range_cost`가 실행 전 예상 series 수와 sample read를 반환한다. instant·range query에 `cost=true`를 추가하면 예상값과 실제값도 함께 볼 수 있다. 하지만 공식 문서는 추정치가 index entry 열거와 제한된 chunk sampling을 사용하므로 실제 비용보다 크거나 작을 수 있다고 명시한다. 이 추정치는 질의를 거부하는 기준이 아니라 dashboard·API client가 위험한 요청을 사전에 설명하거나 범위를 줄이는 신호다.

실제 강제력은 설정의 `global` 아래에 두는 `query_max_series`, `query_max_samples_read`, `query_max_duration`에서 나온다. Prometheus는 실행 중 실제로 읽은 series·sample이 한도를 넘으면 질의를 중단한다. 문제는 이 한도가 UI 요청에만 적용되지 않는다는 점이다. recording rule과 alerting rule도 같은 엔진을 사용하므로, 임계치를 너무 낮게 잡으면 사용자의 탐색 쿼리를 막는 데 성공하면서 핵심 알림 평가도 실패할 수 있다.

![Prometheus query-cost 추정·실행·룰 평가의 공통 자원 경계](https://heracles-jo.github.io/assets/img/posts/prometheus-316-query-cost-upgrade/architecture.svg)

도입 순서는 차단보다 관찰이 먼저여야 한다.

1. staging 또는 read replica에서 기능을 켜고 주요 dashboard·rule의 예상/실제 비용을 수집한다.
2. 업무 시간, 장애 조사, 장기 report처럼 query class를 나눠 p50·p95·최댓값을 구한다.
3. client별로 더 낮은 `max_series`, `max_samples_read`, `max_query_duration`을 사용해 탐색 도구의 실수를 먼저 제한한다.
4. 전역 한도는 정상 workload의 상단보다 충분한 여유를 두되, 단일 질의가 서버 전체를 고갈시키기 전에는 멈추도록 정한다.
5. 한도 초과를 사용자 오류로만 보지 말고 dashboard 변수 폭증, label cardinality 증가, recording rule 부재를 찾는 운영 신호로 남긴다.

`query_max_duration`은 기능이 활성화됐을 때 rule query timeout에도 영향을 준다. 기존 `--query.timeout`만 모니터링했다면 같은 dashboard가 API와 rule에서 다른 결과를 낼 수 있다. 한도 변경은 reload 가능하지만, reload 성공 여부와 실제 feature 활성 상태를 `/api/v1/features`로 함께 확인해야 “설정 파일에는 있는데 동작하지 않는” 상태를 피할 수 있다.

## 비용 제한은 cardinality 문제를 치료하지 않는다

query-cost는 폭주 피해를 제한하지만 metric 설계를 고치지는 않는다. 사용자 ID, request ID, 원문 URL처럼 무한히 늘어나는 값을 label로 넣으면 index와 head memory가 이미 비싸다. recording rule 없이 매번 긴 range의 `rate()`와 다중 join을 계산하면 정상적인 query도 지속적으로 한도에 닿는다. 제한을 올리는 조치만 반복하면 서버 크기와 timeout만 커지고 원인은 남는다.

먼저 dashboard 변수를 bounded set으로 만들고, 정규식 matcher가 실제로 필요한지, 동일 계산을 recording rule로 축약할 수 있는지 본다. rule은 비용을 미리 지불해 새 series를 저장하는 선택이므로 무조건 정답도 아니다. 원본 cardinality, rule output 수, 평가 주기, retention을 함께 계산해야 한다. [PostHog 통합 관측성](/posts/posthog-unified-product-observability/)에서 event taxonomy와 masking 없이 도구만 합치면 데이터 늪이 된다고 본 것처럼, Prometheus도 query limit만 추가하면 비싼 metric 모델을 숨기는 임시 방어선이 된다.

운영 지표에는 최소한 query duration과 concurrency뿐 아니라 loaded series, samples read, peak samples, cancellation 원인, rule evaluation failure를 포함한다. `v3.16.0`은 subquery와 `@` modifier 관련 sample 통계 계산을 수정했으므로, 업그레이드 전후 비용 그래프가 바뀌었다고 즉시 workload 회귀로 단정하면 안 된다. 계측 의미 자체가 바뀐 항목을 release note와 대조해야 한다.

## TSDB 수정은 백업보다 재시작·compaction 재생 시험이 중요하다

이번 릴리스에는 정상 ingest benchmark로는 찾기 어려운 TSDB 수정이 집중돼 있다. out-of-order write-behind log가 필요한 series record를 WAL checkpoint가 제거해 sample이 손실되는 문제, WAL replay가 같은 series의 여러 reference를 병합할 때 mapped chunk가 누락되는 문제, query 시작 뒤 commit된 sample이 보이는 격리 문제, selected/stale-series compaction 중 드물게 sample이 사라질 수 있는 race가 수정됐다.

이 목록을 보고 “패치했으니 안전하다”고 끝내면 절반만 확인한 것이다. 실제 배포에서는 기존 버전이 만든 WAL·checkpoint·block을 새 버전이 읽고, restart와 compaction을 거친 뒤에도 같은 query 결과를 내는지 검증해야 한다. object storage에 block을 복사한 백업이 있어도 WAL replay와 head 복구가 실패하면 최근 데이터의 RPO가 길어진다. 반대로 disk snapshot만 믿으면 process가 쓰던 시점의 일관성 문제가 남을 수 있다.

canary에서는 production과 비슷한 out-of-order window, scrape churn, remote write queue, exemplar와 native histogram 비율을 재현한다. 강제 종료 뒤 재시작 시간, WAL replay 오류, unknown series warning, block count, head series, 동일 시각 query 결과를 비교한다. checksum만 비교하기 어려운 TSDB는 대표 PromQL fixture와 series cardinality·sample count·최신 timestamp를 함께 사용해야 한다.

[Supabase 셀프호스팅 운영](/posts/supabase-self-hosting-operations/)에서 백업 존재와 복원 성공을 구분했듯, Prometheus도 snapshot 파일이 있다는 사실보다 **정해진 RTO 안에 재기동하고 경보에 필요한 최근 구간을 재현하는가**가 기준이다.

## native histogram·OTLP 변경은 혼합 버전에서 가장 위험하다

`v3.16.0`은 native histogram의 비교·quantile·fraction, custom bucket, `+Inf` 경계, exemplar 처리와 OpenMetrics 2.0 parser에 여러 수정 사항을 포함한다. 일부 문제는 값이 완전히 사라지는 대신 조용히 잘못된 quantile이나 bucket count를 만들 수 있어 더 위험하다. latency SLO가 histogram에 의존한다면 binary가 기동되는지만 확인해서는 안 된다.

업그레이드 전후에 classic histogram과 native histogram을 동시에 노출하는 fixture를 두고 `histogram_quantile`, `histogram_fraction`, count·sum, recording rule 결과를 비교한다. OTLP receiver를 사용하는 경우 future timestamp exemplar, trace/span ID와 attribute 충돌, out-of-order exemplar가 어떤 counter와 drop 결과를 만드는지도 본다. remote write 대상이 native histogram 또는 Remote Write 2.0 metadata를 완전히 지원하지 않는다면 송신 성공률만 아니라 대상에서 다시 조회한 값의 의미를 비교해야 한다.

실험적 `st-storage`와 histogram start-timestamp encoding은 특히 주의가 필요하다. 공식 feature 문서는 일부 새 chunk encoding이 구버전에서 읽히지 않을 수 있고, 실험 중 포맷이 바뀌면 수동 block 삭제가 필요할 수 있다고 경고한다. 새 기능을 canary에 켠 상태로 block이 생성됐다면 단순 binary downgrade가 rollback이 아닐 수 있다. feature별로 **디스크 포맷 변경 여부, 구버전 reader 호환성, remote backend 지원, 되돌릴 때 삭제되는 데이터 범위**를 기록해야 한다.

## 보안 경계는 쿼리 엔드포인트와 설정 reload까지 포함한다

비용 추정 API는 실제 query를 실행하지 않지만 index와 chunk 일부를 읽어야 한다. 사용자에게 자유 PromQL을 허용하는 shared Prometheus에서는 예상 비용 조회 자체도 무제한 공개 서비스처럼 취급하면 안 된다. 인증·rate limit·tenant 경계를 reverse proxy나 상위 query frontend에서 적용하고, admin·reload endpoint는 별도로 제한해야 한다.

TLS가 활성화된 `web.config.file` 환경에서 `--web.external-url` 기본 scheme이 HTTPS로 바뀌는 것도 `v3.16.0`의 변경 사항이다. reverse proxy 뒤에서 명시적 external URL을 두지 않았다면 redirect, link, OAuth callback과 dashboard datasource가 달라지는지 확인한다. 설정 reload는 실패 후 원복한 경우 다시 reload되지 않던 문제도 수정됐으므로, 잘못된 config → 실패 → 수정된 config 순서를 자동 시험에 넣을 가치가 있다.

Prometheus의 보안 모델은 metric endpoint에 민감정보를 넣지 않는다는 전제에 크게 의존한다. label과 annotation에 고객 ID, 내부 경로, token fragment가 들어가면 query 권한이 곧 정보 조회 권한이 된다. [OpenBao 시크릿 관리 전환](/posts/openbao-secrets-management-migration/)에서 동적 자격증명도 감사와 복구 없이는 충분하지 않았듯, 관측 시스템도 TLS만 켜는 것보다 datasource 권한, API 노출, config 변경 감사, secret 분리를 함께 설계해야 한다.

## 단계적 업그레이드에서 확인할 중단 조건

![Prometheus 3.16 업그레이드의 query·storage·histogram·rollback 검증 게이트](https://heracles-jo.github.io/assets/img/posts/prometheus-316-query-cost-upgrade/checklist.svg)

한 번에 전체 replica를 바꾸기보다 동일 scrape target을 읽는 canary 또는 독립 shard에서 시작한다. HA pair라면 외부 label과 alert deduplication을 유지한 채 한 replica만 올려 query·rule 결과를 비교할 수 있다. 단, 두 replica가 동일 local TSDB directory를 공유하게 해서는 안 된다.

| 검증 영역 | 측정 항목 | 중단 조건 예시 |
|---|---|---|
| 수집 | target health, scrape duration·size, sample·exemplar drop | 동일 target의 성공률 또는 sample 수가 설명 없이 감소 |
| 쿼리 | p95·p99, series/sample cost, timeout·cancel | 핵심 dashboard·ad hoc 조사 쿼리가 예산 안에서 완료되지 않음 |
| 룰 | evaluation duration·failure, alert pending/firing | query limit 때문에 필수 recording·alert rule이 실패 |
| 저장 | WAL replay, head/block count, out-of-order 결과 | restart·compaction 후 fixture query나 최신 timestamp 불일치 |
| histogram | quantile·fraction·count·sum, remote 조회 | classic/native 또는 송신/수신 결과의 의미가 달라짐 |
| 자원 | RSS, CPU, disk IOPS, remote queue | query 보호가 ingest starvation이나 queue 적체를 유발 |
| rollback | 구버전 reader, feature flag, block format | binary downgrade 후 기존 block을 읽지 못하거나 데이터 삭제 필요 |

배포 승격은 “24시간 오류 없음” 같은 시간 조건만으로 정하지 않는다. 업무 시간 dashboard, rule evaluation cycle, compaction, restart, remote backend 지연, 장애 조사형 long-range query를 최소 한 번씩 통과해야 한다. query-cost 한도는 처음부터 최종값으로 고정하지 말고 관찰 → client별 soft ceiling → 전역 enforcement 순서로 좁혀야 한다.

Prometheus 3.16의 핵심 가치는 무거운 query를 무조건 막는 데 있지 않다. 어떤 질의가 series와 sample을 얼마나 소비하는지 드러내고, 관측 시스템이 자기 자신을 쓰러뜨리기 전에 실행 경계를 적용할 수 있게 된 점에 있다. 동시에 TSDB와 histogram 수정은 metric 값의 정확성과 복구 가능성이 성능만큼 중요한 운영 계약임을 상기시킨다.

업그레이드 판단은 세 질문으로 압축할 수 있다. **핵심 dashboard와 rule의 정상 비용 분포를 알고 있는가. restart·compaction·remote write 뒤에도 같은 시계열 의미를 재현할 수 있는가. 실험 기능이 만든 데이터 포맷까지 포함해 실제 rollback이 가능한가.** 이 세 항목을 canary와 fixture로 증명할 수 있을 때 `v3.16.0`은 단순 버전 상승이 아니라 관측 계층의 자원·정확성·복구 경계를 강화하는 업데이트가 된다.

> 1차 자료: [prometheus/prometheus 저장소와 README](https://github.com/prometheus/prometheus), [v3.16.0 릴리스](https://github.com/prometheus/prometheus/releases/tag/v3.16.0), [Feature flags와 query cost](https://github.com/prometheus/prometheus/blob/main/docs/feature_flags.md), [HTTP API](https://github.com/prometheus/prometheus/blob/main/docs/querying/api.md), [설정 문서](https://github.com/prometheus/prometheus/blob/main/docs/configuration/configuration.md), [스토리지 문서](https://github.com/prometheus/prometheus/blob/main/docs/storage.md), [보안 정책](https://github.com/prometheus/prometheus/blob/main/SECURITY.md), [Apache-2.0 LICENSE](https://github.com/prometheus/prometheus/blob/main/LICENSE), [최근 commits](https://github.com/prometheus/prometheus/commits/main/), [공개 issues와 pull requests](https://github.com/prometheus/prometheus/issues). Trending·저장소 수치는 2026년 11월 7일 08시 56분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이다.
