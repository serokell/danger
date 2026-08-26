# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require "simplecov"
SimpleCov.start do
  skip "/spec/"
  minimum_coverage 95
end

require "danger"
require "serokell_danger"

RSpec.configure do |config|
  config.color = true
end

# A silent UI, following the convention used across the Danger plugin
# ecosystem (see danger/danger-plugin-template's spec_helper.rb).
def testing_ui
  output = StringIO.new
  def output.winsize
    [20, 9999]
  end
  Cork::Board.new(out: output)
end

# A fake GitHub Actions environment, matching the CI this repo actually
# runs on. Danger reads GITHUB_EVENT_PATH as a real JSON file containing
# the pull_request webhook payload; see spec/fixtures/pull_request_event.json.
def testing_env
  {
    "GITHUB_ACTION" => "danger",
    "GITHUB_EVENT_NAME" => "pull_request",
    "GITHUB_REPOSITORY" => "serokell/danger",
    "GITHUB_EVENT_PATH" => File.join(__dir__, "fixtures", "pull_request_event.json"),
    "DANGER_GITHUB_API_TOKEN" => "faketoken"
  }
end

# A real Danger::Dangerfile, with our checks monkey-patched onto it via
# `require "serokell_danger"` above. git/github access still needs
# stubbing per-example (see spec/support/danger_testing.rb).
def testing_dangerfile
  env = Danger::EnvironmentManager.new(testing_env)
  Danger::Dangerfile.new(env, testing_ui)
end

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }
