# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # The filter flags shared by search, search-insights, and search-export.
    module SearchFilters
      BANNER = "[--track S] [--track-match M] [--isrc S] [--artist S] [--artist-match M] [--label S] " \
               "[--station CH] [--time-ago SECONDS] [--start DATE] [--end DATE]"

      def self.define(o, opts)
        f = opts[:filters] = {}
        o.on("--track S", "Track name") { |v| f[:track] = v }
        o.on("--track-match M", "includes or exact") do |v|
          f[:track_match] = CommandSupport.one_of!(v, Endpoints::TRACK_MATCHES, flag: "--track-match")
        end
        o.on("--isrc S", "ISRC code") { |v| f[:isrc] = v }
        o.on("--artist S", "Artist name") { |v| f[:artist] = v }
        o.on("--artist-match M", "all or any") do |v|
          f[:artist_match] = CommandSupport.one_of!(v, Endpoints::ARTIST_MATCHES, flag: "--artist-match")
        end
        o.on("--label S", "Record label") { |v| f[:label] = v }
        o.on("--station CH", "One channel (deeplink, name, or number)") { |v| f[:station] = v }
        o.on("--time-ago SECONDS", "Plays within this many seconds") do |v|
          f[:time_ago] = CommandSupport.count(v, flag: "--time-ago").to_s
        end
        o.on("--start DATE", "Start date (YYYY-MM-DD)") { |v| f[:start] = date!(v, "--start") }
        o.on("--end DATE", "End date (YYYY-MM-DD)") { |v| f[:end] = date!(v, "--end") }
      end

      # The filters with --station resolved to the channel id (one GET /api/station).
      # /api/search rejects a deeplink or number with "Invalid station" (400).
      def self.resolve(ctx, opts)
        filters = opts[:filters].dup
        filters[:station] = CommandSupport.channel(ctx, filters[:station])[:id] if filters[:station]
        filters
      end

      def self.date!(value, flag)
        return value if value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        raise UsageError, "#{flag} must be YYYY-MM-DD, got '#{value}'"
      end
    end
  end
end
