# frozen_string_literal: true

require "xmplaylist_cli/command_support"

module XmplaylistCli
  module Commands
    # xmplaylist report <kind> [ID] [flags]: one dispatcher for the report
    # endpoints, which share most flags. `report --list` prints the kinds.
    # --station is sent as given (a deeplink); reports never spend a request
    # on channel resolution.
    class Report
      # kind => [positional arg name or nil, flags, description]
      KINDS = {
        "most-played" => [nil, %i[days], "Most-played tracks (--days 7|14|30|60|90|180|12m|ytd)"],
        "new-hot" => [nil, %i[genre], "New and hot tracks"],
        "debuts" => [nil, %i[days channels], "Tracks debuting across channels"],
        "catalog-depth" => [nil, %i[artist days min_plays], "How deep an artist's catalog is played (requires --artist)"],
        "station-adds" => [nil, %i[station chart_month since until], "Tracks added by a station"],
        "station-rotation" => [nil, %i[station ending_month], "A station's rotation (requires --station)"],
        "station-rotation-matrix" => [nil, %i[station ending_month], "Rotation as a month matrix (requires --station)"],
        "prime-time" => [nil, %i[days], "Prime-time plays"],
        "momentum" => [nil, %i[view channels], "Track momentum (--view gainers|decliners)"],
        "artist-momentum" => [nil, %i[view days channels], "Artist momentum (--view gainers|decliners)"],
        "recent-episodes" => [nil, %i[station], "Recent show episodes"],
        "recent-episode" => ["EPISODE_ID", %i[station], "One show episode"],
        "track-lookup" => [nil, %i[track artist isrc label station page], "Look up tracks by filters"],
        "track-lookup-show" => ["TRACK_ID", [], "One track lookup"]
      }.freeze

      def self.run(ctx, argv)
        if argv.first == "--list"
          rows = KINDS.map { |kind, (arg, _, desc)| { kind: kind, arg: arg.to_s, description: desc } }
          return ctx.formatter.list("report", rows, columns: { "kind" => :kind, "arg" => :arg, "description" => :description })
        end

        kind = argv.shift
        raise UsageError, "missing report kind; see xmplaylist report --list" if kind.nil? || kind.start_with?("-")
        raise UsageError, "unknown report kind: #{kind}; see xmplaylist report --list" unless KINDS.key?(kind)

        arg_name, flags, = KINDS[kind]
        opts = {}
        parser = CommandSupport.parser(opts, banner: "report #{kind}#{" #{arg_name}" if arg_name} #{flags.map { "--#{_1.to_s.tr('_', '-')} V" }.join(' ')}") do |o|
          flags.each { |flag| o.on("--#{flag.to_s.tr('_', '-')} V") { |v| opts[flag] = v } }
        end
        arg = arg_name ? CommandSupport.one_arg!(parser, argv, arg_name) : CommandSupport.parse!(parser, argv, max_args: 0)
        ctx.formatter.list("report", ctx.client.fetch(request(kind, arg, opts)))
      end

      def self.request(kind, arg, opts)
        case kind
        when "most-played"
          Endpoints.report_most_played(days: CommandSupport.one_of!(opts[:days], Endpoints::MOST_PLAYED_DAYS, flag: "--days"))
        when "new-hot" then Endpoints.report_new_hot(genre: opts[:genre])
        when "debuts" then Endpoints.report_debuts(days: opts[:days], channels: opts[:channels])
        when "catalog-depth"
          raise UsageError, "report catalog-depth requires --artist" unless opts[:artist]

          Endpoints.report_catalog_depth(artist: opts[:artist], min_plays: opts[:min_plays],
                                         days: CommandSupport.one_of!(opts[:days], Endpoints::CATALOG_DAYS, flag: "--days"))
        when "station-adds"
          Endpoints.report_station_adds(station: opts[:station], chart_month: opts[:chart_month], since: opts[:since],
                                        until_date: opts[:until])
        when "station-rotation", "station-rotation-matrix"
          raise UsageError, "report #{kind} requires --station" unless opts[:station]

          meth = kind == "station-rotation" ? :report_station_rotation : :report_station_rotation_matrix
          Endpoints.public_send(meth, station: opts[:station], ending_month: opts[:ending_month])
        when "prime-time" then Endpoints.report_prime_time(days: opts[:days])
        when "momentum" then Endpoints.report_momentum(view: view(opts), channels: opts[:channels])
        when "artist-momentum"
          Endpoints.report_artist_momentum(view: view(opts), days: opts[:days], channels: opts[:channels])
        when "recent-episodes" then Endpoints.report_recent_episodes(station: opts[:station])
        when "recent-episode" then Endpoints.report_recent_episode(arg, station: opts[:station])
        when "track-lookup"
          filters = opts.slice(*Endpoints::LOOKUP_FILTERS)
          Endpoints.report_track_lookup(filters, page: opts[:page] && CommandSupport.count(opts[:page], flag: "--page"))
        when "track-lookup-show" then Endpoints.report_track_lookup_show(arg)
        end
      end

      def self.view(opts) = CommandSupport.one_of!(opts[:view], Endpoints::VIEWS, flag: "--view")
    end
  end
end
