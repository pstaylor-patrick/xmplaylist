# frozen_string_literal: true

module XmplaylistCli
  # Base error. bin/xmplaylist maps each subclass to an exit code:
  # AuthError 2 (PaidPlanError included), NotFoundError 3, ApiError 4,
  # anything else 1.
  class Error < StandardError
    attr_reader :status, :body

    def initialize(msg = nil, status: nil, body: nil)
      super(msg)
      @status = status
      @body = body
    end
  end

  class UsageError < Error; end
  class AuthError < Error; end

  # A 403 from an endpoint the key's plan does not include.
  class PaidPlanError < AuthError
    def initialize(path = nil, **)
      super("requires paid plan: #{path}", **)
    end
  end

  class NotFoundError < Error; end
  class ApiError < Error; end
end

module XmplaylistCli
  class RateLimitError < ApiError; end  # 429 after the one retry (exit 4)
  class AmbiguousError < UsageError; end # a name matched several records (exit 1)
  class GuardRefused < UsageError; end   # destructive command, stdin not a TTY, no --yes
  class Aborted < UsageError; end        # typed confirmation did not match
end
