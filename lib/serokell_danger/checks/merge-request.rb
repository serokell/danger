# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative "../helpers"
require_relative "../issue-prefix"

class Danger::Dangerfile
  def merge_request_default_config
    SerokellDanger::Config.new(
      "merge-request",
      {
        title_prefix: issue_prefix_default_config,

        ticket_links: SerokellDanger::Config.new(
          "ticket-links",
          {
            scan: %i[title body],
            pattern: /\b[A-Z][A-Z0-9]*-\d+\b/,
            base_url: "https://issues.serokell.io/issue/",
            tracker_name: "YouTrack"
          }
        ),
        skip_if_title_matches: default_branch_merge_title_patterns,
        severity: :warn,
        severities: {
          ticket_links: :message
        }
      },
      configure_with: "check_merge_request"
    )
  end

  def check_merge_request(config = merge_request_default_config)
    return unless mr_context?
    return if danger_check_skipped?(config)

    title = githost.mr_title_payload
    body = githost.mr_body

    prefix_config = config[:title_prefix]
    if prefix_config && !SerokellDanger.valid_issue_prefix?(title, prefix_config)
      danger_report(
        config, :title_prefix,
        "Inappropriate title for this merge request: `#{title}`. It should start with " \
        "an issue ID, one of: #{SerokellDanger.issue_prefix_examples(prefix_config)}.",
        hint: "title_prefix: nil"
      )
    end

    links_config = config[:ticket_links]
    return if links_config.nil?

    haystack = SerokellDanger::Util.as_list(links_config[:scan]).map do |where|
      case where.to_sym
      when :title then title
      when :body then body
      else raise ArgumentError, "`ticket_links.scan` expecs :title and/or :body, got #{where.inspect}."
      end
    end.join("\n")

    tickets = haystack.scan(links_config[:pattern]).uniq.map do |ticket_id|
      "[#{ticket_id}](#{links_config[:base_url]}#{ticket_id})"
    end
    return if tickets.empty?

    danger_report(
      config, :ticket_links,
      "Mentioned #{links_config[:tracker_name]} tickets: #{tickets.join(", ")}."
    )
  end
end
