# frozen_string_literal: true

require "xmplaylist_cli/commands/channel_listing"

module XmplaylistCli
  module Commands
    # xmplaylist most-heard CH [window]: most-played tracks.
    class MostHeard
      def self.run(ctx, argv)
        ChannelListing.run(ctx, argv, command: "most-heard", columns: :most_heard, window: true) do |ch, window, _|
          Endpoints.most_heard(ch, window)
        end
      end
    end
  end
end
