# frozen_string_literal: true

require_relative "spec_helper"
require_relative "support/fake_client"
require "json"
require "stringio"
require "tmpdir"
require "xmplaylist_cli/command_support"
require "xmplaylist_cli/formatter"
require "xmplaylist_cli/commands/search_export"
require "xmplaylist_cli/commands/artist_updates_set"

class WriteCommandsSpec < Minitest::Test
  C = XmplaylistCli::Commands
  STATIONS = { results: [{ id: "station-1", name: "Example Rock", number: "101", deeplink: "examplerock" }] }.freeze

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

  def test_search_export_dry_run_sends_nothing
    fake = FakeClient.new
    out = run_cmd(C::SearchExport, ["--artist", "placeholder", "--time-ago", "60", "--station", "101", "-d"], client: fake)
    assert_match(/DRY RUN/, out)
    assert_match(%r{POST /api/search/export}, out)
    assert_match(/"timeAgo": 60/, out)
    assert_empty fake.calls
    assert_empty fake.performed
  end

  def test_search_export_dry_run_json
    body = JSON.parse(run_cmd(C::SearchExport, ["--artist", "placeholder", "--aggregate", "-d"], client: FakeClient.new, json: true))
    assert_equal({ "artistName" => "placeholder", "aggregate" => true }, body["data"]["request"]["body"])
  end

  def test_search_export_csv_to_stdout
    fake = FakeClient.new(fetch: { "/api/station" => STATIONS }, perform: { "/api/search/export" => "a,b\n1,2\n" })
    out = run_cmd(C::SearchExport, ["--artist", "placeholder", "--station", "101"], client: fake)
    assert_equal "a,b\n1,2\n", out
    assert_equal 1, fake.performed.size
    assert_equal({ artistName: "placeholder", station: "examplerock" }, fake.performed.first.body)
  end

  def test_search_export_csv_to_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "out.csv")
      fake = FakeClient.new(perform: { "/api/search/export" => "a,b\n" })
      assert_match(/wrote 4 bytes/, run_cmd(C::SearchExport, ["--artist", "x", "--out", path], client: fake))
      assert_equal "a,b\n", File.read(path)
    end
  end

  def test_search_export_queued_message_passes_through
    fake = FakeClient.new(perform: { "/api/search/export" => { message: "Export queued; it will be emailed" } })
    assert_match(/message:\s+Export queued/, run_cmd(C::SearchExport, ["--artist", "x"], client: fake))
  end

  def test_artist_updates_set_dry_run
    fake = FakeClient.new
    out = run_cmd(C::ArtistUpdatesSet, ["a1", "--off", "-d"], client: fake)
    assert_match(%r{PUT /api/artists/a1/updates}, out)
    assert_match(/"enabled": false/, out)
    assert_empty fake.performed
  end

  def test_artist_updates_set_performs_once
    fake = FakeClient.new
    assert_match(/a1 on/, run_cmd(C::ArtistUpdatesSet, ["a1", "--on"], client: fake))
    assert_equal 1, fake.performed.size
    assert_equal({ enabled: true }, fake.performed.first.body)
  end

  def test_artist_updates_set_requires_on_or_off
    assert_raises(XmplaylistCli::UsageError) { run_cmd(C::ArtistUpdatesSet, ["a1"], client: FakeClient.new) }
  end
end
