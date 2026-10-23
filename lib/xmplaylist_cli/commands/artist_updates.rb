# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist artist-updates ID [--preview]: update-email setting for an
    # artist, or a preview of the email.
    class ArtistUpdates
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "artist-updates ID [--preview]") do |o|
          o.on("--preview", "Preview the update email") { opts[:preview] = true }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        request = opts[:preview] ? Endpoints.artist_updates_preview(id) : Endpoints.artist_updates(id)
        ctx.formatter.show("artist-updates", ctx.client.fetch(request))
      end
    end
  end
end
