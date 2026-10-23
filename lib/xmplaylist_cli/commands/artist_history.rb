# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist artist-history ID [--stations]: play history by track (or
    # by station with --stations).
    class ArtistHistory
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "artist-history ID [--stations]") do |o|
          o.on("--stations", "Group by station instead of track") { opts[:stations] = true }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        request = opts[:stations] ? Endpoints.artist_history_stations(id) : Endpoints.artist_history_tracks(id)
        ctx.formatter.list("artist-history", ctx.client.fetch(request))
      end
    end
  end
end
