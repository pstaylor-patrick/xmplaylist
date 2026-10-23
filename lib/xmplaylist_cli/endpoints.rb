# frozen_string_literal: true

require "uri"

module XmplaylistCli
  # One HTTP call, described but not sent. Paths are absolute from the site
  # root; the client URL-encodes query values.
  Request = Data.define(:method, :path, :query, :body) do
    def initialize(method:, path:, query: {}, body: nil)
      super(method: method, path: path, query: query, body: body)
    end
  end

  # Pure request builders, one per operation in docs/xmplaylist-openapi.json
  # except GET/POST /api/subscriptions/unsubscribe/{token} (an email-link flow
  # that duplicates sub-delete). Commands never build paths themselves.
  # nil-valued query and body keys are dropped.
  module Endpoints
    module_function

    TRACK_MATCHES = %w[includes exact].freeze
    ARTIST_MATCHES = %w[all any].freeze
    VIEWS = %w[gainers decliners].freeze
    MOST_PLAYED_DAYS = %w[7 14 30 60 90 180 12m ytd].freeze
    CATALOG_DAYS = %w[30 60 90 180 365].freeze
    ROSTER_DAYS = %w[7 30 90 365].freeze
    SEARCH_LIMITS = [50, 100, 200, 500, 1000].freeze
    SUB_FREQUENCIES = %w[immediate daily weekly monthly].freeze

    # CLI filter names -> spec query/body keys, shared by search, insights,
    # export, and track-lookup.
    FILTER_KEYS = {
      track: "trackName", track_match: "trackMatch", isrc: "isrc", artist: "artistName",
      artist_match: "artistMatch", label: "recordLabel", station: "station", time_ago: "timeAgo",
      start: "startDate", end: "endDate"
    }.freeze
    # track-lookup takes a narrower filter set.
    LOOKUP_FILTERS = %i[track artist isrc label station].freeze

    # -- stations -------------------------------------------------------------

    def stations = get("/api/station")
    def stations_extended = get("/api/station/extended")
    def station(channel, last: nil) = get(station_path(channel), { "last" => last })
    def station_newest(channel) = get("#{station_path(channel)}/newest")
    def most_heard(channel, window = {}) = get("#{station_path(channel)}/most-heard", window)
    def movers(channel, window = {}, view: nil) = get("#{station_path(channel)}/movers", window.merge("view" => view))
    def rankings(channel, window = {}) = get("#{station_path(channel)}/rankings", window)
    def artist_rankings(channel, window = {}) = get("#{station_path(channel)}/artist-rankings", window)
    def station_track(channel, track_id) = get("#{station_path(channel)}/track/#{segment(track_id)}")

    # -- feed, channel updates, usage ----------------------------------------

    def feed = get("/api/feed")

    def channel_updates(offset: nil, days: nil, channel: nil, name: nil)
      get("/api/channel-updates", { "offset" => offset, "days" => days, "channel" => channel, "name" => name })
    end

    def channel_update_channels = get("/api/channel-updates/channels")
    def usage_remaining = get("/api/api-keys/usage/remaining")
    def track_report(track_id, updated_link:) = write("POST", "/api/track/#{segment(track_id)}/report", { updatedLink: updated_link })

    # -- search ---------------------------------------------------------------

    def search(filters = {}, page: nil, as_of: nil, limit: nil, aggregate: nil)
      get("/api/search", filter_query(filters).merge("page" => page, "asOf" => as_of, "limit" => limit,
                                                     "aggregate" => aggregate))
    end

    def search_insights(filters = {}, page: nil) = get("/api/search/insights", filter_query(filters).merge("page" => page))
    def search_labels(q, limit: nil) = get("/api/search/labels", { "q" => q, "limit" => limit })
    def recent_searches = get("/api/search/recent")

    # aggregate: true|false; the body carries the same filters as search,
    # except timeAgo is an integer in the body (a string in the query).
    def search_export(filters = {}, aggregate: nil)
      body = filter_query(filters).transform_keys(&:to_sym)
      body[:timeAgo] = Integer(body[:timeAgo], 10) if body.key?(:timeAgo)
      body[:aggregate] = aggregate unless aggregate.nil?
      write("POST", "/api/search/export", body)
    end

    # -- subscriptions --------------------------------------------------------

    def subscriptions = get("/api/subscriptions")
    def subscription(id) = get("/api/subscriptions/#{segment(id)}")
    def create_subscription(body) = write("POST", "/api/subscriptions", symbolize(body))
    def update_subscription(id, body) = write("PATCH", "/api/subscriptions/#{segment(id)}", symbolize(body))
    def delete_subscription(id) = write("DELETE", "/api/subscriptions/#{segment(id)}")

    # -- reports --------------------------------------------------------------

    def report_most_played(days: nil) = get("/api/reports/most-played", { "days" => days })
    def report_new_hot(genre: nil) = get("/api/reports/new-hot", { "genre" => genre })
    def report_debuts(days: nil, channels: nil) = get("/api/reports/debuts", { "days" => days, "channels" => channels })

    def report_catalog_depth(artist:, days: nil, min_plays: nil)
      get("/api/reports/catalog-depth", { "artist" => artist, "days" => days, "minPlays" => min_plays })
    end

    def report_station_adds(station: nil, chart_month: nil, since: nil, until_date: nil)
      get("/api/reports/station-adds", { "station" => station, "chartMonth" => chart_month, "since" => since,
                                         "until" => until_date })
    end

    def report_station_rotation(station:, ending_month: nil)
      get("/api/reports/station-rotation", { "station" => station, "endingMonth" => ending_month })
    end

    def report_station_rotation_matrix(station:, ending_month: nil)
      get("/api/reports/station-rotation/matrix", { "station" => station, "endingMonth" => ending_month })
    end

    def report_prime_time(days: nil) = get("/api/reports/prime-time", { "days" => days })
    def report_momentum(view: nil, channels: nil) = get("/api/reports/momentum", { "view" => view, "channels" => channels })

    def report_artist_momentum(view: nil, days: nil, channels: nil)
      get("/api/reports/artist-momentum", { "view" => view, "days" => days, "channels" => channels })
    end

    def report_recent_episodes(station: nil) = get("/api/reports/recent-episodes", { "station" => station })

    def report_recent_episode(episode_id, station: nil)
      get("/api/reports/recent-episodes/#{segment(episode_id)}", { "station" => station })
    end

    def report_track_lookup(filters = {}, page: nil)
      unknown = filters.compact.keys - LOOKUP_FILTERS
      raise ArgumentError, "track-lookup does not take: #{unknown.join(', ')}" unless unknown.empty?

      get("/api/reports/track-lookup", filter_query(filters).merge("page" => page))
    end

    def report_track_lookup_show(track_id) = get("/api/reports/track-lookup/#{segment(track_id)}")

    # -- artists --------------------------------------------------------------

    def artists(q) = get("/api/artists", { "q" => q })
    def artists_search(q) = get("/api/artists/search", { "q" => q })
    def artists_hot = get("/api/artists/hot")
    def artists_hot_full = get("/api/artists/hot/full")
    def artist(id) = get(artist_path(id))
    def artist_peers(id) = get("#{artist_path(id)}/peers")
    def artist_history_tracks(id) = get("#{artist_path(id)}/history/tracks")
    def artist_history_stations(id) = get("#{artist_path(id)}/history/stations")
    def artist_station_rank(id, station_id:) = get("#{artist_path(id)}/station-rank", { "stationId" => station_id })
    def artist_updates(id) = get("#{artist_path(id)}/updates")
    def artist_updates_preview(id) = get("#{artist_path(id)}/updates/preview")
    def set_artist_updates(id, enabled:) = write("PUT", "#{artist_path(id)}/updates", { enabled: enabled })

    # -- roster ---------------------------------------------------------------

    def roster_membership = get("/api/roster/membership")
    def roster = get("/api/roster")
    def roster_artist(id) = get(roster_path(id))

    def roster_add(display_name:, spotify_artist_id: nil)
      write("POST", "/api/roster", { displayName: display_name, spotifyArtistId: spotify_artist_id })
    end

    def roster_remove(id) = write("DELETE", roster_path(id))
    def roster_linked_artist(id) = get("#{roster_path(id)}/linked-artist")
    # The spec declares no body: the API switches to the artist the name is
    # already linked to (see roster_linked_artist), so no artist id is sent.
    def roster_link(id) = write("POST", "#{roster_path(id)}/linked-artist")
    def roster_peers(id) = get("#{roster_path(id)}/peers")
    def roster_report(id, days: nil) = get("#{roster_path(id)}/report", { "days" => days })
    def roster_catalog(id, days: nil) = get("#{roster_path(id)}/catalog", { "days" => days })
    def roster_sparklines(id, days: nil) = get("#{roster_path(id)}/sparklines", { "days" => days })
    def roster_history_tracks(id) = get("#{roster_path(id)}/history/tracks")
    def roster_history_stations(id) = get("#{roster_path(id)}/history/stations")
    def roster_station_rank(id, station_id:) = get("#{roster_path(id)}/station-rank", { "stationId" => station_id })

    # -- helpers --------------------------------------------------------------

    def get(path, query = {}) = Request.new(method: "GET", path: path, query: query.compact)

    def write(method, path, body = nil)
      Request.new(method: method, path: path, body: body&.compact)
    end

    def filter_query(filters)
      unknown = filters.keys - FILTER_KEYS.keys
      raise ArgumentError, "unknown filter: #{unknown.join(', ')}" unless unknown.empty?

      filters.compact.to_h { |key, value| [FILTER_KEYS.fetch(key), value] }
    end

    def symbolize(hash) = hash.to_h { |k, v| [k.to_sym, v] }.compact
    def station_path(channel) = "/api/station/#{segment(channel)}"
    def artist_path(id) = "/api/artists/#{segment(id)}"
    def roster_path(id) = "/api/roster/#{segment(id)}"
    def segment(value) = URI.encode_www_form_component(value.to_s)
  end
end
