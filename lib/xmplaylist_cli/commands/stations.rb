# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist stations [--extended]: every channel (--extended is paid).
    class Stations
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "stations [--extended]") do |o|
          o.on("--extended", "Paid: extended station data") { opts[:extended] = true }
        end
        CommandSupport.parse!(parser, argv, max_args: 0)
        request = opts[:extended] ? Endpoints.stations_extended : Endpoints.stations
        data = ctx.client.fetch(request)
        ctx.formatter.list("stations", data, columns: opts[:extended] ? nil : :stations)
      end
    end
  end
end
