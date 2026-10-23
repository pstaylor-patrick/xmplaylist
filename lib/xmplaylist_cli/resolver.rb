# frozen_string_literal: true

require_relative "error"

module XmplaylistCli
  # Channel resolution over the GET /api/station results. Order: exact
  # deeplink, exact name, case-insensitive exact name or deeplink, channel
  # number. No partial matching.
  module Resolver
    def self.channel(stations, query)
      query = query.to_s.strip
      matchers = [
        ->(s) { s[:deeplink].to_s == query },
        ->(s) { s[:name].to_s == query },
        ->(s) { s[:name].to_s.casecmp?(query) || s[:deeplink].to_s.casecmp?(query) },
        ->(s) { query.match?(/\A\d+\z/) && s[:number].to_s == query }
      ]
      matches = []
      matchers.each do |m|
        matches = stations.select(&m)
        break unless matches.empty?
      end

      case matches.size
      when 1 then matches.first
      when 0 then raise NotFoundError, not_found_message(stations, query)
      else raise AmbiguousError, ambiguous_message(matches, query)
      end
    end

    def self.not_found_message(stations, query)
      names = stations.map { |s| s[:deeplink] }.compact.map(&:to_s).sort.first(8)
      sample = names.empty? ? "none" : "#{names.join(', ')}#{stations.size > names.size ? ', ...' : ''}"
      "no channel matches '#{query}' (for example: #{sample}; run `xmplaylist stations`)"
    end

    def self.ambiguous_message(matches, query)
      lines = matches.map { |s| "  #{s[:deeplink]}  #{s[:number]}  #{s[:name]}" }
      "'#{query}' matches several channels; pass the deeplink:\n#{lines.join("\n")}"
    end

    private_class_method :not_found_message, :ambiguous_message
  end
end
