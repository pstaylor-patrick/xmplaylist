# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist roster-remove ID [--yes] [-d]: remove a roster artist (guarded delete).
    class RosterRemove
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "roster-remove ID [--yes] [-d]", write: true, destructive: true)
        id = CommandSupport.one_arg!(parser, argv, "ID")
        CommandSupport.write!(ctx, command: "roster-remove", opts: opts, request: Endpoints.roster_remove(id),
                                   confirm: { action: "remove roster artist #{id}", token: id },
                                   summary: ->(_) { "roster-remove: removed #{id}" })
      end
    end
  end
end
