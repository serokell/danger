# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require_relative "../../lib/serokell_danger/checks/license-headers"

RSpec.describe "license-headers check" do
  include_context "danger testing"

  let(:outdated_license_year) { make_fixture_path("outdated_license_year.md") }
  let(:wrong_copyright_holder) do
    make_fixture_path("wrong_copyright_holder.md")
  end
  let(:outdated_year_and_wrong_holder) do
    make_fixture_path("outdated_year_and_wrong_holder.md")
  end
  let(:no_license_header) { make_fixture_path("no_license_header.md") }
  let(:nonexistent_file) { make_fixture_path("does_not_exist.md") }

  def make_config(
    scan: :added_files, file_extensions: nil, ignore_paths: [],
    check_year: true, expected_holder: nil, skip_if_title_matches: nil
  )
    SerokellDanger::Config.new(
      "license-headers",
      {
        scan: scan,
        file_extensions: file_extensions,
        ignore_paths: ignore_paths,
        copyright_line_pattern:
          dangerfile.license_headers_default_config[:copyright_line_pattern],
        check_year: check_year,
        expected_holder: expected_holder,
        skip_if_title_matches: skip_if_title_matches,
        severity: :warn
      },
      configure_with: "check_license_headers"
    )
  end

  def set_rule_receive_expectations(rules_to_test)
    set_danger_report_expectations(
      [:check_year, :expected_holder],
      rules_to_test,
      keyword_params: [:file, :line]
    )
  end

  def simple_test(rules_to_test, added_files: [], modified_files: [],
    **config_overrides)
    config = make_config(**config_overrides)
    set_tracked_files(added_files: added_files, modified_files: modified_files)
    set_rule_receive_expectations(rules_to_test)
    yield if block_given?
    dangerfile.check_license_headers(config)
  end

  it "warns about a file with outdated license year" do
    simple_test({check_year: {}}, added_files: [outdated_license_year])
  end

  it "warns about a file with wrong copyright holder" do
    simple_test(
      {
        expected_holder: {
          text: "The copyright holder is `example <https://example.com>`, " \
            "expected `serokell <https://serokell.io>`."
        }
      },
      added_files: [wrong_copyright_holder],
      check_year: false, expected_holder: "Serokell <https://serokell.io>"
    )
  end

  it "runs with files in file_extensions" do
    simple_test(
      {check_year: {}},
      added_files: [outdated_license_year],
      file_extensions: [".md"]
    )
  end

  it "does not run with files not in file_extensions" do
    simple_test(
      {},
      added_files: [outdated_license_year],
      file_extensions: [".rb"]
    )
  end

  it "ignores files in ignore_paths" do
    simple_test(
      {},
      added_files: [outdated_license_year],
      ignore_paths: [outdated_license_year]
    )
  end

  it "scans modified files too when scan: :changed_files" do
    simple_test(
      {check_year: {}},
      modified_files: [outdated_license_year],
      scan: :changed_files
    )
  end

  it "warns about both an outdated year and a wrong holder on the same file" do
    simple_test(
      {
        check_year: {},
        expected_holder: {
          text: "The copyright holder is `example <https://example.com>`, " \
            "expected `serokell <https://serokell.io>`."
        }
      },
      added_files: [outdated_year_and_wrong_holder],
      expected_holder: "Serokell <https://serokell.io>"
    )
  end

  it "does not report a file with no license header at all" do
    simple_test({}, added_files: [no_license_header])
  end

  it "does not report a tracked file that does not exist on disk" do
    simple_test({}, added_files: [nonexistent_file])
  end

  it "raises for an invalid scan value" do
    config = make_config(scan: :invalid)

    expect { dangerfile.check_license_headers(config) }.to raise_error(
      ArgumentError, /`scan` expects/
    )
  end

  it "does not run if the title matches a pattern (GitHub)" do
    stub_githost(:github, title: "Merge branch 'foo' into 'main'")
    simple_test(
      {},
      added_files: [outdated_license_year],
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end

  it "does not run if the title matches a pattern (GitLab)" do
    stub_githost(:gitlab, title: "Merge branch 'foo' into 'main'")
    simple_test(
      {},
      added_files: [outdated_license_year],
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end
end
