# frozen_string_literal: true

require_relative "spec_helper"
require_relative "support/fake_client"
require_relative "support/tty_input"
require "json"
require "stringio"
require "tmpdir"
require "xmplaylist_cli/command_support"
require "xmplaylist_cli/formatter"
%w[report membership roster roster_show roster_add roster_remove roster_link roster_peers roster_report roster_catalog
   roster_sparklines roster_history roster_rank subs sub sub_create sub_update sub_delete usage track_report].each do |f|
  require "xmplaylist_cli/commands/#{f}"
end

# Reports, roster, subscriptions, usage, and track-report. Every write has a
# dry-run spec; both deletes have TTY, --yes, and non-TTY guard specs.
class ReportRosterSubsSpec < Minitest::Test
  C = XmplaylistCli::Commands
  STATIONS = { results: [{ id: "station-1", name: "Example Rock", number: "101", deeplink: "examplerock" }] }.freeze

  def run_cmd(klass, argv, client:, json: false, stdin: StringIO.new)
    out = StringIO.new
    $stdout = out
    formatter = json ? XmplaylistCli::JsonFormatter : XmplaylistCli::Formatter
    ctx = XmplaylistCli::Context.new(client: client, formatter: formatter, stdin: stdin, err: StringIO.new)
    klass.run(ctx, argv)
    out.string
  ensure
    $stdout = STDOUT
  end

  # -- report ---------------------------------------------------------------

  REPORT_CASES = {
    ["most-played", "--days", "30"] => ["/api/reports/most-played", { "days" => "30" }],
    ["new-hot", "--genre", "rock"] => ["/api/reports/new-hot", { "genre" => "rock" }],
    ["debuts", "--days", "7", "--channels", "a,b"] => ["/api/reports/debuts", { "days" => "7", "channels" => "a,b" }],
    ["catalog-depth", "--artist", "x", "--min-plays", "2"] => ["/api/reports/catalog-depth", { "artist" => "x", "minPlays" => "2" }],
    ["station-adds", "--station", "s", "--until", "2026-01-01"] => ["/api/reports/station-adds", { "station" => "s", "until" => "2026-01-01" }],
    ["station-rotation", "--station", "s"] => ["/api/reports/station-rotation", { "station" => "s" }],
    ["station-rotation-matrix", "--station", "s", "--ending-month", "2026-01"] =>
      ["/api/reports/station-rotation/matrix", { "station" => "s", "endingMonth" => "2026-01" }],
    ["prime-time"] => ["/api/reports/prime-time", {}],
    ["momentum", "--view", "decliners"] => ["/api/reports/momentum", { "view" => "decliners" }],
    ["artist-momentum", "--view", "gainers", "--days", "7"] => ["/api/reports/artist-momentum", { "view" => "gainers", "days" => "7" }],
    ["recent-episodes"] => ["/api/reports/recent-episodes", {}],
    ["recent-episode", "e1"] => ["/api/reports/recent-episodes/e1", {}],
    ["track-lookup", "--artist", "x", "--page", "2"] => ["/api/reports/track-lookup", { "artistName" => "x", "page" => 2 }],
    ["track-lookup-show", "t1"] => ["/api/reports/track-lookup/t1", {}]
  }.freeze

  def test_every_report_kind_has_a_case
    assert_equal C::Report::KINDS.keys.sort, REPORT_CASES.keys.map(&:first).sort
  end

  def test_report_kinds_build_spec_requests
    REPORT_CASES.each do |argv, (path, query)|
      fake = FakeClient.new(fetch: { path => { results: [{ title: "placeholder" }] } })
      run_cmd(C::Report, argv.dup, client: fake)
      assert_equal path, fake.calls.last.path, argv.inspect
      assert_equal query, fake.calls.last.query, argv.inspect
    end
  end

  def test_report_list
    out = run_cmd(C::Report, ["--list"], client: FakeClient.new)
    C::Report::KINDS.each_key { |kind| assert_includes out, kind }
  end

  def test_report_unknown_kind_is_usage_error
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Report, ["bogus"], client: FakeClient.new) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Report, [], client: FakeClient.new) }
  end

  def test_report_required_flags_and_enums
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Report, ["catalog-depth"], client: FakeClient.new) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Report, ["station-rotation"], client: FakeClient.new) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Report, ["most-played", "--days", "5"], client: FakeClient.new) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Report, ["recent-episode"], client: FakeClient.new) }
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::Report, ["prime-time", "--genre", "x"], client: FakeClient.new) }
  end

  # -- roster reads ---------------------------------------------------------

  def test_roster_reads
    {
      [C::Membership, []] => "/api/roster/membership",
      [C::Roster, []] => "/api/roster",
      [C::RosterShow, ["r1"]] => "/api/roster/r1",
      [C::RosterPeers, ["r1"]] => "/api/roster/r1/peers",
      [C::RosterReport, ["r1", "--days", "30"]] => "/api/roster/r1/report",
      [C::RosterCatalog, ["r1"]] => "/api/roster/r1/catalog",
      [C::RosterSparklines, ["r1", "--days", "7"]] => "/api/roster/r1/sparklines",
      [C::RosterHistory, ["r1"]] => "/api/roster/r1/history/tracks",
      [C::RosterHistory, ["r1", "--stations"]] => "/api/roster/r1/history/stations",
      [C::RosterLink, ["r1", "--show"]] => "/api/roster/r1/linked-artist",
      [C::Subs, []] => "/api/subscriptions",
      [C::Sub, ["s1"]] => "/api/subscriptions/s1",
      [C::Usage, []] => "/api/api-keys/usage/remaining"
    }.each do |(klass, argv), path|
      fake = FakeClient.new(fetch: { path => { results: [{ id: "placeholder" }] } })
      run_cmd(klass, argv, client: fake)
      assert_equal [path], fake.calls.map(&:path), "#{klass} #{argv.inspect}"
      assert_empty fake.performed
    end
  end

  def test_roster_days_enum
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::RosterReport, ["r1", "--days", "14"], client: FakeClient.new) }
  end

  def test_roster_rank_resolves_station
    fake = FakeClient.new(fetch: { "/api/station" => STATIONS, "/api/roster/r1/station-rank" => { rank: 3 } })
    assert_match(/rank:\s+3/, run_cmd(C::RosterRank, ["r1", "--station", "101"], client: fake))
    assert_equal({ "stationId" => "station-1" }, fake.calls.last.query)
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::RosterRank, ["r1"], client: FakeClient.new) }
  end

  def test_usage_json_envelope
    fake = FakeClient.new(fetch: { "/api/api-keys/usage/remaining" => { remaining: 99 } })
    body = JSON.parse(run_cmd(C::Usage, [], client: fake, json: true))
    assert_equal true, body["ok"]
    assert_equal 99, body["data"]["remaining"]
  end

  # -- dry runs for every write ---------------------------------------------

  def with_body_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "sub.json")
      File.write(path, JSON.generate({ "frequency" => "daily", "artistName" => "placeholder" }))
      yield path
    end
  end

  def assert_dry_run(klass, argv, method_path, stdin: StringIO.new)
    fake = FakeClient.new
    out = run_cmd(klass, argv, client: fake, stdin: stdin)
    assert_match(/DRY RUN/, out)
    assert_includes out, method_path
    assert_empty fake.calls
    assert_empty fake.performed
    out
  end

  def test_dry_runs_send_nothing
    assert_dry_run(C::RosterAdd, ["Placeholder Band", "--spotify", "sp1", "-d"], "POST /api/roster")
    assert_dry_run(C::RosterRemove, ["r1", "-d"], "DELETE /api/roster/r1")
    assert_dry_run(C::RosterLink, ["r1", "-d"], "POST /api/roster/r1/linked-artist")
    assert_dry_run(C::SubDelete, ["s1", "-d"], "DELETE /api/subscriptions/s1")
    out = assert_dry_run(C::TrackReport, ["t1", "--link", "https://example.com/x", "-d"], "POST /api/track/t1/report")
    assert_match(/"updatedLink": "https:\/\/example.com\/x"/, out)
    with_body_file do |path|
      out = assert_dry_run(C::SubCreate, ["--file", path, "-d"], "POST /api/subscriptions")
      assert_match(/"frequency": "daily"/, out)
      assert_dry_run(C::SubUpdate, ["s1", "--file", path, "-d"], "PATCH /api/subscriptions/s1")
    end
    assert_dry_run(C::SubCreate, ["--stdin", "-d"], "POST /api/subscriptions", stdin: StringIO.new('{"frequency":"weekly"}'))
  end

  def test_roster_add_body
    out = JSON.parse(run_cmd(C::RosterAdd, ["Placeholder Band", "--spotify", "sp1", "-d"], client: FakeClient.new, json: true))
    assert_equal({ "displayName" => "Placeholder Band", "spotifyArtistId" => "sp1" }, out["data"]["request"]["body"])
  end

  def test_writes_perform_once
    fake = FakeClient.new
    run_cmd(C::RosterAdd, ["Placeholder Band"], client: fake)
    run_cmd(C::TrackReport, ["t1", "--link", "https://example.com/x"], client: fake)
    with_body_file { |path| run_cmd(C::SubUpdate, ["s1", "--file", path], client: fake) }
    assert_equal ["POST /api/roster", "POST /api/track/t1/report", "PATCH /api/subscriptions/s1"],
                 fake.performed.map { "#{_1.method} #{_1.path}" }
  end

  def test_sub_body_source_errors
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::SubCreate, ["-d"], client: FakeClient.new) }
    assert_raises(XmplaylistCli::UsageError) do
      run_cmd(C::SubCreate, ["--stdin", "-d"], client: FakeClient.new, stdin: StringIO.new("not json"))
    end
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::TrackReport, ["t1"], client: FakeClient.new) }
  end

  # -- guarded deletes ------------------------------------------------------

  GUARDED = { C::SubDelete => "/api/subscriptions/x1", C::RosterRemove => "/api/roster/x1" }.freeze

  def test_guard_non_tty_refuses_and_sends_nothing
    GUARDED.each_key do |klass|
      fake = FakeClient.new
      assert_raises(XmplaylistCli::GuardRefused) { run_cmd(klass, ["x1"], client: fake) }
      assert_empty fake.performed
    end
  end

  def test_guard_typed_id_on_tty_sends_once
    GUARDED.each do |klass, path|
      fake = FakeClient.new
      run_cmd(klass, ["x1"], client: fake, stdin: TtyInput.new("x1\n"))
      assert_equal [["DELETE", path]], fake.performed.map { [_1.method, _1.path] }
    end
  end

  def test_guard_wrong_typed_id_aborts
    GUARDED.each_key do |klass|
      fake = FakeClient.new
      assert_raises(XmplaylistCli::Aborted) { run_cmd(klass, ["x1"], client: fake, stdin: TtyInput.new("nope\n")) }
      assert_empty fake.performed
    end
  end

  def test_guard_yes_skips_prompt
    GUARDED.each do |klass, path|
      fake = FakeClient.new
      run_cmd(klass, ["x1", "--yes"], client: fake)
      assert_equal [path], fake.performed.map(&:path)
    end
  end
end
