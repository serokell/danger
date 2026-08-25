# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require_relative "../../lib/serokell_danger/checks/commits-style"

RSpec.describe "commits-style check" do
  include_context "danger testing"

  # Unlike trailing-whitespace/license-headers, most of this check's rules
  # are already true/set in the real default config, so a made-up commit
  # would otherwise trip several of them at once. Start from the real
  # defaults and override only what a given example cares about, e.g.
  # `make_config(commit_msg_prefix: nil, max_line_length: nil)` to silence
  # unrelated rules while testing one in isolation.
  def make_config(**overrides)
    make_config_from_default(:commits_style_default_config, **overrides)
  end

  def set_rule_receive_expectations(rules_to_test)
    set_danger_report_expectations(
      [
        :commit_msg_prefix,
        :subject_spacing,
        :subject_starts_with_uppercase,
        :subject_no_trailing_dot,
        :max_subject_length,
        :max_subject_length_hard,
        :require_description,
        :blank_line_after_subject,
        :commit_description_patterns,
        :max_line_length
      ],
      rules_to_test,
      keyword_params: {commit_msg_prefix: [:hint]}
    )
  end

  def simple_test(commit, rules_to_test, **config_overrides)
    config = make_config(**config_overrides)
    set_commits(commit)
    set_rule_receive_expectations(rules_to_test)
    yield if block_given?
    dangerfile.check_commits_style(config)
  end

  # --- subject rules ---

  it "warns about a commit missing an issue prefix" do
    simple_test(
      make_commit(subject: "No issue prefix"),
      {commit_msg_prefix: {}}
    )
  end

  it "warns about wrong spacing between the issue prefix and the rest of the subject" do
    simple_test(make_commit(subject: "[#4]No spacing"), {subject_spacing: {}})
  end

  it "warns about a subject not starting with an uppercase letter" do
    simple_test(
      make_commit(subject: "[#4] lowercase subject"),
      {subject_starts_with_uppercase: {}}
    )
  end

  it "warns about a subject with a trailing dot" do
    simple_test(
      make_commit(subject: "[#4] Trailing dot in subject."),
      {subject_no_trailing_dot: {}}
    )
  end

  it "warns about a subject longer than max_subject_length" do
    simple_test(
      make_commit(subject: "[#4] This subject is too long and should be rejected by max_subject_length"),
      {max_subject_length: {}}
    )
  end

  it "warns (harder) about a subject longer than max_subject_length_hard" do
    simple_test(
      make_commit(subject: "[#4] This subject is definitely way too long and should be rejected by max_subject_length_hard"),
      {max_subject_length_hard: {}}
    )
  end

  # --- description rules ---

  it "warns about a commit with no description" do
    simple_test(
      make_commit(subject: "[#4] Subject", description: ""),
      {require_description: {}}
    )
  end

  it "does not warn about a missing description on a chore commit" do
    simple_test(
      make_commit(subject: "[Chore] WIP", description: ""),
      {}
    )
  end

  it "warns about a missing blank line after the subject" do
    simple_test(
      make_commit(subject: "[#4] No blank line", blank_line_after_subject: false),
      {blank_line_after_subject: {}}
    )
  end

  it "warns about a description not matching commit_description_patterns" do
    simple_test(
      make_commit(subject: "[#4] Subject", description: "Not in problem/solution format"),
      {commit_description_patterns: {}}
    )
  end

  it "does not warn when description_escape_hatch matches" do
    simple_test(
      make_commit(subject: "[#4] Subject", description: "I don't care about templates"),
      {}
    )
  end

  it "warns about description lines longer than max_line_length" do
    simple_test(
      make_commit(
        subject: "[#4] Subject",
        description: "Problem: This description is definitely way too long and should be rejected by max_line_length.\n\nSolution: Fail the test expectation."
      ),
      {max_line_length: {}}
    )
  end

  # --- whole-commit exemptions ---

  it "skips a commit entirely if its subject matches wip_commit_patterns" do
    simple_test(
      make_commit(subject: "wip multiple problems.", description: "Not in problem/solution format"),
      {}
    )
  end

  it "skips a commit entirely if its subject matches fixup_commit_patterns" do
    simple_test(
      make_commit(subject: "fixup! wip multiple problems.", description: "Not in problem/solution format"),
      {}
    )
  end

  it "skips a commit entirely if its subject matches exempt_commit_patterns" do
    simple_test(
      make_commit(subject: "changelog wip multiple problems.", description: "Not in problem/solution format"),
      {}
    )
  end

  # --- skip_if_title_matches (mirrors trailing-whitespace/license-headers) ---

  it "does not run if the title matches a pattern (GitHub)" do
    stub_githost(:github, title: "Merge branch 'foo' into 'main'")
    simple_test(
      make_commit(subject: "No issue prefix"),
      {},
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end

  it "does not run if the title matches a pattern (GitLab)" do
    stub_githost(:gitlab, title: "Merge branch 'foo' into 'main'")
    simple_test(
      make_commit(subject: "No issue prefix"),
      {},
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end

  # --- explain_workarounds ---

  it "adds an explanatory markdown note when something was reported and explain_workarounds is true" do
    simple_test(make_commit(subject: "No issue prefix"), {commit_msg_prefix: {}}) do
      expect(dangerfile).to receive(:markdown).with(a_string_matching(/Every rule above can be turned off/))
    end
  end

  it "adds no markdown note when nothing was reported" do
    simple_test(make_commit(subject: "[#4] Well-formed commit subject"), {}) do
      expect(dangerfile).not_to receive(:markdown)
    end
  end

  it "does nothing when there are no commits" do
    config = make_config
    set_commits
    set_rule_receive_expectations({})
    dangerfile.check_commits_style(config)
  end
end
