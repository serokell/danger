# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require_relative "../../lib/serokell_danger/checks/trailing-whitespaces"

RSpec.describe "trailing-whitespace check" do
  include_context "danger testing"

  let(:trailing_whitespace_extra_final_newlines_path) do
    make_fixture_path("TrailingWhitespaceExtraFinalNewlines.hs")
  end
  let(:no_final_newline_path) { make_fixture_path("NoFinalNewline.hs") }

  def make_config(rules, file_extensions: nil, ignore_paths: [],
    skip_if_title_matches: nil)
    config =
      {
        trailing_whitespace: false,
        final_newline: false,
        extra_final_newlines: false,
        file_extensions: file_extensions,
        ignore_paths: ignore_paths,
        severity: :fail,
        skip_if_title_matches: skip_if_title_matches
      }
    config = rules.reduce(config) { |acc, rule| acc.merge({rule => true}) }
    SerokellDanger::Config.new(
      "trailing-whitespace",
      config,
      configure_with: "check_trailing_whitespace"
    )
  end

  def set_rule_receive_expectations(rules_to_test)
    set_danger_report_expectations(
      [:trailing_whitespace, :final_newline, :extra_final_newlines],
      rules_to_test
    )
  end

  # `enable` defaults to the rules under test, but a test that needs a rule
  # turned on without expecting it to fire (e.g. "ignores binary files",
  # which must prove the binary-skip happens before the rule check even
  # runs) can pass its own list.
  def simple_test(fixture, rules_to_test, enable: rules_to_test.keys,
    binary: false, **config_overrides)
    config = make_config(enable, **config_overrides)
    set_diff(fixture, binary: binary)
    set_rule_receive_expectations(rules_to_test)
    yield if block_given?
    dangerfile.check_trailing_whitespace(config)
  end

  it "warns about a file with trailing whitespaces" do
    simple_test(
      trailing_whitespace_extra_final_newlines_path,
      {trailing_whitespace: {}}
    )
  end

  it "warns about a file with no final newline" do
    simple_test(no_final_newline_path, {final_newline: {}})
  end

  it "warns about a file with extra final newlines" do
    simple_test(
      trailing_whitespace_extra_final_newlines_path,
      {extra_final_newlines: {}}
    )
  end

  it "ignores binary files" do
    simple_test(
      no_final_newline_path,
      {},
      enable: [:final_newline],
      binary: true
    )
  end

  it "ignores files in ignore_paths" do
    simple_test(
      no_final_newline_path,
      {},
      enable: [:final_newline],
      ignore_paths: [no_final_newline_path]
    )
  end

  it "runs with files in file_extensions" do
    simple_test(
      no_final_newline_path,
      {final_newline: {}},
      file_extensions: [".hs"]
    )
  end

  it "does not run with files not in file_extensions" do
    simple_test(
      no_final_newline_path,
      {},
      enable: [:final_newline],
      file_extensions: [".rb"]
    )
  end

  it "does not run if the title matches a pattern (GitHub)" do
    stub_githost(:github, title: "Merge branch 'foo' into 'main'")
    simple_test(
      no_final_newline_path,
      {},
      enable: [:final_newline],
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end

  it "does not run if the title matches a pattern (GitLab)" do
    stub_githost(:gitlab, title: "Merge branch 'foo' into 'main'")
    simple_test(
      no_final_newline_path,
      {},
      enable: [:final_newline],
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end
end
