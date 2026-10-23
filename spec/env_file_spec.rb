# frozen_string_literal: true

require_relative "spec_helper"
require "tmpdir"
require "xmplaylist_cli/env_file"

class EnvFileSpec < Minitest::Test
  def with_files(files)
    Dir.mktmpdir do |dir|
      files.each { |name, body| File.write(File.join(dir, name), body) }
      yield dir
    end
  end

  def test_exported_var_wins
    with_files(".env" => "XMPLAYLIST_API_KEY=from-file\n") do |dir|
      env = { "XMPLAYLIST_API_KEY" => "exported" }
      XmplaylistCli::EnvFile.load(dir, env)
      assert_equal "exported", env["XMPLAYLIST_API_KEY"]
    end
  end

  def test_env_then_env_local_order
    with_files(".env" => "A=one\n", ".env.local" => "A=two\nB=local\n") do |dir|
      env = XmplaylistCli::EnvFile.load(dir, {})
      assert_equal "one", env["A"]
      assert_equal "local", env["B"]
    end
  end

  def test_missing_files_are_fine
    Dir.mktmpdir { |dir| assert_equal({}, XmplaylistCli::EnvFile.load(dir, {})) }
  end

  def test_quotes_and_export_prefix
    content = <<~ENV
      # comment
      export A="double"
      B='single'

      C=plain
      not a line
    ENV
    assert_equal [%w[A double], %w[B single], %w[C plain]], XmplaylistCli::EnvFile.parse(content)
  end
end
