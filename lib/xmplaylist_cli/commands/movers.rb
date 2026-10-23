# frozen_string_literal: true

require "xmplaylist_cli/commands/channel_listing"

module XmplaylistCli
  module Commands
    # xmplaylist movers CH [window] [--decliners]: biggest play-count changes.
    class Movers
      DECLINERS = ->(o, opts) { o.on("--decliners", "Show decliners instead of gainers") { opts[:decliners] = true } }

      def self.run(ctx, argv)
        ChannelListing.run(ctx, argv, command: "movers", columns: :movers, window: true, extra: DECLINERS) do |ch, window, opts|
          Endpoints.movers(ch, window, view: opts[:decliners] ? "decliners" : nil)
        end
      end
    end
  end
end
