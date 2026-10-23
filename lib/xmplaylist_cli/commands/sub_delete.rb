# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist sub-delete ID [--yes] [-d]: delete a subscription (guarded delete).
    class SubDelete
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "sub-delete ID [--yes] [-d]", write: true, destructive: true)
        id = CommandSupport.one_arg!(parser, argv, "ID")
        CommandSupport.write!(ctx, command: "sub-delete", opts: opts, request: Endpoints.delete_subscription(id),
                                   confirm: { action: "delete subscription #{id}", token: id },
                                   summary: ->(_) { "sub-delete: deleted #{id}" })
      end
    end
  end
end
