---
title: "C++ std::format 전환: {fmt} 호환성과 마이그레이션 기준"
description: "printf·iostream·{fmt}가 섞인 C++ 코드에서 std::format으로 옮길 범위를 정하고, 출력 호환성·런타임 문자열·성능 회귀를 검증하는 단계별 기준을 제시한다."
author: heracles-jo
date: 2026-09-12 08:45:00 +0900
categories: [Software Engineering, Developer Tools]
tags: [fmt, std-format, cpp, code-modernization, formatting, developer-tools]
image:
  path: https://heracles-jo.github.io/assets/img/posts/cpp-std-format-fmt-migration/cover.svg
  alt: "printf와 iostream에서 fmt를 거쳐 std::format으로 전환하는 C++ 포맷팅 마이그레이션"
---

C++ 코드베이스의 문자열 출력은 좀처럼 한 가지 방식으로 통일되지 않는다. 오래된 모듈에는 `printf`와 `snprintf`가 남아 있고, 객체 출력에는 `operator<<`와 `ostringstream`가 붙으며, 새 코드에서는 `{fmt}`나 `std::format`을 쓴다. 네 방식이 공존해도 빌드는 된다. 그러나 포맷 문자열 오류를 발견하는 시점, locale 처리, 사용자 정의 타입 확장, 버퍼 소유권, 예외 정책이 서로 달라지면서 로그 한 줄을 고치는 변경도 플랫폼별 회귀가 된다.

2026년 9월 12일 08시 55분 KST 전후 GitHub Trending daily에서 [fmtlib/fmt](https://github.com/fmtlib/fmt)는 **963 stars today**로 표시됐다. GitHub API 확인 시점에는 약 **25.7k stars**, **3.1k forks**, MIT 라이선스, 10개의 열린 이슈가 있었고 마지막 push는 9월 12일 KST 새벽이었다. 최신 정식 릴리스는 2026년 6월 16일의 `12.2.0`이다. 당일 관심만 높은 저장소가 아니라 2012년부터 이어진 기반 라이브러리가 다시 주목받은 사례다.

이 글은 `{fmt}` 사용법을 나열하지 않는다. 검색 의도는 더 좁다. **이미 `{fmt}`를 쓰는 조직이 `std::format`과 `std::print`로 언제, 어디까지 옮겨야 하며 무엇을 같다고 가정하면 안 되는가**를 다룬다. Search Console과 Analytics의 실제 검색어·노출 데이터에는 이번 실행 환경에서 접근할 수 없었으므로 트래픽 수치를 근거로 주제를 선택하지 않았다.

## 후보를 비교하니 새 도구보다 오래된 경계가 남았다

오늘 daily·weekly 후보 가운데 상당수는 최근 글의 검색 의도와 겹쳤다. 저장소 README, 라이선스, 최신 릴리스와 push, 공개 이슈·PR 활동을 확인하고 장기적으로 반복될 질문이 있는지 비교했다.

| 후보 | 확인 시점 신호 | 중복·검색 의도 판단 |
|---|---|---|
| [fmtlib/fmt](https://github.com/fmtlib/fmt) | daily 963 stars today, API 약 25.7k stars, MIT, 12.2.0 | 기존 C++ 기반 라이브러리 글은 스택 표준화가 중심이었다. 이번에는 `{fmt}`와 표준 포맷 API 사이의 실제 전환 계약을 다뤄 별도 의도가 선명하다. |
| [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) | daily 774, API 약 244.6k stars, MIT, v2026.9.11 | 메모리·스킬·도구를 가진 에이전트 런타임은 중요하지만 기존 에이전트 운영·스킬 보안 글과 겹친다. |
| [affaan-m/ECC](https://github.com/affaan-m/ECC) | daily 751, API 약 256.5k stars, MIT, v2.2.1 | 에이전트 하네스 최적화는 최근 후보 조사에서 여러 번 제외했고 Agent Skills 클러스터와 중심 논지가 같다. |
| [magnitudedev/magnitude](https://github.com/magnitudedev/magnitude) | daily 161, API 약 4.3k stars, Apache-2.0, 0.0.14 | 하드웨어 프로파일 기반 로컬 추론은 OMLX·AirLLM·MAX 글과 같은 도입 의도에 가깝다. |
| [averygan/reclip](https://github.com/averygan/reclip) | daily 88, API 약 9.2k stars, MIT, 정식 release 없음 | 셀프호스팅 다운로드 UI라는 별도 의도는 있으나 외부 서비스 약관·저작권 경계가 사용 환경마다 달라 기술 아키텍처만으로 답하기 어렵다. |

Weekly 상위의 Archify, OpenMAIC, Modern Go Guidelines, TimesFM, Omarchy도 이미 직접 다뤘다. Ponytail 역시 AI 코딩 에이전트 과잉 구현 글이 있다. 발행 연속성을 지키기 위해 비슷한 에이전트 저장소를 하나 더 요약하는 것보다, 장기간 유지되는 네이티브 코드에서 계속 반복되는 마이그레이션 문제를 좁게 푸는 편이 낫다.

## 문법이 닮았다고 백엔드가 교체 가능한 것은 아니다

`{fmt}`는 C++20 `std::format`과 C++23 `std::print`에 가까운 API와 중괄호 포맷 문법을 제공한다. 공식 문서는 C++20 포맷팅 라이브러리의 거의 전부를 구현한다고 설명하지만, namespace만 바꾸면 항상 같은 결과가 나온다고 약속하지는 않는다. 폭 계산과 Unicode 처리 같은 차이가 있고, `{fmt}`에는 ranges, color, OS 출력, format-string compilation 등 표준 API 밖의 기능도 있다.

여기에 배포 현실이 겹친다. 애플리케이션 소스가 C++20을 사용한다고 해서 모든 빌드 타깃의 표준 라이브러리가 필요한 `std::format` 구현을 같은 수준으로 제공하는 것은 아니다. 컴파일러 버전뿐 아니라 libstdc++, libc++, MSVC STL 버전과 링크 환경을 함께 봐야 한다. C++23의 `std::print`까지 쓰려면 기준선은 더 높아진다. 오래된 Linux 배포판, 사내 SDK, CUDA 툴체인, 임베디드 크로스 컴파일러가 하나라도 남아 있으면 `{fmt}`가 호환성 계층으로 계속 필요할 수 있다.

반대 방향의 비용도 있다. 모든 타깃이 충분히 새롭고 사용하는 기능이 표준 부분집합에 머문다면 외부 의존성을 유지할 이유가 줄어든다. 보안 패치와 패키지 업데이트, CMake export, 정적·동적 링크 정책을 관리할 대상이 하나 줄어든다. 판단 기준은 “표준이 더 좋다”가 아니라 **지원 플랫폼 행렬과 실제 사용 API의 교집합**이다.

![호출부와 포맷 백엔드를 어댑터로 분리하고 동일 corpus로 검증하는 전환 구조](https://heracles-jo.github.io/assets/img/posts/cpp-std-format-fmt-migration/architecture.svg)

[프로덕션 C++ 기반 라이브러리 스택](/posts/github-trending-cpp-foundation-libraries/)에서 Abseil·Catch2·yaml-cpp·Asio를 함께 다룰 때는 의존성 표준화와 ABI가 중심이었다. `{fmt}` 전환은 한 단계 더 미세하다. 문자열 출력은 로그, 오류 메시지, 파일 포맷, CLI 결과처럼 외부 관찰면에 닿는다. 라이브러리 링크가 성공해도 공백 하나, 소수점 자리 하나, 잘못된 UTF-8 처리 하나가 golden test나 운영 파서를 깨뜨릴 수 있다.

## 먼저 호출부에서 포맷 정책을 걷어낸다

대규모 치환을 시작하기 전에 프로젝트 내부에 얇은 경계를 두는 편이 안전하다. 예를 들어 `project::format`, `project::format_to`, `project::print`만 애플리케이션에 노출하고 구현부에서 `{fmt}` 또는 표준 라이브러리를 선택한다. 이 계층은 새 포맷 엔진을 발명하기 위한 wrapper가 아니다. 다음 정책을 한곳에 고정하기 위한 임시 이행 장치다.

- 컴파일 타임 포맷 문자열과 런타임 문자열을 API 수준에서 분리한다.
- locale을 기본으로 쓰지 않고 필요한 호출만 명시적으로 허용한다.
- 포맷 실패가 예외, 오류 코드, 프로세스 종료 중 무엇으로 이어지는지 정한다.
- 사용자 정의 타입은 공개 표현과 진단용 표현을 분리하고 민감 필드를 기본 출력에서 제외한다.
- 로그 sink가 문자열을 다시 파싱하지 않도록 구조화 필드를 별도 전달한다.

이 경계를 영구 추상화로 키우면 오히려 표준 API의 장점이 사라진다. 목표는 호출부를 프로젝트 고유 문법에 묶는 것이 아니라, 전환 기간에 백엔드 차이를 측정하고 제거 가능한 범위를 찾는 것이다. 표준 전환이 끝난 모듈은 직접 `std::format`을 쓰게 하거나, 어댑터를 최소 alias 수준으로 축소할 수 있다.

### 런타임 포맷 문자열은 별도 제품 기능이다

문자열 리터럴을 사용하는 일반 호출은 타입과 형식 지정자의 불일치를 컴파일 시점에 찾을 수 있다. 반면 번역 파일, 관리자 템플릿, 데이터베이스에서 읽은 포맷 문자열은 컴파일 타임 상수가 아니다. `{fmt}`에서는 `fmt::runtime` 또는 `vformat` 계열, 표준에서는 `std::vformat` 같은 명시적 동적 경로가 필요하다. C++26에는 `std::dynamic_format` 경로도 추가된다.

이 차이를 편의 wrapper로 숨기면 정적 검사가 적용된다고 착각하기 쉽다. 런타임 문자열은 허용되는 인자 이름과 형식 지정자를 schema로 검증하고, `format_error`를 호출 경계에서 처리해야 한다. 번역 한 줄의 중괄호 오류가 요청 처리 전체를 실패시키거나 로깅 중 예외가 다시 장애 경로를 가리는 상황을 막아야 한다. 외부 사용자가 임의 format string과 큰 width·precision 값을 보낼 수 있다면 입력 길이와 출력 크기도 제한한다.

`printf` 자동 변환도 같은 이유로 일괄 정규식 치환에 맡기기 어렵다. `%n`, positional argument, `*` width·precision, 길이 modifier, locale 의존 출력은 타입 정보와 호출 문맥을 함께 봐야 한다. `{fmt}` README는 clang-tidy 18의 `modernize-use-std-print`가 설정에 따라 `printf`·`fprintf`를 `fmt::print` 또는 기본값인 `std::print`로 변환할 수 있다고 안내한다. 자동 수정은 후보를 만드는 데 쓰고, 컴파일과 출력 corpus가 승인하는 변경만 남겨야 한다.

## 같은 입력이 같은 바이트가 되는지 확인한다

마이그레이션 테스트는 “샘플 Hello World가 같다”로 끝나지 않는다. 먼저 실제 코드에서 포맷 문자열과 인자 타입을 수집한다. 개인정보가 있는 운영 로그를 그대로 반출하지 말고, 형식별로 합성한 corpus를 만든다. 정수 경계값, NaN과 infinity, 음수 0, 큰·작은 부동소수점, 날짜 경계, 빈 range, Unicode, 잘못된 입력을 포함한다.

검증 항목은 세 층으로 나누면 원인을 찾기 쉽다.

1. **컴파일 계약**: 잘못된 지정자가 실제로 빌드를 실패시키는지, custom formatter의 `parse`가 constexpr 요구를 만족하는지, 필요한 header를 직접 include하는지 본다.
2. **출력 계약**: `{fmt}`와 `std` 결과를 byte 단위로 비교하되, 의도한 차이는 플랫폼별 승인 목록에 이유와 만료 조건을 남긴다. locale, timezone, 콘솔 encoding은 실행 환경을 고정한다.
3. **운영 계약**: 예외 발생률, 로그 손실, 할당량, 처리량, p95/p99 지연, 빌드 시간, 바이너리 크기를 기준선과 비교한다.

`{fmt}` 12.2.0 변경 로그만 봐도 C11 API 추가, C++20 module용 CMake target, floating-point 경로 최적화와 함께 `fmt/core.h`의 include 동작 변경, `std::byte` formatter 이동, compile-time 검사와 printf out-of-bounds read 수정이 들어 있다. minor update를 단순 기능 추가로 보면 안 된다. 전이 include에 기대던 코드와 출력 경계가 바뀔 수 있으므로 버전을 고정하고 변경 로그 기반 회귀 corpus를 돌려야 한다.

[Magic Trace로 프로덕션 병목을 찾는 방법](/posts/github-trending-production-profiling-magic-trace/)에서 평균값 대신 실제 실행 경로를 보자고 했던 이유도 여기 적용된다. 공식 사이트의 성능 수치는 가능성을 보여 줄 뿐, 우리 템플릿 분포와 allocator, compiler flag, sink에서는 결론이 아니다. 숫자와 로그가 대부분인지, 날짜와 ranges가 많은지에 따라 결과가 달라진다. microbenchmark 외에 실제 요청 또는 배치 workload를 재생해야 한다.

## 세 가지 전환 경로를 섞지 않는다

![컴파일러 지원과 fmt 확장 사용 여부로 백엔드를 선택하는 의사결정 트리](https://heracles-jo.github.io/assets/img/posts/cpp-std-format-fmt-migration/decision.svg)

### 오래된 타깃이 남아 있다면 `{fmt}`를 기준 구현으로 둔다

C++11/14/17 타깃이나 불완전한 표준 라이브러리를 지원해야 하면 `{fmt}`를 유지하는 편이 단순하다. 대신 버전과 빌드 방식을 고정하고, header-only와 compiled library 중 하나를 팀 기준으로 정한다. 여러 의존성이 서로 다른 `{fmt}` 버전을 끌어오거나 `FMT_HEADER_ONLY`·visibility·컴파일 옵션이 섞이면 ODR와 바이너리 경계 문제가 생길 수 있다. 패키지 그래프에서 중복 버전을 탐지하고 최종 산출물의 라이선스·SBOM에도 기록한다.

### 혼합 환경에서는 표준 부분집합만 새 코드 규칙으로 삼는다

새 플랫폼은 `std::format`, 오래된 플랫폼은 `{fmt}`를 쓰되 호출부는 둘의 공통 부분집합에 제한할 수 있다. ranges, color, `fmt::memory_buffer`, `FMT_COMPILE` 같은 확장은 별도 adapter 뒤에 격리한다. 이 방식은 코드가 두 백엔드에서 실제로 컴파일되는 CI가 있을 때만 유효하다. 전처리기 분기만 만들고 한쪽 job을 돌리지 않으면 호환성 주장은 곧 낡는다.

[Modern Go Guidelines를 이용한 코드 현대화](/posts/modern-go-guidelines-ai-code-modernization/)에서도 언어 버전을 먼저 탐지한 뒤 자동 수정과 의미 검증을 분리했다. C++은 compiler와 standard library 조합이 더 다양하므로 “C++20 사용” 한 줄보다 feature-test macro와 실제 compile probe가 중요하다.

### 표준으로 완전히 옮길 때는 의존성 제거를 마지막에 한다

모든 지원 타깃이 필요한 기능을 갖췄고 fmt 전용 API를 제거했다면 backend를 `std`로 바꾼다. 그 뒤 한 릴리스 이상 dual-backend test를 유지하고, 운영 지표가 안정된 다음 `{fmt}` 패키지를 제거한다. 먼저 의존성을 지우고 컴파일 오류를 따라가며 수정하면 어떤 출력 차이가 라이브러리 변경 때문인지 대규모 코드 수정 때문인지 분리하기 어렵다.

C++ 빌드 파이프라인 자체가 느리다면 포맷 호출의 런타임만 보지 말아야 한다. include 무게, template instantiation, precompiled header, module 사용 여부가 개발자 피드백 시간을 바꾼다. [SWC가 Rust 웹 툴체인에서 보여 준 전환 비용](/posts/github-trending-swc-rust-web-toolchain/)처럼 런타임 성능과 빌드·플러그인 호환성은 별도 축이다.

## PoC에서 답해야 할 질문

대표 서비스 하나를 골라 2주 안에 결론을 낼 수 있다. 첫 주에는 호출 유형을 분류하고 adapter와 dual-backend CI를 만든다. 둘째 주에는 실제 workload를 재생하고 출력 차이를 triage한다. 합격 기준은 팀 환경에 맞게 수치화하되 최소한 다음 질문에는 답해야 한다.

샘플은 호출 횟수보다 소비자 기준으로 고른다. 사람이 읽는 진단 로그, 모니터링 규칙이 파싱하는 로그, 셸 스크립트가 읽는 CLI 출력, 다른 시스템에 전달하는 파일은 같은 문자열처럼 보여도 변경 허용 범위가 다르다. 관측용 로그는 표현을 개선할 수 있지만, 자동화가 읽는 출력은 사실상 직렬화 프로토콜이다. 후자는 포맷 엔진을 바꾸기 전에 구조화 형식과 명시적 버전으로 옮기는 편이 안전하다. 테스트 실패를 공백 차이라고 무시하지 말고 누가 그 바이트를 소비하는지 먼저 확인해야 한다.

- 지원하는 compiler·standard library·OS 조합마다 `format`, `print`, chrono, ranges가 실제로 컴파일되는가?
- 전체 호출 중 리터럴 format string과 runtime string의 비율은 얼마이며, 후자의 schema와 예외 처리는 어디에 있는가?
- golden corpus의 불일치가 0인가? 아니라면 각 차이는 의도됐고 소비자와 호환되는가?
- 로그·CLI·파일 출력 중 byte 안정성이 API 계약인 경로는 무엇인가?
- custom formatter가 비밀값을 노출하거나 재귀·과도한 할당으로 장애를 만들 가능성은 없는가?
- 변경 전후 빌드 시간, 바이너리 크기, CPU, allocation, p95/p99 지연이 허용 범위 안인가?
- rollback이 namespace 대량 재치환이 아니라 backend flag 또는 한 커밋 되돌리기로 가능한가?

여기서 합격하지 못하면 표준 전환을 미루는 것이 실패는 아니다. `{fmt}`는 활발히 유지되는 독립 라이브러리이고 표준보다 넓은 플랫폼과 기능을 제공한다. 반대로 컴파일러 기준선이 이미 올라갔는데도 관성 때문에 의존성을 유지하는 것 역시 비용이다.

## 표준화가 끝나는 지점

좋은 마이그레이션의 결과는 모든 파일에 `std::`가 보이는 상태가 아니다. 팀이 포맷 문자열을 언제 정적으로 검사하고, 동적 문자열을 어디서 거부하며, 어떤 출력 바이트를 호환성 계약으로 보는지 설명할 수 있는 상태다. `{fmt}`와 `std::format`은 문법의 상당 부분을 공유하지만 릴리스 주기, 확장 범위, 지원 플랫폼, 구현 세부는 다르다.

따라서 순서는 단순하다. 실제 호출과 타깃 행렬을 조사하고, 표준 부분집합과 fmt 확장을 나누고, 얇은 전환 경계에서 두 backend를 같은 corpus로 검증한다. 출력과 운영 지표가 맞은 뒤에 namespace와 의존성을 정리한다. 이 순서를 지키면 포맷팅 현대화는 취향 논쟁이 아니라 측정 가능한 호환성 작업이 된다.

> 1차 자료: [{fmt} 저장소와 README](https://github.com/fmtlib/fmt), [{fmt} 최신 API 문서](https://fmt.dev/latest/api/), [format string 문법](https://fmt.dev/latest/syntax/), [{fmt} 12.2.0 릴리스](https://github.com/fmtlib/fmt/releases/tag/12.2.0), [변경 로그](https://github.com/fmtlib/fmt/blob/main/ChangeLog.md), [`std::format` 참고 문서](https://en.cppreference.com/w/cpp/utility/format/format), [`std::print` 참고 문서](https://en.cppreference.com/w/cpp/io/print). Trending와 GitHub 저장소 수치는 2026년 9월 12일 08시 55분 KST 전후 공개 페이지·API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
