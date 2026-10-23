# frozen_string_literal: true

require "xmplaylist_cli/command_support"
require "xmplaylist_cli/commands/search_filters"

module XmplaylistCli
  module Commands
    # xmplaylist search-export [filters] [--aggregate] [--out FILE] [-d]
    # Paid write. Small exports come back as CSV (to FILE or stdout); large
    # ones are queued and emailed, and the API's message is passed through.
    class SearchExport
      def self.run(ctx, argv)
        opts = {}
        parser = CommandSupport.parser(opts, banner: "search-export #{SearchFilters::BANNER} [--aggregate] [--out FILE] [-d]",
                                             write: true) do |o|
          SearchFilters.define(o, opts)
          o.on("--aggregate", "One row per track with a play count") { opts[:aggregate] = true }
          o.on("--out FILE", "Write the CSV here instead of stdout") { |v| opts[:out] = v }
        end
        CommandSupport.parse!(parser, argv, max_args: 0)
        # A dry run must not touch the network, so --station is sent as given.
        filters = opts[:dry_run] ? opts[:filters] : SearchFilters.resolve(ctx, opts)
        request = Endpoints.search_export(filters, aggregate: opts[:aggregate])
        if opts[:dry_run]
          ctx.formatter.dry_run("search-export", request)
          return
        end

        result = ctx.client.perform(request)
        if result.is_a?(String) && opts[:out]
          File.write(File.expand_path(opts[:out]), result)
          ctx.formatter.written("search-export", { file: opts[:out], bytes: result.bytesize },
                                summary: "search-export: wrote #{result.bytesize} bytes to #{opts[:out]}")
        elsif result.is_a?(String)
          ctx.formatter.text("search-export", result)
        else
          ctx.formatter.show("search-export", result)
        end
      end
    end
  end
end
