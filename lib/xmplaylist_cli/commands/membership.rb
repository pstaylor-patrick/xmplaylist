# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist membership: your roster plan and seat usage.
    class Membership
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "membership")
        CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.show("membership", ctx.client.fetch(Endpoints.roster_membership))
      end
    end
  end
end
