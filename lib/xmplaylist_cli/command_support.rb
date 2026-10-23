# frozen_string_literal: true

require "json"
require "optparse"
require_relative "error"
require_relative "guard"
require_relative "endpoints"
require_relative "resolver"

module XmplaylistCli
  # What every command receives: the client, the formatter (human or JSON),
  # stdin for the guard, and stderr for warnings.
  Context = Data.define(:client, :formatter, :stdin, :err) do
    def initialize(client:, formatter:, stdin: $stdin, err: $stderr)
      super
    end
  end

  # Shared option parsing for commands. The reserved short flags (-d, -y, and
  # the global -j) are defined here and nowhere else.
  module CommandSupport
    # write: adds -d/--dry-run; destructive: adds -y/--yes; all: adds --all.
    def self.parser(opts, banner:, write: false, destructive: false, all: false)
      OptionParser.new do |o|
        o.banner = "Usage: xmplaylist #{banner}"
        o.on("-d", "--dry-run", "Print the request without sending it") { opts[:dry_run] = true } if write
        o.on("-y", "--yes", "Confirm a delete without the typed-name prompt") { opts[:yes] = true } if destructive
        o.on("--all", "Follow pages (capped at 50 requests)") { opts[:all] = true } if all
        yield o if block_given?
      end
    end

    # Parses argv in place; returns positionals. Bad flags become UsageError.
    def self.parse!(parser, argv, max_args: nil)
      rest = parser.parse(argv)
      raise UsageError, "unexpected argument: #{rest[max_args]}\n#{parser.banner}" if max_args && rest.size > max_args

      rest
    rescue OptionParser::ParseError => e
      raise UsageError, "#{e.message}\n#{parser.banner}"
    end

    # Exactly the named positional arguments, in order, or a usage error.
    def self.args!(parser, argv, *names)
      args = parse!(parser, argv, max_args: names.size)
      raise UsageError, "missing #{names.drop(args.size).join(' and ')}\n#{parser.banner}" if args.size < names.size

      args
    end

    def self.one_arg!(parser, argv, name) = args!(parser, argv, name).first

    # An integer flag value within min..max.
    def self.count(value, flag:, min: 1, max: nil)
      text = value.to_s.strip
      number = text.match?(/\A\d+\z/) ? text.to_i : nil
      if number.nil? || number < min || (max && number > max)
        range = max ? "#{min}..#{max}" : ">= #{min}"
        raise UsageError, "#{flag} must be an integer in #{range}, got '#{value}'"
      end
      number
    end

    def self.one_of!(value, allowed, flag:)
      return value if value.nil? || allowed.map(&:to_s).include?(value.to_s)

      raise UsageError, "#{flag} must be one of #{allowed.join(', ')}, got '#{value}'"
    end

    # A JSON object from --file PATH or --stdin (exactly one).
    def self.read_json(opts, stdin)
      sources = %i[file stdin].select { |k| opts[k] }
      raise UsageError, "give exactly one of --file PATH or --stdin" unless sources.size == 1

      text = if opts[:file]
               path = File.expand_path(opts[:file])
               raise UsageError, "no such file: #{opts[:file]}" unless File.file?(path)

               File.read(path)
             else
               stdin.read.to_s
             end
      parsed = JSON.parse(text)
      raise UsageError, "expected a JSON object" unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError => e
      raise UsageError, "invalid JSON: #{e.message}"
    end

    # The station record for a deeplink, name, or number (one GET /api/station).
    def self.channel(ctx, query)
      stations = Array(ctx.client.fetch(Endpoints.stations)[:results])
      Resolver.channel(stations, query)
    end

    # The one write path, in fixed order:
    #   dry run (print, send nothing) -> guard -> perform -> print.
    # confirm: nil for non-destructive writes, else {action:, token:}.
    # Returns the API result, or nil on a dry run.
    def self.write!(ctx, command:, request:, opts:, confirm: nil, summary: nil)
      if opts[:dry_run]
        ctx.formatter.dry_run(command, request)
        return nil
      end

      Guard.confirm!(confirm, yes: opts[:yes], stdin: ctx.stdin, command: command, out: ctx.err) if confirm
      result = ctx.client.perform(request)
      ctx.formatter.written(command, result, summary: summary&.call(result))
      result
    end
  end
end
