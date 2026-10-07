---
title: "RAD Debugger 네이티브 디버깅: PDB·DWARF 검증 기준"
description: "RAD Debugger의 RDI 변환·멀티프로세스 제어·Linux 지원을 분해하고, 대형 C/C++ 프로젝트에서 기호 정확성·충돌 분석·보안 경계를 검증하는 도입 기준을 제시한다."
author: heracles-jo
date: 2026-10-08 08:10:00 +0900
categories: [Developer Tools, Software Engineering]
tags: [rad-debugger, native-debugging, pdb, dwarf, crash-dump, cpp-toolchain]
image:
  path: https://heracles-jo.github.io/assets/img/posts/rad-debugger-native-debugging/cover.svg
  alt: "PDB와 DWARF 디버그 정보가 RDI 변환을 거쳐 멀티프로세스 네이티브 디버깅으로 이어지는 구조"
---

네이티브 프로그램의 장애는 소스 한 줄과 일대일로 대응하지 않는다. 최적화가 함수를 합치거나 제거하고, 인라인 프레임과 템플릿 타입이 디버그 정보를 부풀리며, 여러 프로세스와 수백 개 스레드가 동시에 멈춘다. 크래시 덤프를 열었는데 호출 스택이 끊기거나 변수 값이 틀리면 디버거 UI가 아무리 빠르더라도 판단 근거로 쓸 수 없다.

[EpicGames/raddebugger](https://github.com/EpicGames/raddebugger)는 로컬 네이티브 프로그램을 위한 사용자 모드·멀티프로세스 그래픽 디버거다. 핵심은 PDB나 DWARF를 매번 직접 탐색하지 않고 자체 **RAD Debug Info(RDI)** 형식으로 변환해 비동기로 적재하는 구조, 프로세스 제어와 프런트엔드를 분리한 계층, 대형 실행 파일의 링크 시간을 줄이려는 RAD Linker를 한 프로젝트에서 개발한다는 점이다.

여기서 실무 질문은 “Visual Studio나 GDB보다 화면이 편한가”가 아니다. **우리 컴파일러·링커·최적화 옵션이 만든 디버그 정보를 정확히 해석하고, 실패했을 때 기존 도구로 즉시 돌아갈 수 있는가**다. 디버거를 바꾸는 일은 편집기 테마를 바꾸는 일이 아니라 장애 증거의 해석기를 바꾸는 일에 가깝다.

2026년 10월 8일 08시 18분 KST 전후 GitHub Trending daily에서 RAD Debugger는 **82 stars today**로 표시됐다. GitHub API 기준 저장소는 **7,850 stars**, 381 forks, MIT 라이선스였고 최신 릴리스 `v0.9.29-alpha`는 9월 30일 공개됐다. 10월 8일 KST 아침까지 구형 DWARF 파싱, Linux 창 관리, 원격 제어 기반 코드와 빌드 스크립트 수정이 이어졌다. 수치와 활동은 확인 시점의 공개 스냅샷이며 안정성이나 도입 적합성을 보증하지 않는다. 이번 실행 환경에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근할 수 없어 선정 근거로 사용하지 않았다.

## 후보 비교에서 남은 것은 네이티브 장애 증거의 정확성이었다

오늘 daily·weekly 목록은 역공학 에이전트, 코딩 agent skill, 콘솔 포팅, 터미널과 셀프호스팅 앱으로 흩어져 있었다. 기존 글의 제목·description·저장소 링크뿐 아니라 중심 질문을 대조했다. 에이전트 메모리·보안 skill·GUI 자동화는 이미 여러 클러스터와 경쟁한다. RAD Debugger는 [Magic Trace 프로파일링 글](/posts/github-trending-production-profiling-magic-trace/)과 실행 관측이라는 접점이 있지만, 성능 타임라인이 아니라 **중단된 프로세스의 기호·스택·변수를 신뢰할 수 있는가**라는 별도 검색 의도를 가진다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [EpicGames/raddebugger](https://github.com/EpicGames/raddebugger) | daily 82, 7,850 stars, MIT, v0.9.29-alpha | PDB·DWARF 변환 정확성, 대형 바이너리, 덤프·멀티프로세스 디버깅의 도입 기준이라는 독립 질문이 있어 선택했다. |
| [morluto/rea](https://github.com/morluto/rea) | daily 4,666, 14,799 stars, MIT, rea-agents 5.0.0 | 에이전트 기반 역공학은 가치가 크지만 악성 입력·도구 권한·분석 증거의 신뢰를 함께 다뤄야 하며 어제 후보와 반복된다. |
| [boykopovar/AnyPS5](https://github.com/boykopovar/AnyPS5) | daily 2,725, 10,415 stars, GPL-2.0, v0.1.1 | 실행 파일 호환 계층은 기술적으로 흥미롭지만 초기 호환성과 플랫폼·콘텐츠 권리 경계가 중심이어서 장기 실무 의도가 좁다. |
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) | daily 96, 27,826 stars, v0.65.0 | 에이전트 터미널 멀티태스킹은 개발 경험 주제와 가깝고 API가 보고한 라이선스가 `NOASSERTION`이라 별도 검토가 필요하다. |
| [DuarteSantos8/openGym](https://github.com/DuarteSantos8/openGym) | daily 1,494, 6,849 stars, AGPL-3.0, v1.3.10 | 셀프호스팅 데이터 소유권은 분명하지만 현재 사이트의 개발 도구·플랫폼 권위와 연결성이 낮다. |

RAD Debugger를 지금 살펴볼 직접 계기는 Linux x64 디버깅이 `v0.9.29-alpha`에서 처음 공개 시험 단계에 들어갔기 때문이다. 동시에 Minidump 열기, 선택 스레드에 묶는 breakpoint, debug info 적재 상태 표시가 추가됐다. 기능 목록보다 중요한 신호는 릴리스 노트가 `fork`·`vfork`, TLS 위치 계산, `.eh_frame_hdr`, bitfield, DWARF 타입 중복 제거 같은 미완성 경계를 구체적으로 공개했다는 점이다. 새 플랫폼 지원은 “실행된다”보다 **어떤 바이너리와 컴파일 옵션에서 해석이 아직 틀릴 수 있는가**를 읽어야 한다.

## PDB·DWARF를 RDI로 바꾸는 순간 새로운 신뢰 경계가 생긴다

일반적인 네이티브 디버깅 경로는 실행 파일, PDB 또는 DWARF, 소스 파일을 디버거가 연결하는 구조다. RAD Debugger는 여기에 RDI라는 중간 표현을 둔다. `dbg_info` 계층이 원본 디버그 정보를 별도 프로세스에서 필요할 때 변환하고, 결과를 캐시한 뒤 프런트엔드의 타입 검색·표현식 평가·호출 스택에 공급한다. `radbin`은 변환과 텍스트 덤프를 담당하며, RAD Linker는 선택적으로 RDI를 직접 만들 수 있다.

![RAD Debugger에서 빌드 산출물과 PDB·DWARF가 RDI 변환·캐시·디버그 엔진으로 연결되는 아키텍처](https://heracles-jo.github.io/assets/img/posts/rad-debugger-native-debugging/architecture.svg)

이 중간 형식은 대형 디버그 정보를 한 번 정규화하고 비동기로 탐색하기에 유리하다. 반면 변환기가 원본 의미를 잘못 옮기면 이후 UI와 표현식 평가가 일관되게 틀릴 수 있다. 최근 공개 이슈는 이 위험을 구체적으로 보여 준다.

- DWARF→RDI 변환에서 헤더에 반복 정의된 타입이 여러 사본으로 보이는 타입 중복 제거 문제가 보고됐다.
- Clang 22.1.8로 만든 간단한 구조체에서 길이 2인 배열을 16개로 해석한 재현 사례가 열려 있다.
- MinGW의 DWARF를 읽고 RDI 파일을 만들었지만 소스 매핑과 일부 정보가 빠지는 문제는 다음 날 파서 수정과 함께 닫혔다.
- `.eh_frame` 처리의 예상과 다른 입력이 assert를 일으키는 Linux 사례도 남아 있다.

따라서 “기호가 로드됨”은 검증 완료 조건이 아니다. 최소한 함수·소스 라인·인라인 프레임·지역 변수·TLS·배열 길이·bitfield·템플릿 타입·예외 프레임의 의미를 기준 디버거와 대조해야 한다. [scriptc 네이티브 실행 파일 글](/posts/scriptc-typescript-native-compiler/)에서 artifact가 만들어지는 것과 stack trace·symbol이 운영 가능한 것을 분리했듯, RDI 생성 성공과 디버깅 정확성도 다른 상태다.

RDI 캐시는 빌드 식별자와 함께 관리해야 한다. 실행 파일만 새로 만들고 이전 변환 결과가 남으면 가장 위험한 종류의 오류, 즉 그럴듯하지만 다른 주소·타입을 가리키는 화면이 생길 수 있다. 바이너리 hash, PDB GUID·age 또는 ELF build ID, 컴파일러·링커 버전, 변환기 commit, RDI hash를 manifest로 묶고 불일치 시 재변환하도록 한다.

## 멀티프로세스 제어는 편의 기능이 아니라 정지 상태의 일관성 문제다

RAD Debugger의 `ctrl` 계층은 연결된 프로세스가 실행될 때 자신은 멈추고, 제어 계층이 동작할 때 대상 프로세스를 정지시키는 lockstep 모델을 설명한다. `demon`은 운영체제별 저수준 프로세스 제어를 추상화하고, `dbg_engine`은 실행·중단·스레드 freeze·breakpoint·step을 조정한다. 프런트엔드는 다른 스레드에서 이를 구동한다.

여러 프로세스가 IPC, 공유 메모리, socket으로 연결된 프로그램에서는 한 프로세스만 멈추는 순간 상태가 계속 변할 수 있다. 서버가 멈췄지만 worker가 queue를 소비하거나, producer가 공유 ring buffer를 덮어쓰거나, watchdog이 멈춘 프로세스를 재시작하면 관찰한 메모리는 사건 당시의 일관된 스냅샷이 아니다. 멀티프로세스 디버거를 평가할 때는 단순 attach 수가 아니라 다음을 확인해야 한다.

1. breakpoint 적중 시 모든 대상 프로세스와 스레드가 어떤 순서로 정지하는가.
2. 한 스레드만 잠그는 breakpoint가 deadlock·timeout·watchdog에 어떤 영향을 주는가.
3. child process 생성, exec, `fork`·`vfork`와 프로세스 종료를 놓치지 않는가.
4. 정지 중 외부 서비스와 커널 자원은 계속 변하는지, 재개 후 timeout이 폭발하지 않는가.
5. dump·로그·trace의 timestamp를 같은 사건 ID로 연결할 수 있는가.

Linux 공개 지원이 아직 `fork`와 `vfork`를 다루지 못한다는 릴리스 경고는 이 경계가 단순한 누락 기능이 아님을 보여 준다. 테스트 runner, 빌드 도구, 게임 launcher, 브라우저와 worker 구조는 child process를 흔히 사용한다. 대상 프로그램이 실행은 되더라도 디버거가 추적해야 할 실제 작업 프로세스가 경계 밖으로 빠질 수 있다.

## Linux 지원은 UI 포팅보다 unwind와 타입 의미가 먼저다

프로젝트는 Linux에서 자체 코드를 빌드할 수 있고 OpenGL·FreeType·X11 계층을 개발하지만, 최신 릴리스의 네이티브 Linux 디버깅은 명시적으로 초기 단계다. 바이너리도 아직 배포하지 않아 사용자가 source build를 해야 한다. 운영체제 포팅을 창이 열린다는 사실로 평가하면 안 되는 이유가 여기에 있다.

호출 스택은 ELF와 DWARF만 읽는다고 자동으로 만들어지지 않는다. 현재 명령 주소에서 이전 프레임의 register와 return address를 복원해야 하며, frame pointer 생략, 인라인, signal trampoline, 예외 처리 정보, 최적화와 tail call이 결과를 바꾼다. 릴리스는 `.eh_frame_hdr`가 없을 때 unwind가 올바르지 않을 수 있고, debugger와 debuggee의 libc가 같다고 가정해 TLS 위치를 계산한다고 밝힌다. 이 조건이 깨지면 프레임이나 thread-local 변수는 비어 보이는 수준을 넘어 잘못된 값으로 보일 수 있다.

실제 공개 이슈에는 Factorio Linux demo를 열 때 debugger가 멈추고 메모리가 56GB까지 증가했다는 재현 보고, 구조체 배열 크기 오해, 잘못된 `.eh_frame` 입력에서 assert가 발생한 사례가 있다. 알파 프로젝트에서 버그가 있다는 사실 자체보다, 이 실패를 production debugging 경로에 어떻게 격리할지가 중요하다.

- 별도 진단용 workstation 또는 VM에서 실행하고 메모리·CPU 한도를 둔다.
- core dump, 원본 ELF, 별도 debug symbol, compiler command line을 보존한다.
- GDB 또는 LLDB로 같은 dump·실행 지점을 열어 call stack과 변수를 대조한다.
- 지원 compiler·libc·linker·optimization 조합을 작은 matrix로 고정한다.
- 재현 가능한 최소 바이너리와 symbol을 만들되 고객 데이터·비밀은 제거한다.

[TileLang GPU 커널 글](/posts/tilelang-gpu-kernel-dsl-validation/)에서 backend별 “지원”을 같은 수준으로 읽지 말아야 한다고 했듯, RAD Debugger도 Windows PDB 경로와 Linux DWARF 경로를 하나의 제품 성숙도로 묶으면 안 된다. 플랫폼별 승인 envelope가 필요하다.

## Minidump와 live debugging은 같은 질문에 답하지 않는다

`v0.9.29-alpha`는 Windows Minidump를 여는 초기 기능을 추가했다. Live debugging은 breakpoint를 추가하고 메모리와 register를 바꾸며 재실행할 수 있지만, 실행 timing을 교란한다. Crash dump는 사건 뒤의 정적 증거라 재현이 어려운 production 장애에 유리하지만 수집 당시 포함하지 않은 heap·handle·thread 정보는 복구할 수 없다.

도입 PoC에서는 둘을 경쟁 도구로 보지 말고 역할을 분리한다.

| 증거 경로 | 강점 | 놓치기 쉬운 것 | 검증 질문 |
|---|---|---|---|
| Live attach·launch | step, 조건부 breakpoint, 표현식·메모리 탐색 | timing 변화, deadlock 유발, production 접근 위험 | attach·detach 후 대상이 정상 복구되고 여러 프로세스 상태가 일관적인가 |
| Minidump | 재현 없이 사건 보존, 공유·보관 가능 | dump type에 없는 메모리, symbol 불일치 | 같은 dump를 WinDbg와 열었을 때 stack·module·exception이 일치하는가 |
| Core dump | Linux 사후 분석, 배포 바이너리와 결합 | container·namespace·별도 symbol 수집 누락 | build ID로 정확한 ELF·debug package를 찾을 수 있는가 |
| Trace·profile | 실행 흐름·성능 병목의 시간축 | 임의 시점의 전체 변수·메모리 상태 | dump의 crash thread와 직전 trace event를 같은 release·request로 연결하는가 |

[Magic Trace 글](/posts/github-trending-production-profiling-magic-trace/)의 고해상도 timeline은 “어디서 시간이 사라졌는가”에 답하고, debugger와 dump는 “멈춘 시점에 무엇이 들어 있었는가”에 답한다. 장애 대응 품질은 한 도구의 기능 수보다 symbol server, artifact retention, release SHA, dump·trace 상관관계에서 결정된다.

## 소켓 기반 IPC는 자동화 표면인 동시에 제어 표면이다

최신 릴리스는 그래픽 debugger와 명령을 주고받는 IPC를 shared-memory ring buffer에서 socket으로 변경했다. 기본 port는 `7423`이며 `--ipc_port`로 바꿀 수 있고, IP와 port를 지정해 다른 debugger instance에 명령을 보낼 수 있다고 설명한다. 사용 문서에는 continue, halt, kill, detach, attach, register·memory 조작과 project 명령이 포함된다.

이 기능은 IDE, 테스트 harness, 내부 crash triage 자동화와 연결하기 쉽다. 동시에 debugger가 가진 권한으로 대상 프로세스를 멈추고 메모리를 읽거나 제어할 수 있는 관리 인터페이스다. 릴리스가 원격 명령 가능성을 제공한다고 해서 네트워크 공개를 전제로 설계됐다고 가정해서는 안 된다.

PoC에서는 실제 bind address, 인증·암호화 유무, 명령 허용 범위, 방화벽과 사용자 권한을 packet·socket 수준에서 확인한다. 외부 연결이 필요 없다면 loopback과 host firewall로 제한하고, 진단 VM의 관리망 밖에서는 도달하지 못하게 한다. 원격 디버깅 요구가 있다면 VPN·jump host만으로 끝내지 말고 세션 승인, 짧은 수명, 명령 감사와 binary provenance를 별도 control plane에서 보완해야 한다. 디버거 port를 일반 개발 서비스처럼 열어 두면 code execution 권한에 가까운 인터페이스가 된다.

## Visual Studio·WinDbg·GDB·LLDB와의 선택은 대체보다 교차 검증이다

RAD Debugger의 장점은 대형 debug info를 RDI로 변환해 빠르게 탐색하려는 설계, 즉시 모드 UI, 멀티프로세스와 풍부한 watch visualizer, debugger·linker·binary utility를 함께 개선하는 흐름이다. 그러나 알파 단계에서 조직 표준을 한 번에 교체하는 선택은 위험하다.

| 선택지 | 강점 | 운영 비용·한계 | 적합한 역할 |
|---|---|---|---|
| RAD Debugger | 빠른 네이티브 UI, RDI 비동기 적재, 멀티프로세스, custom visualizer | 알파, Linux 초기 지원, RDI 변환 정확성·IPC 경계 검증 필요 | Windows 대형 C/C++ 로컬 개발의 보조 debugger, Linux 제한 PoC |
| Visual Studio Debugger | MSVC·IDE·NatVis·Windows 개발 흐름의 성숙도 | 무거운 IDE 결합, 대형 프로젝트 성능·자동화 제약 | Windows 애플리케이션의 기본 개발 경로 |
| WinDbg | Windows dump, symbol server, low-level 진단과 축적된 운영 절차 | 학습 곡선과 UI 복잡성 | production crash dump의 기준 판독기 |
| GDB | 넓은 Unix·언어·원격 target 생태계, script 가능성 | 대형 C++ 타입·UI 경험은 별도 도구 의존 | Linux live·core·embedded 기준 경로 |
| LLDB | LLVM·Clang 통합, script와 platform 지원 | compiler·platform 조합별 차이 | Clang 기반 프로젝트와 macOS·Linux 교차 검증 |

[C++ 기반 라이브러리 스택 글](/posts/github-trending-cpp-foundation-libraries/)에서 toolchain·ABI·패키지 조합을 함께 고정해야 한다고 했듯, debugger 역시 compiler 뒤에 독립적으로 붙는 뷰어가 아니다. MSVC·Clang·GCC, linker, debug format version, sanitizer, 최적화와 symbol 보관 정책의 일부다.

## 2주 PoC는 조작 속도보다 틀린 판단을 찾는다

![RAD Debugger 도입을 확대·보류·중단하는 기호 정확성·안정성·보안 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/rad-debugger-native-debugging/decision-gates.svg)

대상은 실제 코드베이스 전체보다 작은 진단 corpus로 시작한다. Windows는 MSVC PDB와 Clang-cl PDB, 가능하면 MinGW DWARF를 포함하고 Linux는 GCC·Clang의 `-O0`, `-O2`, frame pointer 유무를 나눈다. 템플릿, 상속, bitfield, TLS, exception, signal, shared library, child process, 매우 깊은 stack을 의도적으로 넣는다. 기존 debugger가 읽은 결과와 golden expectation을 함께 보관한다.

| 검증 영역 | 최소 측정값 | 중단 조건 예시 |
|---|---|---|
| 기호 변환 | 함수·라인·타입·배열·TLS·inline 일치율, RDI 생성·재사용 시간 | symbol loaded로 표시되지만 source·타입·값이 기준과 다름 |
| Stack·unwind | 최적화·예외·signal·깊은 재귀의 frame 정확성 | crash frame이 끊기거나 다른 함수로 보이는데 경고가 없음 |
| 프로세스 제어 | attach·detach·step·restart, child 추적, 중단 후 복구 | 프로세스 누락, deadlock, watchdog 재시작이나 데이터 손상 유발 |
| 안정성 | 대형 PDB·DWARF 메모리, load p95, freeze·crash, cache 무효화 | 진단 도구가 무제한 메모리를 쓰거나 stale RDI를 재사용 |
| Dump | Minidump·core module, exception, thread, symbol 일치 | 기준 도구와 crash 원인 또는 주요 변수 해석이 다름 |
| 보안 | IPC bind·도달 범위, 명령 권한, artifact·dump 접근 | 미승인 host가 debugger 제어 port에 접근하거나 dump가 평문 공유됨 |
| 운영성 | 재현 bundle 생성 시간, fallback 전환, issue 최소화 시간 | RAD 실패가 원래 장애보다 긴 별도 조사로 번지고 기준 도구로 복귀 불가 |

최종 승인 기준은 “F5와 watch가 빠르다”가 아니다. 잘못된 배열 길이, 끊어진 frame, stale symbol처럼 **사람이 믿기 쉬운 오답을 자동으로 탐지할 수 있는가**가 핵심이다. 첫 단계에서는 Windows 개발자 일부가 보조 debugger로 사용하고, production dump 판독은 WinDbg와 이중 확인하는 편이 안전하다. Linux는 지원하는 compiler·libc·linker 조합을 명시한 실험군으로 제한하고 core dump의 기준 판독기를 유지한다.

RAD Debugger의 장기 가치는 그래픽 debugger 하나를 더 만드는 데 있지 않다. 거대한 PDB와 DWARF를 RDI로 정규화하고, process control·expression evaluation·visualization·linking을 같은 성능 지향 도구 체계로 다시 설계하려는 데 있다. 그 방향은 대형 네이티브 프로젝트에 매력적이다. 다만 디버거의 오류는 눈에 띄는 실패보다 그럴듯한 오답이 더 위험하다. **도입 기준은 화면 반응 속도가 아니라 동일한 바이너리와 dump에서 기호·스택·변수 해석을 기준 도구와 반복해서 대조할 수 있는가**여야 한다.

> 1차 자료: [RAD Debugger 저장소와 기술 README](https://github.com/EpicGames/raddebugger), [MIT LICENSE](https://github.com/EpicGames/raddebugger/blob/master/LICENSE), [`v0.9.29-alpha` release](https://github.com/EpicGames/raddebugger/releases/tag/v0.9.29-alpha), [사용 설명서 release asset](https://github.com/EpicGames/raddebugger/releases/download/v0.9.29-alpha/raddbg_readme.md), [RDI library](https://github.com/EpicGames/raddebugger/tree/master/src/lib_rdi), [DWARF→RDI converter](https://github.com/EpicGames/raddebugger/tree/master/src/rdi_from_dwarf), [최근 commits](https://github.com/EpicGames/raddebugger/commits/master/), [공개 issues](https://github.com/EpicGames/raddebugger/issues), [공개 pull requests](https://github.com/EpicGames/raddebugger/pulls). Trending·저장소 수치는 2026년 10월 8일 08시 18분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
