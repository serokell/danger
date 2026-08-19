# SPDX-FileCopyrightText: 2023 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative "../helpers"
require_relative "commits-style"

class Danger::Dangerfile
  def premerge_commits_default_config
    SerokellDanger::Config.new(
      "premerge-commits",
      {
        wip_commit_patterns: default_wip_commit_patterns,
        fixup_commit_patterns: default_fixup_commit_patterns,

        skip_if_title_matches: default_branch_merge_title_patterns,

        severity: :fail
      },
      configure_with: "check_premerge_commits"
    )
  end

  def check_premerge_commits(config = premerge_commits_default_config)
    return if danger_check_skipped?(config)

    {
      wip_commit_patterns: "work-in-progress",
      fixup_commit_patterns: "fixup"
    }.each do |rule, kind|
      patterns = config[rule]
      next if patterns.nil?

      offenders = git.commits.select { |commit| commit.subject_matches?(patterns) }
      next if offenders.empty?

      danger_report(
        config, rule,
        "Some #{kind} commits are still there: " \
        "#{offenders.map { |c| "#{c.short_ref} (#{c.subject_ticked})" }.join(", ")}."
      )
    end
  end
end
