# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-catalog ID [--days 7|30|90|365]
    class RosterCatalog
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "roster-catalog ID [--days 7|30|90|365]") do |o|
          o.on("--days N", "Window: 7, 30, 90, or 365") { |v| opts[:days] = CommandSupport.one_of!(v, Endpoints::ROSTER_DAYS, flag: "--days") }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        ctx.formatter.list("roster-catalog", ctx.client.fetch(Endpoints.roster_catalog(id, days: opts[:days])))
      end
    end
  end
end
