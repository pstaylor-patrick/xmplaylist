# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"
require "json"
require_relative "error"
require_relative "rate_limit"
require_relative "version"

module XmplaylistCli
  # HTTP for the xmplaylist.com API: optional bearer auth, JSON, one
  # wait-and-retry on 429, and status-to-error mapping. The key is never
  # printed, including under XMPLAYLIST_DEBUG=1.
  class Client
    DEFAULT_BASE = "https://xmplaylist.com"
    NETWORK_ERRORS = [SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
                      Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError].freeze

    Response = Data.define(:status, :headers, :body, :raw)

    attr_reader :base

    # transport: ->(Net::HTTPRequest, URI) { response }, injectable for specs.
    #   The response needs #code, #body, and #[](header).
    # sleeper: ->(seconds) {}, injectable so specs never sleep.
    def initialize(key: ENV["XMPLAYLIST_API_KEY"], base: ENV.fetch("XMPLAYLIST_BASE_URL", DEFAULT_BASE),
                   transport: nil, sleeper: ->(seconds) { sleep(seconds) }, err: $stderr,
                   debug: ENV["XMPLAYLIST_DEBUG"] == "1")
      @key = key.to_s.strip.empty? ? nil : key.strip
      @base = base.chomp("/")
      @transport = transport || method(:net_http)
      @sleeper = sleeper
      @err = err
      @debug = debug
    end

    def authenticated? = !@key.nil?

    # One request; returns the parsed body (symbolized), {} on 204/empty, or
    # the raw string for a non-JSON response (CSV export).
    def fetch(request) = call(request).body

    # Writes: same as fetch, named separately so call sites read as intent.
    def perform(request) = call(request).body

    # Pure: maps a non-2xx status and raw body to an error.
    def self.error_for(status, raw, path)
      parsed = parse_json(raw)
      message = parsed.is_a?(Hash) ? (parsed[:message] || parsed[:error]).to_s : ""

      case status
      when 401 then AuthError.new("unauthorized (401); set XMPLAYLIST_API_KEY", status: status, body: raw)
      when 403 then PaidPlanError.new(path, status: status, body: raw)
      when 404 then NotFoundError.new(message.empty? ? "not found (404): #{path}" : message, status: status, body: raw)
      when 429 then RateLimitError.new("rate limited (429); try again later", status: status, body: raw)
      else ApiError.new(message.empty? ? "request failed (#{status})" : "#{message} (#{status})", status: status, body: raw)
      end
    end

    def self.parse_json(raw)
      JSON.parse(raw.to_s, symbolize_names: true)
    rescue JSON::ParserError
      nil
    end

    private

    def call(request)
      response = transmit(request)
      if response.status == 429 && RateLimit.retry?(response.headers)
        # A 429 means the request was not processed, so retrying a write is safe.
        wait = RateLimit.wait_seconds(response.headers)
        @err.puts "xmplaylist: rate limited, waiting #{wait}s"
        @sleeper.call(wait)
        response = transmit(request)
      end
      unless (200..299).cover?(response.status)
        raise self.class.error_for(response.status, response.raw, request.path)
      end

      response
    end

    def transmit(request)
      uri = build_uri(request)
      raw_response = @transport.call(build_http_request(request, uri), uri)
      status = raw_response.code.to_i
      @err.puts "xmplaylist: #{request.method} #{request.path} -> #{status}" if @debug
      raw = raw_response.body.to_s
      headers = { "retry-after" => raw_response["retry-after"], "content-type" => raw_response["content-type"] }
      Response.new(status: status, headers: headers, body: parse_body(status, raw, headers["content-type"]), raw: raw)
    rescue *NETWORK_ERRORS => e
      raise Error, "network error talking to xmplaylist.com: #{e.class}: #{e.message}"
    end

    def build_uri(request)
      url = "#{@base}#{request.path}"
      url += "?#{URI.encode_www_form(request.query)}" unless request.query.nil? || request.query.empty?
      URI(url)
    end

    def build_http_request(request, uri)
      http_request = Net::HTTP.const_get(request.method.capitalize).new(uri)
      http_request["Authorization"] = "Bearer #{@key}" if @key
      http_request["Accept"] = "application/json"
      http_request["User-Agent"] = "xmplaylist-cli/#{VERSION}"
      unless request.body.nil?
        http_request["Content-Type"] = "application/json"
        http_request.body = JSON.generate(request.body)
      end
      http_request
    end

    def parse_body(status, raw, content_type)
      return {} if status == 204 || raw.strip.empty?
      return raw if content_type.to_s.include?("csv")

      parsed = self.class.parse_json(raw)
      parsed.nil? ? raw : parsed
    end

    def net_http(http_request, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                          open_timeout: 10, read_timeout: 60) do |http|
        http.request(http_request)
      end
    end
  end
end
