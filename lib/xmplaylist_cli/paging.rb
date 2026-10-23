# frozen_string_literal: true

require "uri"

module XmplaylistCli
  # Three paging shapes, each single-page unless all: true. With all, pages
  # are followed up to MAX_PAGES (the Supporter quota is 100 requests a day);
  # hitting the cap warns on stderr. Each returns the first page's body with
  # :results replaced by every collected result.
  module Paging
    MAX_PAGES = 50

    # Station history: follow `next`, reading its `last` (ms timestamp).
    def self.cursor(client, request, all: false, err: $stderr)
      walk(client, request, all, err) do |body, _query|
        last = cursor_from(body[:next])
        last && { "last" => last }
      end
    end

    # 1-based `page`: continue while `next` is set or currentPage < pages.
    def self.page(client, request, all: false, err: $stderr)
      walk(client, request, all, err) do |body, query|
        current = (query["page"] || body[:currentPage] || 1).to_i
        more = !body[:next].to_s.empty? || (body[:pages] && current < body[:pages].to_i)
        more && !Array(body[:results]).empty? ? { "page" => current + 1 } : nil
      end
    end

    # `offset` (0..10000): follow nextOffset.
    def self.offset(client, request, all: false, err: $stderr)
      walk(client, request, all, err) do |body, _query|
        nxt = body[:nextOffset]
        nxt.nil? || nxt.to_i > 10_000 ? nil : { "offset" => nxt.to_i }
      end
    end

    def self.cursor_from(next_url)
      return nil if next_url.to_s.empty?

      URI.decode_www_form(URI(next_url.to_s).query.to_s).to_h["last"]
    rescue URI::InvalidURIError, ArgumentError
      nil
    end

    def self.walk(client, request, all, err)
      query = (request.query || {}).dup
      first = nil
      results = []
      pages = 0
      loop do
        body = client.fetch(request.with(query: query))
        pages += 1
        first ||= body
        results.concat(Array(body[:results]))
        break unless all

        step = yield(body, query)
        break unless step

        if pages >= MAX_PAGES
          err.puts "xmplaylist: stopped after #{MAX_PAGES} pages; results are truncated"
          break
        end
        query = query.merge(step)
      end
      first.is_a?(Hash) ? first.merge(results: results) : first
    end

    private_class_method :walk
  end
end
