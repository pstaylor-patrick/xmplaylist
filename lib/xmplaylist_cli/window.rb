# frozen_string_literal: true

require_relative "error"

module XmplaylistCli
  # The --days N | --year Y | --month YYYY-MM | --week YYYY-MM-DD window shared
  # by most-heard, movers, rankings, and artist-rankings. At most one is given;
  # none means the API default.
  module Window
    KEYS = %i[days year month week].freeze

    def self.add_options(parser, opts)
      parser.on("--days N", "Days through today (past 60 is paid)") { |v| opts[:days] = v }
      parser.on("--year YYYY", "Paid: a calendar year since 2021") { |v| opts[:year] = v }
      parser.on("--month YYYY-MM", "Paid: a calendar month") { |v| opts[:month] = v }
      parser.on("--week YYYY-MM-DD", "Paid: the Sunday starting a week") { |v| opts[:week] = v }
    end

    # The query hash for opts, validated.
    def self.query(opts)
      given = KEYS.select { |k| opts[k] }
      raise UsageError, "give at most one of --days, --year, --month, --week" if given.size > 1
      return {} if given.empty?

      key = given.first
      value = opts[key].to_s.strip
      pattern = { days: /\A\d+\z/, year: /\A\d{4}\z/, month: /\A\d{4}-\d{2}\z/, week: /\A\d{4}-\d{2}-\d{2}\z/ }[key]
      raise UsageError, "--#{key} has the wrong format: '#{value}'" unless value.match?(pattern)

      { key.to_s => (%i[days year].include?(key) ? value.to_i : value) }
    end
  end
end
