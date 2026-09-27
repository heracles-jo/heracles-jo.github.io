---
title: "TypeScript 네이티브 컴파일: scriptc 도입 경계와 검증 기준"
description: "scriptc의 tsc·typed IR·LLVM 파이프라인을 따라 Node 없는 실행 파일의 이점과 호환성, 디버깅, 공급망, 성능 검증 기준을 정리한다."
author: heracles-jo
date: 2026-09-28 07:58:00 +0900
categories: [Developer Tools, Software Engineering]
tags: [scriptc, typescript, native-compiler, llvm, standalone-executable, developer-tools]
image:
  path: https://heracles-jo.github.io/assets/img/posts/scriptc-typescript-native-compiler/cover.svg
  alt: "TypeScript 소스가 typed IR과 LLVM을 거쳐 네이티브 실행 파일이 되는 scriptc 컴파일 파이프라인 표지"
---

TypeScript로 만든 CLI나 작은 서버를 배포할 때 흔히 생기는 질문은 “사용자에게 Node.js까지 설치하게 해야 하는가”다. 번들러로 파일 수를 줄여도 런타임은 남고, 단일 실행 파일 도구를 쓰면 배포는 쉬워지지만 JavaScript 엔진과 런타임 전체가 바이너리에 포함되는 경우가 많다. 반대로 코드를 네이티브 명령어로 바꾸면 시작 시간과 배포 형태를 단순화할 여지가 있지만, Node 호환성과 JavaScript의 동적 의미를 어디까지 보존할지가 새로운 문제가 된다.

[Vercel Labs의 scriptc](https://github.com/vercel-labs/scriptc)는 이 경계를 정면으로 다룬다. TypeScript 컴파일러로 소스를 파싱하고 타입 검사한 뒤 typed IR로 낮추고, C 또는 LLVM IR을 거쳐 네이티브 실행 파일과 WebAssembly를 만든다. 정적으로 컴파일되는 경로에는 Node도 JavaScript 엔진도 포함하지 않는다. 대신 정적 변환이 불가능한 구문은 진단으로 거부하고, npm 패키지나 `any` 중심 코드가 필요하면 `--dynamic`을 명시해 quickjs-ng를 넣는다. 핵심은 “TypeScript를 무조건 C로 바꾼다”가 아니라 **정적 의미를 증명할 수 있는 코드와 동적 런타임이 필요한 코드를 구분하는 배포 모델**이다.

이번 실행 환경에서는 Search Console과 Analytics의 실제 검색어·노출·클릭 데이터에 접근할 수 없었다. 접근했다고 가정하지 않았고, 기존 129개 글의 제목·description·저장소 링크·중심 논지와 `_data/written_topics.yml`을 비교했다. [SWC 글](/posts/github-trending-swc-rust-web-toolchain/)은 웹 빌드와 변환 속도를 다뤘지만 결과물은 여전히 JavaScript 생태계 안에 있다. 이번 글은 TypeScript 프로그램을 **Node 없는 네이티브 artifact로 배포할 수 있는 조건과 실패 경계**를 묻기 때문에 별도의 검색 의도가 있다.

## 에이전트·메모리 후보를 제치고 scriptc를 고른 이유

2026년 9월 28일 08시 06분 KST 전후 GitHub Trending daily·weekly와 GitHub API를 확인했다. Trending은 후보 발굴 신호로만 사용했으며 아래 별 수와 릴리스 상태는 조회 시점의 스냅샷이다.

| 후보 | 공개 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---:|---|
| [Paperclip](https://github.com/paperclipai/paperclip) | daily 2,527, 89,723 stars, MIT, v2026.916.1 | 업무용 에이전트 관리 제어면은 강한 신호지만 Google AX·Orca의 오케스트레이션 및 병렬 운영 의도와 가깝다. |
| [Hindsight](https://github.com/vectorize-io/hindsight) | daily 4,463, 37,185 stars, MIT, v0.10.1 | 학습형 에이전트 메모리는 Supermemory·코드베이스 기억 계층 글과 직접 경쟁한다. |
| [VoiceStudio](https://github.com/debpalash/VoiceStudio) | daily 3,060, 39,980 stars, AGPL-3.0, v0.5.6 | 로컬 음성 제작과 모델·권리 거버넌스는 9월 3일 글에서 이미 중심적으로 다뤘다. |
| [Univer](https://github.com/dream-num/univer) | daily 920, 20,130 stars, Apache-2.0, v1.0.2 | 오피스 하네스는 OfficeCLI 문서 자동화 글과 독자 질문이 인접한다. |
| [scriptc](https://github.com/vercel-labs/scriptc) | daily 186, 5,379 stars, Apache-2.0, v0.1.7 | TypeScript를 엔진 없는 네이티브 실행 파일로 내릴 수 있는 범위와 검증법이라는 독립된 장기 검색 의도가 선명하다. |

scriptc 저장소는 2026년 7월 22일 생성된 초기 프로젝트다. 9월 27일 공개된 `v0.1.7`은 개발 빌드의 TypeScript/JavaScript 소스 디버깅, 추가 `Math` 연산의 정적 컴파일, Promise rejection callback, 더 넓은 패키지 레이아웃 지원을 포함한다. 같은 날 main에는 compiler optimization과 backend 분석을 네이티브로 실행하는 변경이 이어졌다. 빠른 릴리스는 가능성을 보여 주지만 API와 artifact 계약이 아직 움직인다는 뜻이기도 하다. Vercel Labs가 README에 명시한 것처럼 현재는 실험 프로젝트로 평가해야 한다.

## 번들링이 아니라 의미를 낮추는 컴파일 파이프라인

scriptc의 파이프라인은 프런트엔드, typed IR, backend, link 네 층으로 나뉜다.

![scriptc가 TypeScript를 typed IR과 LLVM으로 낮추고 정적 runtime unit을 링크하는 구조](https://heracles-jo.github.io/assets/img/posts/scriptc-typescript-native-compiler/architecture.svg)

첫 단계에서는 실제 TypeScript compiler가 `tsconfig.json`의 strictness와 타입 좁히기를 반영해 소스를 검사한다. 그 결과를 바로 문자열 치환하거나 JavaScript bundle로 만들지 않고, generic을 구체화하고 union을 tagged value로 표현하며 closure capture를 명시한 typed IR로 내린다. `--emit=ir`을 쓰면 이 중간표현을 JSON으로 확인할 수 있다. 지원하지 않는 construct는 뒤늦은 잘못된 코드 생성보다 이 단계의 명시적 진단으로 끝내는 것이 설계 목표다.

그다음 C와 LLVM backend가 갈린다. `--emit=c`는 읽을 수 있는 C를, `--emit=llvm`은 textual LLVM IR을 만든다. 지원 플랫폼의 `--emit=asm|obj`는 버전이 맞는 별도 LLVM 22 helper를 사용해 assembly나 object를 만든다. 실행 파일 빌드는 기본적으로 LLVM 경로를 사용하고, 해당 정적 tier가 지원하지 않는 네이티브 프로그램은 C backend로 내려갈 수 있다. WASI target은 이런 fallback 없이 지원 여부를 명확히 판정한다.

링크 단계에서는 모든 기능을 가진 거대한 runtime을 무조건 붙이지 않는다. release package가 기능 단위의 사전 컴파일 runtime object와 QuickJS, 정규식, 압축, TLS 관련 archive를 제공하고, IR의 feature gate가 필요한 단위를 고르는 구조다. 그러나 “컴파일러가 있으니 외부 도구가 전혀 필요 없다”는 뜻은 아니다. 일반 실행 파일을 만들려면 목표 플랫폼의 linker driver와 SDK 또는 sysroot가 필요하고, C backend·sanitizer·일부 fallback은 C compiler가 필요하다. 컴파일 환경 manifest를 고정하지 않으면 같은 소스와 scriptc 버전만으로 동일 artifact를 재현하기 어렵다.

이 지점은 [C++ `std::format` 전환 글](/posts/cpp-std-format-fmt-migration/)에서 다룬 의미 동등성 문제와 닮았다. 컴파일이 성공해도 문자열 표현, 예외, 비동기 순서, 파일·네트워크 API의 경계가 원래 Node 실행과 같다는 보장은 별도의 검증 대상이다. 낮은 계층으로 내려갈수록 “빌드 성공”보다 **관찰 가능한 동작이 같은가**가 중요해진다.

## 정적 tier와 dynamic island의 경계를 숨기지 않는다

scriptc의 가장 실용적인 기능은 `scriptc coverage`다. 프로그램의 statement 중 무엇이 정적으로 컴파일되고, 어떤 구문이 동적이거나 아직 지원되지 않는지 코드가 붙은 진단으로 보여 준다. 전체 애플리케이션을 한 번에 옮기기보다 작은 CLI, migration 도구, protocol adapter처럼 타입이 구체적이고 입출력 표면이 좁은 코드부터 적합성을 볼 수 있다.

정적 tier에서 값은 reference counting으로 관리되고 cycle은 결정된 지점의 collector가 처리한다. 비동기 코드는 fiber와 native event loop를 사용하며 macOS의 kqueue, Linux의 epoll에 연결된다. `net`, `http`, `https`, `tls`, `dgram`, `dns` 일부도 native runtime 구현을 사용한다. 프로젝트는 corpus를 Node와 compiled binary에서 각각 실행해 stdout, stderr, exit code를 byte 단위로 비교하고, AddressSanitizer와 reference-count audit도 CI gate로 둔다.

그렇다고 Node 전체가 구현됐다는 뜻은 아니다. 공식 limitations 문서는 지원하지 않는 generic·dynamic import·Node API·shape 변환과 의도적인 차이를 길게 공개한다. exact struct처럼 다루는 record shape, 제한된 Map/Set key, 특정 filesystem option, 동적으로 계산된 module specifier, engine boundary의 객체 identity 같은 곳에서 제약이 생긴다. 실제 답은 README의 예제가 아니라 자기 코드에 `coverage`를 실행했을 때 나온다.

`--dynamic`은 이 간극을 quickjs-ng가 포함된 dynamic island로 넘긴다. npm package의 JavaScript와 `any` 기반 연산은 embedded engine에서 실행되고, 정적 세계로 돌아오는 값은 runtime validation을 거친다. 이 선택은 호환성을 넓히지만 scriptc의 가장 큰 차별점인 “엔진 없는 실행 파일”을 약화한다. binary size, cold start, 메모리, 보안 업데이트 표면도 달라진다. 따라서 PoC 결과에는 정적 coverage 비율만 아니라 **dynamic island가 실제 요청 경로에서 얼마나 자주 실행되는지**를 기록해야 한다.

## Bun·Deno·Node SEA와 같은 단일 파일이지만 같은 방식은 아니다

TypeScript 단일 실행 파일이라는 결과만 보면 Bun, Deno, Node SEA와 비슷해 보인다. 그러나 무엇을 binary에 넣는지가 다르다.

| 선택지 | 실행 모델 | 강점 | 주의할 경계 |
|---|---|---|---|
| scriptc static tier | typed IR을 native code로 낮추고 작은 native runtime을 link, JS engine 없음 | 작은 정적 프로그램의 시작·배포 모델 단순화, IR/C/LLVM/object 관찰 가능 | 지원 언어·Node API가 제한적이며 linker·SDK와 플랫폼별 runtime pack을 관리해야 함 |
| scriptc `--dynamic` | 정적 코드 옆에 quickjs-ng island 포함 | npm package와 동적 코드 호환성 확대 | 두 heap·microtask 세계의 경계, engine 보안 업데이트와 성능 비용이 추가됨 |
| Bun `--compile` | 코드·패키지와 Bun runtime을 하나의 executable에 bundle | Bun·Node API 호환, cross-target, bytecode와 sourcemap 등 배포 기능 | JavaScriptCore와 Bun runtime이 포함되며 runtime 설정·환경 로딩 정책을 함께 검토해야 함 |
| `deno compile` | 프로그램을 stripped Deno runtime인 denort에 삽입 | 권한을 compile 시점에 고정, cross-compile, asset·framework 지원 | 기본은 V8 runtime을 포함하며 bundle·QuickJS·self-extracting 옵션마다 보안·크기 경계가 달라짐 |
| Node SEA | bundle script와 asset을 Node binary에 삽입 | 기존 Node API와 배포 계약을 가장 직접적으로 유지 | 기능이 active development 상태이며 platform·code cache·snapshot·native addon 제약을 관리해야 함 |

Bun 공식 문서는 compiled executable에 import된 파일·패키지와 Bun runtime을 함께 넣는다고 설명한다. Deno는 도구 명령을 뺀 `denort`에 프로그램을 포함하고, 기본 V8 외에 실험적 QuickJS 선택도 제공한다. Node SEA 역시 preparation blob을 Node binary에 넣는 방식이다. 이들은 엔진을 유지해 넓은 JavaScript 호환성을 얻는다. scriptc는 정적으로 증명 가능한 범위에서 엔진을 제거하는 대신 호환성 비용을 사용자에게 더 일찍 보여 준다.

따라서 “scriptc가 Bun보다 빠른가”를 일반론으로 묻는 것은 좋은 비교가 아니다. 작은 계산형 CLI, I/O 중심 서버, npm dependency가 많은 도구, native addon을 쓰는 앱은 서로 다른 결과를 낸다. [Modular MAX의 runtime 이식성 글](/posts/modular-max-hardware-portable-ai-inference/)에서 동일 API가 backend별 성능과 정확도를 보장하지 않았듯, standalone executable도 파일 하나라는 외형보다 내부 runtime, target ABI, syscall과 library 계약을 봐야 한다.

## 운영에서 먼저 드러나는 실패 모드

첫째는 **의미 호환성의 과신**이다. Node와 differential test를 한다고 조직의 코드까지 검증된 것은 아니다. timezone, locale, TLS CA store, signal, child process, stream backpressure, 파일 권한, DNS, 예외 메시지와 microtask 순서가 업무 로직에 영향을 줄 수 있다. golden test는 stdout 비교를 넘어 실제 protocol client와 fixture를 사용해야 한다.

둘째는 **플랫폼 artifact 폭증**이다. macOS arm64에서 성공한 binary가 Linux glibc·musl, Windows x64, WASI에서 같은 방식으로 동작하지 않는다. target별 helper와 runtime pack, system library, code signing, notarization, SBOM, checksum을 별도 release artifact로 관리해야 한다. [BrewUI의 패키지 운영 글](/posts/brewui-homebrew-gui-package-management/)에서 GUI가 `brew`의 책임을 없애지 않았듯, 단일 실행 파일도 release engineering을 없애지 않는다. 오히려 플랫폼 matrix를 제품팀이 직접 소유하게 할 수 있다.

셋째는 **공급망 범위 축소 착각**이다. 루트 라이선스는 Apache-2.0이지만 release에는 LLVM helper, platform runtime pack과 QuickJS·mbedTLS·zlib 등 third-party component가 포함될 수 있다. 정적 링크 여부와 배포 대상에 따라 notice와 취약점 추적 범위가 달라진다. npm에서 `scriptc` 한 패키지만 고정하는 것으로 끝내지 말고 package lock, platform package, linker/SDK, target sysroot, 최종 binary digest와 third-party notices를 함께 보관해야 한다.

넷째는 **디버깅 경로의 변화**다. `v0.1.7`은 `--optimization=dev`에서 source breakpoint와 native stack frame을 지원하지만, 모든 JavaScript 객체가 익숙한 형태로 보이는 것은 아니다. string은 native `ScrStr`, tagged union은 내부 arm, 일부 heap value는 opaque pointer로 나타날 수 있고 dynamic engine 안의 코드는 같은 방식으로 step debugging되지 않는다. 운영팀이 Node inspector와 JavaScript stack trace에 익숙하다면 crash dump, symbol, `.dSYM`, source mapping을 포함한 새 runbook이 필요하다.

다섯째는 **초기 프로젝트의 변경 속도**다. object ABI는 exact runtime version compatibility를 요구하고 semver-stable이 아니라고 문서에 명시돼 있다. compiler minor update가 지원 surface, runtime ABI, 생성 artifact와 성능을 동시에 바꿀 수 있다. 자동 업데이트보다 승인된 버전 쌍과 회귀 corpus를 두는 편이 안전하다.

## 2주 PoC는 benchmark가 아니라 배포 계약을 검증한다

![scriptc 도입을 진행하거나 보류하기 위한 호환성·artifact·운영 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/scriptc-typescript-native-compiler/decision.svg)

첫 PoC에는 의존성이 적고 실행 시간이 짧으며 입력·출력 계약이 분명한 내부 CLI 하나가 적합하다. 전체 웹 서비스나 프레임워크 앱을 고르면 unsupported surface와 배포 문제를 동시에 만나 원인을 분리하기 어렵다. 기준선은 Node 24 실행, 비교군은 scriptc static, 필요할 때만 scriptc dynamic과 Bun 또는 Deno executable로 둔다.

| 검증 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 정적 적합성 | statement coverage, diagnostic 종류, dynamic island 호출 비율 | 핵심 경로가 `--dynamic` 없이는 컴파일되지 않거나 rewrite가 코드 의미를 흐림 |
| 의미 동등성 | golden output, exit code, 예외, async 순서, protocol·filesystem fixture | Node 기준과 다른 결과가 재현되며 문서화된 divergence로 수용할 수 없음 |
| 성능 | cold/warm start, wall time, RSS, CPU, binary size, p95 latency | binary만 작아지고 실제 workload의 시작·메모리·처리 시간이 개선되지 않음 |
| artifact | target별 build 재현, digest, symbols, SBOM, code signing | 같은 manifest로 binary를 다시 만들 수 없거나 target별 차이를 추적할 수 없음 |
| 운영성 | stack trace, native debugger, crash dump, rollback 시간 | on-call이 원인을 Node·runtime·linker·OS 중 어디서 찾아야 할지 분리하지 못함 |
| 공급망 | scriptc·platform pack·LLVM helper·SDK 버전, notices, 취약점 | 포함 component와 라이선스·업데이트 소유자를 설명할 수 없음 |
| 업그레이드 | v0.1.7에서 다음 승인 버전으로 corpus 재실행, ABI·크기 diff | compiler update가 artifact 계약을 깨는데 rollback과 재검증 시간이 배포 창을 초과 |

성능 실험은 “hello world가 몇 ms 빨라졌다”에서 멈추면 안 된다. 실제 CLI의 가장 흔한 명령과 가장 무거운 명령을 분리하고, macOS 개발 장비와 Linux CI·배포 환경에서 각각 측정한다. binary size는 strip 전후, static과 dynamic을 나눠 기록한다. 서버라면 첫 요청 지연, steady-state throughput, keep-alive, TLS, DNS, memory plateau와 shutdown 시간을 본다. 계산형 작업은 LLVM optimization 효과가 클 수 있지만, 외부 API 대기가 대부분이라면 컴파일 방식보다 네트워크가 지배한다.

도입에 적합한 팀은 TypeScript로 작은 배포 도구·CLI·sidecar를 만들고, Node 설치 없는 artifact가 실제 운영 이점이며, 테스트 corpus와 target별 release pipeline을 소유할 수 있는 곳이다. 반대로 npm 생태계와 native addon을 넓게 사용하고, reflection과 동적 module loading이 많으며, Node inspector 기반 운영 경험을 유지해야 하는 서비스라면 Bun·Deno·Node SEA가 더 낮은 전환 비용을 줄 수 있다.

scriptc의 가치는 JavaScript를 네이티브보다 열등한 것으로 선언하는 데 있지 않다. TypeScript의 타입 정보와 실제 compiler를 이용해 **어디까지 엔진 없이 실행할 수 있고, 어디서 동적 runtime이 다시 필요한지 측정 가능하게 만든다**는 데 있다. 그 경계를 `coverage`, differential test, artifact manifest와 target별 운영 훈련으로 증명할 수 있다면 scriptc는 작은 프로그램의 배포 모델을 단순화할 수 있다. 증명할 수 없다면 파일 하나로 만들어졌다는 사실만으로 프로덕션 준비가 끝난 것은 아니다.

> 1차 자료: [scriptc 저장소와 README](https://github.com/vercel-labs/scriptc), [How It Works](https://scriptc.dev/how-it-works), [Limitations](https://scriptc.dev/limitations), [Platform Support](https://scriptc.dev/platforms), [Dependencies](https://scriptc.dev/dependencies), [v0.1.7 release](https://github.com/vercel-labs/scriptc/releases/tag/v0.1.7), [Apache-2.0 LICENSE](https://github.com/vercel-labs/scriptc/blob/main/LICENSE), [Bun single-file executable](https://bun.com/docs/bundler/executables), [`deno compile`](https://docs.deno.com/runtime/reference/cli/compile/), [Node.js SEA](https://nodejs.org/api/single-executable-applications.html). Trending·저장소 수치는 2026년 9월 28일 08시 06분 KST 전후 공개 페이지와 GitHub API 확인 시점의 스냅샷이며 이후 달라질 수 있다.
