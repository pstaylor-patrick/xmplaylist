# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist hot [--full]: artists gaining spins (--full is the long list).
    class Hot
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "hot [--full]") do |o|
          o.on("--full", "The full hot list") { opts[:full] = true }
        end
        CommandSupport.parse!(parser, argv, max_args: 0)
        request = opts[:full] ? Endpoints.artists_hot_full : Endpoints.artists_hot
        ctx.formatter.list("hot", ctx.client.fetch(request), columns: :hot)
      end
    end
  end
end
