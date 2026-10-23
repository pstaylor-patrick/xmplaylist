# frozen_string_literal: true

require_relative "spec_helper"
require "json"
require "stringio"
require "xmplaylist_cli/client"
require "xmplaylist_cli/endpoints"

FakeResponse = Struct.new(:code, :body, :headers) do
  def [](name) = (headers || {})[name.downcase]
end

describe XmplaylistCli::Client do
  KEY = "placeholder-test-key"

  def client_with(*responses, key: KEY, debug: false)
    @sent = []
    @err = StringIO.new
    queue = responses.dup
    transport = lambda do |request, uri|
      @sent << [request, uri]
      queue.shift or raise "unexpected request"
    end
    XmplaylistCli::Client.new(key: key, base: "https://xm.test", transport: transport,
                              sleeper: ->(_) {}, err: @err, debug: debug)
  end

  def json(status, payload, headers = {}) = FakeResponse.new(status.to_s, JSON.generate(payload), headers)

  it "sends the user agent, accept, and bearer headers" do
    client = client_with(json(200, { results: [] }))
    client.fetch(XmplaylistCli::Endpoints.feed)
    request, uri = @sent.first
    assert_equal "https://xm.test/api/feed", uri.to_s
    assert_equal "xmplaylist-cli/#{XmplaylistCli::VERSION}", request["User-Agent"]
    assert_equal "application/json", request["Accept"]
    assert_equal "Bearer #{KEY}", request["Authorization"]
  end

  it "omits Authorization without a key" do
    client = client_with(json(200, {}), key: "  ")
    client.fetch(XmplaylistCli::Endpoints.feed)
    assert_nil @sent.first[0]["Authorization"]
    refute client.authenticated?
  end

  it "encodes the query and sends a JSON body on writes" do
    client = client_with(json(200, { ok: true }), json(200, { id: "x" }))
    client.fetch(XmplaylistCli::Endpoints.search({ artist: "A B" }, page: 2))
    assert_equal "https://xm.test/api/search?artistName=A+B&page=2", @sent[0][1].to_s
    client.perform(XmplaylistCli::Endpoints.roster_add(display_name: "Placeholder"))
    assert_equal({ "displayName" => "Placeholder" }, JSON.parse(@sent[1][0].body))
    assert_equal "application/json", @sent[1][0]["Content-Type"]
  end

  it "debug output names method, path, and status, never the key" do
    client = client_with(json(200, {}), debug: true)
    client.fetch(XmplaylistCli::Endpoints.feed)
    assert_includes @err.string, "GET /api/feed -> 200"
    refute_includes @err.string, KEY
    refute_includes @err.string, "Bearer"
  end

  it "returns a CSV body raw" do
    client = client_with(FakeResponse.new("200", "a,b\n1,2\n", { "content-type" => "text/csv" }))
    assert_equal "a,b\n1,2\n", client.perform(XmplaylistCli::Endpoints.search_export({ artist: "x" }))
  end

  it "returns {} for 204" do
    client = client_with(FakeResponse.new("204", "", {}))
    assert_equal({}, client.perform(XmplaylistCli::Endpoints.delete_subscription("s1")))
  end

  describe "status mapping" do
    def error_for(status, body = "{}")
      client = client_with(FakeResponse.new(status.to_s, body, {}))
      assert_raises(XmplaylistCli::Error) { client.fetch(XmplaylistCli::Endpoints.stations_extended) }
    end

    it "401 -> AuthError asking for the key" do
      e = error_for(401)
      assert_instance_of XmplaylistCli::AuthError, e
      assert_includes e.message, "set XMPLAYLIST_API_KEY"
    end

    it "403 -> PaidPlanError (an AuthError, exit 2) naming the path" do
      e = error_for(403)
      assert_instance_of XmplaylistCli::PaidPlanError, e
      assert_kind_of XmplaylistCli::AuthError, e
      assert_equal "requires paid plan: /api/station/extended", e.message
      assert_equal 1, @sent.size
    end

    it "404 -> NotFoundError, other 4xx/5xx -> ApiError with the API message" do
      assert_instance_of XmplaylistCli::NotFoundError, error_for(404)
      e = error_for(400, '{"message":"bad input"}')
      assert_instance_of XmplaylistCli::ApiError, e
      assert_includes e.message, "bad input"
      assert_instance_of XmplaylistCli::ApiError, error_for(500, "oops")
    end

    it "never puts the key in an error message" do
      refute_includes error_for(401).message, KEY
    end
  end

  it "wraps network errors" do
    client = XmplaylistCli::Client.new(key: KEY, base: "https://xm.test", transport: ->(*) { raise SocketError, "down" })
    e = assert_raises(XmplaylistCli::Error) { client.fetch(XmplaylistCli::Endpoints.feed) }
    assert_includes e.message, "network error"
  end
end
