# frozen_string_literal: true

require_relative "spec_helper"
require "stringio"
require "xmplaylist_cli/client"
require "xmplaylist_cli/endpoints"

RLResponse = Struct.new(:code, :body, :headers) do
  def [](name) = (headers || {})[name.downcase]
end

describe XmplaylistCli::RateLimit do
  it "reads retry-after, else a default" do
    assert_equal 12, XmplaylistCli::RateLimit.wait_seconds("retry-after" => "12")
    assert_equal XmplaylistCli::RateLimit::DEFAULT_WAIT, XmplaylistCli::RateLimit.wait_seconds({})
    assert_equal XmplaylistCli::RateLimit::DEFAULT_WAIT, XmplaylistCli::RateLimit.wait_seconds("retry-after" => "soon")
    refute XmplaylistCli::RateLimit.retry?("retry-after" => "61")
  end

  describe "in the client" do
    def client_with(*responses)
      @sent = 0
      @slept = []
      queue = responses.dup
      transport = ->(_req, _uri) { @sent += 1; queue.shift or raise "unexpected request" }
      XmplaylistCli::Client.new(key: nil, base: "https://xm.test", transport: transport,
                                sleeper: ->(s) { @slept << s }, err: StringIO.new)
    end

    def limited(wait = "3") = RLResponse.new("429", "{}", { "retry-after" => wait })

    it "waits retry-after once and succeeds on the retry" do
      client = client_with(limited, RLResponse.new("200", '{"results":[]}', {}))
      assert_equal({ results: [] }, client.fetch(XmplaylistCli::Endpoints.feed))
      assert_equal [3], @slept
      assert_equal 2, @sent
    end

    it "raises an ApiError (exit 4) on a second 429, without looping" do
      client = client_with(limited, limited)
      error = assert_raises(XmplaylistCli::RateLimitError) { client.fetch(XmplaylistCli::Endpoints.feed) }
      assert_kind_of XmplaylistCli::ApiError, error
      assert_equal 2, @sent
    end

    it "does not wait when retry-after exceeds 60 seconds" do
      client = client_with(limited("120"))
      assert_raises(XmplaylistCli::RateLimitError) { client.fetch(XmplaylistCli::Endpoints.feed) }
      assert_empty @slept
      assert_equal 1, @sent
    end
  end
end
