# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require_relative "../../lib/serokell_danger/checks/premerge-commits"

RSpec.describe "premerge-commits check" do
  include_context "danger testing"

  def make_config(**overrides)
    make_config_from_default(:premerge_commits_default_config, **overrides)
  end

  def set_rule_receive_expectations(rules_to_test)
    set_danger_report_expectations([:wip_commit_patterns, :fixup_commit_patterns], rules_to_test)
  end

  def simple_test(commits, rules_to_test, **config_overrides)
    config = make_config(**config_overrides)
    set_commits(*commits)
    set_rule_receive_expectations(rules_to_test)
    yield if block_given?
    dangerfile.check_premerge_commits(config)
  end

  it "reports a commit whose subject matches wip_commit_patterns" do
    simple_test(
      [make_commit(subject: "wip write a test for premerge-commits")],
      {wip_commit_patterns: {}}
    )
  end

  it "reports a commit whose subject matches fixup_commit_patterns" do
    simple_test(
      [make_commit(subject: "fixup! add premerge-commits tests")],
      {fixup_commit_patterns: {}}
    )
  end

  it "does not report a commit whose subject matches neither pattern" do
    simple_test(
      [make_commit(subject: "[#4] Add premerge-commits tests")],
      {}
    )
  end

  it "mentions every offending commit in a single danger_report call" do
    simple_test(
      [
        make_commit(subject: "wip add premerge-commits tests"),
        make_commit(subject: "wip add merge-request tests", short_ref: "fee1dead")
      ],
      {
        wip_commit_patterns: {
          text: "Some work-in-progress commits are still there: deadbeef (`wip add premerge-commits tests`), fee1dead (`wip add merge-request tests`)."
        }
      }
    )
  end

  it "does not check for wip commits when wip_commit_patterns is nil" do
    simple_test(
      [make_commit(subject: "wip add premerge-commits tests")],
      {},
      wip_commit_patterns: nil
    )
  end

  it "does not check for fixup commits when fixup_commit_patterns is nil" do
    simple_test(
      [make_commit(subject: "fixup add premerge-commits tests")],
      {},
      fixup_commit_patterns: nil
    )
  end

  it "does not run if the title matches a pattern (GitHub)" do
    stub_githost(:github, title: "Merge branch 'foo' into 'main'")
    simple_test(
      [make_commit(subject: "wip: still in progress")],
      {},
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end

  it "does not run if the title matches a pattern (GitLab)" do
    stub_githost(:gitlab, title: "Merge branch 'foo' into 'main'")
    simple_test(
      [make_commit(subject: "wip: still in progress")],
      {},
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end

  it "does nothing when there are no commits" do
    simple_test([], {})
  end
end
