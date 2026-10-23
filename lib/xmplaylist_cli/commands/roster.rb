# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster: the artists on your roster.
    class Roster
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "roster")
        CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.list("roster", ctx.client.fetch(Endpoints.roster))
      end
    end
  end
end
