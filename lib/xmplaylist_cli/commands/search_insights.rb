# frozen_string_literal: true

require "xmplaylist_cli/command_support"
require "xmplaylist_cli/commands/search_filters"

module XmplaylistCli
  module Commands
    # xmplaylist search-insights [filters] [--page N]: summary for a search.
    class SearchInsights
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "search-insights #{SearchFilters::BANNER} [--page N]") do |o|
          SearchFilters.define(o, opts)
          o.on("--page N", "Page (1-based)") { |v| opts[:page] = CommandSupport.count(v, flag: "--page") }
        end
        CommandSupport.parse!(parser, argv, max_args: 0)
        request = Endpoints.search_insights(SearchFilters.resolve(ctx, opts), page: opts[:page])
        ctx.formatter.show("search-insights", ctx.client.fetch(request))
      end
    end
  end
end
