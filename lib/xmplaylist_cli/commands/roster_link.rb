# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-link ID [--show] [-d]: show (--show) or switch to the artist the roster name is linked to (write). The spec declares no request body, so no artist id is sent.
    class RosterLink
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "roster-link ID [--show] [-d]", write: true) do |o|
          o.on("--show", "Show the linked artist instead of switching") { opts[:show] = true }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        return ctx.formatter.show("roster-link", ctx.client.fetch(Endpoints.roster_linked_artist(id))) if opts[:show]

        CommandSupport.write!(ctx, command: "roster-link", opts: opts, request: Endpoints.roster_link(id),
                                   summary: ->(_) { "roster-link: switched #{id} to its linked artist" })
      end
    end
  end
end
