# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative "../helpers"

class Danger::Dangerfile
  def merge_commits_default_config
    SerokellDanger::Config.new(
      "merge-commits",
      {
        detect: %i[parents],
        merge_commit_subject_patterns: [
          /\AMerge branch\b/,
          /\AMerge remote-tracking branch\b/,
          /\AMerge pull request\b/
        ],
        skip_if_title_matches: default_branch_merge_title_patterns,
        severity: :fail
      },
      configure_with: "check_merge_commits"
    )
  end

  def check_merge_commits(config = merge_commits_default_config)
    return if danger_check_skipped?(config)

    methods = SerokellDanger::Util.as_list(config[:detect])
    offenders = git.commits.select do |commit|
      methods.any? do |method|
        case method.to_sym
        when :parents then commit.parents.count > 1
        when :subject then commit.subject_matches?(config[:merge_commit_subject_patterns])
        else raise ArgumentError, "`detect` expects :parents and/or :subject, got #{method.inspect}."
        end
      end
    end
    return if offenders.empty?

    danger_report(
      config, :detect,
      "Please, no merge commits, rebase for the win. Found: " \
      "#{offenders.map { |c| "#{c.short_ref} (#{c.subject_ticked})" }.join(", ")}.",
      hint: "detect: nil"
    )
  end
end
