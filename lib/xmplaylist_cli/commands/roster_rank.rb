# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-rank ID --station CH: current rank on one channel.
    class RosterRank
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "roster-rank ID --station CH") do |o|
          o.on("--station CH", "Channel (deeplink, name, or number)") { |v| opts[:station] = v }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        raise UsageError, "missing --station CH\n#{parser.banner}" unless opts[:station]

        channel = CommandSupport.channel(ctx, opts[:station])
        station_id = channel[:id] || channel[:deeplink]
        ctx.formatter.show("roster-rank", ctx.client.fetch(Endpoints.roster_station_rank(id, station_id: station_id)))
      end
    end
  end
end
