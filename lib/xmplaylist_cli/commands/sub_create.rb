# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist sub-create --file F | --stdin [-d]: create a subscription from a JSON object (write).
    class SubCreate
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "sub-create --file F | --stdin [-d]", write: true) do |o|
          o.on("--file F", "JSON body file") { |v| opts[:file] = v }
          o.on("--stdin", "Read the JSON body from stdin") { opts[:stdin] = true }
        end
        CommandSupport.parse!(parser, argv, max_args: 0)
        body = CommandSupport.read_json(opts, ctx.stdin)
        CommandSupport.write!(ctx, command: "sub-create", opts: opts, request: Endpoints.create_subscription(body),
                                   summary: ->(r) { "sub-create: created #{r.is_a?(Hash) ? r[:id] : nil}".strip })
      end
    end
  end
end
