# frozen_string_literal: true

require "xmplaylist_cli/commands/channel_listing"

module XmplaylistCli
  module Commands
    # xmplaylist rankings CH [window]: track ranks against the previous period.
    class Rankings
      def self.run(ctx, argv)
        ChannelListing.run(ctx, argv, command: "rankings", columns: :rankings, window: true) do |ch, window, _|
          Endpoints.rankings(ch, window)
        end
      end
    end
  end
end
