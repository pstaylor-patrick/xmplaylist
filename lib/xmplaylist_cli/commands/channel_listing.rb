# frozen_string_literal: true

require "xmplaylist_cli/command_support"
require "xmplaylist_cli/window"

module XmplaylistCli
  module Commands
    # Shared shape for the per-channel listings: resolve CH, optionally parse
    # the window flags, fetch one request, print a table.
    module ChannelListing
      def self.run(ctx, argv, command:, columns:, window: false, extra: nil)
        opts = {}
        banner = "#{command} CH#{window ? ' [--days N | --year Y | --month YYYY-MM | --week YYYY-MM-DD]' : ''}"
        parser = CommandSupport.parser(opts, banner: banner) do |o|
          Window.add_options(o, opts) if window
          extra&.call(o, opts)
        end
        query = CommandSupport.one_arg!(parser, argv, "CH")
        window_query = window ? Window.query(opts) : {}
        channel = CommandSupport.channel(ctx, query)
        data = ctx.client.fetch(yield(channel[:deeplink], window_query, opts))
        ctx.formatter.list(command, data, columns: columns)
      end
    end
  end
end
