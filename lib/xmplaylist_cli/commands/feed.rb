# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist feed: the latest plays across every channel (one request).
    class Feed
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "feed")
        CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.list("feed", ctx.client.fetch(Endpoints.feed), columns: :feed)
      end
    end
  end
end
