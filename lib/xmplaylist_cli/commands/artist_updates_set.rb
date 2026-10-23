# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist artist-updates-set ID --on|--off [-d]: turn artist update
    # emails on or off (write).
    class ArtistUpdatesSet
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "artist-updates-set ID --on|--off [-d]", write: true) do |o|
          o.on("--on", "Enable update emails") { opts[:enabled] = true }
          o.on("--off", "Disable update emails") { opts[:enabled] = false }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        raise UsageError, "give --on or --off\n#{parser.banner}" if opts[:enabled].nil?

        CommandSupport.write!(ctx, command: "artist-updates-set", request: Endpoints.set_artist_updates(id, enabled: opts[:enabled]),
                                   opts: opts, summary: ->(_) { "artist-updates-set: #{id} #{opts[:enabled] ? 'on' : 'off'}" })
      end
    end
  end
end
