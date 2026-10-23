# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist labels Q [--limit N]: record label suggestions (N <= 25).
    class Labels
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "labels Q [--limit 1-25]") do |o|
          o.on("--limit N", "At most N labels (1-25)") { |v| opts[:limit] = CommandSupport.count(v, flag: "--limit", max: 25) }
        end
        q = CommandSupport.one_arg!(parser, argv, "Q")
        raise UsageError, "Q must be at least 2 characters" if q.strip.length < 2

        ctx.formatter.list("labels", ctx.client.fetch(Endpoints.search_labels(q, limit: opts[:limit])))
      end
    end
  end
end
