# SPDX-FileCopyrightText: 2023 Serokell <https://serokell.io>
# SPDX-License-Identifier: MPL-2.0

require_relative "../helpers"

class Danger::Dangerfile
  def license_headers_default_config
    SerokellDanger::Config.new(
      "license-headers",
      {
        scan: :added_files,
        file_extensions: nil,
        ignore_paths: [],

        copyright_line_pattern:
          /^(?<prefix>.*?(?:SPDX-FileCopyrightText|Copyright(?:\s*\([Cc]\))?)\s*:?)\s+
            (?<years>\d{4}(?:\s*-\s*\d{4})?)\s+(?<holder>.+?)\s*$/x,
        check_year: true,
        expected_holder: nil,

        severity: :warn
      },
      configure_with: "check_license_headers"
    )
  end

  def check_license_headers(config = license_headers_default_config)
    return if danger_check_skipped?(config)

    license_headers_files(config).each do |path|
      next unless File.file?(path)

      header = license_header_match(path, config)
      next if header.nil?

      check_license_header_line(path, header, config)
    end
  end

  private

  def license_headers_files(config)
    files =
      case config[:scan].to_sym
      when :added_files then git.added_files.to_a
      when :changed_files then git.added_files.to_a + git.modified_files.to_a
      else raise ArgumentError, "`scan` expects :added_files or :changed_files, got #{config[:scan].inspect}."
      end
    files.uniq.select do |path|
      SerokellDanger::Util.path_selected?(
        path,
        file_extensions: config[:file_extensions],
        ignore_paths: config[:ignore_paths]
      )
    end
  end

  def license_header_match(path, config)
    File.foreach(path).with_index(1) do |line, number|
      match = config[:copyright_line_pattern].match(line)
      return {match: match, line_number: number, line: line.chomp} if match
    end
    nil
  rescue ArgumentError, SystemCallError
    nil
  end

  def check_license_header_line(path, header, config)
    match = header[:match]
    years = named_capture(match, "years").to_s
    holder = named_capture(match, "holder").to_s.strip
    current_year = Time.now.year.to_s
    first_year, last_year = years.split(/\s*-\s*/)
    last_year ||= first_year

    problems = []
    if config[:check_year] && last_year != current_year
      problems << [:check_year, "the year in this license header is outdated (#{years})"]
    end
    if config[:expected_holder] && holder != config[:expected_holder].to_s
      problems << [:expected_holder,
        "the copyright holder is `#{holder}`, expected `#{config[:expected_holder]}`"]
    end
    return if problems.empty?

    problems.each do |rule, text|
      danger_report(
        config, rule, "#{text.capitalize}.",
        file: path, line: header[:line_number]
      )
    end

    suggested_years = (first_year == last_year) ? current_year : "#{first_year}-#{current_year}"
    suggested_years = years if problems.none? { |rule, _| rule == :check_year }
    suggested_holder = config[:expected_holder] || holder
    suggested = "#{named_capture(match, "prefix")} #{suggested_years} #{suggested_holder}"
    fence = mr_context? ? githost.suggestion_fence : "suggestion"
    markdown(
      "```#{fence}\n#{suggested}\n```",
      file: path, line: header[:line_number]
    )
  end

  def named_capture(match, name)
    match.names.include?(name) ? match[name] : nil
  end

  public
end
