# frozen_string_literal: true

require "xmplaylist_cli/commands/channel_listing"

module XmplaylistCli
  module Commands
    # xmplaylist artist-rankings CH [window]: artist ranks against the previous period.
    class ArtistRankings
      def self.run(ctx, argv)
        ChannelListing.run(ctx, argv, command: "artist-rankings", columns: :artist_rankings, window: true) do |ch, window, _|
          Endpoints.artist_rankings(ch, window)
        end
      end
    end
  end
end
