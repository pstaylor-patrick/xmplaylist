# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist artist ID: one artist's detail.
    class Artist
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "artist ID")
        id = CommandSupport.one_arg!(parser, argv, "ID")
        ctx.formatter.show("artist", ctx.client.fetch(Endpoints.artist(id)))
      end
    end
  end
end
