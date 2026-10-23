# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist artist-rank ID --station CH: the artist's current rank on one
    # channel. The channel resolves to its station id.
    class ArtistRank
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "artist-rank ID --station CH") do |o|
          o.on("--station CH", "Channel (deeplink, name, or number)") { |v| opts[:station] = v }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        raise UsageError, "missing --station CH\n#{parser.banner}" unless opts[:station]

        channel = CommandSupport.channel(ctx, opts[:station])
        station_id = channel[:id] || channel[:deeplink]
        ctx.formatter.show("artist-rank", ctx.client.fetch(Endpoints.artist_station_rank(id, station_id: station_id)))
      end
    end
  end
end
