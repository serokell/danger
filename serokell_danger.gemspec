# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require_relative "lib/serokell_danger/version"

Gem::Specification.new do |spec|
  spec.name = "serokell_danger"
  spec.version = SerokellDanger::VERSION
  spec.authors = ["Serokell"]
  spec.email = ["hi@serokell.io"]

  spec.summary = "Serokell's GitHub/GitLab-agnostic Danger checks"
  spec.homepage = "https://github.com/serokell/danger"
  spec.license = "MPL-2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*.rb", "LICENSE", "LICENSES/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "danger", ">= 9.0"
end
