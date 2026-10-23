# frozen_string_literal: true

require_relative "spec_helper"
require_relative "support/fake_client"
require "stringio"
require "xmplaylist_cli/paging"
require "xmplaylist_cli/endpoints"

describe XmplaylistCli::Paging do
  EP = XmplaylistCli::Endpoints

  before { @err = StringIO.new }

  it "returns one page by default" do
    client = FakeClient.new(fetch: { "/api/station/examplerock" => { results: [1], next: "https://x/api?last=5" } })
    body = XmplaylistCli::Paging.cursor(client, EP.station("examplerock"), err: @err)
    assert_equal [1], body[:results]
    assert_equal 1, client.calls.size
  end

  it "follows the station cursor from next's last" do
    pages = { nil => { results: [1], next: "https://xm.test/api/station/examplerock?last=1700000000000" },
              "1700000000000" => { results: [2], next: nil } }
    client = FakeClient.new(fetch: { "/api/station/examplerock" => ->(r) { pages.fetch(r.query["last"]) } })
    body = XmplaylistCli::Paging.cursor(client, EP.station("examplerock"), all: true, err: @err)
    assert_equal [1, 2], body[:results]
    assert_equal [nil, "1700000000000"], client.calls.map { |r| r.query["last"] }
  end

  it "follows page numbers until pages is reached" do
    client = FakeClient.new(fetch: { "/api/reports/track-lookup" => lambda { |r|
      page = (r.query["page"] || 1).to_i
      { results: [page], currentPage: page, pages: 3 }
    } })
    body = XmplaylistCli::Paging.page(client, EP.report_track_lookup({ track: "x" }), all: true, err: @err)
    assert_equal [1, 2, 3], body[:results]
  end

  it "follows nextOffset" do
    client = FakeClient.new(fetch: { "/api/channel-updates" => lambda { |r|
      offset = r.query["offset"].to_i
      { results: [offset], nextOffset: offset < 100 ? offset + 50 : nil }
    } })
    body = XmplaylistCli::Paging.offset(client, EP.channel_updates, all: true, err: @err)
    assert_equal [0, 50, 100], body[:results]
  end

  it "caps --all at 50 pages and warns" do
    client = FakeClient.new(fetch: { "/api/search" => ->(r) { { results: [r.query["page"]], next: "more" } } })
    body = XmplaylistCli::Paging.page(client, EP.search({ artist: "x" }), all: true, err: @err)
    assert_equal 50, client.calls.size
    assert_equal 50, body[:results].size
    assert_includes @err.string, "stopped after 50 pages"
  end
end
