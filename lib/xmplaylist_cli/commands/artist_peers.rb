# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist artist-peers ID: artists played alongside this one.
    class ArtistPeers
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "artist-peers ID")
        id = CommandSupport.one_arg!(parser, argv, "ID")
        ctx.formatter.list("artist-peers", ctx.client.fetch(Endpoints.artist_peers(id)))
      end
    end
  end
end
