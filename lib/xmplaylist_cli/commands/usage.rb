# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist usage: API key requests remaining today.
    class Usage
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "usage")
        CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.show("usage", ctx.client.fetch(Endpoints.usage_remaining))
      end
    end
  end
end
