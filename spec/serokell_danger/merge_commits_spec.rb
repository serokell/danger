# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require_relative "../../lib/serokell_danger/checks/merge-commits"

RSpec.describe "merge-commits check" do
  include_context "danger testing"

  def make_config(**overrides)
    make_config_from_default(:merge_commits_default_config, **overrides)
  end

  def set_rule_receive_expectations(rules_to_test)
    set_danger_report_expectations([:detect], rules_to_test, keyword_params: [:hint])
  end

  def simple_test(commits, rules_to_test, **config_overrides)
    config = make_config(**config_overrides)
    set_commits(*commits)
    set_rule_receive_expectations(rules_to_test)
    yield if block_given?
    dangerfile.check_merge_commits(config)
  end

  it "reports a commit with more than one parent" do
    simple_test(
      [make_commit(subject: "[#4] Subject", parents: %i[parent1 parent2])],
      {detect: {}}
    )
  end

  it "does not report a commit with a single parent" do
    simple_test(
      [make_commit(subject: "[#4] Subject", parents: %i[parent])],
      {}
    )
  end

  it "reports a commit whose subject matches merge_commit_subject_patterns when detect includes :subject" do
    simple_test(
      [make_commit(subject: "Merge branch 'foo' into 'main")],
      {detect: {}},
      detect: %i[subject]
    )
  end

  it "does not detect by subject when detect does not include :subject (the default)" do
    simple_test(
      [make_commit(subject: "Merge branch 'foo' into 'main")],
      {}
    )
  end

  it "mentions every offending commit in a single danger_report call" do
    simple_test(
      [
        make_commit(subject: "[#4] Subject", parents: %i[parent1 parent2]),
        make_commit(subject: "Merge branch 'foo' into 'main", short_ref: "fee1dead")
      ],
      {
        detect: {
          text: "Please, no merge commits, rebase for the win. Found: " \
            "deadbeef (`[#4] Subject`), fee1dead (`Merge branch 'foo' into 'main`)."
        }
      },
      detect: %i[parents subject]
    )
  end

  it "raises for an invalid detect value" do
    config = make_config(detect: %i[this_option_does_not_exist])
    set_commits(make_commit(subject: "[#4] Subject"))

    expect { dangerfile.check_merge_commits(config) }.to raise_error(
      ArgumentError,
      "`detect` expects :parents and/or :subject, got :this_option_does_not_exist."
    )
  end

  it "does not run if the title matches a pattern (GitHub)" do
    stub_githost(:github, title: "Merge branch 'foo' into 'main'")
    simple_test(
      [make_commit(subject: "[#4] Subject", parents: %i[parent1 parent2])],
      {},
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end

  it "does not run if the title matches a pattern (GitLab)" do
    stub_githost(:gitlab, title: "Merge branch 'foo' into 'main'")
    simple_test(
      [make_commit(subject: "[#4] Subject", parents: %i[parent1 parent2])],
      {},
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end
end
