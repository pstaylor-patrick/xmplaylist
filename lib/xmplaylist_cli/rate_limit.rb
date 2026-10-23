# frozen_string_literal: true

module XmplaylistCli
  # Pure wait-time computation for a 429. The API sends no rate-limit headers
  # on success, so only retry-after is honored.
  module RateLimit
    DEFAULT_WAIT = 5
    MAX_WAIT = 60

    # headers: a Hash with lowercase string keys (missing keys are fine).
    # Returns retry-after in seconds (never negative), else DEFAULT_WAIT.
    def self.wait_seconds(headers)
      text = headers["retry-after"].to_s.strip
      text.match?(/\A\d+\z/) ? text.to_i : DEFAULT_WAIT
    end

    # True when one wait-and-retry is allowed for these headers.
    def self.retry?(headers) = wait_seconds(headers) <= MAX_WAIT
  end
end
