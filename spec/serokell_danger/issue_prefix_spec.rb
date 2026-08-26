# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require "serokell_danger"

RSpec.describe SerokellDanger do
  describe ".valid_issue_prefix?" do
    def valid?(text, config)
      described_class.valid_issue_prefix?(text, config)
    end

    it "recognizes a github/gitlab-style issue prefix" do
      expect(valid?("[#4] Fix bug", {kinds: [:github_issue]})).to be true
    end

    it "recognizes a youtrack-style issue prefix" do
      config = {kinds: [:youtrack_issue]}
      expect(valid?("[SRK-160] Fix bug", config)).to be true
    end

    it "recognizes a youtrack-style issue prefix whose project key starts with a digit" do
      config = {kinds: [:youtrack_issue]}
      expect(valid?("[1AB-123] Fix bug", config)).to be true
      expect(valid?("[42XY-456] Fix bug", config)).to be true
    end

    it "recognizes a chore prefix" do
      expect(valid?("[Chore] Cleanup", {kinds: [:chore]})).to be true
    end

    it "rejects text with no recognized prefix" do
      expect(valid?("No prefix here", {kinds: [:github_issue]})).to be false
    end

    it "recognizes a custom extra_patterns prefix" do
      config = {kinds: [], extra_patterns: [/XYZ-\d+/]}
      expect(valid?("XYZ-1 Fix bug", config)).to be true
    end

    it "allows stacked prefixes with no separator when allow_multiple is true" do
      config = {kinds: %i[github_issue chore], allow_multiple: true}
      expect(valid?("[#4][Chore] Fix bug", config)).to be true
    end

    it "rejects stacked prefixes with no separator when allow_multiple is false" do
      config = {kinds: %i[github_issue chore], allow_multiple: false}
      expect(valid?("[#4][Chore] Fix bug", config)).to be false
    end
  end

  describe ".issue_prefix_pattern" do
    it "builds a pattern that matches a configured prefix" do
      config = {kinds: [:github_issue]}
      pattern = described_class.issue_prefix_pattern(config)
      expect(pattern).to match("[#4] Fix bug")
      expect(pattern).not_to match("No prefix here")
    end

    it "raises for an unknown kind" do
      config = {kinds: [:bogus]}
      expect { described_class.issue_prefix_pattern(config) }.to raise_error(
        ArgumentError, /Unknown issue prefix kind `:bogus`/
      )
    end

    it "raises when no kinds or extra_patterns are configured" do
      config = {kinds: [], extra_patterns: []}
      expect { described_class.issue_prefix_pattern(config) }.to raise_error(
        ArgumentError, "No issue prefix kinds configured."
      )
    end
  end

  describe ".issue_prefix_separator" do
    it "returns the whitespace between the prefix and the rest of the text" do
      config = {kinds: [:github_issue]}
      separator = described_class.issue_prefix_separator("[#4] Fix bug", config)
      expect(separator).to eq(" ")
    end

    it "returns an empty string when there is no separator" do
      config = {kinds: [:github_issue]}
      separator = described_class.issue_prefix_separator("[#4]Fix bug", config)
      expect(separator).to eq("")
    end

    it "returns nil when the text has no recognized prefix" do
      config = {kinds: [:github_issue]}
      separator = described_class.issue_prefix_separator("No prefix", config)
      expect(separator).to be_nil
    end
  end

  describe ".strip_issue_prefix" do
    it "removes the prefix and separator, leaving the rest of the text" do
      config = {kinds: [:github_issue]}
      stripped = described_class.strip_issue_prefix("[#4] Fix bug", config)
      expect(stripped).to eq("Fix bug")
    end

    it "leaves the text unchanged when there is no recognized prefix" do
      config = {kinds: [:github_issue]}
      stripped = described_class.strip_issue_prefix("Fix bug", config)
      expect(stripped).to eq("Fix bug")
    end
  end

  describe ".issue_prefix_examples" do
    it "formats an example for each configured kind" do
      config = {kinds: %i[github_issue chore]}
      examples = described_class.issue_prefix_examples(config)
      expect(examples).to eq("`[#123]`, `[Chore]`")
    end

    it "includes extra_patterns as examples too" do
      config = {kinds: [], extra_patterns: [/XYZ-\d+/]}
      examples = described_class.issue_prefix_examples(config)
      expect(examples).to eq("`XYZ-\\d+`")
    end
  end
end
