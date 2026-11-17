#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'json'
require 'optparse'
require 'pathname'
require 'yaml'

ROOT = Pathname.new(__dir__).parent.expand_path
POST_GLOB = ROOT.join('_posts', '*.md').to_s
REQUIRED_FIELDS = %w[title description author date categories tags image].freeze
SITE_ORIGIN = 'https://heracles-jo.github.io'
TAXONOMY = YAML.safe_load(File.read(ROOT.join('_data', 'taxonomy.yml')), aliases: true).freeze
ALLOWED_CATEGORIES = TAXONOMY.fetch('categories').freeze

options = { mode: :all, base: nil, site: nil }
OptionParser.new do |opts|
  opts.banner = 'Usage: ruby tools/seo-validate.rb [--all | --changed BASE] [--site DIR]'
  opts.on('--all', 'Validate every post against the repository baseline') { options[:mode] = :all }
  opts.on('--changed BASE', 'Validate changed posts; apply strict rules to newly added posts') do |base|
    options[:mode] = :changed
    options[:base] = base
  end
  opts.on('--site DIR', 'Validate the rendered Jekyll output') { |dir| options[:site] = dir }
end.parse!

errors = []
warnings = []

def front_matter(path)
  text = File.read(path, encoding: 'UTF-8')
  match = text.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)
  raise 'front matter delimiters are missing' unless match

  data = YAML.safe_load(
    match[1],
    permitted_classes: [Date, Time],
    aliases: true
  ) || {}
  [data, match[2]]
end

def post_files_for(options)
  return [Dir.glob(POST_GLOB).sort, []] if options[:mode] == :all

  base = options.fetch(:base)
  git_lines = lambda do |*args|
    IO.popen(['git', *args], chdir: ROOT.to_s, err: File::NULL, &:read).lines.map(&:strip)
  end

  committed = git_lines.call('diff', '--name-only', '--diff-filter=AM', "#{base}...HEAD", '--', '_posts/*.md')
  staged = git_lines.call('diff', '--cached', '--name-only', '--diff-filter=AM', '--', '_posts/*.md')
  unstaged = git_lines.call('diff', '--name-only', '--diff-filter=AM', '--', '_posts/*.md')
  untracked = git_lines.call('ls-files', '--others', '--exclude-standard', '--', '_posts/*.md')

  changed = (committed + staged + unstaged + untracked).uniq.sort
  added = (
    git_lines.call('diff', '--name-only', '--diff-filter=A', "#{base}...HEAD", '--', '_posts/*.md') +
    git_lines.call('diff', '--cached', '--name-only', '--diff-filter=A', '--', '_posts/*.md') +
    untracked
  ).uniq.sort
  [changed.map { |path| ROOT.join(path).to_s }, added]
end

def local_asset_path(url)
  path = url.to_s.sub(SITE_ORIGIN, '').sub(%r{\A/}, '')
  ROOT.join(path)
end

files, added_paths = post_files_for(options)
all_files = Dir.glob(POST_GLOB).sort
all_metadata = {}

all_files.each do |path|
  begin
    all_metadata[path] = front_matter(path).first
  rescue StandardError => e
    errors << "#{Pathname.new(path).relative_path_from(ROOT)}: #{e.message}"
  end
end

%w[title description].each do |field|
  groups = all_metadata.group_by { |_path, data| data[field].to_s.strip.downcase }
  groups.each do |value, entries|
    next if value.empty? || entries.length == 1

    names = entries.map { |path, _data| Pathname.new(path).relative_path_from(ROOT) }
    errors << "duplicate #{field}: #{names.join(', ')}"
  end
end

files.each do |path|
  relative = Pathname.new(path).relative_path_from(ROOT).to_s
  begin
    data, body = front_matter(path)
  rescue StandardError => e
    errors << "#{relative}: #{e.message}"
    next
  end

  REQUIRED_FIELDS.each do |field|
    value = data[field]
    errors << "#{relative}: missing #{field}" if value.nil? || (value.respond_to?(:empty?) && value.empty?)
  end

  errors << "#{relative}: author must be heracles-jo" unless data['author'] == 'heracles-jo'
  categories = data['categories']
  tags = data['tags']
  errors << "#{relative}: categories must contain one or two values" unless categories.is_a?(Array) && categories.length.between?(1, 2)
  if categories.is_a?(Array)
    unknown_categories = categories - ALLOWED_CATEGORIES
    errors << "#{relative}: unknown categories: #{unknown_categories.join(', ')}" unless unknown_categories.empty?
  end
  errors << "#{relative}: tags must contain four to six values" unless tags.is_a?(Array) && tags.length.between?(4, 6)
  if tags.is_a?(Array)
    invalid_tags = tags.reject do |tag|
      value = tag.to_s
      value == value.downcase && value.match?(/\A[[:alnum:]][[:alnum:].+#-]*\z/)
    end
    errors << "#{relative}: tags must use lowercase kebab-case: #{invalid_tags.join(', ')}" unless invalid_tags.empty?
  end

  image = data['image']
  unless image.is_a?(Hash) && image['path'] && image['alt'].to_s.length.between?(10, 160)
    errors << "#{relative}: image.path and descriptive image.alt are required"
  end

  if image.is_a?(Hash) && image['path']
    asset = local_asset_path(image['path'])
    errors << "#{relative}: missing hero asset #{asset.relative_path_from(ROOT)}" unless asset.file?
  end

  body.scan(/!\[[^\]]*\]\((#{Regexp.escape(SITE_ORIGIN)}\/assets\/[^)]+)\)/).flatten.each do |url|
    asset = local_asset_path(url)
    errors << "#{relative}: missing body asset #{asset.relative_path_from(ROOT)}" unless asset.file?
  end

  body.scan(/!\[([^\]]*)\]\([^)]+\)/).flatten.each do |alt|
    errors << "#{relative}: body image has missing or generic alt text" if alt.strip.length < 10 || alt.match?(/\A(image|이미지|그림|photo)\z/i)
  end

  tokens = body.scan(/[[:alnum:]가-힣]+/).length
  errors << "#{relative}: content coverage is too thin (#{tokens} tokens; minimum 1000)" if tokens < 1000
  errors << "#{relative}: no external primary-source link" unless body.match?(%r{https://})
  errors << "#{relative}: body must not contain an H1 heading" if body.match?(/^#\s+/)

  next unless added_paths.include?(relative)

  title_length = data['title'].to_s.length
  description_length = data['description'].to_s.length
  internal_links = body.scan(%r{\]\(/posts/[^)]+\)}).length

  errors << "#{relative}: title length #{title_length} is outside 20..65" unless title_length.between?(20, 65)
  errors << "#{relative}: description length #{description_length} is outside 80..160" unless description_length.between?(80, 160)
  errors << "#{relative}: new posts require 4..6 tags" unless tags.is_a?(Array) && tags.length.between?(4, 6)
  errors << "#{relative}: new posts require at least three contextual internal links" if internal_links < 3
  errors << "#{relative}: new posts require an explicit primary-source section" unless body.match?(/^##\s+.*(참고|출처|자료|Sources?)/i)
  warnings << "#{relative}: consider 1500+ tokens for competitive search intent" if tokens < 1500
end

if options[:site]
  site = ROOT.join(options[:site])
  errors << "rendered site directory not found: #{site}" unless site.directory?

  if site.directory?
    home = site.join('index.html')
    if home.file?
      html = home.read
      h1_count = html.scan(/<h1\b/i).length
      errors << "rendered homepage must contain exactly one H1 (found #{h1_count})" unless h1_count == 1
      errors << 'rendered homepage contains malformed twitter:site=@' if html.include?('name="twitter:site" content="@"')
    end

    Dir.glob(site.join('posts', '**', 'index.html')).each do |post_html|
      html = File.read(post_html, encoding: 'UTF-8')
      errors << "#{post_html}: missing BlogPosting JSON-LD" unless html.include?('"@type":"BlogPosting"') || html.include?('"@type": "BlogPosting"')
      errors << "#{post_html}: JSON-LD still contains invalid ImageObject.alt" if html.match?(/"image"\s*:\s*\{[^}]*"alt"\s*:/m)
      errors << "#{post_html}: public author name is not heracles.jo" unless html.include?('"name":"heracles.jo"') || html.include?('"name": "heracles.jo"')
    end

    sitemap = site.join('sitemap.xml')
    if sitemap.file?
      xml = sitemap.read
      errors << 'rendered sitemap must exclude /archives/' if xml.include?('<loc>https://heracles-jo.github.io/archives/</loc>')
    else
      errors << 'rendered sitemap.xml is missing'
    end
  end
end

warnings.each { |warning| warn "WARN: #{warning}" }

if errors.empty?
  puts "SEO validation passed: #{files.length} post(s) checked#{options[:site] ? ' with rendered-site checks' : ''}."
  exit 0
end

warn "SEO validation failed with #{errors.length} issue(s):"
errors.each { |error| warn "- #{error}" }
exit 1
