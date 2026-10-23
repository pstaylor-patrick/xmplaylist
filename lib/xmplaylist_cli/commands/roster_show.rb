# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-show ID: one roster artist.
    class RosterShow
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "roster-show ID")
        id = CommandSupport.one_arg!(parser, argv, "ID")
        ctx.formatter.show("roster-show", ctx.client.fetch(Endpoints.roster_artist(id)))
      end
    end
  end
end
