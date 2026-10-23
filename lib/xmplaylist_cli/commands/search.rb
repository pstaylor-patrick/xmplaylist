# frozen_string_literal: true

require "xmplaylist_cli/command_support"
require "xmplaylist_cli/paging"
require "xmplaylist_cli/commands/search_filters"

module XmplaylistCli
  module Commands
    # xmplaylist search [filters] [--as-of T] [--page N] [--limit N] [--aggregate] [--all]
    class Search
      def self.run(ctx, argv)
        opts = {}
        banner = "search #{SearchFilters::BANNER} [--as-of TIME] [--page N] [--limit 50|100|200|500|1000] [--aggregate] [--all]"
        parser = CommandSupport.parser(opts, banner: banner, all: true) do |o|
          SearchFilters.define(o, opts)
          o.on("--as-of TIME", "Snapshot time (ISO 8601)") { |v| opts[:as_of] = v }
          o.on("--page N", "Page (1-based)") { |v| opts[:page] = CommandSupport.count(v, flag: "--page") }
          o.on("--limit N", "Results per page") do |v|
            opts[:limit] = CommandSupport.one_of!(v, Endpoints::SEARCH_LIMITS, flag: "--limit").to_i
          end
          o.on("--aggregate", "One row per track with a play count") { opts[:aggregate] = "true" }
        end
        CommandSupport.parse!(parser, argv, max_args: 0)
        request = Endpoints.search(SearchFilters.resolve(ctx, opts), page: opts[:page], as_of: opts[:as_of],
                                                                     limit: opts[:limit], aggregate: opts[:aggregate])
        data = Paging.page(ctx.client, request, all: opts[:all], err: ctx.err)
        ctx.formatter.list("search", data)
      end
    end
  end
end
