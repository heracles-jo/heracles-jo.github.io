---
title: "AI 역공학 에이전트: REA 권한·증거 검증 기준"
description: "REA의 MCP 기반 바이너리·웹·앱 분석 구조를 살펴보고, 승인 범위·실행 격리·증거 추적·재현성으로 AI 역공학을 통제하는 도입 기준을 정리한다."
author: heracles-jo
date: 2026-10-10 08:35:00 +0900
categories: [Security, Developer Tools]
tags: [rea, reverse-engineering, mcp, binary-analysis, security-governance, ai-agent]
image:
  path: https://heracles-jo.github.io/assets/img/posts/rea-agent-reverse-engineering/cover.svg
  alt: "AI 역공학 에이전트가 승인된 분석 대상과 로컬 도구를 거쳐 근거가 연결된 결과를 만드는 흐름"
---

역공학에 AI 에이전트를 붙이면 가장 먼저 빨라지는 것은 디컴파일 자체가 아니다. 문자열과 호출 관계를 오가고, 웹 요청을 캡처하며, Electron의 renderer와 main process 경계를 추적하고, 발견한 단서를 다시 확인하는 **조사 루프**가 짧아진다. 문제는 같은 자동화가 권한을 잘못 해석하거나 불완전한 근거를 확정 사실처럼 포장할 때 피해 범위도 함께 넓힌다는 점이다.

[morluto/rea](https://github.com/morluto/rea)는 native binary, JavaScript·Electron, .NET assembly, Android APK, firmware, 웹 페이지와 네트워크 캡처를 하나의 CLI와 MCP 서버로 연결한다. Hopper·Ghidra·IDA 같은 분석 엔진과 브라우저·프로세스 관찰 도구를 에이전트가 호출하고, 결과에 evidence와 limitation을 붙이는 구조다. 이 접근의 실무 가치는 “프롬프트 한 번으로 앱을 복제한다”는 문구보다 **서로 다른 분석 도구의 관찰 결과를 동일한 조사 문맥에서 연결할 수 있다는 것**에 있다.

2026년 10월 10일 08시 47분 KST 전후 GitHub Trending daily에서 REA는 **15,335 stars today**로 표시됐다. 같은 시점 GitHub API 기준 저장소는 45,187 stars, 7,142 forks, 열린 issue와 PR을 합친 94개, MIT 라이선스였고 10월 10일 KST 아침까지 커밋이 이어졌다. API가 반환한 최신 공개 release는 `rea-agents-6.2.0`이었지만 main의 `package.json`은 `6.3.0`이어서, main 문서와 설치 가능한 공개 artifact가 잠시 어긋날 수 있는 시점이었다. 수치와 버전은 확인 당시의 공개 스냅샷이며 정확성·합법성·프로덕션 적합성을 보증하지 않는다. 이번 실행에서는 Search Console·Analytics의 실제 검색어와 노출 데이터에 접근하지 못했으므로 선정 근거로 사용하지 않았다.

## 후보 다섯 개에서 “분석 권한과 증거”를 남긴 이유

오늘 daily·weekly 상위에는 전날에도 보였던 에이전트 skill, 장기 기억, 콘솔 호환 계층, LLM gateway가 반복됐다. 저장소 이름이 새로워도 기존 글과 검색 의도가 같으면 주제 권위보다 키워드 자기잠식이 커진다. REA는 전날 후보로 검토했지만, 오늘은 단순 도구 소개가 아니라 **에이전트가 제3자 실행 파일과 런타임을 조사할 때 승인·격리·증거를 어떻게 설계할 것인가**라는 별도 질문이 남았다.

| 후보 | 확인 시점 신호 | 중복·검색 의도·장기 가치 판단 |
|---|---|---|
| [morluto/rea](https://github.com/morluto/rea) | daily 15,335, API 45,187 stars, MIT, 공개 release 6.2.0 | binary·웹·앱을 잇는 MCP 조사 계층과 권한·증거 거버넌스가 독립적인 검색 의도를 만든다. |
| [boykopovar/AnyPS5](https://github.com/boykopovar/AnyPS5) | daily 5,925, 22,186 stars, GPL-2.0 | 호환 계층은 흥미롭지만 플랫폼 콘텐츠 권리와 재배포 범위가 중심이어서 일반 조직의 적용 범위가 좁다. |
| [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) | daily 714, 28,235 stars, Apache-2.0 | knowledge worker plugin은 기존 에이전트 skill·공급망·업무 자동화 글과 중심 독자가 겹친다. |
| [BerriAI/litellm](https://github.com/BerriAI/litellm) | daily 95, 60,645 stars, API 라이선스 `NOASSERTION` | 모델 gateway는 이미 Switchyard 중심의 라우팅·비용·거버넌스 검색 의도를 다뤘다. |
| [mvschwarz/openrig](https://github.com/mvschwarz/openrig) | weekly 2,693, 6,438 stars, Apache-2.0 | 지속형 에이전트 팀은 Orca·Google AX의 병렬 실행과 오케스트레이션 논지에 가깝다. |

[네이티브 디버깅 글](/posts/rad-debugger-native-debugging/)은 PDB·DWARF·crash dump를 정확히 해석하는 도구 관점에 집중했다. [MVT 모바일 포렌식 글](/posts/mvt-mobile-spyware-forensics/)은 증거 수집과 IOC 판정에서 오탐·미탐을 통제하는 방법을 다뤘다. REA를 보는 관점은 그 사이에 있다. 분석 도구의 출력을 에이전트가 연쇄 호출할 때 **누가 어떤 대상을 어떤 권한으로 열었고, 어느 결론이 어느 바이트·요청·관찰에서 나왔는지**를 유지하는 문제다.

## 하나의 MCP 뒤에는 서로 다른 위험 등급의 실행 경로가 있다

REA의 표면은 MCP와 CLI지만 실제 작업은 한 종류가 아니다. 정적 JavaScript·.NET 분석은 사용자가 제공한 파일을 읽는 경로에 가깝다. native 분석은 Hopper·Ghidra·IDA에 파일 파싱과 디컴파일을 위임한다. 웹 분석은 브라우저의 DOM, script, network observation을 다루며, process capture는 선택한 프로그램을 현재 사용자 권한으로 실행하고 상호작용할 수 있다. Android와 firmware 분석도 JADX, Binwalk, Unblob 같은 외부 도구에 의존한다.

![REA가 분석 대상을 MCP 조사와 로컬 provider로 연결하고 evidence bundle을 만드는 아키텍처](https://heracles-jo.github.io/assets/img/posts/rea-agent-reverse-engineering/architecture.svg)

이 차이를 “REA 도구 사용”이라는 단일 권한으로 묶으면 안 된다. 최소한 네 개의 lane으로 분리해야 한다.

1. **정적 읽기**: 복사본의 파일 inventory, 문자열, metadata, import·call graph를 읽는다.
2. **격리된 파싱**: Ghidra·JADX·archive extractor처럼 복잡한 parser가 비신뢰 입력을 연다.
3. **런타임 관찰**: process·browser·Electron을 실행해 파일·network·IPC 변화를 본다.
4. **변경·재구현**: 분석 결과를 근거로 코드나 patch를 만들고 별도 프로젝트에서 시험한다.

앞 단계의 승인이 뒤 단계까지 자동으로 확장돼서는 안 된다. “이 바이너리를 살펴봐도 된다”는 말이 곧 “인터넷 연결 상태로 실행하고 로그인하며 트래픽을 가로채도 된다”는 뜻은 아니다. 에이전트의 tool catalog도 lane별로 분리하고, runtime 도구는 대상 hash, 실행 사용자, network policy, writable path, 시간 제한을 명시한 작업에서만 열어 주는 편이 안전하다.

## 로컬 분석은 샌드박스를 의미하지 않는다

REA Security Policy는 provider bridge session에 random capability token과 current-user Unix socket을 사용한다고 설명한다. token을 process argument나 environment variable 대신 private session descriptor로 전달하는 것은 같은 호스트의 우발적 노출을 줄이는 좋은 경계다. Ghidra 경로도 격리된 temporary project와 private home·cache·runtime directory를 사용하고, 요청한 target만 import하며 CPU·heap과 protocol message를 제한한다.

그러나 공식 문서가 명확히 밝히듯 이것은 sandbox가 아니다. 같은 OS 사용자로 이미 실행 중인 악성 process를 막지 못하고, 비신뢰 바이너리 파싱은 선택한 provider와 사용자 권한에 위임된다. runtime capture는 더 직접적이다. 대상 프로그램이 실행되면 그 사용자가 읽을 수 있는 파일, credential helper, browser profile, local service에 접근할 가능성이 생긴다.

따라서 PoC 환경은 일상 개발 장비가 아니라 폐기 가능한 VM 또는 전용 분석 host가 낫다. 기본 정책은 outbound network 차단, read-only sample mount, 빈 home directory, 개인 SSH agent·cloud credential·browser profile 미탑재, clipboard·shared folder 비활성화다. 분석 엔진의 cache와 임시 project도 sample별 workspace에 가두고 종료 후 hash와 log를 남긴 뒤 폐기한다. macOS·Windows에서 host 통합 기능이 필요한 경우에도 production credential이 있는 주 사용자 session과 분리해야 한다.

[OpenShell 정책 런타임 글](/posts/openshell-agent-policy-runtime/)에서 살펴본 kernel 격리, egress 제한, 목적지 제한 credential 주입이 여기서도 기준선이 된다. REA의 local socket과 capability token은 provider session을 구분하지만, 파일·프로세스·네트워크 권한 전체를 강제하지는 않는다. 제품의 보안 경계를 그 제품이 주장하는 범위보다 넓게 해석하지 않는 것이 중요하다.

## 에이전트의 설명보다 evidence chain을 먼저 본다

역공학 결과에는 구조적으로 불확실성이 많다. stripped symbol 때문에 함수 이름을 추론해야 하고, decompiler가 제어 흐름을 단순화하며, source map이 오래됐거나 변조됐을 수 있다. runtime에서 관찰하지 못한 branch를 static graph만으로 “호출되지 않는다”고 결론 내리기도 쉽다. 에이전트는 이런 빈틈을 자연스러운 서술로 메워 버릴 수 있다.

REA의 최근 changelog에 evidence context, target identity, source-map URL, snapshot revision history, unknown value 보존과 관련된 breaking change와 bug fix가 집중된 이유도 이 문제를 보여 준다. 분석 결과 schema가 바뀔 때 예전 저장 데이터를 임의 필드 추가로 맞추지 말고 재생성하라는 지침은 역공학에서 provenance가 단순 metadata가 아님을 뜻한다.

실무 결과물은 최소한 다음 연결을 보존해야 한다.

- target의 원본 hash, 수집 경로, 승인 ticket, 분석용 복사본 hash
- REA·provider·plugin·JDK·Node 버전과 host OS
- 정적 관찰인지 runtime 관찰인지, 실행했다면 network와 filesystem 정책
- conclusion이 참조한 address, symbol, byte range, source location, request·response ID
- decompiler output과 raw assembly·metadata의 대응 관계
- `verified`, `inferred`, `unknown`, `contradicted`, `out-of-scope` 같은 판정 상태
- 재실행 command, fixture와 결과 artifact의 digest

에이전트 보고서에 “검색 기능은 로컬 SQLite를 사용한다”는 문장이 있다면 package import, SQL string, runtime file open, network absence 중 무엇을 확인했는지 구분해야 한다. 정적 코드에 SQLite dependency가 있다는 사실만으로 실제 데이터 경로를 확정할 수 없고, 한 번의 runtime에서 외부 요청이 보이지 않았다는 사실도 모든 경로의 offline 동작을 증명하지 않는다.

[Cloudflare 보안 감사 skill 글](/posts/cloudflare-security-audit-skill-validation-pipeline/)에서 다룬 독립 반증 단계가 유용하다. 첫 번째 에이전트가 가설과 근거를 모으면, 두 번째 검증 lane은 결론 문장을 보지 않고 원본 artifact와 evidence locator만 받아 같은 판단에 도달하는지 확인한다. 불일치하면 더 그럴듯한 설명을 고르는 대신 `unknown`으로 남기고 추가 관찰을 설계해야 한다.

## 합법성은 면책 문구가 아니라 작업 입력이어야 한다

REA README는 lawful research와 필요한 authorization을 전제로 하며 불법·무단 사용을 지지하지 않는다고 명시한다. 이 문구는 중요하지만 자동화된 조사에서 충분한 통제는 아니다. 제품 소유권, 고객 계약, EULA, 저작권 예외, 영업비밀, 접근통제 우회, 개인정보, 취약점 공개 의무는 대상과 관할에 따라 달라진다. 이 글은 법률 자문이 아니며 경계가 불명확한 제3자 제품은 조직의 법무·보안 검토가 먼저다.

작업 요청에는 자연어로 “분석해 줘”만 쓰지 말고 authorization manifest를 붙이는 편이 낫다.

| 필드 | 예시 판단 | 에이전트가 지켜야 할 제한 |
|---|---|---|
| 대상 소유·승인 | 자사 앱, 고객이 서면 승인한 build | 승인된 hash와 version만 연다. |
| 목적 | 호환성, malware triage, 보안 검증, 데이터 복구 | 기능 복제·우회처럼 목적이 바뀌면 중단한다. |
| 허용 기법 | static only / isolated runtime / network capture | 목록 밖 provider와 runtime tool을 호출하지 않는다. |
| 데이터 경계 | test account, synthetic data | 실제 고객 계정·개인정보·production token을 사용하지 않는다. |
| 산출물 | 내부 report, patch, IOC | 원본 binary·proprietary code의 외부 공개와 재배포를 막는다. |
| 종료 조건 | protection bypass 필요, scope 밖 host 발견 | 자동 확대하지 않고 사람 승인을 요구한다. |

특히 에이전트가 “비슷한 기능을 구현”할 때는 아이디어와 API behavior, 표현과 코드 복제를 분리해야 한다. clean-room이 필요한 상황이라면 분석자와 구현자를 분리하고, 구현자는 승인된 behavior specification과 테스트만 받아야 한다. 원본 decompiled code나 고유 asset이 생성 모델의 장기 memory·외부 provider log로 흘러가지 않는지도 확인해야 한다.

## 가장 위험한 실패는 틀린 결론보다 조용한 범위 확대다

![AI 역공학 PoC에서 승인·격리·증거·재현성을 순서대로 통과시키는 의사결정 게이트](https://heracles-jo.github.io/assets/img/posts/rea-agent-reverse-engineering/decision-gates.svg)

다음 실패 모드는 정확도 테스트만으로 잡히지 않는다.

- **target drift**: 사용자가 승인한 binary 대신 updater가 내려받은 새 파일이나 같은 이름의 다른 process를 분석한다.
- **provider drift**: main 문서의 schema와 공개 npm release가 달라 tool contract와 저장 snapshot을 잘못 해석한다.
- **runtime escape**: sample이 분석 workspace 밖의 home, keychain, socket, local service를 읽는다.
- **evidence laundering**: decompiler 추론이 에이전트 요약을 거치며 “관찰된 사실”로 바뀐다.
- **prompt injection**: 웹 페이지, README, embedded string의 문장이 분석 지시처럼 모델에 들어간다.
- **cleanup illusion**: 임시 project 삭제는 성공했지만 provider cache, crash dump, HAR, shell history에 민감 자료가 남는다.
- **scope creep**: 연결된 domain, updater, plugin, 다른 process를 발견했다는 이유로 승인 없이 조사를 확장한다.

외부 콘텐츠는 지시가 아니라 evidence payload로 표시해야 한다. binary string이나 웹 DOM에서 “보안 검사를 중단하라”는 문장을 찾더라도 그것은 분석 대상의 데이터일 뿐 tool policy를 바꿀 수 없다. 실행 권한과 조사 범위는 사용자 승인 manifest와 별도 policy engine에서만 와야 한다. 위험 명령을 실행 직전에 차단하는 방법은 [dcg 도입 기준 글](/posts/ai-agent-destructive-command-guard/)의 사전 실행 hook 설계와 연결된다.

## 2주 PoC는 속도보다 조사 품질과 통제 실패를 측정한다

PoC 대상은 세 종류면 충분하다. source와 기대 동작을 아는 내부 fixture, 공개 라이선스와 재현 가능한 build가 있는 sample, 실제 운영 환경을 모사하되 synthetic data만 포함한 test application이다. blind target만 사용하면 에이전트가 맞았는지 판단할 기준이 없고, 실제 proprietary target만 사용하면 안전한 실패 주입이 어렵다.

1. **관찰 정확도**: 함수·route·IPC·network behavior에 대한 ground truth 대비 precision과 recall을 잰다.
2. **근거 완전성**: 결론 중 원본 locator와 tool·version이 연결된 비율, `unknown`을 적절히 남긴 비율을 측정한다.
3. **재현성**: 같은 target hash와 고정 버전에서 다른 analyst가 evidence bundle만으로 같은 결론을 재생성하는지 본다.
4. **격리**: canary file, fake credential, blocked domain을 두고 read·write·egress 시도를 기록한다. 허용 밖 접근은 0건이어야 한다.
5. **범위 통제**: redirect, child process, updater, linked binary를 발견했을 때 자동 확장하지 않고 중단하는지 시험한다.
6. **불확실성 보존**: stripped symbol, 깨진 source map, timeout, truncated capture에서 추론이 확정 문장으로 승격되지 않는지 검토한다.
7. **버전 전환**: 공개 release와 main schema가 다를 때 저장 snapshot을 잘못 migration하지 않고 호환 불가를 드러내는지 확인한다.
8. **비용과 시간**: 사람 기준선 대비 첫 유효 가설, 검증된 결론, 오탐 제거까지 걸린 시간과 provider 비용을 나눠 기록한다.
9. **정리**: VM, temporary project, HAR, report, model provider retention에서 canary가 정해진 기간 안에 제거되는지 확인한다.

확대 조건은 “분석이 빨랐다”가 아니다. 승인 밖 runtime·network 접근이 없어야 하고, 핵심 결론은 재현 가능한 evidence locator를 가져야 하며, target·provider·schema drift가 탐지돼야 한다. 미확인 가설을 `unknown`으로 남긴 결과가 조금 느리더라도, 근거 없는 확신을 빠르게 만드는 결과보다 운영 가치가 높다.

REA는 여러 역공학 도구를 에이전트가 사용할 수 있는 공통 조사 계층으로 묶고, 결과를 evidence 중심으로 다루려는 방향을 보여 준다. 빠르게 넓어지는 target 지원과 촘촘한 verification script는 강점이다. 반면 잦은 breaking change, 외부 provider 의존성, 현재 사용자 권한으로 동작하는 runtime 경로, 법적 승인 범위는 설치 명령 하나로 해결되지 않는다.

도입 판단의 핵심은 “AI가 이 앱을 이해했는가”가 아니다. **승인된 대상을 벗어나지 않았는지, 실행 경계가 실제로 강제됐는지, 결론을 원본 증거까지 되짚을 수 있는지, 다른 사람이 같은 결과를 재현할 수 있는지**다. 이 네 조건을 통과하면 역공학 에이전트는 반복 탐색을 줄이는 강력한 조사 보조 도구가 된다. 하나라도 빠지면 빠른 분석은 빠른 오판과 범위 확대를 의미할 수 있다.

> 1차 출처: [REA 저장소와 README](https://github.com/morluto/rea), [Security Policy](https://github.com/morluto/rea/blob/main/SECURITY.md), [Changelog](https://github.com/morluto/rea/blob/main/CHANGELOG.md), [MCP contracts](https://github.com/morluto/rea/blob/main/docs/mcp-contracts.md), [CLI and Evidence](https://github.com/morluto/rea/blob/main/docs/cli.md), [Testing](https://github.com/morluto/rea/blob/main/docs/testing.md), [공개 releases](https://github.com/morluto/rea/releases), [최근 commits](https://github.com/morluto/rea/commits/main/), [공개 issues](https://github.com/morluto/rea/issues), [MIT License](https://github.com/morluto/rea/blob/main/LICENSE). Trending·저장소 수치는 2026년 10월 10일 08시 47분 KST 전후 확인한 공개 스냅샷이며 이후 달라질 수 있다.
