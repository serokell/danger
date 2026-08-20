# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative "../helpers"

class Danger::Dangerfile
  def trailing_whitespace_default_config
    SerokellDanger::Config.new(
      "trailing-whitespace",
      {
        trailing_whitespace: true,
        final_newline: true,
        extra_final_newlines: true,
        file_extensions: nil,
        ignore_paths: [],
        severity: :fail
      },
      configure_with: "check_trailing_whitespace"
    )
  end
  alias_method :trailing_whitespaces_default_config, :trailing_whitespace_default_config

  def check_trailing_whitespace(config = trailing_whitespace_default_config)
    return if danger_check_skipped?(config)

    counts = Hash.new(0)

    git.diff.each do |file|
      next unless %w[new modified].include?(file.type)
      next if file.binary?

      path = file.destination_path
      next unless SerokellDanger::Util.path_selected?(
        path,
        file_extensions: config[:file_extensions],
        ignore_paths: config[:ignore_paths]
      )
      next if File.directory?(path) || !File.file?(path)

      contents = File.read(path)
      next if contents.empty?

      check_file_trailing_whitespace(path, contents.lines, config, counts)
    end

    {
      trailing_whitespace: "Trailing whitespaces detected",
      final_newline: "Missing newlines at the end of file detected",
      extra_final_newlines: "Extra newlines at the end of file detected"
    }.each do |rule, summary|
      next if counts[rule].zero?

      danger_report(
        config, rule,
        "#{summary} (#{counts[rule]} place(s), see the inline comments)."
      )
    end
  end
  alias_method :check_trailing_whitespaces, :check_trailing_whitespace

  private

  def check_file_trailing_whitespace(path, lines, config, counts)
    if config[:trailing_whitespace]
      lines.each.with_index(1) do |line, line_index|
        line = line.chomp
        next unless /\s\z/.match?(line)

        counts[:trailing_whitespace] += 1
        markdown(
          "I have found some trailing whitespaces here:\n" \
          "```#{whitespace_suggestion_fence}\n#{line.rstrip}\n```\n",
          file: path, line: line_index
        )
      end
    end

    if config[:final_newline] && !lines.last.end_with?("\n")
      counts[:final_newline] += 1
      markdown(
        "I have found a missing newline at the end of this file:\n" \
        "```#{whitespace_suggestion_fence}\n#{lines.last.rstrip}\n\n```\n",
        file: path, line: lines.length
      )
    end

    return unless config[:extra_final_newlines]

    extra_lines = lines.reverse_each.take_while { |line| line == "\n" }.length
    return if extra_lines.zero?

    counts[:extra_final_newlines] += 1
    markdown(
      "#{extra_final_newlines_message(extra_lines)}\n" \
      "```#{whitespace_suggestion_fence(above: extra_lines - 1)}\n```\n",
      file: path, line: lines.length
    )
  end

  def extra_final_newlines_message(extra_lines)
    if extra_lines == 1
      "Extra newline at the end of the file."
    else
      "#{extra_lines} extra newlines at the end of the file."
    end
  end

  def whitespace_suggestion_fence(above: 0, below: 0)
    if mr_context?
      githost.suggestion_fence(above: above, below: below)
    else
      "suggestion"
    end
  end

  public
end
