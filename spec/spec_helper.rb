# frozen_string_literal: true

# Specs never load bin/xmplaylist, never read the repo .env, and never open a socket.
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
