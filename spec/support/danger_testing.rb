# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

RSpec.shared_context "danger testing" do
  let(:dangerfile) { testing_dangerfile }

  def make_fixture_path(fixture)
    File.join(__dir__, "..", "fixtures", fixture)
  end

  def set_diff(fixture, binary: false)
    allow(dangerfile.git).to receive(:diff).and_return([
      instance_double(
        Git::Diff::DiffFile,
        type: "modified",
        binary?: binary,
        destination_path: fixture
      )
    ])
  end

  def set_tracked_files(added_files: [], modified_files: [])
    allow(dangerfile.git).to receive(:added_files).and_return(added_files)
    allow(dangerfile.git).to receive(:modified_files).and_return(modified_files)
  end

  # Stubs dangerfile.githost to a fake PR/MR with the given title.
  # host is :github or :gitlab.
  def stub_githost(host, title:)
    plugin =
      case host
      when :github then double("plugin", pr_title: title, pr_body: "")
      when :gitlab then double("plugin", mr_title: title, mr_body: "")
      else raise ArgumentError, "expected :github or :gitlab, got #{host.inspect}"
      end
    allow(dangerfile).to receive(:githost).and_return(SerokellDanger::GitHost.new(plugin, host))
  end

  # Expects dangerfile.danger_report to fire once for each rule in
  # rules_to_test, and not to fire for any other rule in possible_rules.
  #
  # rules_to_test maps rule => expected attributes, e.g.
  # `{trailing_whitespace: {text: "some exact message"}}`. An empty
  # attributes hash means "expect it to fire, don't care what with".
  #
  # keyword_params lists the keyword arguments danger_report is called
  # with (e.g. `[:file, :line]`), so they get matched too (or defaulted
  # to `anything`). Pass an Array to use it for every rule, or a Hash to
  # use a different list per rule, e.g. `{check_year: [:file, :line],
  # expected_holder: [:file]}`.
  def set_danger_report_expectations(possible_rules, rules_to_test, keyword_params: [])
    possible_rules.each do |rule|
      rule_keyword_params =
        keyword_params.is_a?(Hash) ? keyword_params.fetch(rule, []) : keyword_params

      if rules_to_test.key?(rule)
        attrs = rules_to_test[rule]
        keywords = rule_keyword_params.to_h { |param| [param, attrs.fetch(param, anything)] }
        expect(dangerfile).to receive(:danger_report).with(anything, rule, attrs.fetch(:text, anything), **keywords)
      else
        keywords = rule_keyword_params.to_h { |param| [param, anything] }
        expect(dangerfile).not_to receive(:danger_report).with(anything, rule, anything, **keywords)
      end
    end
  end

  # Builds a fake commit with the given subject, description, and other
  # attributes used by the checks.
  def make_commit(
    subject:,
    description: "Problem: This is a placeholder description.\n\nSolution: It exists so unrelated rules don't fire.\n",
    blank_line_after_subject: true, short_ref: "deadbeef", parents: [nil]
  )
    commit = instance_double(
      Git::Object::Commit,
      subject: subject,
      subject_ticked: "`#{subject.tr("`", "'")}`",
      description: description,
      blank_line_after_subject?: blank_line_after_subject,
      short_ref: short_ref,
      parents: parents
    )
    allow(commit).to receive(:subject_matches?) { |patterns| SerokellDanger::Util.matches_any?(subject, patterns) }
    commit
  end

  def set_commits(*commits)
    allow(dangerfile.git).to receive(:commits).and_return(commits)
  end

  # Builds a config from a check's real default config (e.g.
  # :commits_style_default_config), overriding skip_if_title_matches to
  # nil unless overrides sets it.
  def make_config_from_default(default_config_method, **overrides)
    dangerfile.public_send(default_config_method).merge({skip_if_title_matches: nil}.merge(overrides))
  end
end
