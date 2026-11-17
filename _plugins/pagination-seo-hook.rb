# frozen_string_literal: true

Jekyll::Hooks.register :site, :pre_render do |site|
  site.pages.each do |page|
    next unless page.respond_to?(:pager) && page.pager
    next unless page.pager.page > 1

    page_number = page.pager.page
    total_pages = page.pager.total_pages
    page.data['title'] = "기술 블로그 글 목록 — 페이지 #{page_number}"
    page.data['description'] =
      "Heracles.jo 기술 블로그의 #{page_number}번째 글 목록입니다. " \
      "오픈소스, AI, 클라우드 인프라와 보안 분석을 확인하세요. " \
      "전체 #{total_pages}페이지 중 #{page_number}페이지입니다."
    page.data['seo'] = { 'type' => 'CollectionPage' }
  end
end