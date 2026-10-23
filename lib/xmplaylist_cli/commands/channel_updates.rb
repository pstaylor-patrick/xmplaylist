# frozen_string_literal: true

require "xmplaylist_cli/command_support"
require "xmplaylist_cli/paging"

module XmplaylistCli
  module Commands
    # xmplaylist channel-updates [--days 1-30] [--channel CH] [--name S] [--offset N] [--all]
    class ChannelUpdates
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "channel-updates [--days 1-30] [--channel CH] [--name S] [--offset N] [--all]",
                                             all: true) do |o|
          o.on("--days N", "Days of history (1-30)") { |v| opts[:days] = CommandSupport.count(v, flag: "--days", max: 30) }
          o.on("--channel CH", "One channel (deeplink, name, or number)") { |v| opts[:channel] = v }
          o.on("--name S", "Channel name filter") { |v| opts[:name] = v }
          o.on("--offset N", "Start offset (0-10000)") { |v| opts[:offset] = CommandSupport.count(v, flag: "--offset", min: 0, max: 10_000) }
        end
        CommandSupport.parse!(parser, argv, max_args: 0)
        channel = opts[:channel] && CommandSupport.channel(ctx, opts[:channel])[:deeplink]
        request = Endpoints.channel_updates(offset: opts[:offset], days: opts[:days], channel: channel, name: opts[:name])
        data = Paging.offset(ctx.client, request, all: opts[:all], err: ctx.err)
        ctx.formatter.list("channel-updates", data, columns: :channel_updates)
      end
    end
  end
end
