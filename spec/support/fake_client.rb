# frozen_string_literal: true

require "xmplaylist_cli/error"

# Answers fetch from canned bodies keyed by request path and records every
# call. perform records the request and returns a canned body (or {}). A
# canned value that responds to #call is called with the request each time,
# so a spec can answer a sequence of pages.
class FakeClient
  attr_reader :calls, :performed

  def initialize(fetch: {}, perform: {})
    @fetch = fetch
    @perform = perform
    @calls = []
    @performed = []
  end

  def fetch(request)
    @calls << request
    answer(@fetch.fetch(request.path) { raise XmplaylistCli::NotFoundError, "no canned fetch for #{request.path}" }, request)
  end

  def perform(request)
    @performed << request
    answer(@perform.fetch(request.path, {}), request)
  end

  private

  def answer(value, request) = value.respond_to?(:call) ? value.call(request) : value
end
