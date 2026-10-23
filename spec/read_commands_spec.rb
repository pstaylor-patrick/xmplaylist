# frozen_string_literal: true

require_relative "spec_helper"
require_relative "support/fake_client"
require "json"
require "stringio"
require "xmplaylist_cli/command_support"
require "xmplaylist_cli/formatter"
%w[stations station newest most_heard movers rankings artist_rankings track feed channel_updates update_channels
   search search_insights labels recent_searches artists artist artist_peers artist_history artist_rank hot
   artist_updates]
  .each { |f| require "xmplaylist_cli/commands/#{f}" }

class ReadCommandsSpec < Minitest::Test
  C = XmplaylistCli::Commands

  def fixture(name) = JSON.parse(File.read(File.expand_path("fixtures/#{name}.json", __dir__)), symbolize_names: true)

  def client(extra = {})
    FakeClient.new(fetch: { "/api/station" => fixture("stations") }.merge(extra))
  end

  # Runs a command with the human formatter (or JSON) and returns stdout.
  def run_cmd(klass, argv, client:, json: false)
    out = StringIO.new
    $stdout = out
    formatter = json ? XmplaylistCli::JsonFormatter : XmplaylistCli::Formatter
    ctx = XmplaylistCli::Context.new(client: client, formatter: formatter, stdin: StringIO.new, err: StringIO.new)
    klass.run(ctx, argv)
    out.string
  ensure
    $stdout = STDOUT
  end

  def test_stations_table
    out = run_cmd(C::Stations, [], client: client)
    assert_match(/^deeplink\s+number\s+name\s+genres$/, out)
    assert_match(/examplerock\s+101\s+Example Rock\s+rock/, out)
  end

  def test_stations_json_envelope
    body = JSON.parse(run_cmd(C::Stations, [], client: client, json: true))
    assert_equal true, body["ok"]
    assert_equal "stations", body["command"]
    assert_equal "examplerock", body["data"]["results"][0]["deeplink"]
  end

  def test_stations_extended_hits_paid_path
    fake = client("/api/station/extended" => fixture("stations"))
    run_cmd(C::Stations, ["--extended"], client: fake)
    assert_equal "/api/station/extended", fake.calls.last.path
  end

  def test_station_resolves_name_and_trims
    fake = client("/api/station/examplerock" => fixture("station_history"))
    out = run_cmd(C::Station, ["Example Rock", "-n", "1"], client: fake)
    assert_match(/Placeholder Song\s+Placeholder Artist/, out)
    refute_match(/Example Tune/, out)
    assert_equal "/api/station/examplerock", fake.calls.last.path
  end

  def test_station_since_ms_sets_cursor
    fake = client("/api/station/examplerock" => fixture("station_history"))
    run_cmd(C::Station, ["101", "--since-ms", "1700000000000"], client: fake)
    assert_equal 1_700_000_000_000, fake.calls.last.query["last"]
  end

  def test_unknown_channel_is_not_found
    assert_raises(XmplaylistCli::NotFoundError) { run_cmd(C::Station, ["nope"], client: client) }
  end

  def test_newest
    fake = client("/api/station/examplerock/newest" => fixture("station_history"))
    assert_match(/Example Tune\s+Example Band, Guest Artist/, run_cmd(C::Newest, ["examplerock"], client: fake))
  end

  def test_most_heard_with_window
    fake = client("/api/station/examplerock/most-heard" => fixture("rankings"))
    out = run_cmd(C::MostHeard, ["examplerock", "--days", "7"], client: fake)
    assert_match(/^plays\s+title\s+artists$/, out)
    assert_equal({ "days" => 7 }, fake.calls.last.query)
  end

  def test_window_flags_are_exclusive
    assert_raises(XmplaylistCli::UsageError) do
      run_cmd(C::Rankings, ["examplerock", "--days", "7", "--year", "2025"], client: client)
    end
  end

  def test_movers_decliners
    fake = client("/api/station/examplerock/movers" => { results: [] })
    run_cmd(C::Movers, ["examplerock", "--decliners"], client: fake)
    assert_equal "decliners", fake.calls.last.query["view"]
  end

  def test_rankings_table
    fake = client("/api/station/examplerock/rankings" => fixture("rankings"))
    assert_match(/^1\s+2\s+40\s+Placeholder Song/, run_cmd(C::Rankings, ["examplerock"], client: fake))
  end

  def test_artist_rankings_table
    fake = client("/api/station/examplerock/artist-rankings" => fixture("artist_rankings"))
    out = run_cmd(C::ArtistRankings, ["examplerock", "--month", "2026-01"], client: fake)
    assert_match(/Placeholder Artist\s+Placeholder Song/, out)
    assert_equal({ "month" => "2026-01" }, fake.calls.last.query)
  end

  def test_track_show
    fake = client("/api/station/examplerock/track/track-1" => { id: "track-1", title: "Placeholder Song" })
    assert_match(/title:\s+Placeholder Song/, run_cmd(C::Track, ["examplerock", "track-1"], client: fake))
  end

  def test_track_needs_both_args
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Track, ["examplerock"], client: client) }
  end

  def test_feed_table_and_json
    fake = FakeClient.new(fetch: { "/api/feed" => fixture("feed") })
    assert_match(/placeholderpop\s+Feed Song\s+Feed Artist/, run_cmd(C::Feed, [], client: fake))
    body = JSON.parse(run_cmd(C::Feed, [], client: fake, json: true))
    assert_equal [true, "feed"], [body["ok"], body["command"]]
  end

  def test_channel_updates_maps_channel_to_deeplink
    fake = client("/api/channel-updates" => fixture("channel_updates"))
    out = run_cmd(C::ChannelUpdates, ["--channel", "101", "--days", "3"], client: fake)
    assert_match(/2026-01-01\s+examplerock\s+101\s+Example Rock\s+active/, out)
    assert_equal({ "offset" => nil, "days" => 3, "channel" => "examplerock", "name" => nil }.compact,
                 fake.calls.last.query.compact)
  end

  def test_channel_updates_days_range
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::ChannelUpdates, ["--days", "31"], client: client) }
  end

  def test_update_channels
    fake = FakeClient.new(fetch: { "/api/channel-updates/channels" => [
      { id: "station-1", name: "Example Rock", number: "101", deeplink: "examplerock", latestDate: "2026-01-01" }
    ] })
    assert_match(/examplerock\s+101\s+Example Rock\s+2026-01-01/, run_cmd(C::UpdateChannels, [], client: fake))
  end

  def test_search_maps_filters_and_resolves_station
    fake = client("/api/search" => { results: [{ id: "play-1", timestamp: "2026-01-01T12:00:00.000Z" }] })
    run_cmd(C::Search, ["--artist", "Placeholder Artist", "--station", "101", "--limit", "100", "--time-ago", "3600"],
            client: fake)
    assert_equal({ "artistName" => "Placeholder Artist", "station" => "examplerock", "limit" => 100, "timeAgo" => "3600" },
                 fake.calls.last.query)
  end

  def test_search_rejects_bad_limit_and_match
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Search, ["--limit", "7"], client: client) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Search, ["--track-match", "fuzzy"], client: client) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Search, ["--start", "Jan 1"], client: client) }
  end

  def test_search_all_follows_pages
    pages = ->(req) { req.query["page"] == 2 ? { results: [{ id: "b" }], next: nil } : { results: [{ id: "a" }], next: "x" } }
    fake = FakeClient.new(fetch: { "/api/search" => pages })
    body = JSON.parse(run_cmd(C::Search, ["--track", "Song", "--all"], client: fake, json: true))
    assert_equal %w[a b], body["data"]["results"].map { |r| r["id"] }
  end

  def test_search_insights_show
    fake = FakeClient.new(fetch: { "/api/search/insights" => { totalPlays: 12 } })
    assert_match(/totalPlays:\s+12/, run_cmd(C::SearchInsights, ["--isrc", "XX0000000000"], client: fake))
    assert_equal({ "isrc" => "XX0000000000" }, fake.calls.last.query)
  end

  def test_labels
    fake = FakeClient.new(fetch: { "/api/search/labels" => [{ name: "Example Records" }] })
    assert_match(/Example Records/, run_cmd(C::Labels, ["ex", "--limit", "5"], client: fake))
    assert_equal({ "q" => "ex", "limit" => 5 }, fake.calls.last.query)
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Labels, ["ex", "--limit", "26"], client: fake) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Labels, ["e"], client: fake) }
  end

  def test_recent_searches
    fake = FakeClient.new(fetch: { "/api/search/recent" => [{ id: "s-1", query: "placeholder" }] })
    assert_match(/s-1\s+placeholder/, run_cmd(C::RecentSearches, [], client: fake))
  end

  def test_artists_and_full
    fake = FakeClient.new(fetch: { "/api/artists" => [{ id: "a1", name: "Placeholder Artist" }],
                                   "/api/artists/search" => [{ id: "a1", name: "Placeholder Artist" }] })
    assert_match(/a1\s+Placeholder Artist/, run_cmd(C::Artists, ["place"], client: fake))
    run_cmd(C::Artists, ["place", "--full"], client: fake)
    assert_equal ["/api/artists/search", { "q" => "place" }], [fake.calls.last.path, fake.calls.last.query]
  end

  def test_artist_peers_and_history
    fake = FakeClient.new(fetch: { "/api/artists/a1" => { name: "Placeholder Artist" },
                                   "/api/artists/a1/peers" => [{ name: "Peer" }],
                                   "/api/artists/a1/history/tracks" => [{ title: "T" }],
                                   "/api/artists/a1/history/stations" => [{ station: "S" }] })
    assert_match(/name:\s+Placeholder Artist/, run_cmd(C::Artist, ["a1"], client: fake))
    assert_match(/Peer/, run_cmd(C::ArtistPeers, ["a1"], client: fake))
    run_cmd(C::ArtistHistory, ["a1"], client: fake)
    assert_equal "/api/artists/a1/history/tracks", fake.calls.last.path
    run_cmd(C::ArtistHistory, ["a1", "--stations"], client: fake)
    assert_equal "/api/artists/a1/history/stations", fake.calls.last.path
  end

  def test_artist_rank_resolves_station_id
    fake = client("/api/artists/a1/station-rank" => { rank: 3 })
    assert_match(/rank:\s+3/, run_cmd(C::ArtistRank, ["a1", "--station", "Example Rock"], client: fake))
    assert_equal({ "stationId" => "station-1" }, fake.calls.last.query)
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::ArtistRank, ["a1"], client: fake) }
  end

  def test_hot_columns_and_full
    row = { spotifyArtistId: "a1", name: "Placeholder Artist", spins: 9, spinGain: 4 }
    fake = FakeClient.new(fetch: { "/api/artists/hot" => [row], "/api/artists/hot/full" => [row] })
    assert_match(/a1\s+Placeholder Artist\s+9\s+4/, run_cmd(C::Hot, [], client: fake))
    run_cmd(C::Hot, ["--full"], client: fake)
    assert_equal "/api/artists/hot/full", fake.calls.last.path
  end

  def test_artist_updates_and_preview
    fake = FakeClient.new(fetch: { "/api/artists/a1/updates" => { enabled: true },
                                   "/api/artists/a1/updates/preview" => { subject: "Preview" } })
    assert_match(/enabled:\s+true/, run_cmd(C::ArtistUpdates, ["a1"], client: fake))
    assert_match(/subject:\s+Preview/, run_cmd(C::ArtistUpdates, ["a1", "--preview"], client: fake))
  end
end
