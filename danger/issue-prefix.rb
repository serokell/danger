# SPDX-FileCopyrightText: 2023 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative 'config'

module SerokellDanger
  ISSUE_PREFIX_KINDS = {
    github_issue: /\[#\d+\]/,
    gitlab_issue: /\[#\d+\]/,
    youtrack_issue: /\[[A-Z][A-Z0-9]*-\d+\]/,
    chore: /\[Chore\]/,
  }.freeze

  module_function

  def issue_prefix_pattern(config)
    tags = Util.as_list(config[:kinds]).map do |kind|
      ISSUE_PREFIX_KINDS[kind.to_sym] ||
        raise(ArgumentError,
              "Unknown issue prefix kind `#{kind.inspect}`. " \
              "Known kinds: #{ISSUE_PREFIX_KINDS.keys.join(', ')}. " \
              'Custom prefixes can be added via `extra_patterns`.')
    end
    tags += Util.as_list(config[:extra_patterns])
    raise ArgumentError, 'No issue prefix kinds configured.' if tags.empty?

    alternation = Regexp.union(tags).source
    quantifier = config[:allow_multiple] ? '+' : ''
    Regexp.new(
      "\\A(?:#{alternation})#{quantifier}(?<separator>[ \\t]*)(?!#{alternation})(?=\\S)"
    )
  end

  def issue_prefix_match(text, config)
    issue_prefix_pattern(config).match(text.to_s)
  end

  def valid_issue_prefix?(text, config)
    !issue_prefix_match(text, config).nil?
  end

  def issue_prefix_separator(text, config)
    match = issue_prefix_match(text, config)
    match && match[:separator]
  end

  def strip_issue_prefix(text, config)
    text.to_s.sub(issue_prefix_pattern(config), '')
  end

  def issue_prefix_examples(config)
    examples = Util.as_list(config[:kinds]).map do |kind|
      case kind.to_sym
      when :github_issue, :gitlab_issue then '`[#123]`'
      when :youtrack_issue then '`[KEK-123]`'
      when :chore then '`[Chore]`'
      end
    end.compact
    examples += Util.as_list(config[:extra_patterns]).map { |p| "`#{p.source}`" }
    examples.uniq.join(', ')
  end
end

class Danger::Dangerfile
  def issue_prefix_default_config
    SerokellDanger::Config.new(
      'issue-prefix',
      {
        kinds: %i[github_issue youtrack_issue chore],
        extra_patterns: [],
        allow_multiple: true,
      }
    )
  end
end
