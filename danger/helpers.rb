# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative "config"

module SerokellDanger
  DRAFT_TITLE_PATTERN = /\A(?:\[Draft\]\s*|(?:Draft|WIP)\s*:\s*)/i

  ANY_LEADING_TAGS_PATTERN = /\A(?:\[[^\]]*\]\s*)*/

  class GitHost
    attr_reader :plugin, :host

    def initialize(plugin, host)
      @plugin = plugin
      @host = host
    end

    def self.detect(dangerfile)
      if dangerfile.respond_to?(:github) && dangerfile.github
        new(dangerfile.github, :github)
      elsif dangerfile.respond_to?(:gitlab) && dangerfile.gitlab
        new(dangerfile.gitlab, :gitlab)
      end
    end

    def github?
      host == :github
    end

    def gitlab?
      host == :gitlab
    end

    def mr_title
      plugin.mr_title.to_s
    end
    alias_method :pr_title, :mr_title

    def mr_body
      plugin.mr_body.to_s
    end
    alias_method :pr_body, :mr_body

    def mr_json
      plugin.mr_json
    end
    alias_method :pr_json, :mr_json

    def branch_for_head
      plugin.branch_for_head
    end
    alias_method :source_branch, :branch_for_head

    def branch_for_base
      plugin.branch_for_base
    end
    alias_method :target_branch, :branch_for_base

    def mr_iid
      json_field("iid", "number")
    end
    alias_method :pr_iid, :mr_iid

    def mr_url
      json_field("web_url", "html_url")
    end
    alias_method :pr_url, :mr_url

    def mr_draft?
      return plugin.pr_draft? if github? && plugin.respond_to?(:pr_draft?)

      json = mr_json
      return true if truthy_field(json, "work_in_progress") || truthy_field(json, "draft")

      DRAFT_TITLE_PATTERN.match?(mr_title)
    end
    alias_method :pr_draft?, :mr_draft?

    def mr_title_payload
      mr_title.sub(DRAFT_TITLE_PATTERN, "")
    end
    alias_method :pr_title_payload, :mr_title_payload

    def suggestion_fence(above: 0, below: 0)
      if gitlab?
        "suggestion:-#{above}+#{below}"
      elsif above.zero? && below.zero?
        "suggestion"
      else
        "diff"
      end
    end

    def method_missing(name, *args, **kwargs, &block)
      if plugin.respond_to?(name)
        plugin.public_send(name, *args, **kwargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      plugin.respond_to?(name, include_private) || super
    end

    private

    def json_field(gitlab_key, github_key)
      json = mr_json
      key = gitlab? ? gitlab_key : github_key
      json[key]
    rescue
      nil
    end

    def truthy_field(json, key)
      json[key]
    rescue
      nil
    end
  end

  module Util
    module_function

    def as_list(value)
      case value
      when nil then []
      when Array then value
      else [value]
      end
    end

    def matches_any?(string, patterns)
      as_list(patterns).any? { |pattern| pattern_matches?(string, pattern) }
    end

    def pattern_matches?(string, pattern)
      case pattern
      when Regexp then pattern.match?(string)
      else string.include?(pattern.to_s)
      end
    end

    def path_selected?(path, file_extensions: nil, ignore_paths: [])
      path = path.to_s
      return false if as_list(ignore_paths).any? { |ignored| path_ignored?(path, ignored) }
      return true if file_extensions.nil?

      extension = File.extname(path)
      as_list(file_extensions).any? do |wanted|
        wanted = wanted.to_s
        wanted = ".#{wanted}" unless wanted.start_with?(".")
        extension == wanted
      end
    end

    def path_ignored?(path, ignored)
      case ignored
      when Regexp then ignored.match?(path)
      else File.fnmatch?(ignored.to_s, path, File::FNM_PATHNAME | File::FNM_EXTGLOB) ||
        path.start_with?(ignored.to_s)
      end
    end

    def severity_for(config, rule, override = nil)
      return override unless override.nil?

      severities = config.key?(:severities) ? config[:severities] : nil
      severity = severities && (severities[rule] || severities[rule.to_sym])
      severity || (config.key?(:severity) ? config[:severity] : :warn)
    end
  end
end

class Danger::Dangerfile
  def default_branch_merge_title_patterns
    [/\AMerg\w+ .+ (?:in|into|with|to) ./i]
  end

  def githost
    SerokellDanger::GitHost.detect(self)
  end

  def mr_context?
    !githost.nil?
  end

  def githost!
    githost || raise("Failed to figure out which service are we running from.")
  end

  def mr_title_payload
    githost!.mr_title_payload
  end
  alias_method :pr_title_payload, :mr_title_payload

  def danger_report(config, rule, text, severity: nil, hint: nil, **opts)
    severity = SerokellDanger::Util.severity_for(config, rule, severity)
    return if severity.nil? || severity == :off

    line = "[#{config.check_name}/#{rule}] #{text}"
    if %i[warn fail failure].include?(severity)
      hint ||= "#{rule}: nil"
      line += " (To disable this rule: `#{hint}`"
      line += " in `#{config.configure_with}`" if config.configure_with
      line += ".)"
    end

    case severity
    when :fail, :failure then fail(line, **opts)
    when :warn then warn(line, **opts)
    when :message then message(line, **opts)
    when :markdown then markdown(line, **opts)
    else
      raise ArgumentError,
        "Unknown severity `#{severity.inspect}` for `#{config.check_name}/#{rule}`. " \
        "Expected one of: :fail, :warn, :message, :off."
    end
  end

  def danger_check_skipped?(config)
    return false unless config.key?(:skip_if_title_matches)

    patterns = config[:skip_if_title_matches]
    return false if patterns.nil? || !mr_context?

    title = githost.mr_title_payload.sub(SerokellDanger::ANY_LEADING_TAGS_PATTERN, "")
    SerokellDanger::Util.matches_any?(title, patterns)
  end
end

class Git::Diff::DiffFile
  def destination_path
    rename_match = /(?<=(\nrename to ))(\S)*/.match(patch)
    if rename_match.nil?
      path
    else
      rename_match.to_s
    end
  end
end

class Git::Object::Commit
  def subject
    message.lines.first.to_s.rstrip
  end
  alias_method :message_subject, :subject

  def subject_ticked
    "`" + subject.tr("`", "'") + "`"
  end

  def description
    message.lines.drop(1).drop_while { |s| s == "\n" }.join
  end
  alias_method :message_body, :description

  def blank_line_after_subject?
    message.lines[1] == "\n"
  end

  def subject_matches?(patterns)
    SerokellDanger::Util.matches_any?(subject, patterns)
  end

  def short_ref
    sha.to_s[0, 8]
  end
end

module Danger::Helpers::CommentsHelper
  def markdown_link_to_message(_, _)
    ""
  end
end
