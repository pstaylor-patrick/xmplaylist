# frozen_string_literal: true

require "xmplaylist_cli/command_support"
require "xmplaylist_cli/paging"

module XmplaylistCli
  module Commands
    # xmplaylist station CH [-n N] [--all] [--since-ms MS]: recent plays,
    # newest first. -n trims the printed rows; --all follows the cursor.
    class Station
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "station CH [-n N] [--all] [--since-ms MS]", all: true) do |o|
          o.on("-n N", "Print at most N plays") { |v| opts[:limit] = CommandSupport.count(v, flag: "-n") }
          o.on("--since-ms MS", "Start the cursor at this ms timestamp") { |v| opts[:last] = CommandSupport.count(v, flag: "--since-ms", min: 0) }
        end
        query = CommandSupport.one_arg!(parser, argv, "CH")
        channel = CommandSupport.channel(ctx, query)
        data = Paging.cursor(ctx.client, Endpoints.station(channel[:deeplink], last: opts[:last]), all: opts[:all], err: ctx.err)
        data = data.merge(results: data[:results].first(opts[:limit])) if opts[:limit] && data.is_a?(Hash)
        ctx.formatter.list("station", data, columns: :history)
      end
    end
  end
end
