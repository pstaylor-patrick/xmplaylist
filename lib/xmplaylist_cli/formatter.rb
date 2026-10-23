# frozen_string_literal: true

require "json"
require "uri"

module XmplaylistCli
  # The printable form of a request that a dry run did not send.
  module DryRun
    def self.describe(request)
      { method: request.method, path: request.path, query: request.query || {}, body: request.body }
    end

    def self.target(described)
      query = described[:query]
      query.empty? ? described[:path] : "#{described[:path]}?#{URI.encode_www_form(query)}"
    end
  end

  # JSON output (-j/--json): {"ok":true,"command":..,"data":<raw>} on success,
  # {"ok":false,"command":..,"error":{"code":..,"message":..}} on failure.
  module JsonFormatter
    def self.emit(command, data, out: $stdout)
      out.puts JSON.pretty_generate({ ok: true, command: command, data: data })
    end

    def self.list(command, data, columns: nil, records: nil, out: $stdout) = emit(command, data, out: out)
    def self.show(command, data, fields: nil, out: $stdout) = emit(command, data, out: out)
    def self.text(command, content, out: $stdout) = emit(command, content, out: out)

    def self.dry_run(command, request, out: $stdout)
      emit(command, { dry_run: true, request: DryRun.describe(request) }, out: out)
    end

    def self.written(command, result, summary: nil, out: $stdout)
      emit(command, result.nil? || result == {} ? { done: true } : result, out: out)
    end

    def self.error(command, code, message, out: $stdout)
      out.puts JSON.pretty_generate({ ok: false, command: command, error: { code: code, message: message } })
    end
  end

  # Human output. Known columns for public responses; a generic fallback for
  # paid responses whose shape is not pinned down.
  module Formatter
    RESET = "\e[0m"
    BOLD = "\e[1m"
    DIM = "\e[2m"

    # Columns per known response, as {header => ->(record) { value }} or a key.
    COLUMNS = {
      stations: { "deeplink" => :deeplink, "number" => :number, "name" => :name, "genres" => :genres },
      history: { "time" => :timestamp, "title" => [:track, :title], "artists" => [:track, :artists] },
      feed: { "time" => :timestamp, "channel" => :channelId, "title" => [:track, :title], "artists" => [:track, :artists] },
      hot: { "id" => :spotifyArtistId, "name" => :name, "spins" => :spins, "gain" => :spinGain }
    }.freeze

    # records: the rows; columns: a COLUMNS key, a column hash, or nil for
    # the first record's own first-level keys. data is ignored (JSON uses it).
    def self.list(command, data, columns: nil, records: nil, out: $stdout)
      records ||= extract_records(data)
      return show(command, data, out: out) if records.nil?

      columns = COLUMNS.fetch(columns) if columns.is_a?(Symbol)
      columns ||= generic_columns(records)
      noun = records.size == 1 ? "result" : "results"
      out.puts style("#{records.size} #{noun}", DIM)
      return if records.empty?

      header = columns.keys.map(&:to_s)
      cells = records.map { |r| columns.values.map { |path| cell(dig(r, path)) } }
      widths = header.each_index.map { |i| ([header[i]] + cells.map { |c| c[i] }).map(&:length).max }
      out.puts style(align(header, widths), BOLD)
      cells.each { |c| out.puts align(c, widths) }
    end

    # "field: value" lines for a Hash (every first-level key unless fields).
    def self.show(command, data, fields: nil, out: $stdout)
      return text(command, data, out: out) unless data.is_a?(Hash)

      fields ||= data.keys
      width = fields.map { |f| f.to_s.length }.max.to_i + 1
      fields.each { |f| out.puts "#{style("#{f}:".ljust(width), DIM)} #{cell(data[f])}" }
    end

    def self.text(command, content, out: $stdout)
      body = content.is_a?(String) ? content : JSON.pretty_generate(content)
      out.print body
      out.puts unless body.empty? || body.end_with?("\n")
    end

    def self.dry_run(command, request, out: $stdout)
      described = DryRun.describe(request)
      out.puts style("DRY RUN (nothing sent)", BOLD)
      out.puts "#{described[:method]} #{DryRun.target(described)}"
      out.puts "body: #{JSON.pretty_generate(described[:body])}" unless described[:body].nil?
    end

    def self.written(command, result, summary: nil, out: $stdout)
      out.puts summary || "#{command}: done"
    end

    def self.error(command, code, message, out: $stderr)
      out.puts "xmplaylist: #{message}"
    end

    # The list inside a response: the body itself when an Array, else the
    # first Array-of-Hash value (results, artists, ...), else nil.
    def self.extract_records(data)
      return data if data.is_a?(Array)
      return nil unless data.is_a?(Hash)

      found = data[:results] || data.values.find { |v| v.is_a?(Array) && v.all?(Hash) }
      found.is_a?(Array) ? found : nil
    end

    def self.generic_columns(records)
      keys = records.first.is_a?(Hash) ? records.first.keys : []
      keys.reject { |k| records.first[k].is_a?(Hash) || k.to_s.match?(/image|url|hash/i) }
          .first(6).to_h { |k| [k.to_s, k] }
    end

    def self.dig(record, path)
      return record unless record.is_a?(Hash)

      path.respond_to?(:call) ? path.call(record) : record.dig(*Array(path))
    end

    def self.cell(value)
      case value
      when nil then "-"
      when Array then value.empty? ? "-" : value.map { |v| cell(v) }.join(", ")
      when Hash then JSON.generate(value)
      else value.to_s.gsub(/\s*\n\s*/, " ")
      end
    end

    def self.align(values, widths)
      values.each_with_index.map { |v, i| i == values.size - 1 ? v : v.ljust(widths[i]) }.join("  ")
    end

    def self.style(text, code)
      $stdout.tty? && ENV["NO_COLOR"].to_s.empty? ? "#{code}#{text}#{RESET}" : text
    end

    private_class_method :generic_columns, :dig, :align, :style
  end
end
