# frozen_string_literal: true

module Jekyll
  class ArchiveSeoPolicy < Generator
    safe true
    priority :low

    def generate(site)
      site.pages.each do |page|
        next unless page.respond_to?(:type)
        next unless %w[tag category].include?(page.type)

        page.data["robots"] = "noindex, follow"
        page.data["sitemap"] = false
      end
    end
  end
end