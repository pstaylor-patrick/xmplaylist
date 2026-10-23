# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist recent-searches: the current user's recent searches.
    class RecentSearches
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "recent-searches")
        CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.list("recent-searches", ctx.client.fetch(Endpoints.recent_searches))
      end
    end
  end
end
