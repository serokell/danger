# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require "serokell_danger"

RSpec.describe Git::Object::Commit do
  # Builds a real Commit, entirely offline: passing `init` eagerly (see
  # Git::Object::Commit#initialize/#from_data in the git gem) sets @tree,
  # so #check_commit's lazy-fetch guard never triggers and no real
  # repository is ever touched.
  def make_commit(message, sha: "deadbeef" * 5, parent_count: 0)
    data = {
      "sha" => sha,
      "committer" => "Test <test@example.com> 1700000000 +0000",
      "author" => "Test <test@example.com> 1700000000 +0000",
      "tree" => "a" * 40,
      "parent" => Array.new(parent_count) { |i| "p#{i}" * 10 },
      "message" => message
    }
    described_class.new(nil, sha, data)
  end

  describe "#subject" do
    it "is the first line of the message, without the trailing newline" do
      commit = make_commit("Fix the bug\n\nProblem: it broke.")
      expect(commit.subject).to eq("Fix the bug")
    end

    it "is the whole message when there is no description" do
      commit = make_commit("Only a subject")
      expect(commit.subject).to eq("Only a subject")
    end
  end

  describe "#subject_ticked" do
    it "wraps the subject in backticks" do
      commit = make_commit("Fix the bug")
      expect(commit.subject_ticked).to eq("`Fix the bug`")
    end

    it "replaces literal backticks in the subject with single quotes" do
      commit = make_commit("Add `foo` helper")
      expect(commit.subject_ticked).to eq("`Add 'foo' helper`")
    end
  end

  describe "#description" do
    it "is everything after the subject and the blank line following it" do
      commit = make_commit("Subject\n\nProblem: X.\n\nSolution: Y.")
      expect(commit.description).to eq("Problem: X.\n\nSolution: Y.")
    end

    it "drops every leading blank line, not just one" do
      commit = make_commit("Subject\n\n\n\nBody after extra blanks")
      expect(commit.description).to eq("Body after extra blanks")
    end

    it "keeps the second line as-is when it is not blank" do
      commit = make_commit("Subject\nDirectly attached body")
      expect(commit.description).to eq("Directly attached body")
    end

    it "is empty when the message has no second line at all" do
      commit = make_commit("Only a subject")
      expect(commit.description).to eq("")
    end
  end

  describe "#blank_line_after_subject?" do
    it "is true when the subject is followed by a blank line" do
      commit = make_commit("Subject\n\nBody")
      expect(commit.blank_line_after_subject?).to be true
    end

    it "is false when the body is directly attached to the subject" do
      commit = make_commit("Subject\nBody")
      expect(commit.blank_line_after_subject?).to be false
    end

    it "is false when there is no second line at all" do
      commit = make_commit("Only a subject")
      expect(commit.blank_line_after_subject?).to be false
    end
  end

  describe "#subject_matches?" do
    it "is true when the subject matches one of the given patterns" do
      commit = make_commit("wip: still in progress")
      expect(commit.subject_matches?([/\bwip\b/i])).to be true
    end

    it "is false when the subject matches none of the given patterns" do
      commit = make_commit("Fix the bug")
      expect(commit.subject_matches?([/\bwip\b/i])).to be false
    end
  end

  describe "#short_ref" do
    it "is the first 8 characters of the SHA" do
      commit = make_commit("Subject", sha: "0123456789abcdef")
      expect(commit.short_ref).to eq("01234567")
    end
  end
end
