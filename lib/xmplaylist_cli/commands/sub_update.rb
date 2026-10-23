# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist sub-update ID --file F | --stdin [-d]: patch a subscription (write).
    class SubUpdate
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "sub-update ID --file F | --stdin [-d]", write: true) do |o|
          o.on("--file F", "JSON body file") { |v| opts[:file] = v }
          o.on("--stdin", "Read the JSON body from stdin") { opts[:stdin] = true }
        end
        id = CommandSupport.one_arg!(parser, argv, "ID")
        body = CommandSupport.read_json(opts, ctx.stdin)
        CommandSupport.write!(ctx, command: "sub-update", opts: opts, request: Endpoints.update_subscription(id, body),
                                   summary: ->(_) { "sub-update: updated #{id}" })
      end
    end
  end
end
