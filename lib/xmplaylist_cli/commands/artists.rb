# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist artists Q [--full]: artist lookup (--full: every known and
    # unconfirmed identity).
    class Artists
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "artists Q [--full]") do |o|
          o.on("--full", "Search every known and unconfirmed identity") { opts[:full] = true }
        end
        q = CommandSupport.one_arg!(parser, argv, "Q")
        request = opts[:full] ? Endpoints.artists_search(q) : Endpoints.artists(q)
        ctx.formatter.list("artists", ctx.client.fetch(request))
      end
    end
  end
end
