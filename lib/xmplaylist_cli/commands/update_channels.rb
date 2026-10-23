# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist update-channels: channels with update history.
    class UpdateChannels
      def self.run(ctx, argv)
        parser = CommandSupport.parser({}, banner: "update-channels")
        CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.list("update-channels", ctx.client.fetch(Endpoints.channel_update_channels), columns: :update_channels)
      end
    end
  end
end
