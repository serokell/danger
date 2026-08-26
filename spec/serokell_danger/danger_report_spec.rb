# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

RSpec.describe "danger_report" do
  include_context "danger testing"

  def make_config(**overrides)
    SerokellDanger::Config.new(
      "test-check",
      {severity: :warn}.merge(overrides),
      configure_with: "check_test"
    )
  end

  # method is the underlying report call danger_report is expected to make
  # (:fail/:warn/:message/:markdown), or nil to expect none of them to fire.
  # receive_kwargs are the keyword arguments expected on that call.
  # report_kwargs are passed through to danger_report itself.
  def simple_test(method, expected_text = anything, receive_kwargs: {},
    report_kwargs: {}, **config_overrides)
    config = make_config(**config_overrides)
    if method.nil?
      %i[fail warn message markdown].each { |m| expect(dangerfile).not_to receive(m) }
    else
      expect(dangerfile).to receive(method).with(expected_text, **receive_kwargs)
    end
    dangerfile.danger_report(config, :rule, "Some text", **report_kwargs)
  end

  it "does nothing when severity resolves to :off" do
    simple_test(nil, severity: :off)
  end

  it "reports via fail with a disable hint for :fail severity" do
    simple_test(
      :fail,
      "[test-check/rule] Some text (To disable this rule: `rule: nil` in `check_test`.)",
      severity: :fail
    )
  end

  it "reports via warn with a disable hint for :warn severity" do
    simple_test(
      :warn,
      "[test-check/rule] Some text (To disable this rule: `rule: nil` in `check_test`.)",
      severity: :warn
    )
  end

  it "reports via message with no disable hint for :message severity" do
    simple_test(:message, "[test-check/rule] Some text", severity: :message)
  end

  it "reports via markdown with no disable hint for :markdown severity" do
    simple_test(:markdown, "[test-check/rule] Some text", severity: :markdown)
  end

  it "uses a custom hint instead of the default one when given" do
    simple_test(
      :warn,
      "[test-check/rule] Some text (To disable this rule: `custom: false` in `check_test`.)",
      report_kwargs: {hint: "custom: false"},
      severity: :warn
    )
  end

  it "omits the 'in `configure_with`' clause when the config has no configure_with" do
    config = SerokellDanger::Config.new("test-check", {severity: :warn})
    expect(dangerfile).to receive(:warn).with(
      "[test-check/rule] Some text (To disable this rule: `rule: nil`.)"
    )
    dangerfile.danger_report(config, :rule, "Some text")
  end

  it "passes extra keyword arguments through to the underlying report call" do
    simple_test(
      :warn,
      receive_kwargs: {file: "foo.rb", line: 3},
      report_kwargs: {file: "foo.rb", line: 3},
      severity: :warn
    )
  end

  it "lets an explicit severity: override win over the config" do
    simple_test(:fail, report_kwargs: {severity: :fail}, severity: :off)
  end

  it "raises for an unknown severity" do
    config = make_config(severity: :bogus)
    expect { dangerfile.danger_report(config, :rule, "Some text") }.to raise_error(
      ArgumentError,
      "Unknown severity `:bogus` for `test-check/rule`. " \
      "Expected one of: :fail, :warn, :message, :off."
    )
  end
end
