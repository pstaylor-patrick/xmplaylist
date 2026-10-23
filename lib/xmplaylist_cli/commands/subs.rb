# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist subs: your alert subscriptions.
    class Subs
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "subs")
        CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.list("subs", ctx.client.fetch(Endpoints.subscriptions))
      end
    end
  end
end
