# CLAUDE.md

이 파일은 저장소에서 작업할 때 Claude Code(claude.ai/code)에게 제공되는 가이드다.

## 명령어

### 개발 서버
```bash
bundle exec jekyll s -l                          # 라이브 리로드가 적용된 개발 서버
bash tools/run.sh                                # 위와 동일, 스크립트 방식
bash tools/run.sh -p                             # 프로덕션 모드
bash tools/run.sh -H 0.0.0.0                     # 모든 인터페이스에 바인딩
```

### JavaScript 빌드
```bash
npm run build        # 프로덕션용 CSS(PurgeCSS) + JS(Rollup) 빌드
npm run build:js     # JS만 빌드
npm run build:css    # Bootstrap CSS 정제(purge)만 수행
npm run watch:js     # 소스맵과 함께 JS 감시 (개발용)
```

### 린팅
```bash
npm run lint:js      # _javascript/에 ESLint 실행
npm run lint:scss    # _sass/**/*.scss에 Stylelint 실행
npm run lint:fix:scss
npm test             # lint:js와 lint:scss 모두 실행
```

### HTML 테스트 (CI)
```bash
bash tools/test.sh   # 프로덕션 Jekyll 빌드 + htmlproofer (외부 링크 제외)
```

### Ruby / Jekyll
```bash
bundle install       # gem 의존성 설치
bundle exec jekyll b # 정적 빌드만 수행
```

## 아키텍처

### 이중 빌드 파이프라인

이 테마는 두 개의 병렬 에셋 파이프라인을 가지며, 항상 동기화 상태를 유지해야 한다.

1. **JavaScript** (`_javascript/` → `assets/js/dist/`): 소스 파일은 Rollup이 Babel 트랜스파일과 terser 압축을 거쳐 번들링한다. 각 진입점(`commons`, `home`, `categories`, `page`, `post`, `misc`, `theme`)은 특정 페이지 유형에 대응한다. PWA 파일(`pwa/app.js`, `pwa/sw.js`)은 별도로 빌드되며 Jekyll frontmatter가 주입되어 Jekyll이 정규 경로로 서빙한다.

2. **CSS** (`_sass/` → `_sass/vendors/_bootstrap.scss`): Bootstrap은 HTML 템플릿과 JS 소스를 콘텐츠로 삼아 PurgeCSS로 정제된다. 정제된 결과는 `_sass/vendors/_bootstrap.scss`로 커밋되어 테마의 SCSS와 함께 Jekyll Sass 파이프라인이 컴파일한다.

**핵심 규칙**: `assets/js/dist/`와 `_sass/vendors/`의 파일을 직접 편집하지 말 것 — 생성된 파일이다. 항상 `_javascript/`나 `_sass/`의 소스를 수정한다.

### 레이아웃 체인

```
compress.html          ← 최외각, HTML 압축
  └─ default.html      ← 셸: sidebar, topbar, main, panel, footer
       ├─ home.html
       ├─ post.html    ← panel_includes: [toc], tail_includes: [related-posts, post-nav]
       ├─ page.html
       ├─ categories.html / category.html
       └─ tags.html / tag.html / archives.html
```

`default.html`은 각 자식 레이아웃의 YAML front matter 목록(`panel_includes`, `tail_includes`, `script_includes`)을 기반으로 패널, 테일, 스크립트 인클루드를 동적으로 주입한다.

### SCSS 구조

```
_sass/
  abstracts/     ← 변수, 믹스인, 브레이크포인트, 플레이스홀더
  themes/        ← _light.scss, _dark.scss (CSS 사용자 정의 속성)
  base/          ← 리셋, 타이포그래피, 구문 강조
  components/    ← 재사용 가능한 UI 컴포넌트
  layout/        ← sidebar, topbar, footer 등
  pages/         ← 페이지별 오버라이드
  vendors/       ← 생성된 Bootstrap (편집 금지)
```

테마 전환은 CSS 사용자 정의 속성 기반이다. `_light.scss`와 `_dark.scss`가 동일한 사용자 정의 속성 집합을 정의하며, `<html>`의 `data-mode` 속성을 토글하면 두 테마 간에 전환된다.

### JavaScript 모듈 시스템

`_javascript/modules/`는 두 그룹을 내보낸다.
- `layouts.js` — `basic`, `initSidebar`, `initTopbar` (모든 페이지에서 사용)
- `components.js` — `loadImg`, `imgPopup`, `initToc`, `initClipboard`, `initLocaleDatetime`, `loadMermaid` (게시물 페이지에서 사용)

페이지 유형별 진입점이 이 모듈에서 임포트한다. 서드파티 라이브러리(GLightbox, ClipboardJS, tocbot, mermaid, dayjs)는 런타임에 CDN으로 로드되며 `eslint.config.js`에서 전역 변수로 참조된다.

### 데이터 기반 다국어 처리

모든 UI 문자열은 `_data/locales/<lang>.yml`에 위치한다. 템플릿은 `site.data.locales[lang].<key>`로 참조한다. 활성 언어는 `_includes/lang.html`에서 결정되어 모든 인클루드에 `lang` 변수로 전달된다.

### Jekyll 플러그인

`_plugins/posts-lastmod-hook.rb`는 git 커밋이 두 개 이상인 게시물의 `last_modified_at`을 자동으로 채워, front matter를 수동으로 작성하지 않아도 "수정됨" 타임스탬프가 표시되도록 한다.

### 커밋 컨벤션

커밋은 [Conventional Commits](https://www.conventionalcommits.org/)를 따라야 한다 — `.husky/commit-msg` 훅을 통해 commitlint가 강제한다. 타입: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `chore`, `ci`.
