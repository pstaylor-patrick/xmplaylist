# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist track CH TRACK_ID: one track's detail on a channel.
    class Track
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "track CH TRACK_ID")
        query, track_id = CommandSupport.args!(parser, argv, "CH", "TRACK_ID")
        channel = CommandSupport.channel(ctx, query)
        data = ctx.client.fetch(Endpoints.station_track(channel[:deeplink], track_id))
        ctx.formatter.show("track", data)
      end
    end
  end
end
