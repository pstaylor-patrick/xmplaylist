# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-history ID [--stations]: play history by track (or station).
    class RosterHistory
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "roster-history ID [--stations]") do |o|
          o.on("--stations", "Group by station instead of track") { opts[:stations] = true }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        request = opts[:stations] ? Endpoints.roster_history_stations(id) : Endpoints.roster_history_tracks(id)
        ctx.formatter.list("roster-history", ctx.client.fetch(request))
      end
    end
  end
end
