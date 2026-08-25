# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require "serokell_danger"

RSpec.describe SerokellDanger::Util do
  describe ".as_list" do
    it "turns nil into an empty array" do
      expect(described_class.as_list(nil)).to eq([])
    end

    it "leaves an array as is" do
      expect(described_class.as_list([1, 2])).to eq([1, 2])
    end

    it "wraps a single value in an array" do
      expect(described_class.as_list(:foo)).to eq([:foo])
    end
  end

  describe ".pattern_matches?" do
    it "matches a Regexp against the string" do
      expect(described_class.pattern_matches?("foobar", /oob/)).to be true
      expect(described_class.pattern_matches?("foobar", /xyz/)).to be false
    end

    it "checks substring inclusion for a non-Regexp pattern" do
      expect(described_class.pattern_matches?("foobar", "oob")).to be true
      expect(described_class.pattern_matches?("foobar", "xyz")).to be false
    end
  end

  describe ".matches_any?" do
    it "is true if any pattern in the list matches" do
      expect(described_class.matches_any?("foobar", [/xyz/, /oob/])).to be true
    end

    it "is false if no pattern in the list matches" do
      expect(described_class.matches_any?("foobar", [/xyz/, "abc"])).to be false
    end

    it "accepts a single pattern instead of a list" do
      expect(described_class.matches_any?("foobar", /oob/)).to be true
    end
  end

  describe ".path_selected?" do
    it "is true with no file_extensions and no ignore_paths" do
      expect(described_class.path_selected?("lib/foo.rb")).to be true
    end

    it "is false for a path matching ignore_paths (glob)" do
      expect(
        described_class.path_selected?("lib/foo.rb", ignore_paths: ["lib/*.rb"])
      ).to be false
    end

    it "is false for a path matching ignore_paths (Regexp)" do
      expect(
        described_class.path_selected?("lib/foo.rb", ignore_paths: [/\.rb\z/])
      ).to be false
    end

    it "lets ignore_paths take precedence over file_extensions" do
      expect(
        described_class.path_selected?(
          "lib/foo.rb", file_extensions: [".rb"], ignore_paths: ["lib/*.rb"]
        )
      ).to be false
    end

    it "is true when the path's extension is in file_extensions" do
      expect(
        described_class.path_selected?("lib/foo.rb", file_extensions: [".rb"])
      ).to be true
    end

    it "is false when the path's extension is not in file_extensions" do
      expect(
        described_class.path_selected?("lib/foo.rb", file_extensions: [".hs"])
      ).to be false
    end

    it "accepts file_extensions without a leading dot" do
      expect(
        described_class.path_selected?("lib/foo.rb", file_extensions: ["rb"])
      ).to be true
    end
  end

  describe ".path_ignored?" do
    it "matches a Regexp against the path" do
      expect(described_class.path_ignored?("lib/foo.rb", /\.rb\z/)).to be true
      expect(described_class.path_ignored?("lib/foo.rb", /\.hs\z/)).to be false
    end

    it "matches a glob pattern against the path" do
      expect(described_class.path_ignored?("lib/foo.rb", "lib/*.rb")).to be true
      expect(
        described_class.path_ignored?("lib/foo.rb", "spec/*.rb")
      ).to be false
    end

    it "matches a plain path prefix" do
      expect(described_class.path_ignored?("lib/foo.rb", "lib/")).to be true
      expect(described_class.path_ignored?("lib/foo.rb", "spec/")).to be false
    end
  end

  describe ".severity_for" do
    def make_config(**values)
      SerokellDanger::Config.new("test-check", values)
    end

    it "returns the override when one is given" do
      config = make_config(severity: :warn)
      severity = described_class.severity_for(config, :some_rule, :fail)
      expect(severity).to eq(:fail)
    end

    it "returns the rule's own entry in severities when present" do
      config = make_config(severity: :warn, severities: {some_rule: :fail})
      expect(described_class.severity_for(config, :some_rule)).to eq(:fail)
    end

    it "falls back to the top-level severity when severities has no entry" do
      config = make_config(severity: :message, severities: {other_rule: :fail})
      expect(described_class.severity_for(config, :some_rule)).to eq(:message)
    end

    it "falls back to :warn when neither severities nor severity is set" do
      config = make_config(some_key: "irrelevant")
      expect(described_class.severity_for(config, :some_rule)).to eq(:warn)
    end
  end
end
