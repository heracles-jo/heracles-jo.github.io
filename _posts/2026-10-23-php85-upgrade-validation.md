---
title: "PHP 8.5 업그레이드: 비호환 변경·확장 모듈 검증 기준"
description: "PHP 8.5.12 보안 패치와 8.4→8.5 비호환 변경을 바탕으로 Composer 의존성, 확장 모듈, FPM·OPcache, 카나리 배포를 검증하는 절차를 정리한다."
author: heracles-jo
date: 2026-10-23 08:20:00 +0900
categories: [Platform Engineering, Developer Tools]
tags: [php-8-5, php-upgrade, composer, php-fpm, opcache, runtime-migration]
image:
  path: https://heracles-jo.github.io/assets/img/posts/php85-upgrade-validation/cover.svg
  alt: "PHP 8.5 업그레이드에서 애플리케이션, 확장 모듈, FPM과 OPcache를 단계별로 검증하는 구조"
---

PHP 마이너 버전 업그레이드는 문법 몇 개를 바꾸는 작업처럼 보이기 쉽다. 실제 장애는 더 아래에서 생긴다. 애플리케이션 테스트는 통과했지만 오래된 PECL 확장이 로드되지 않거나, 경고가 대량으로 늘어 로그와 APM 비용이 급증하거나, OPcache 구성 방식이 바뀌어 컨테이너가 시작할 때마다 경고를 쏟거나, PDO의 예외 종류가 달라져 재시도 분기가 작동하지 않을 수 있다.

이번에 볼 대상은 [php/php-src](https://github.com/php/php-src)와 PHP 8.5다. 8.5는 URI API, 파이프 연산자, clone 시 속성 변경, `#[\NoDiscard]`, persistent cURL share handle 같은 기능을 추가했지만, 운영자가 먼저 읽어야 할 문서는 신기능 목록보다 migration guide와 최신 보안 릴리스다. **업그레이드의 성공 기준은 새 문법을 쓸 수 있는가가 아니라, 현재 트래픽·확장 모듈·관측 체계가 같은 의미로 동작하고 긴급 패치를 반복 가능하게 적용할 수 있는가**다.

2026년 10월 23일 08시 29분 KST 전후 GitHub Trending daily에서 php-src는 `423 stars today`로 표시됐다. GitHub API 기준 41,133 stars, 8,305 forks, BSD-3-Clause 라이선스였고 최신 릴리스는 10월 21일 공개된 `PHP 8.5.12`였다. 이 릴리스는 인증되지 않은 원격 코드 실행으로 이어질 수 있는 두 건의 치명적 취약점(CVE-2026-109618, CVE-2026-109619)을 수정하며, 공식 공지는 완전한 완화책이 없어 업데이트가 안전한 선택이라고 명시한다. 수치와 저장소 상태는 확인 시점의 공개 스냅샷이다. 이번 실행 환경에서는 Search Console이나 Analytics의 검색어·노출 데이터에 접근하지 않았다.

## 후보 비교에서 남은 검색 의도는 런타임 업그레이드였다

오늘 후보 네 개를 기존 글의 저장소명뿐 아니라 중심 질문과 비교했다. AI 에이전트 도구의 상승 신호는 강했지만 최근 콘텐츠와 검색 의도가 반복됐다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [php/php-src](https://github.com/php/php-src) | daily 423, 41,133 stars, BSD-3-Clause, 8.5.12 | 보안 패치와 언어·확장·SAPI 변경을 함께 다루는 **PHP 런타임 전환 검증**은 기존 글에 없는 독립 의도다. |
| [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) | daily 303, 31,564 stars, Apache-2.0, 정식 tag 없음 | 지식 노동 플러그인의 커넥터 권한은 중요하지만 Cursor Plugins·Android Skills·에이전트 스킬 운영 글과 인접한다. |
| [Graphify](https://github.com/Graphify-Labs/graphify) | daily 1,407, 132,906 stars, Apache-2.0, v0.9.94 | 코드 지식 그래프는 codebase-memory·XERJ 검색 계층에서 이미 다뤘고 최근 후보 비교에서도 중복으로 제외했다. |
| [FastAPI](https://github.com/fastapi/fastapi) | daily 96, 103,713 stars, MIT, 0.161.1 | 프로덕션 Python API는 장기 가치가 높지만 오늘 신호만으로는 배포·의존성·관측성 중 하나의 좁은 문제를 고르기 어렵다. |

PHP 8.5는 2025년 11월 20일 처음 공개됐고 공식 지원 표상 2027년 12월 31일까지 active support, 2029년 12월 31일까지 security support가 예정돼 있다. 반면 8.2는 2026년 12월 31일에 security support가 끝난다. 지금 8.2를 운영하는 조직이라면 “언젠가 8.5로 가자”가 아니라 지원 종료와 긴급 보안 패치를 함께 고려한 전환 계획이 필요하다. 다만 8.2에서 8.5로 한 번에 건너뛰면 8.3·8.4·8.5의 deprecation과 비호환 변경을 모두 합쳐 검증해야 한다.

## 업그레이드 범위는 코드보다 실행 그래프가 넓다

PHP 서비스의 실제 실행 경로는 애플리케이션 저장소 하나로 끝나지 않는다. Composer가 설치한 라이브러리, C 확장, PHP-FPM 설정, 웹 서버와 FastCGI 연결, OPcache·JIT, OS 패키지, ICU·OpenSSL·SQLite 같은 네이티브 라이브러리, 이미지 빌드와 health check가 한 릴리스 단위로 묶인다.

![PHP 8.5 업그레이드에서 소스 코드부터 네이티브 확장과 런타임 설정까지 이어지는 검증 아키텍처](https://heracles-jo.github.io/assets/img/posts/php85-upgrade-validation/architecture.svg)

업그레이드 inventory는 최소 다섯 층으로 나누는 편이 좋다.

1. **언어 층**: 문법, type coercion, warning·exception, reflection과 serialization 의미
2. **패키지 층**: `composer.json`의 PHP 제약, lock file, framework·polyfill·test tool 호환성
3. **확장 층**: 내장·shared·PECL 확장, ABI, 필요한 system library와 compile flag
4. **SAPI 층**: CLI, FPM, Apache module, worker runtime마다 다른 INI와 process lifecycle
5. **운영 층**: container base image, health check, OPcache warm-up, 로그·metric·trace, rollback artifact

[Effect 4 전환 글](/posts/effect-typescript-runtime-adoption/)에서 package version만 맞춰도 실행 계약이 자동으로 보존되지는 않았던 것처럼, PHP도 `composer update` 성공을 업그레이드 완료로 볼 수 없다. CLI 테스트가 통과해도 FPM pool의 환경 변수, preload, request 종료 시 destructor, long-running worker의 memory와 signal 처리에서 다른 결과가 날 수 있다.

## 8.5의 위험은 큰 문법 파괴보다 작은 의미 변화에 숨어 있다

공식 migration guide는 8.5를 새 minor release로 설명하지만 production 전환 전에 비호환성을 시험하라고 분명히 경고한다. 변화는 한 번에 애플리케이션을 멈추는 parse error보다, 기존 예외 처리와 로그 기준선을 흔드는 형태가 많다.

예를 들어 비교 불가능한 내부 객체와 boolean의 느슨한 비교가 일관된 방식으로 바뀌었다. `gc_collect_cycles()` 반환값은 cycle을 통해 간접 수집된 문자열과 resource를 더 이상 포함하지 않는다. non-array 값을 destructuring하면 warning이 발생하고, 표현 범위를 벗어난 float·float 형태 문자열을 int로 바꿀 때도 warning이 생긴다. 기존 monitoring이 warning 수나 GC 수치를 운영 판단에 사용했다면 “결과는 대체로 같다”는 말로 넘길 수 없다.

확장별 변경은 더 구체적이다.

- Intl은 최소 ICU 57.1을 요구하고 일부 오류가 `IntlException`이나 `ValueError`로 바뀐다.
- PDO는 `FETCH_CLASS` constructor argument가 일반적인 named argument 의미를 따르며, fetch 중 `setFetchMode()` 같은 재진입 패턴은 Error가 된다.
- Session은 `$_SESSION` key에 `|`가 있을 때 조용히 실패하지 않고 warning을 낸다.
- Socket·SNMP·LDAP·PCNTL의 잘못된 port·option·null byte 입력은 더 적극적으로 `ValueError`를 던진다.
- SimpleXML의 node set이 아닌 XPath 결과는 warning과 `false`를 반환한다.
- `disable_classes` INI는 제거됐다.

이 변경들은 정상 요청보다 예외·오염 입력·복구 경로에서 드러난다. happy-path API test만 돌리면 놓치기 쉽다. 오류를 문자열로 비교하는 legacy code, `TypeError`만 잡는 adapter, 비정상 입력을 조용히 무시하는 batch job을 별도 corpus로 만들어야 한다.

## deprecation은 나중 문제지만 지금의 관측 문제다

PHP 8.5는 backtick shell 실행, `(boolean)`·`(integer)` 같은 비표준 cast, `case ...;`, `null` array offset, `__sleep()`·`__wakeup()`, 비숫자 문자열 증가 등을 deprecate한다. `curl_close()`, `finfo_close()`, `imagedestroy()`, `xml_parser_free()`처럼 객체 수명으로 대체된 명시적 close 함수도 목록에 들어갔다. PDO driver 전용 상수와 method는 `Pdo\Mysql`, `Pdo\Pgsql`, `Pdo\Sqlite` 같은 driver class 쪽으로 이동하는 방향이다.

기술적으로 deprecation은 즉시 fatal error가 아닐 수 있다. 운영에서는 그렇지 않다. `E_DEPRECATED`를 production log에 새로 포함하면 초당 수천 건의 오래된 호출이 storage와 전송 비용을 만들 수 있고, 반대로 숨기면 다음 major 전환의 작업량을 잃는다. 따라서 다음 세 경로를 분리한다.

- CI는 `E_ALL`로 실행하고 deprecation을 test failure 또는 정리 가능한 report로 만든다.
- staging은 실제 traffic replay에서 발생 빈도와 호출 위치를 수집한다.
- production은 sampling·rate limit을 적용하되 release SHA와 route별 count를 남긴다.

정적 분석과 자동 변환은 후보를 찾는 데 유용하지만, magic method와 serialization처럼 저장 데이터 형식에 영향을 주는 변경은 코드 치환만으로 끝나지 않는다. Queue payload, cache object, session, DB blob을 구버전과 신버전이 동시에 읽는 배포 구간까지 시험해야 한다.

## OPcache가 내장됐다는 변화는 이미지와 설정 계약을 바꾼다

8.5에서는 OPcache가 PHP binary에 항상 built-in되고 항상 로드된다. `--enable-opcache`·`--disable-opcache` configure flag가 제거됐고 별도 `opcache.so`나 `php_opcache.dll`을 만들지 않는다. 기존 이미지가 `zend_extension=opcache.so`를 주입하면 warning이 발생한다. 단순히 extension이 “기본 활성화됐다”는 변화가 아니라 build recipe와 INI 생성 방식을 정리해야 한다는 뜻이다.

컨테이너에서는 다음을 확인한다.

- base image가 공식 binary인지 자체 compile인지, build option이 더 이상 유효한지
- `/usr/local/etc/php/conf.d` 등에 중복 `zend_extension`이 남아 있지 않은지
- CLI와 FPM에서 `opcache.enable`, `opcache.enable_cli`, JIT 설정이 의도대로 다른지
- preload script가 모든 worker에서 같은 path·권한·extension set을 보는지
- read-only root filesystem에서 file cache를 쓸 경우 새 `opcache.file_cache_read_only`와 artifact 생성 조건이 맞는지

OPcache file cache는 다른 PHP build, file path, 설정, 로드된 extension 조합으로 만들면 무시될 수 있다. 따라서 image A에서 만든 cache를 image B가 재사용할 수 있다고 가정하지 않는다. Release artifact에 PHP exact version, extension 목록, INI digest, application path를 함께 기록하고, warm-up 실패가 cold start와 latency에 미치는 영향을 측정한다.

[티어별 상태와 복구를 분리한 OpenBao 전환 글](/posts/openbao-secrets-management-migration/)처럼, PHP runtime도 binary와 config, cache를 하나의 mutable 서버 상태로 두기보다 다시 만들 수 있는 release artifact로 취급해야 한다. 그래야 긴급 보안 릴리스가 나왔을 때 같은 절차로 rebuild·검증·rollout할 수 있다.

## 8.5.12는 기능 업그레이드와 보안 패치를 분리해서 생각할 수 없게 한다

`PHP 8.5.12`는 두 건의 critical RCE 취약점을 수정한 security release다. 아직 8.5를 쓰지 않는 서비스가 이 소식만 보고 production major/minor 전환을 즉시 수행하는 것도 위험하지만, 이미 8.5를 운영하면서 framework test가 많다는 이유로 patch를 미루는 것은 더 위험하다. 대응 경로를 나눠야 한다.

이미 8.5 계열이면 8.5.12로 patch하고, 동일 minor 안의 binary·extension·container 회귀를 빠르게 돌린다. 8.4나 8.3이면 각 branch의 공식 보안 release와 advisory를 확인해 현재 branch에서 안전한 version으로 먼저 올린 뒤 8.5 전환을 별도 change로 진행한다. EOL 또는 EOL 임박 branch라면 응급 patch와 지원 branch migration을 같은 프로그램에서 관리하되 배포 단위는 분리한다.

보안 릴리스 속도는 운영 성숙도를 드러낸다. Base image tag가 mutable하고 SBOM·digest가 없거나, extension을 빌드한 source와 compiler를 재현할 수 없거나, 카나리 없이 전체 FPM fleet를 교체해야 한다면 문제는 PHP 8.5 기능이 아니라 patch pipeline이다. [Caddy 패치 업그레이드 글](/posts/caddy-automatic-https-operations/)에서 보안 기본값 변경이 스트리밍 회귀를 만들었던 것처럼, 긴급성은 회귀 검증을 생략할 이유가 아니라 검증 시간을 줄여 놓아야 할 이유다.

## blue-green 전환은 binary가 아니라 의미를 비교해야 한다

안전한 방식은 같은 application commit을 PHP 8.4와 8.5.12 두 runtime으로 빌드해 결과를 비교하는 것이다. 단순 HTTP 200 비율만으로는 부족하다. Response body, header, cookie, error class, log severity, SQL query, queue event, serialization 결과를 request 단위로 대조해야 한다.

![PHP 8.5를 정적 검사에서 카나리와 전체 전환까지 확대하는 배포 의사결정 흐름](https://heracles-jo.github.io/assets/img/posts/php85-upgrade-validation/decision.svg)

권장 순서는 다음과 같다.

1. `composer.lock`을 고정하고 현재 runtime의 test·benchmark 기준선을 저장한다.
2. PHP 8.5.12 image에서 Composer platform check와 extension inventory를 확인한다.
3. 8.3·8.4·8.5 migration guide의 deprecation과 비호환 항목을 정적 분석·test로 좁힌다.
4. Unit test보다 먼저 bootstrap, container compile, migration dry-run, CLI command, queue worker 시작을 확인한다.
5. 대표 traffic을 두 runtime에 replay해 응답과 부작용을 diff한다.
6. read-only·idempotent endpoint부터 shadow 또는 소량 canary로 보낸다.
7. 결제·로그인·파일 업로드·batch·serialization처럼 상태를 바꾸는 경로를 별도 승인한다.
8. FPM worker recycling, memory growth, OPcache hit, fatal backtrace와 warning rate를 관측한다.
9. rollback은 image tag가 아니라 검증된 digest와 이전 DB·payload 호환성을 기준으로 실행한다.

같은 host에서 PHP binary만 바꾸는 in-place upgrade는 rollback을 어렵게 한다. OS package dependency와 extension 파일이 섞이고, 오래된 worker가 남아 두 ABI가 공존할 수 있다. Container나 immutable VM image로 runtime 전체를 교체하고, old pool을 drain한 뒤 종료하는 편이 원인 분리와 복구에 유리하다.

## PoC에서 측정할 것은 처리량보다 회귀 탐지 능력이다

PHP 8.5의 성능 개선에는 Clang 19 이상의 x86_64·aarch64에서 기본 활성화되는 TAILCALL VM, ARM NEON 활용 확대, exception object 생성과 callback array 함수, URL encoding, XMLReader·XMLWriter 개선 등이 포함된다. 그러나 공식 최적화 목록을 자신의 workload 성능 향상률로 바꾸면 안 된다. Framework bootstrap, ORM hydration, JSON, template, network wait 비중에 따라 효과가 다르고, extension이나 JIT 설정 변화가 반대 결과를 만들 수 있다.

| 검증 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 호환성 | 실패 test, 새 warning·exception, response·payload diff | 정상 입력의 의미 변화 또는 복구 분기가 다른 예외를 놓침 |
| 의존성 | Composer platform 충돌, extension load, native library version | 필수 package·extension이 임시 fork나 미지원 binary에 의존 |
| FPM | startup·reload, worker memory, request p95·p99, drain 시간 | worker crash·누수 또는 rollback 중 요청 손실이 재현됨 |
| OPcache | hit rate, restart 횟수, warm-up 시간, stale code | config 중복·cache 불일치로 예측 불가능한 cold start 발생 |
| 관측성 | deprecation·warning rate, fatal backtrace, APM 연결 | 새 로그 폭주를 제어하지 못하거나 오류가 기존 dashboard에서 사라짐 |
| 보안 패치 | advisory→artifact→canary→전체 배포 시간 | exact version·SBOM·digest를 추적하지 못해 패치 완료를 증명할 수 없음 |
| 복구 | 이전 image 전환, schema·session·queue 역호환 | rollback 후 구버전이 신버전 payload를 읽지 못함 |

[fmt에서 `std::format`으로 옮기는 글](/posts/cpp-std-format-fmt-migration/)에서 출력 호환성을 별도 golden test로 잡았듯, PHP 전환도 기존 test suite가 표현하지 않는 관찰 결과를 golden corpus로 만들어야 한다. 날짜·locale·Unicode, URL parsing, float→int, PDO fetch, session key, serialize·unserialize, error handler, shutdown·destructor 순서는 작은 fixture로 고정하기 좋다.

## 채택 기준은 8.5 기능이 아니라 패치 가능한 런타임이다

PHP 8.5는 읽기 쉬운 파이프 연산자와 표준 URI API, API misuse를 드러내는 `#[\NoDiscard]`, readonly 객체의 clone 갱신 같은 유용한 기능을 제공한다. Persistent cURL share handle과 OPcache·VM 개선도 특정 workload에서는 실질적인 이득이 될 수 있다. 하지만 새 기능을 쓰기 시작하면 8.5가 최소 runtime이 되고 rollback·혼합 fleet 전략이 좁아진다. 전환 직후에는 feature adoption과 runtime migration을 같은 release에 넣지 않는 편이 안전하다.

먼저 8.5.12에서 기존 동작을 보존하고, Composer·extension·FPM·OPcache·관측·rollback 증거를 만든다. 그다음 URI API나 pipe operator를 작은 영역부터 사용한다. 그래야 문제가 생겼을 때 runtime 차이인지 application rewrite인지 분리할 수 있다.

PHP 업그레이드에서 가장 중요한 질문은 “테스트가 통과했는가?”보다 구체적이어야 한다. **현재 branch의 지원 종료를 알고 있는가, exact binary와 extension을 재현할 수 있는가, 새 warning과 예외 의미를 관측하는가, critical patch를 며칠이 아니라 몇 시간 안에 같은 절차로 배포할 수 있는가.** 이 네 가지가 갖춰지면 8.5 전환은 일회성 버전 작업이 아니라 지속 가능한 런타임 운영 개선이 된다.

> 1차 자료: [php-src 저장소](https://github.com/php/php-src), [PHP 8.5 발표](https://www.php.net/releases/8.5/en.php), [8.4→8.5 migration guide](https://www.php.net/manual/en/migration85.php), [비호환 변경](https://www.php.net/manual/en/migration85.incompatible.php), [deprecated features](https://www.php.net/manual/en/migration85.deprecated.php), [기타 runtime·OPcache 변경](https://www.php.net/manual/en/migration85.other-changes.php), [공식 지원 버전 표](https://www.php.net/supported-versions.php), [PHP 8.5.12 security release](https://github.com/php/php-src/releases/tag/php-8.5.12), [최근 commits](https://github.com/php/php-src/commits/master/), [공개 issues](https://github.com/php/php-src/issues), [공개 pull requests](https://github.com/php/php-src/pulls). Trending·저장소 수치는 2026년 10월 23일 08시 29분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
