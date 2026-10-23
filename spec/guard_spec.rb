# frozen_string_literal: true

require_relative "spec_helper"
require_relative "support/tty_input"
require_relative "support/fake_client"
require "stringio"
require "xmplaylist_cli/guard"
require "xmplaylist_cli/command_support"
require "xmplaylist_cli/formatter"

describe XmplaylistCli::Guard do
  CONFIRM = { action: "delete subscription sub-123", token: "sub-123" }.freeze

  def confirm!(stdin, yes: false)
    out = StringIO.new
    XmplaylistCli::Guard.confirm!(CONFIRM, yes: yes, stdin: stdin, command: "sub-delete", out: out)
    out.string
  end

  it "skips the prompt entirely with --yes" do
    stdin = StringIO.new("")
    assert_equal "", confirm!(stdin, yes: true)
    assert_equal 0, stdin.pos
  end

  it "refuses a non-TTY stdin without --yes, pointing at --yes and -d" do
    error = assert_raises(XmplaylistCli::GuardRefused) { confirm!(StringIO.new("sub-123\n")) }
    assert_includes error.message, "sub-delete"
    assert_includes error.message, "--yes"
    assert_includes error.message, "-d"
  end

  it "passes when the typed token matches, ignoring surrounding whitespace" do
    out = confirm!(TtyInput.new("  sub-123  \n"))
    assert_includes out, "This will delete subscription sub-123. This cannot be undone."
    assert_includes out, "Type sub-123 to confirm: "
  end

  it "aborts on a mismatch and on end of input" do
    error = assert_raises(XmplaylistCli::Aborted) { confirm!(TtyInput.new("SUB-123\n")) }
    assert_includes error.message, "nothing was changed"
    assert_raises(XmplaylistCli::Aborted) { confirm!(TtyInput.new("")) }
  end

  it "maps refusals to exit 1 (UsageError)" do
    assert_operator XmplaylistCli::GuardRefused, :<, XmplaylistCli::UsageError
    assert_operator XmplaylistCli::Aborted, :<, XmplaylistCli::UsageError
  end

  describe "CommandSupport.write!" do
    def ctx(stdin)
      @client = FakeClient.new
      @out = StringIO.new
      fmt = Module.new
      out = @out
      fmt.define_singleton_method(:dry_run) { |c, r| XmplaylistCli::Formatter.dry_run(c, r, out: out) }
      fmt.define_singleton_method(:written) { |c, r, summary: nil| XmplaylistCli::Formatter.written(c, r, summary: summary, out: out) }
      XmplaylistCli::Context.new(client: @client, formatter: fmt, stdin: stdin, err: StringIO.new)
    end

    REQ = XmplaylistCli::Endpoints.delete_subscription("sub-123")

    it "dry run prints the request and sends nothing, without prompting" do
      result = XmplaylistCli::CommandSupport.write!(ctx(StringIO.new), command: "sub-delete", request: REQ,
                                                                        opts: { dry_run: true }, confirm: CONFIRM)
      assert_nil result
      assert_empty @client.performed
      assert_includes @out.string, "DELETE /api/subscriptions/sub-123"
    end

    it "non-TTY without --yes sends nothing" do
      assert_raises(XmplaylistCli::GuardRefused) do
        XmplaylistCli::CommandSupport.write!(ctx(StringIO.new), command: "sub-delete", request: REQ, opts: {}, confirm: CONFIRM)
      end
      assert_empty @client.performed
    end

    it "sends once after a typed confirmation" do
      XmplaylistCli::CommandSupport.write!(ctx(TtyInput.new("sub-123\n")), command: "sub-delete", request: REQ,
                                                                           opts: {}, confirm: CONFIRM)
      assert_equal [REQ], @client.performed
      assert_includes @out.string, "sub-delete: done"
    end
  end
end
