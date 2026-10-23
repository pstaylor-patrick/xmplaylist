# frozen_string_literal: true

require_relative "spec_helper"
require "xmplaylist_cli/resolver"
require "xmplaylist_cli/window"

describe XmplaylistCli::Resolver do
  STATIONS = [
    { deeplink: "placeholderhits", name: "Placeholder Hits", number: "2" },
    { deeplink: "examplerock", name: "Example Rock", number: "20" },
    { deeplink: "samplejazz", name: "Twin", number: "30" },
    { deeplink: "samplesoul", name: "twin", number: "31" }
  ].freeze

  def pick(query) = XmplaylistCli::Resolver.channel(STATIONS, query)

  it "matches deeplink, name, case-insensitive name, and number" do
    assert_equal "examplerock", pick("examplerock")[:deeplink]
    assert_equal "examplerock", pick("Example Rock")[:deeplink]
    assert_equal "examplerock", pick("example rock")[:deeplink]
    assert_equal "examplerock", pick("EXAMPLEROCK")[:deeplink]
    assert_equal "placeholderhits", pick("2")[:deeplink]
  end

  it "prefers an exact name over a case-insensitive one" do
    assert_equal "samplejazz", pick("Twin")[:deeplink]
  end

  it "never matches partially" do
    error = assert_raises(XmplaylistCli::NotFoundError) { pick("rock") }
    assert_includes error.message, "examplerock"
  end

  it "lists deeplinks when several match" do
    error = assert_raises(XmplaylistCli::AmbiguousError) { pick("TWIN") }
    assert_includes error.message, "samplejazz"
    assert_includes error.message, "samplesoul"
  end
end

describe XmplaylistCli::Window do
  it "builds one spec query key" do
    assert_equal({}, XmplaylistCli::Window.query({}))
    assert_equal({ "days" => 30 }, XmplaylistCli::Window.query(days: "30"))
    assert_equal({ "year" => 2024 }, XmplaylistCli::Window.query(year: "2024"))
    assert_equal({ "month" => "2024-05" }, XmplaylistCli::Window.query(month: "2024-05"))
    assert_equal({ "week" => "2024-05-05" }, XmplaylistCli::Window.query(week: "2024-05-05"))
  end

  it "rejects two windows or a bad format" do
    assert_raises(XmplaylistCli::UsageError) { XmplaylistCli::Window.query(days: "7", year: "2024") }
    assert_raises(XmplaylistCli::UsageError) { XmplaylistCli::Window.query(month: "May") }
  end
end
