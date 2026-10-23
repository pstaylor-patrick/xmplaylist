# frozen_string_literal: true

require "xmplaylist_cli/commands/channel_listing"

module XmplaylistCli
  module Commands
    # xmplaylist newest CH: tracks the channel played for the first time.
    class Newest
      def self.run(ctx, argv)
        ChannelListing.run(ctx, argv, command: "newest", columns: :history) { |ch, _, _| Endpoints.station_newest(ch) }
      end
    end
  end
end
