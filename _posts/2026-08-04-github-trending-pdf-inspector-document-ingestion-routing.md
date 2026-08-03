---
title: "PDF Inspector와 문서 수집 라우팅: OCR 비용을 줄이는 Rust 기반 PDF 분류 전략"
description: "GitHub Trending에 오른 firecrawl/pdf-inspector를 중심으로 PDF 분류, 구조 기반 텍스트 추출, OCR 라우팅, RAG 문서 수집 파이프라인의 비용·성능·보안 리스크를 실무 관점에서 분석한다."
author: heracles-jo
date: 2026-08-04 07:29:10 +0900
categories: [Data Engineering, Document AI]
tags: [github-trending, pdf-inspector, pdf-parsing, document-ai, ocr, rag, rust, wasm, python, nodejs, firecrawl, pymupdf, markitdown, unstructured]
image:
  path: https://heracles-jo.github.io/assets/img/posts/github-trending-pdf-inspector-document-ingestion-routing/cover.svg
  alt: "PDF Inspector가 텍스트 기반 PDF와 스캔 PDF를 먼저 분류해 OCR과 문서 AI 파이프라인의 비용과 지연을 줄이는 문서 수집 전략"
---

GitHub Trending daily에서 [firecrawl/pdf-inspector](https://github.com/firecrawl/pdf-inspector)가 눈에 띈 이유는 “또 하나의 PDF 파서”가 등장했기 때문만은 아니다. 2026년 8월 4일 오전 KST 확인 시점의 공개 스냅샷 기준으로 이 저장소는 GitHub Trending daily에 **1,769 stars today**로 표시됐고, GitHub API 기준 약 **8,014 stars, 536 forks, 59 open issues**를 보유했다. 저장소는 2026년 2월 생성됐으며, 2026년 8월 3일에도 `lopdf` 의존성 업데이트, GitHub Actions 업데이트, Linux musl 및 ARM64 N-API 바이너리 추가 같은 커밋이 이어졌다. 릴리스 탭에는 별도 GitHub Release가 없었지만 README에는 crates.io, npm, PyPI 배포 배지가 연결되어 있었다. 이 수치와 활동 정보는 확인 시점의 스냅샷이며 이후 변동될 수 있다.

오늘의 기술 흐름은 명확하다. **문서 AI와 RAG 파이프라인에서 모든 PDF를 무조건 OCR 또는 LLM 파서로 보내던 방식이, 먼저 저비용 구조 분석을 수행한 뒤 문서 유형별로 경로를 나누는 하이브리드 수집 아키텍처로 이동하고 있다.** pdf-inspector는 Rust로 구현된 PDF 분류·텍스트 추출 라이브러리다. README는 텍스트 기반, 스캔, 이미지 기반, 혼합 PDF를 샘플링으로 판별하고, 위치 정보가 있는 텍스트를 추출하며, 깨끗한 Markdown으로 변환한다고 설명한다. Python, Node.js/Bun N-API, 브라우저 WebAssembly 바인딩을 제공한다는 점도 중요하다. 문서 수집은 백엔드 배치 작업, 웹 크롤러, 사내 업로드 포털, 브라우저 기반 전처리 UI 등 여러 지점에서 발생하기 때문이다.

![PDF 수집 파이프라인에서 구조 기반 분류와 OCR 라우팅이 나뉘는 아키텍처](https://heracles-jo.github.io/assets/img/posts/github-trending-pdf-inspector-document-ingestion-routing/architecture.svg)

## 오늘의 GitHub Trending 후보 비교: 왜 pdf-inspector인가

이번 조사는 GitHub Trending daily와 weekly를 함께 확인하고, 최근 블로그에서 이미 다룬 로컬 LLM 추론, 에이전트 스킬, AI 코딩 도구, 클라우드 네이티브 GIS, 하드웨어 보안 워크벤치와 겹치지 않는 주제를 우선했다. daily 상위권에는 `lyogavin/airllm`, `zhaoxuya520/reverse-skill`, `esengine/DeepSeek-Reasonix`, `TencentCloud/TencentDB-Agent-Memory`처럼 AI 에이전트·로컬 추론·코딩 도구와 가까운 저장소가 많았다. weekly에서도 `book-to-skill`, `openwork`, `airi`, `GeoLibre` 같은 후보가 보였지만 이 블로그의 최근 각도와 중복 위험이 컸다.

| 후보 저장소 | 확인 시점의 공개 신호 | 중복 위험 | 실무적으로 읽을 수 있는 흐름 |
| --- | --- | --- | --- |
| [firecrawl/pdf-inspector](https://github.com/firecrawl/pdf-inspector) | daily 1,769 stars today, 약 8,014 stars, Rust, Python/Node/WASM 바인딩, 2026년 8월 커밋 활동 | 낮음~중간 | 문서 AI 파이프라인에서 OCR 이전의 저비용 분류·라우팅 계층이 중요해짐 |
| [block/buzz](https://github.com/block/buzz) | weekly 8,217 stars, 약 21,793 stars, Rust, self-hostable human-agent workspace, 최근 desktop 릴리스 | 높음 | 인간과 에이전트가 같은 워크스페이스에서 협업하는 흐름이나 에이전트 네이티브 소프트웨어 각도와 인접 |
| [pascalorg/editor](https://github.com/pascalorg/editor) | weekly 상위, 약 20,927 stars, React Three Fiber/WebGPU 기반 3D 건축 편집기, v1.0.0-beta.1 | 중간 | 브라우저 기반 3D 제작 도구의 성숙이라는 흥미로운 흐름이나 최근 3D 파이프라인 글과 일부 인접 |
| [shiyu-coder/Kronos](https://github.com/shiyu-coder/Kronos) | daily 상위, 약 35,806 stars, 금융 시장용 foundation model, 2026년 4월 이후 푸시 활동은 제한적 | 중간 | 금융 시계열 foundation model 흐름은 중요하지만 최근 agentic finance 글과 겹칠 수 있음 |
| [TencentCloud/TencentDB-Agent-Memory](https://github.com/TencentCloud/TencentDB-Agent-Memory) | daily 1,091 stars today, 약 12,016 stars, v2.0.0 릴리스, 팀 단위 agent memory hub | 높음 | 에이전트 메모리 거버넌스는 중요하지만 최근 AI memory·skill·agent workflow 주제와 중복 |

pdf-inspector를 선택한 이유는 저장소 하나의 인기도보다 “문서 수집의 병목이 어디로 이동하는가”를 설명하기 좋기 때문이다. 많은 조직이 RAG, 검색, 지식관리, 계약서 분석, 고객지원 자동화, 리서치 자동화 프로젝트를 시작할 때 PDF를 단일 입력 포맷처럼 취급한다. 그러나 실제 PDF는 디지털 텍스트, 스캔 이미지, 이미지 위에 일부 텍스트 레이어가 얹힌 혼합 문서, 깨진 폰트 인코딩, 2단 편집, 표와 차트, 워터마크, 회전된 페이지가 뒤섞인 컨테이너다. 이 차이를 초기에 구분하지 못하면 성능, 비용, 품질, 보안 리스크가 뒤에서 폭발한다.

## pdf-inspector의 핵심 동작: OCR이 아니라 “OCR을 언제 쓸지” 결정한다

pdf-inspector의 README와 Python/Node/WASM 문서는 공통적으로 세 가지 기능을 강조한다. 첫째는 **Smart classification**이다. PDF를 `text_based`, `scanned`, `image_based`, `mixed` 같은 유형으로 분류하고, 신뢰도 점수와 페이지별 OCR 라우팅 정보를 제공한다. 문서에 따르면 샘플링 기반 분류는 약 10~50ms 수준을 목표로 하며, Firecrawl은 텍스트 기반 PDF를 로컬에서 200ms 미만으로 처리해 OCR이 필요 없는 약 54%의 PDF에 대해 비싼 OCR 서비스를 건너뛰기 위해 이 도구를 만들었다고 설명한다. 이 54% 수치는 프로젝트 설명에 제시된 맥락상의 수치로, 특정 조직의 문서 집합에 그대로 적용된다고 가정해서는 안 된다.

둘째는 **layout-aware extraction**이다. 단순히 텍스트 스트림을 읽는 것을 넘어 X/Y 좌표, 폰트 정보, 다단 읽기 순서, RTL 지원, CID/Type0 폰트와 ToUnicode CMap 처리, 깨진 인코딩 감지 같은 요소를 다룬다. PDF는 화면에 보이는 순서와 내부 객체 순서가 일치하지 않는 경우가 많다. 특히 논문, 보고서, 청구서, 표가 많은 재무 문서에서는 “텍스트가 추출된다”와 “검색·요약·질의응답에 쓸 수 있는 순서로 추출된다” 사이에 큰 차이가 있다.

셋째는 **Markdown conversion과 바인딩 전략**이다. README는 headings, lists, code blocks, bold/italic, URL linking, drawing operation과 text-alignment heuristic을 함께 쓰는 table detection을 언급한다. 또한 Rust core를 Python(PyO3), Node.js/Bun(napi-rs), 브라우저 WebAssembly로 노출한다. 이 조합은 문서 AI 파이프라인에서 중요하다. 데이터팀은 Python 배치와 Airflow/Prefect 작업에서, 웹 플랫폼팀은 Node API와 크롤러에서, 제품팀은 브라우저 업로드 화면이나 내부 도구에서 같은 분류 결과를 사용할 수 있다. 동일한 core를 여러 런타임에 노출하면 품질 정책과 라우팅 기준을 통일하기 쉽다.

## 왜 지금 PDF 분류 계층이 중요해졌나

첫 번째 배경은 RAG 시스템의 운영 비용이다. 초기 RAG PoC에서는 문서 수가 적고, 모든 파일을 고가의 OCR 또는 문서 AI API로 보내도 비용이 크게 보이지 않는다. 문제는 사내 문서 저장소, 고객 업로드, 웹 크롤링, 계약서 아카이브, 매뉴얼, 연구 보고서처럼 입력 규모가 커질 때 발생한다. 10만 개 PDF 중 절반이 이미 텍스트 레이어를 가진 문서라면, 이들을 OCR로 다시 처리하는 것은 비용뿐 아니라 지연, 장애 면적, 개인정보 노출 면적을 불필요하게 키운다. 반대로 스캔 문서를 구조 기반 파서로만 처리하면 빈 텍스트 또는 깨진 텍스트가 인덱스에 들어가 검색 품질을 떨어뜨린다.

두 번째 배경은 문서 품질 관측성의 필요성이다. 많은 RAG 실패는 모델이 나빠서가 아니라 수집 단계에서 이미 잘못된 텍스트가 들어갔기 때문에 발생한다. 표의 열이 섞이고, 2단 문서의 좌우 문단이 번갈아 붙고, 헤더·푸터·페이지 번호가 반복되며, 이미지 기반 차트가 누락된다. 이 상태에서 임베딩 모델이나 LLM을 바꿔도 근본 문제가 해결되지 않는다. pdf-inspector 같은 계층은 “이 문서는 구조 추출로 충분한가”, “이 페이지는 OCR이 필요한가”, “인코딩이 깨졌는가”, “표 추출 신뢰도가 낮은가” 같은 품질 신호를 앞단에서 남길 수 있다.

세 번째 배경은 데이터 거버넌스다. 문서에는 계약 금액, 고객 개인정보, 내부 설계, 보안 정책, 법무 의견처럼 민감한 정보가 포함된다. 모든 문서를 외부 OCR API나 LLM API로 전송하는 전략은 도입 심사에서 막히기 쉽다. 구조 기반 로컬 처리가 가능한 문서는 사내 환경에서 처리하고, OCR이 필요한 일부 문서만 승인된 경로로 보내며, 민감도에 따라 온프레미스 OCR 또는 격리된 워커로 분기하는 설계가 현실적이다. 이때 필요한 것은 “OCR 엔진 자체”보다 “어떤 문서를 어느 경로로 보낼지 결정하는 분류와 감사 로그”다.

## 대체 도구와 비교: pdf-inspector의 위치

PDF 처리 도구는 기능 이름만 보면 모두 비슷해 보인다. 그러나 실무에서는 목적이 다르다. 문서 뷰어에 가까운 라이브러리, 텍스트 추출 라이브러리, OCR 엔진, LLM 기반 파서, RAG용 문서 로더는 서로 다른 최적화 지점을 가진다.

| 도구/접근 | 강점 | 한계 | pdf-inspector와의 차이 |
| --- | --- | --- | --- |
| [PyMuPDF](https://github.com/pymupdf/PyMuPDF) / fitz | 성숙한 PDF 렌더링·추출 생태계, Python에서 널리 사용 | 라우팅 정책과 Markdown 품질 관측성은 별도 구현 필요 | pdf-inspector는 분류·Markdown·OCR 라우팅을 전면에 둔다 |
| [Microsoft MarkItDown](https://github.com/microsoft/markitdown) | 다양한 파일을 Markdown으로 변환하는 범용성 | PDF별 세밀한 품질 신호와 하이브리드 OCR 라우팅은 목적이 다름 | pdf-inspector는 PDF 전용 구조 분석과 빠른 분류에 집중한다 |
| [Unstructured](https://github.com/Unstructured-IO/unstructured) | 문서 AI 파이프라인과 파티셔닝 생태계가 넓음 | 배포 무게와 의존성, 비용 구조가 커질 수 있음 | pdf-inspector는 가벼운 전처리·분류 계층으로 배치하기 좋다 |
| OCR 엔진(Tesseract, cloud OCR 등) | 이미지 문서와 스캔본 처리에 필수 | 텍스트 PDF에 쓰면 비용·지연 낭비, 개인정보 전송 리스크 | pdf-inspector는 OCR을 대체하기보다 OCR 호출 대상을 줄인다 |
| LLM 기반 문서 파서 | 의미 해석, 복잡한 표·양식 이해에 강할 수 있음 | 비용, 지연, 환각, 감사 가능성, 데이터 경계 문제가 큼 | pdf-inspector는 LLM 이전에 결정론적 품질 신호를 만든다 |

README의 벤치마크 표도 이 위치를 뒷받침한다. 프로젝트 문서는 opendataloader-bench 200개 PDF 코퍼스 기준으로 pdf-inspector가 overall 0.875, reading order 0.915, tables(TEDS) 0.814, speed 0.470s를 기록했다고 제시한다. 같은 표에서 liteparse는 overall 0.873과 speed 0.750s, opendataloader는 0.831과 2.569s, pymupdf4llm은 0.735와 17.117s, markitdown은 0.589와 16.165s로 표시되어 있다. 이 벤치마크는 2026년 7월 31일 Apple M4 Pro에서 갱신됐고 OCR과 모델 기반 파싱은 제외했다고 문서에 명시되어 있다. 벤치마크는 특정 코퍼스와 설정의 스냅샷이므로 구매·도입 결정을 대신할 수는 없지만, “가벼운 구조 기반 전처리 계층”이라는 방향성은 충분히 읽을 수 있다.

![문서 처리 방식별 비용, 정확도, 운영 리스크를 비교한 선택 매트릭스](https://heracles-jo.github.io/assets/img/posts/github-trending-pdf-inspector-document-ingestion-routing/decision-matrix.svg)

## 실무 도입 시 장점: 비용 절감보다 더 중요한 것은 실패의 조기 분리

가장 직접적인 장점은 OCR 비용과 지연을 줄일 수 있다는 점이다. 하지만 실무적으로 더 큰 장점은 실패 유형을 앞단에서 분리할 수 있다는 것이다. 문서 수집 파이프라인은 보통 “파일 업로드 → 파싱 → 청킹 → 임베딩 → 검색 인덱싱 → 질의응답”으로 이어진다. 앞단에서 잘못 파싱된 문서는 뒤 단계에서 계속 비용을 만든다. 임베딩은 엉뚱한 문단을 벡터화하고, 검색은 관련 없는 청크를 반환하며, LLM은 부족한 근거로 답변을 생성한다. pdf-inspector 같은 분류 계층은 스캔 문서, 혼합 문서, 깨진 인코딩 문서, 표 중심 문서를 별도 큐로 보내는 기준점을 제공한다.

두 번째 장점은 아키텍처 유연성이다. Python 바인딩은 데이터 엔지니어링 배치와 분석 환경에 맞고, Node/Bun 바인딩은 웹 크롤러나 API 서버에 맞으며, WASM 바인딩은 브라우저에서 파일을 업로드하기 전에 로컬로 분류하는 UX를 가능하게 한다. 특히 브라우저 WASM 문서는 PDF bytes가 업로드되지 않고 로컬에서 파싱되며, CMaps가 내장되어 CJK 폰트 디코딩이 파일시스템에 의존하지 않는다고 설명한다. 대용량 문서는 Web Worker에서 실행하라는 권고도 실무적으로 중요하다. 이 구조는 민감 문서를 서버로 보내기 전에 “이 파일은 OCR이 필요한가”, “페이지 수가 너무 많은가”, “추출 가능한 텍스트가 있는가”를 사용자 단말에서 먼저 확인하는 설계로 확장될 수 있다.

세 번째 장점은 정책화 가능성이다. 예를 들어 조직은 다음과 같은 규칙을 만들 수 있다. 텍스트 기반이고 confidence가 높은 문서는 로컬 Markdown 추출 후 바로 인덱싱한다. scanned 또는 image_based 문서는 OCR 큐로 보낸다. mixed 문서는 페이지별로 구조 추출과 OCR을 나누고 결과를 병합한다. broken encoding이 감지되면 OCR fallback을 강제한다. 표가 많거나 quality score가 낮은 문서는 사람이 검수하거나 고급 문서 AI 파서로 보낸다. 이 정책은 단순한 비용 최적화를 넘어 문서 처리의 감사 가능성과 재현성을 높인다.

## 한계와 리스크: PDF는 “낡은 포맷”이 아니라 복잡한 실행 경계다

첫 번째 한계는 PDF 자체의 복잡성이다. PDF는 본질적으로 문서의 시각적 표현을 보존하기 위한 포맷이지, 데이터베이스처럼 구조화된 의미를 보장하는 포맷이 아니다. 텍스트 객체의 순서, 폰트 인코딩, 좌표계, 회전, 레이어, 이미지, annotation, embedded file, JavaScript, XFA form, 암호화, 손상된 cross-reference table 등 수많은 변수가 존재한다. 어떤 라이브러리도 모든 문서를 완벽하게 처리할 수 없다. 따라서 pdf-inspector를 도입할 때도 “파싱 성공/실패”의 이진 상태가 아니라 문서 유형, 페이지 유형, 추출 품질, fallback 경로를 함께 모델링해야 한다.

두 번째 리스크는 보안이다. PDF 파서는 공격 표면이 넓다. 오래된 PDF 라이브러리의 파싱 취약점, 압축 폭탄, 깊은 객체 중첩, 악성 링크, embedded file, 과도한 페이지 수, 비정상 CMap, 메모리 사용량 폭증은 모두 고려 대상이다. 실제로 pdf-inspector의 최근 커밋에는 `lopdf`를 0.42.0으로 올려 nesting-depth DoS 이슈에 대응한 기록이 있었다. 이는 프로젝트가 보안성 개선을 하고 있다는 긍정적 신호인 동시에, PDF 파싱 계층을 외부 입력 경계로 취급해야 한다는 reminder다. 운영 환경에서는 파일 크기 제한, 페이지 수 제한, CPU·메모리 제한, 타임아웃, 샌드박스, 격리된 워커, 의존성 취약점 스캔이 필요하다.

세 번째 리스크는 품질 지표의 오해다. 벤치마크에서 높은 점수를 보였다고 해서 조직의 문서에서도 같은 결과가 나온다는 보장은 없다. 한국어·일본어·중국어 문서, 세로쓰기, 스캔 품질이 낮은 팩스 문서, 도면, 영수증, 관공서 양식, 법률 계약서, 표와 각주가 많은 보고서는 별도 평가가 필요하다. 특히 RAG에서는 전체 텍스트 추출률보다 “질문에 답하는 데 필요한 근거 문단과 표가 올바른 순서와 단위로 들어갔는가”가 더 중요하다. 따라서 PoC에서는 엔진 벤치마크만 보지 말고 실제 검색·질의응답 품질까지 연결해 측정해야 한다.

## 권장 아키텍처: 파서가 아니라 라우터로 배치하라

pdf-inspector를 가장 안전하게 쓰는 방식은 단일 만능 파서가 아니라 **문서 라우터**로 배치하는 것이다. 입력 단계에서 파일의 메타데이터와 해시를 기록하고, pdf-inspector로 빠른 구조 분석을 수행한 뒤, 결과에 따라 여러 처리 경로로 분기한다. 텍스트 기반 문서는 구조 기반 Markdown 추출로 보낸다. 스캔 문서는 OCR로 보낸다. 혼합 문서는 페이지 단위로 분리하고, 텍스트 페이지와 이미지 페이지를 다르게 처리한다. 품질이 낮은 문서는 고급 파서 또는 사람 검수 큐로 보낸다. 이후 모든 경로는 공통 normalized document schema로 합류해 청킹, 임베딩, 검색 인덱싱으로 넘어간다.

이때 반드시 남겨야 할 로그는 원본 파일 해시, 페이지 수, 분류 결과, confidence, 추출 엔진 버전, OCR 사용 여부, 처리 시간, fallback 이유, 오류 코드, 최종 텍스트 길이, 표 추출 여부다. 이 정보가 있어야 나중에 “왜 이 계약서 검색 결과가 이상한가”, “왜 이번 달 OCR 비용이 늘었는가”, “어떤 문서 유형에서 품질이 낮은가”를 추적할 수 있다. 문서 AI 운영은 모델 프롬프트만의 문제가 아니라 수집 단계의 관측성 문제다.

## PoC 체크리스트

실무 PoC는 저장소를 설치해 샘플 몇 개를 돌리는 수준에서 끝나면 안 된다. 최소한 다음 항목을 확인해야 한다.

- **문서 샘플링**: 실제 업무 문서에서 텍스트 PDF, 스캔본, 혼합 문서, 표 중심 문서, CJK 문서, 암호화 문서, 손상 문서를 골고루 200~500개 수집한다.
- **분류 정확도**: pdf-inspector의 `text_based`, `scanned`, `image_based`, `mixed` 판단과 사람이 라벨링한 기준을 비교한다.
- **라우팅 효과**: OCR 호출 절감률, 평균 처리 시간, 실패율, 재처리율, 비용 변화를 측정한다.
- **검색 품질**: 단순 추출 점수뿐 아니라 실제 질문 세트에서 recall, grounded answer 비율, 표 질의 정확도를 본다.
- **보안 경계**: 파일 크기·페이지 수 제한, timeout, worker isolation, dependency scanning, SBOM, 로그 내 개인정보 마스킹을 적용한다.
- **운영 호환성**: Python, Node, WASM 중 어느 런타임을 표준으로 삼을지 정하고 결과 schema를 통일한다.
- **fallback 정책**: confidence가 낮거나 broken encoding이 감지될 때 OCR 또는 고급 문서 AI로 보내는 기준을 명문화한다.
- **버전 관리**: 추출 엔진 버전이 바뀌면 같은 문서의 결과가 달라질 수 있으므로 재색인 정책과 회귀 테스트를 둔다.

## 어떤 팀에 적합하고, 언제 피해야 하나

pdf-inspector는 문서 수집량이 많고, OCR 비용이나 지연이 부담이며, RAG 또는 검색 품질을 운영 지표로 관리하려는 팀에 적합하다. 특히 사내 지식 검색, 고객지원 문서 수집, 공시·보고서 크롤링, 계약서 저장소, 기술 매뉴얼 인덱싱, SaaS 업로드 파이프라인처럼 PDF가 계속 유입되는 환경에서 가치가 크다. Rust core와 여러 바인딩은 플랫폼팀이 공통 전처리 서비스를 만들기에도 좋다.

반대로 문서 수가 적고 대부분이 고품질 스캔 이미지라면 우선순위가 낮을 수 있다. 이 경우에는 OCR 품질, 이미지 전처리, layout model, 사람이 검수하는 워크플로가 더 중요하다. 복잡한 양식 인식, 서명·도장 검출, 차트 해석, 의미 기반 필드 추출이 핵심이라면 pdf-inspector만으로는 부족하고 전문 문서 AI 또는 LLM 기반 파서가 필요하다. 또한 규제 산업에서 외부 오픈소스 파서를 곧바로 운영 경계에 넣기 어렵다면, 샌드박스와 보안 검토를 먼저 통과해야 한다.

## 향후 관찰해야 할 지표와 전망

앞으로 볼 지표는 stars 증가보다 품질과 운영 성숙도다. 첫째, GitHub Release와 changelog가 정리되는지, 배포 아티팩트가 서명되거나 재현 가능한 빌드 체계를 갖추는지 봐야 한다. 둘째, open issues 중 레이아웃, 표, CJK, broken encoding, 보안 이슈가 어떤 속도로 처리되는지 관찰해야 한다. 셋째, 벤치마크가 더 다양한 공개 코퍼스와 언어권으로 확장되는지, raw artifact와 평가 스크립트가 재현 가능한지 확인할 필요가 있다. 넷째, Python/Node/WASM API가 안정화되어 장기 운영에서 breaking change가 줄어드는지도 중요하다.

문서 AI 시장은 더 강한 모델만으로 해결되지 않는다. 입력 문서의 품질을 모르고 모델에 넘기는 시스템은 비용을 많이 쓰면서도 신뢰성을 얻기 어렵다. pdf-inspector가 GitHub Trending에 오른 것은 개발자들이 PDF 처리에서 “정교한 후처리”보다 “초기 분류와 라우팅”의 중요성을 체감하고 있다는 신호로 해석할 수 있다. 실무 의사결정자에게 결론은 간단하다. PDF 파이프라인을 새로 설계한다면 OCR, LLM, 벡터DB부터 고르기 전에 먼저 문서 유형을 관측하고 분기하는 얇고 빠른 계층을 두어야 한다. 그 계층이 있어야 비용 최적화, 보안 통제, 검색 품질 개선이 같은 방향으로 움직인다.
