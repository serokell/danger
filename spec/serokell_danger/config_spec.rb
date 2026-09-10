# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

RSpec.describe SerokellDanger::Config do
  let(:config) do
    described_class.new("example-check", {severity: :warn, max_length: 80})
  end

  describe "#[]" do
    it "returns the configured value for a known key" do
      expect(config[:severity]).to eq(:warn)
    end

    it "accepts a string key, same as the symbol" do
      expect(config["severity"]).to eq(:warn)
    end

    it "raises ArgumentError for an unknown key" do
      expect { config[:does_not_exist] }.to raise_error(ArgumentError, /Unknown option/)
    end
  end

  describe "method_missing dot-access" do
    it "resolves a known key the same way [] does" do
      expect(config.severity).to eq(:warn)
    end

    it "still raises NoMethodError for something that isn't a key at all" do
      expect { config.not_a_real_method }.to raise_error(NoMethodError)
    end
  end

  describe "#merge (aliased as #with)" do
    it "returns a new Config with the override applied" do
      overridden = config.merge(severity: :error)
      expect(overridden[:severity]).to eq(:error)
    end

    it "does not mutate the original config" do
      config.merge(severity: :error)
      expect(config[:severity]).to eq(:warn)
    end

    it "leaves keys it doesn't override untouched" do
      overridden = config.with(severity: :error)
      expect(overridden[:max_length]).to eq(80)
    end

    it "raises ArgumentError when overriding an unknown key" do
      expect { config.merge(unknown_key: 1) }.to raise_error(ArgumentError, /Unknown option/)
    end
  end

  describe "#to_h" do
    it "returns a plain hash of the configured values" do
      expect(config.to_h).to eq({severity: :warn, max_length: 80})
    end
  end
end
