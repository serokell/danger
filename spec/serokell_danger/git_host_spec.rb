# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require "serokell_danger"

RSpec.describe SerokellDanger::GitHost do
  describe ".detect" do
    it "wraps dangerfile.github when it is present" do
      dangerfile = double("dangerfile", github: double("gh"), gitlab: nil)
      expect(described_class.detect(dangerfile).host).to eq(:github)
    end

    it "wraps dangerfile.gitlab when github is absent" do
      dangerfile = double("dangerfile", github: nil, gitlab: double("gl"))
      expect(described_class.detect(dangerfile).host).to eq(:gitlab)
    end

    it "is nil when neither github nor gitlab is present" do
      dangerfile = double("dangerfile", github: nil, gitlab: nil)
      expect(described_class.detect(dangerfile)).to be_nil
    end
  end

  describe "#github?/#gitlab?" do
    it "is true for the host it was built with" do
      github = described_class.new(double("plugin"), :github)
      gitlab = described_class.new(double("plugin"), :gitlab)
      expect(github.github?).to be true
      expect(github.gitlab?).to be false
      expect(gitlab.gitlab?).to be true
      expect(gitlab.github?).to be false
    end
  end

  describe "#mr_title / #pr_title" do
    it "delegates to plugin.pr_title on GitHub" do
      plugin = double("plugin", pr_title: "My PR")
      host = described_class.new(plugin, :github)
      expect(host.mr_title).to eq("My PR")
      expect(host.pr_title).to eq("My PR")
    end

    it "delegates to plugin.mr_title on GitLab" do
      plugin = double("plugin", mr_title: "My MR")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_title).to eq("My MR")
      expect(host.pr_title).to eq("My MR")
    end
  end

  describe "#mr_body / #pr_body" do
    it "delegates to plugin.pr_body on GitHub" do
      plugin = double("plugin", pr_body: "Body text")
      host = described_class.new(plugin, :github)
      expect(host.mr_body).to eq("Body text")
      expect(host.pr_body).to eq("Body text")
    end

    it "delegates to plugin.mr_body on GitLab" do
      plugin = double("plugin", mr_body: "Body text")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_body).to eq("Body text")
      expect(host.pr_body).to eq("Body text")
    end
  end

  describe "#branch_for_head / #source_branch" do
    it "delegates to plugin.branch_for_head regardless of host" do
      plugin = double("plugin", branch_for_head: "feature-branch")
      host = described_class.new(plugin, :github)
      expect(host.branch_for_head).to eq("feature-branch")
      expect(host.source_branch).to eq("feature-branch")
    end
  end

  describe "#branch_for_base / #target_branch" do
    it "delegates to plugin.branch_for_base regardless of host" do
      plugin = double("plugin", branch_for_base: "master")
      host = described_class.new(plugin, :gitlab)
      expect(host.branch_for_base).to eq("master")
      expect(host.target_branch).to eq("master")
    end
  end

  describe "#mr_iid / #pr_iid" do
    it "reads iid from the JSON payload on GitLab" do
      plugin = double("plugin", mr_json: {"iid" => 7})
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_iid).to eq(7)
      expect(host.pr_iid).to eq(7)
    end

    it "reads number from the JSON payload on GitHub" do
      plugin = double("plugin", pr_json: {"number" => 42})
      host = described_class.new(plugin, :github)
      expect(host.mr_iid).to eq(42)
      expect(host.pr_iid).to eq(42)
    end

    it "is nil when the JSON payload can't be read" do
      plugin = double("plugin")
      allow(plugin).to receive(:mr_json).and_raise("boom")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_iid).to be_nil
    end
  end

  describe "#mr_url / #pr_url" do
    it "reads web_url from the JSON payload on GitLab" do
      plugin = double("plugin", mr_json: {"web_url" => "https://x/1"})
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_url).to eq("https://x/1")
      expect(host.pr_url).to eq("https://x/1")
    end

    it "reads html_url from the JSON payload on GitHub" do
      plugin = double("plugin", pr_json: {"html_url" => "https://x/2"})
      host = described_class.new(plugin, :github)
      expect(host.mr_url).to eq("https://x/2")
      expect(host.pr_url).to eq("https://x/2")
    end
  end

  describe "#mr_draft? / #pr_draft?" do
    it "delegates to plugin.pr_draft? on GitHub when it responds to it" do
      plugin = double("plugin", pr_draft?: true)
      host = described_class.new(plugin, :github)
      expect(host.mr_draft?).to be true
      expect(host.pr_draft?).to be true
    end

    it "is true when the JSON payload's work_in_progress is truthy" do
      plugin = double(
        "plugin", mr_json: {"work_in_progress" => true}, mr_title: "Title"
      )
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_draft?).to be true
    end

    it "is true when the title matches the draft title pattern" do
      plugin = double("plugin", mr_json: {}, mr_title: "WIP: something")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_draft?).to be true
    end

    it "is false otherwise" do
      plugin = double("plugin", mr_json: {}, mr_title: "Normal title")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_draft?).to be false
      expect(host.pr_draft?).to be false
    end
  end

  describe "#mr_title_payload / #pr_title_payload" do
    it "strips a [Draft] prefix from the title" do
      plugin = double("plugin", mr_title: "[Draft] Add feature")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_title_payload).to eq("Add feature")
    end

    it "strips a WIP: prefix from the title" do
      plugin = double("plugin", mr_title: "WIP: Add feature")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_title_payload).to eq("Add feature")
    end

    it "leaves a non-draft title unchanged" do
      plugin = double("plugin", mr_title: "Add feature")
      host = described_class.new(plugin, :gitlab)
      expect(host.mr_title_payload).to eq("Add feature")
      expect(host.pr_title_payload).to eq("Add feature")
    end
  end

  describe "#suggestion_fence" do
    it "uses GitLab's suggestion:-above+below syntax on GitLab" do
      host = described_class.new(double("plugin"), :gitlab)
      expect(host.suggestion_fence(above: 1, below: 2)).to eq("suggestion:-1+2")
    end

    it "uses plain 'suggestion' on GitHub with no offsets" do
      host = described_class.new(double("plugin"), :github)
      expect(host.suggestion_fence).to eq("suggestion")
    end

    it "uses 'diff' on GitHub when there are offsets" do
      host = described_class.new(double("plugin"), :github)
      expect(host.suggestion_fence(above: 1)).to eq("diff")
    end
  end

  describe "#method_missing / #respond_to_missing?" do
    it "delegates unknown methods to the plugin" do
      plugin = double("plugin", custom_method: "hello")
      host = described_class.new(plugin, :github)
      expect(host.custom_method).to eq("hello")
    end

    it "reports responding to methods the plugin responds to" do
      plugin = double("plugin", custom_method: "hello")
      host = described_class.new(plugin, :github)
      expect(host.respond_to?(:custom_method)).to be true
    end

    it "raises for methods neither GitHost nor the plugin define" do
      host = described_class.new(double("plugin"), :github)
      expect { host.totally_unknown_method }.to raise_error(NoMethodError)
    end
  end
end
