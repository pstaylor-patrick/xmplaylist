# frozen_string_literal: true

module XmplaylistCli
  # Loads .env then .env.local from a directory into an env hash without
  # overriding anything already set: exported variables win, and an earlier
  # file wins over a later one.
  module EnvFile
    FILES = %w[.env .env.local].freeze
    ASSIGNMENT = /\A\s*(?:export\s+)?(?<key>[A-Za-z_][A-Za-z0-9_.]*)\s*=(?<value>.*)\z/

    def self.load(root, env = ENV)
      FILES.each do |name|
        path = File.join(root, name)
        next unless File.file?(path)

        parse(File.read(path)).each { |key, value| env[key] ||= value }
      end
      env
    end

    # [[key, value], ...] in file order. Comments, blanks, and unparsable
    # lines are skipped. One pair of surrounding quotes is stripped.
    def self.parse(content)
      content.to_s.each_line.filter_map do |line|
        next if line.strip.empty? || line.lstrip.start_with?("#")

        match = ASSIGNMENT.match(line.chomp)
        match && [match[:key], unquote(match[:value].strip)]
      end
    end

    def self.unquote(value)
      if value.length >= 2 && ['"', "'"].include?(value[0]) && value[-1] == value[0]
        value[1..-2]
      else
        value
      end
    end

    private_class_method :unquote
  end
end
