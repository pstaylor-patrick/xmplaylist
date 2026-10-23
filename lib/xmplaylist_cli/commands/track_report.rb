# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist track-report TRACK_ID --link URL [-d]: report a better link for a track (write).
    class TrackReport
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "track-report TRACK_ID --link URL [-d]", write: true) do |o|
          o.on("--link URL", "The corrected link") { |v| opts[:link] = v }
        end
        id = CommandSupport.one_arg!(parser, argv, "TRACK_ID")
        raise UsageError, "missing --link URL\n#{parser.banner}" unless opts[:link]

        CommandSupport.write!(ctx, command: "track-report", opts: opts,
                                   request: Endpoints.track_report(id, updated_link: opts[:link]),
                                   summary: ->(_) { "track-report: reported #{id}" })
      end
    end
  end
end
