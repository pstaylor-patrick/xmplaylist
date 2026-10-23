# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-peers ID: artists played alongside a roster artist.
    class RosterPeers
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "roster-peers ID")
        id = CommandSupport.one_arg!(parser, argv, "ID")
        ctx.formatter.list("roster-peers", ctx.client.fetch(Endpoints.roster_peers(id)))
      end
    end
  end
end
