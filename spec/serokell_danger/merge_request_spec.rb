# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require_relative "../../lib/serokell_danger/checks/merge-request"

RSpec.describe "merge-request check" do
  include_context "danger testing"

  # Unlike the other checks, check_merge_request reads
  # githost.mr_title_payload/mr_body unconditionally (mr_context? is
  # checked first, before anything else) - every example needs
  # stub_githost(:github/:gitlab, title:, body:), there's no "works fine
  # with the real unstubbed githost" fallback here.
  def make_config(**overrides)
    make_config_from_default(:merge_request_default_config, **overrides)
  end

  def set_rule_receive_expectations(rules_to_test)
    set_danger_report_expectations(
      [:title_prefix, :ticket_links],
      rules_to_test,
      keyword_params: {title_prefix: [:hint]}
    )
  end

  def simple_test(rules_to_test, title:, body: "", **config_overrides)
    %i[github gitlab].each do |githost|
      stub_githost(githost, title: title, body: body)
      config = make_config(**config_overrides)
      set_rule_receive_expectations(rules_to_test)
      yield if block_given?
      dangerfile.check_merge_request(config)
    end
  end

  # --- title_prefix ---

  it "warns about a title missing an issue prefix" do
    simple_test({title_prefix: {}}, title: "No issue prefix")
  end

  it "does not warn about a title with a valid issue prefix" do
    simple_test({}, title: "[#4] Issue prefix")
  end

  # --- ticket_links ---

  it "reports ticket links mentioned in the title" do
    simple_test({ticket_links: {}}, title: "[SRK-160] Issue prefix")
  end

  it "reports ticket links mentioned in the body" do
    simple_test({ticket_links: {}}, title: "[#4] Issue prefix", body: "Fixes SRK-160")
  end

  it "does not scan the body for ticket links when ticket_links.scan does not include :body" do
    simple_test(
      {},
      title: "[#4] Issue prefix",
      body: "Fixes SRK-160",
      ticket_links: SerokellDanger::Config.new(
        "ticket-links",
        {
          scan: %i[title],
          pattern: /\b[A-Z][A-Z0-9]*-\d+\b/,
          base_url: "https://issues.serokell.io/issue/",
          tracker_name: "YouTrack"
        }
      )
    )
  end

  it "does not report the same ticket link twice" do
    simple_test(
      {ticket_links: {text: "Mentioned YouTrack tickets: [SRK-160](https://issues.serokell.io/issue/SRK-160)."}},
      title: "[SRK-160] Issue prefix",
      body: "Fixes SRK-160"
    )
  end

  it "does nothing when ticket_links is nil" do
    simple_test(
      {},
      title: "[SRK-160] Issue prefix",
      body: "Fixes SRK-160",
      ticket_links: nil
    )
  end

  it "raises for an invalid ticket_links.scan value" do
    config = make_config(
      ticket_links: SerokellDanger::Config.new(
        "ticket-links",
        {
          scan: %i[this_item_does_not_exist],
          pattern: /\b[A-Z][A-Z0-9]*-\d+\b/,
          base_url: "https://issues.serokell.io/issue/",
          tracker_name: "YouTrack"
        }
      )
    )

    stub_githost(:github, title: "[#4] Dummy")
    expect { dangerfile.check_merge_request(config) }.to raise_error(
      ArgumentError,
      "`ticket_links.scan` expects :title and/or :body, got :this_item_does_not_exist."
    )
  end

  # --- context/skip ---

  it "does nothing outside of an MR/PR context" do
    allow(dangerfile).to receive(:githost).and_return(nil)
    config = make_config
    set_rule_receive_expectations({})
    dangerfile.check_merge_request(config)
  end

  it "does not run if the title matches a pattern" do
    simple_test(
      {},
      title: "Merge branch 'foo' into 'main'",
      skip_if_title_matches: dangerfile.default_branch_merge_title_patterns
    )
  end
end
