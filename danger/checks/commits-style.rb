# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative "../helpers"
require_relative "../issue-prefix"

class Danger::Dangerfile
  def default_wip_commit_patterns
    [/\bwip\b/i, /\btmp\b/i, /\[temporary\]/i]
  end

  def default_fixup_commit_patterns
    [/\bfixup!/, /\bsquash!/]
  end

  def commits_style_default_config
    SerokellDanger::Config.new(
      "commits-style",
      {
        wip_commit_patterns: default_wip_commit_patterns,
        fixup_commit_patterns: default_fixup_commit_patterns,
        exempt_commit_patterns: [/changelog/i],
        chore_commit_patterns: [/\[Chore\]/],
        commit_msg_prefix: issue_prefix_default_config,
        max_subject_length: 72,
        max_subject_length_hard: 90,
        subject_starts_with_uppercase: true,
        subject_no_trailing_dot: true,
        subject_spacing: true,
        require_description: true,
        blank_line_after_subject: true,
        commit_description_patterns: [
          /^Problem:[ \n].*^Solution:[ \n]/m
        ],
        description_escape_hatch: /I don't care about templates/,
        max_line_length: 72,
        skip_if_title_matches: default_branch_merge_title_patterns,
        explain_workarounds: true,
        severity: :warn,
        severities: {
          max_subject_length_hard: :fail,
          require_description: :fail
        }
      },
      configure_with: "check_commits_style"
    )
  end

  def check_commits_style(config = commits_style_default_config)
    return if danger_check_skipped?(config)

    reported = false
    report = lambda do |rule, text, **opts|
      severity = SerokellDanger::Util.severity_for(config, rule)
      reported = true if %i[warn fail failure].include?(severity)
      danger_report(config, rule, text, **opts)
    end

    git.commits.each do |commit|
      next if commit.subject_matches?(config[:wip_commit_patterns])
      next if commit.subject_matches?(config[:fixup_commit_patterns])
      next if commit.subject_matches?(config[:exempt_commit_patterns])

      check_commit_subject(commit, config, report)
      check_commit_description(commit, config, report)
    end

    return unless reported && config[:explain_workarounds]

    markdown(
      "[#{config.check_name}] Every rule above can be turned off in `#{config.configure_with}`. " \
      "A single commit is exempt from all of them if its subject is marked as a work in " \
      "progress (#{describe_patterns(config[:wip_commit_patterns])}) or as a fixup " \
      "(#{describe_patterns(config[:fixup_commit_patterns])})."
    )
  end

  private

  def check_commit_subject(commit, config, report)
    subject = commit.subject
    ticked = commit.subject_ticked
    ref = commit.short_ref

    prefix_config = config[:commit_msg_prefix]
    if prefix_config && !SerokellDanger.valid_issue_prefix?(subject, prefix_config)
      report.call(
        :commit_msg_prefix,
        "Commit #{ref} lacks an issue ID: #{ticked}. Expected the subject to start with " \
        "one of: #{SerokellDanger.issue_prefix_examples(prefix_config)}.",
        hint: "commit_msg_prefix: nil"
      )
    end

    payload = prefix_config ? SerokellDanger.strip_issue_prefix(subject, prefix_config) : subject
    separator = prefix_config && SerokellDanger.issue_prefix_separator(subject, prefix_config)

    if config[:subject_spacing] && separator && separator != " "
      report.call(
        :subject_spacing,
        "Expected exactly one space between the issue prefix and the rest of the subject " \
        "of commit #{ref}: #{ticked}."
      )
    end

    if config[:subject_starts_with_uppercase] && !payload.start_with?(/[A-Z]/)
      report.call(
        :subject_starts_with_uppercase,
        "Subject of commit #{ref} does not begin with an uppercase letter: #{ticked}."
      )
    end

    if config[:subject_no_trailing_dot] && subject.end_with?(".")
      report.call(
        :subject_no_trailing_dot,
        "Subject of commit #{ref} ends with a dot: #{ticked}."
      )
    end

    hard_limit = config[:max_subject_length_hard]
    soft_limit = config[:max_subject_length]
    if hard_limit && subject.length > hard_limit
      report.call(
        :max_subject_length_hard,
        "Subject of commit #{ref} is way too long (#{subject.length} chars, " \
        "the hard limit is #{hard_limit})."
      )
    elsif soft_limit && subject.length > soft_limit
      report.call(
        :max_subject_length,
        "Subject of commit #{ref} is too long (#{subject.length} chars), " \
        "please keep its length within #{soft_limit} characters."
      )
    end
  end

  def check_commit_description(commit, config, report)
    ref = commit.short_ref
    chore = commit.subject_matches?(config[:chore_commit_patterns])
    description = commit.description

    if description.strip.empty?
      unless chore || !config[:require_description]
        report.call(
          :require_description,
          "Commit #{ref} lacks a description " \
          "(commits matching #{describe_patterns(config[:chore_commit_patterns])} are exempt)."
        )
      end
      return
    end

    if config[:blank_line_after_subject] && !commit.blank_line_after_subject?
      report.call(
        :blank_line_after_subject,
        "In commit #{ref} the blank line after the subject is missing."
      )
    end

    patterns = SerokellDanger::Util.as_list(config[:commit_description_patterns])
    escape_hatch = config[:description_escape_hatch]
    unless chore || patterns.empty?
      matched = SerokellDanger::Util.matches_any?(description, patterns)
      matched ||= SerokellDanger::Util.matches_any?(description, escape_hatch) if escape_hatch
      unless matched
        text = "Description of commit #{ref} does not follow any of the accepted templates " \
               "(#{describe_patterns(patterns)})."
        text += " If you really have to, add `#{escape_hatch.source}` to the description." if escape_hatch
        report.call(:commit_description_patterns, text)
      end
    end

    limit = config[:max_line_length]
    return unless limit

    too_long = description_overlong_lines(description, limit)
    return if too_long.empty?

    report.call(
      :max_line_length,
      "Description of commit #{ref} has #{too_long.size} line(s) longer than #{limit} " \
      "characters (first one is #{too_long.first[0]}: #{too_long.first[1][0, 30].inspect}...)."
    )
  end

  def description_overlong_lines(description, limit)
    in_fence = false
    description.lines.each_with_index.filter_map do |line, index|
      line = line.chomp
      if line.strip.start_with?("```")
        in_fence = !in_fence
        next
      end
      next if in_fence
      next if line.start_with?("    ", "\t")
      next if line.length <= limit
      next if line.split(/\s+/).any? { |token| token.length > limit }

      [index + 2, line]
    end
  end

  def describe_patterns(patterns)
    SerokellDanger::Util.as_list(patterns).map do |pattern|
      pattern.is_a?(Regexp) ? "`#{pattern.source}`" : "`#{pattern}`"
    end.join(", ")
  end

  public
end
