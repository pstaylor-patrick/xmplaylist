# frozen_string_literal: true

require_relative "spec_helper"
require "json"
require "xmplaylist_cli/endpoints"

# Every request builder checked against docs/xmplaylist-openapi.json: the
# method and path template exist, query keys are declared parameters, body
# keys are properties of the request schema, required keys are present, and
# values fit declared enums and types. A coverage test makes sure every spec
# operation is built by some builder, except EXCLUDED. Refresh the snapshot,
# then run this file.
describe "Endpoints against docs/xmplaylist-openapi.json" do
  SNAPSHOT = JSON.parse(File.read(File.expand_path("../docs/xmplaylist-openapi.json", __dir__)))
  EP = XmplaylistCli::Endpoints
  HTTP_METHODS = %w[get post put patch delete].freeze

  # Email-link unsubscribe flow; sub-delete covers the same action.
  EXCLUDED = ["GET /api/subscriptions/unsubscribe/{token}", "POST /api/subscriptions/unsubscribe/{token}"].freeze

  # Module functions that build parts of requests rather than requests.
  HELPERS = %i[get write filter_query symbolize station_path artist_path roster_path segment].freeze

  FILTERS = { track: "Placeholder Song", track_match: "exact", isrc: "USXXX0000000", artist: "Placeholder Artist",
              artist_match: "any", label: "Placeholder Records", station: "examplerock", time_ago: "86400",
              start: "2026-01-01", end: "2026-01-31" }.freeze
  WINDOWS = [{}, { "days" => 30 }, { "year" => 2024 }, { "month" => "2024-05" }, { "week" => "2024-05-05" }].freeze
  SUB_BODY = { "name" => "Placeholder alert", "frequency" => "weekly", "action" => "email",
               "queries" => [{ "stationId" => "examplerock", "artistName" => "Placeholder Artist",
                               "trackMatch" => "exact", "artistMatch" => "any" }] }.freeze

  # One or more sample calls per builder, covering every optional key.
  SAMPLES = {
    stations: [-> { EP.stations }],
    stations_extended: [-> { EP.stations_extended }],
    station: [-> { EP.station("examplerock") }, -> { EP.station("examplerock", last: "1700000000000") }],
    station_newest: [-> { EP.station_newest("examplerock") }],
    most_heard: WINDOWS.map { |w| -> { EP.most_heard("examplerock", w) } },
    movers: WINDOWS.map { |w| -> { EP.movers("examplerock", w) } } +
      EP::VIEWS.map { |v| -> { EP.movers("examplerock", { "days" => 7 }, view: v) } },
    rankings: WINDOWS.map { |w| -> { EP.rankings("examplerock", w) } },
    artist_rankings: WINDOWS.map { |w| -> { EP.artist_rankings("examplerock", w) } },
    station_track: [-> { EP.station_track("examplerock", "track-1") }],
    feed: [-> { EP.feed }],
    channel_updates: [-> { EP.channel_updates },
                      -> { EP.channel_updates(offset: 50, days: 30, channel: "examplerock", name: "Example") }],
    channel_update_channels: [-> { EP.channel_update_channels }],
    usage_remaining: [-> { EP.usage_remaining }],
    track_report: [-> { EP.track_report("track-1", updated_link: "https://open.spotify.com/track/placeholder") }],
    search: [-> { EP.search({ artist: "Placeholder Artist" }) },
             -> { EP.search(FILTERS, page: 2, as_of: "2026-01-31T00:00:00Z", limit: 100, aggregate: "true") }] +
      EP::TRACK_MATCHES.product(EP::ARTIST_MATCHES).map { |t, a| -> { EP.search({ track_match: t, artist_match: a }) } },
    search_insights: [-> { EP.search_insights(FILTERS, page: 1) }],
    search_labels: [-> { EP.search_labels("Pl") }, -> { EP.search_labels("Placeholder", limit: 25) }],
    recent_searches: [-> { EP.recent_searches }],
    search_export: [-> { EP.search_export({ artist: "Placeholder Artist" }) },
                    -> { EP.search_export(FILTERS, aggregate: true) }],
    subscriptions: [-> { EP.subscriptions }],
    subscription: [-> { EP.subscription("sub-1") }],
    create_subscription: [-> { EP.create_subscription(SUB_BODY) }] +
      EP::SUB_FREQUENCIES.map { |f| -> { EP.create_subscription(SUB_BODY.merge("frequency" => f)) } },
    update_subscription: [-> { EP.update_subscription("sub-1", { "isActive" => false }) },
                          -> { EP.update_subscription("sub-1", SUB_BODY.merge("isActive" => true)) }],
    delete_subscription: [-> { EP.delete_subscription("sub-1") }],
    report_most_played: [-> { EP.report_most_played }] +
      EP::MOST_PLAYED_DAYS.map { |d| -> { EP.report_most_played(days: d) } },
    report_new_hot: [-> { EP.report_new_hot }, -> { EP.report_new_hot(genre: "rock") }],
    report_debuts: [-> { EP.report_debuts }, -> { EP.report_debuts(days: 14, channels: "all") }],
    report_catalog_depth: [-> { EP.report_catalog_depth(artist: "Placeholder Artist") }] +
      EP::CATALOG_DAYS.map { |d| -> { EP.report_catalog_depth(artist: "Placeholder Artist", days: d, min_plays: "3") } },
    report_station_adds: [-> { EP.report_station_adds },
                          lambda {
                            EP.report_station_adds(station: "examplerock", chart_month: "2026-01-01",
                                                   since: "2026-01-01", until_date: "2026-01-31")
                          }],
    report_station_rotation: [-> { EP.report_station_rotation(station: "examplerock", ending_month: "2026-01-01") }],
    report_station_rotation_matrix: [-> { EP.report_station_rotation_matrix(station: "examplerock") }],
    report_prime_time: [-> { EP.report_prime_time }, -> { EP.report_prime_time(days: 30) }],
    report_momentum: EP::VIEWS.map { |v| -> { EP.report_momentum(view: v, channels: "music") } },
    report_artist_momentum: EP::VIEWS.map { |v| -> { EP.report_artist_momentum(view: v, days: 7, channels: "all") } },
    report_recent_episodes: [-> { EP.report_recent_episodes }, -> { EP.report_recent_episodes(station: "examplerock") }],
    report_recent_episode: [-> { EP.report_recent_episode("ep-1", station: "examplerock") }],
    report_track_lookup: [-> { EP.report_track_lookup(FILTERS.slice(*EP::LOOKUP_FILTERS), page: 2) }],
    report_track_lookup_show: [-> { EP.report_track_lookup_show("track-1") }],
    artists: [-> { EP.artists("Placeholder") }],
    artists_search: [-> { EP.artists_search("Placeholder") }],
    artists_hot: [-> { EP.artists_hot }],
    artists_hot_full: [-> { EP.artists_hot_full }],
    artist: [-> { EP.artist("artist0000000000000001") }],
    artist_peers: [-> { EP.artist_peers("artist0000000000000001") }],
    artist_history_tracks: [-> { EP.artist_history_tracks("artist0000000000000001") }],
    artist_history_stations: [-> { EP.artist_history_stations("artist0000000000000001") }],
    artist_station_rank: [-> { EP.artist_station_rank("artist0000000000000001", station_id: "examplerock") }],
    artist_updates: [-> { EP.artist_updates("artist0000000000000001") }],
    artist_updates_preview: [-> { EP.artist_updates_preview("artist0000000000000001") }],
    set_artist_updates: [true, false].map { |on| -> { EP.set_artist_updates("artist0000000000000001", enabled: on) } },
    roster_membership: [-> { EP.roster_membership }],
    roster: [-> { EP.roster }],
    roster_artist: [-> { EP.roster_artist("00000000-0000-0000-0000-000000000001") }],
    roster_add: [-> { EP.roster_add(display_name: "Placeholder Artist") },
                 -> { EP.roster_add(display_name: "Placeholder Artist", spotify_artist_id: "artist0000000000000001") }],
    roster_remove: [-> { EP.roster_remove("00000000-0000-0000-0000-000000000001") }],
    roster_linked_artist: [-> { EP.roster_linked_artist("00000000-0000-0000-0000-000000000001") }],
    roster_link: [-> { EP.roster_link("00000000-0000-0000-0000-000000000001") }],
    roster_peers: [-> { EP.roster_peers("r1") }],
    roster_report: [-> { EP.roster_report("r1") }] + EP::ROSTER_DAYS.map { |d| -> { EP.roster_report("r1", days: d) } },
    roster_catalog: EP::ROSTER_DAYS.map { |d| -> { EP.roster_catalog("r1", days: d) } },
    roster_sparklines: EP::ROSTER_DAYS.map { |d| -> { EP.roster_sparklines("r1", days: d) } },
    roster_history_tracks: [-> { EP.roster_history_tracks("r1") }],
    roster_history_stations: [-> { EP.roster_history_stations("r1") }],
    roster_station_rank: [-> { EP.roster_station_rank("r1", station_id: "examplerock") }]
  }.freeze

  # -- schema helpers ---------------------------------------------------------

  def deref(schema)
    while schema.is_a?(Hash) && schema["$ref"]
      schema = schema["$ref"].delete_prefix("#/").split("/").reduce(SNAPSHOT) { |node, key| node.fetch(key) }
    end
    schema
  end

  def json_type(value)
    case value
    when nil then "null"
    when true, false then "boolean"
    when Integer then "integer"
    when Numeric then "number"
    when String then "string"
    when Array then "array"
    when Hash then "object"
    end
  end

  # Problems with a JSON body value against schema; [] when it fits.
  def problems(value, schema, where)
    schema = deref(schema)
    return [] unless schema.is_a?(Hash)

    if (alternatives = schema["anyOf"] || schema["oneOf"])
      found = alternatives.map { |alt| problems(value, alt, where) }
      return found.any?(&:empty?) ? [] : ["#{where}: #{value.inspect} fits none of anyOf/oneOf"]
    end

    out = []
    types = Array(schema["type"])
    type = json_type(value)
    unless types.empty? || types.include?(type) || (type == "integer" && types.include?("number"))
      out << "#{where}: #{type} is not #{types.join('|')}"
    end
    out << "#{where}: #{value.inspect} is not one of #{schema['enum'].join(', ')}" if schema["enum"] && !schema["enum"].include?(value)
    if value.is_a?(Hash)
      props = schema["properties"] || {}
      out.concat(value.keys.map(&:to_s).reject { |k| props.key?(k) }.map { |k| "#{where}: #{k} is not a property" })
      out.concat((schema["required"] || []).reject { |k| value.key?(k.to_sym) || value.key?(k) }
                                          .map { |k| "#{where}: required #{k} is missing" })
      value.each { |k, v| out.concat(problems(v, props[k.to_s], "#{where}.#{k}")) if props.key?(k.to_s) }
    end
    value.each_with_index { |item, i| out.concat(problems(item, schema["items"], "#{where}[#{i}]")) } if value.is_a?(Array) && schema["items"]
    out
  end

  # Query values travel as text, so a type is checked on the text and an enum
  # compared as strings.
  def query_value_problems(value, schema, where)
    schema = deref(schema)
    return [] unless schema.is_a?(Hash)
    if (alternatives = schema["anyOf"] || schema["oneOf"])
      return alternatives.any? { |alt| query_value_problems(value, alt, where).empty? } ? [] : ["#{where}: fits no alternative"]
    end

    text = value.to_s
    out = []
    types = Array(schema["type"]) - ["null"]
    ok = types.empty? || types.any? do |t|
      case t
      when "integer" then text.match?(/\A-?\d+\z/)
      when "number" then text.match?(/\A-?\d+(\.\d+)?\z/)
      when "boolean" then %w[true false].include?(text)
      else true
      end
    end
    out << "#{where}: '#{text}' is not #{types.join('|')}" unless ok
    out << "#{where}: '#{text}' is not one of #{schema['enum'].join(', ')}" if schema["enum"] && !schema["enum"].map(&:to_s).include?(text)
    out << "#{where}: '#{text}' does not match #{schema['pattern']}" if schema["pattern"] && !text.match?(Regexp.new(schema["pattern"]))
    out
  end

  # The template the router would pick: a literal match beats a parameter.
  def template_for(path)
    SNAPSHOT["paths"].keys
                     .select { |t| Regexp.new("\\A#{Regexp.escape(t).gsub(/\\\{[^}]+\\\}/, '[^/]+')}\\z").match?(path) }
                     .min_by { |t| t.count("{") }
  end

  def params_of(operation, path_item)
    ((operation["parameters"] || []) + (path_item["parameters"] || [])).map { |p| deref(p) }
  end

  def query_problems(request, operation, path_item)
    params = params_of(operation, path_item).select { |p| p["in"] == "query" }
    declared = params.to_h { |p| [p["name"], p["schema"]] }
    missing = params.select { |p| p["required"] && !request.query.key?(p["name"]) }.map { |p| "required query #{p['name']} is missing" }
    missing + request.query.flat_map do |key, value|
      declared.key?(key) ? query_value_problems(value, declared[key], "query #{key}") : ["query #{key} is not a declared parameter"]
    end
  end

  def body_problems(request, operation)
    body_spec = operation["requestBody"]
    return(body_spec&.dig("required") ? ["body is required"] : []) if request.body.nil?
    return ["sends a body, but the operation takes none"] unless body_spec

    schema = body_spec.dig("content", "application/json", "schema")
    return ["no application/json request schema"] unless schema

    problems(request.body, schema, "body")
  end

  def operation_key(request) = "#{request.method} #{template_for(request.path)}"

  # -- specs ------------------------------------------------------------------

  it "has a sample for every builder" do
    assert_equal (EP.singleton_methods - HELPERS).sort, SAMPLES.keys.sort
  end

  SAMPLES.each do |name, calls|
    it "#{name} matches the snapshot" do
      calls.each do |call|
        request = call.call
        template = template_for(request.path)
        refute_nil template, "#{name}: #{request.path} matches no path in the snapshot"
        path_item = SNAPSHOT["paths"][template]
        operation = path_item[request.method.downcase]
        refute_nil operation, "#{name}: #{request.method} is not defined on #{template}"

        found = query_problems(request, operation, path_item) + body_problems(request, operation)
        assert_empty found, "#{name} (#{request.method} #{template}):\n  #{found.join("\n  ")}"
      end
    end
  end

  it "covers every spec operation except EXCLUDED, and EXCLUDED names real operations" do
    spec_ops = SNAPSHOT["paths"].flat_map do |path, item|
      (item.keys & HTTP_METHODS).map { |m| "#{m.upcase} #{path}" }
    end
    built = SAMPLES.values.flatten.map { |call| operation_key(call.call) }.uniq
    assert_empty EXCLUDED - spec_ops, "EXCLUDED lists operations the snapshot does not have"
    assert_empty built & EXCLUDED, "an EXCLUDED operation has a builder"
    assert_empty (spec_ops - EXCLUDED - built).sort, "spec operations with no builder"
  end

  describe "validation tables match the snapshot enums" do
    def query_enum(path, name, method = "get")
      op = SNAPSHOT.dig("paths", path, method)
      deref(params_of(op, SNAPSHOT["paths"][path]).find { |p| p["name"] == name }["schema"])["enum"]
    end

    it "matches" do
      assert_equal query_enum("/api/search", "trackMatch"), EP::TRACK_MATCHES
      assert_equal query_enum("/api/search", "artistMatch"), EP::ARTIST_MATCHES
      assert_equal query_enum("/api/station/{channel}/movers", "view"), EP::VIEWS
      assert_equal query_enum("/api/reports/momentum", "view"), EP::VIEWS
      assert_equal query_enum("/api/reports/most-played", "days"), EP::MOST_PLAYED_DAYS
      assert_equal query_enum("/api/reports/catalog-depth", "days"), EP::CATALOG_DAYS
      %w[report catalog sparklines].each { |k| assert_equal query_enum("/api/roster/{id}/#{k}", "days"), EP::ROSTER_DAYS }
      sub = SNAPSHOT.dig("paths", "/api/subscriptions", "post", "requestBody", "content", "application/json", "schema")
      assert_equal sub.dig("properties", "frequency", "enum"), EP::SUB_FREQUENCIES
    end

    it "FILTER_KEYS map to search parameters and export body keys" do
      search = params_of(SNAPSHOT.dig("paths", "/api/search", "get"), {}).map { |p| p["name"] }
      export = SNAPSHOT.dig("paths", "/api/search/export", "post", "requestBody", "content", "application/json",
                            "schema", "properties").keys
      assert_empty EP::FILTER_KEYS.values - search
      assert_empty EP::FILTER_KEYS.values - export
    end
  end

  describe "the checker itself" do
    it "flags an unknown body key, a missing required key, a bad type, and a bad enum" do
      schema = { "type" => "object", "required" => %w[a], "properties" => {
        "a" => { "type" => "string" }, "b" => { "type" => "string", "enum" => %w[x y] }
      } }
      assert_equal 3, problems({ b: "z", c: 1 }, schema, "body").size
      assert_equal ["body.a: integer is not string"], problems({ a: 1 }, schema, "body")
    end

    it "flags an undeclared query key and a bad query enum" do
      op = SNAPSHOT.dig("paths", "/api/reports/most-played", "get")
      bad = XmplaylistCli::Request.new(method: "GET", path: "/api/reports/most-played", query: { "days" => "8", "x" => 1 })
      assert_equal 2, query_problems(bad, op, {}).size
    end

    it "prefers a literal path over a parameter" do
      assert_equal "/api/station/extended", template_for("/api/station/extended")
      assert_equal "/api/artists/hot", template_for("/api/artists/hot")
    end

    it "rejects a body on an operation that takes none" do
      op = SNAPSHOT.dig("paths", "/api/roster/{id}/linked-artist", "post")
      request = XmplaylistCli::Request.new(method: "POST", path: "/x", body: { a: 1 })
      assert_equal ["sends a body, but the operation takes none"], body_problems(request, op)
    end
  end
end
