# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-add NAME [--spotify ID] [-d]: add an artist to the roster (write).
    class RosterAdd
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "roster-add NAME [--spotify ID] [-d]", write: true) do |o|
          o.on("--spotify ID", "Spotify artist id") { |v| opts[:spotify] = v }
        end
        name = CommandSupport.one_arg!(parser, argv, "NAME")
        CommandSupport.write!(ctx, command: "roster-add", opts: opts,
                                   request: Endpoints.roster_add(display_name: name, spotify_artist_id: opts[:spotify]),
                                   summary: ->(_) { "roster-add: added #{name}" })
      end
    end
  end
end
