# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist sub ID: one subscription.
    class Sub
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "sub ID")
        id = CommandSupport.one_arg!(parser, argv, "ID")
        ctx.formatter.show("sub", ctx.client.fetch(Endpoints.subscription(id)))
      end
    end
  end
end
