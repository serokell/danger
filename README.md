<!--
   - SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
   -
   - SPDX-License-Identifier: CC0-1.0
   -->

# serokell_danger

GitHub/GitLab-agnostic Danger checks for CI review: commit style, license headers, MR/PR conventions.

[![CI](https://github.com/serokell/danger/actions/workflows/ci.yml/badge.svg)](https://github.com/serokell/danger/actions/workflows/ci.yml)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](LICENSE)

## Table of contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Background

[Danger](https://danger.systems/ruby/) runs a `Dangerfile` against every pull
request and lets it post review comments back to GitHub or GitLab. This gem
adds a set of checks written against Danger's own primitives:

- `check_commits_style` — commit subject/description formatting.
- `check_premerge_commits` — flags fixup/squash-worthy commits before merge.
- `check_merge_request` — MR/PR title and description conventions.
- `check_merge_commits` — merge-commit hygiene on the target branch.
- `check_license_headers` — flags stale SPDX copyright years on changed files.
- `check_trailing_whitespace` — flags trailing whitespace on changed lines.

Each check is configurable per-repository, and `GitHost` (in `helpers.rb`)
gives every check the same interface over GitHub's and GitLab's otherwise
different plugin APIs, so a single `Dangerfile` works unmodified on either
host.

## Install

Published as a git source:

```ruby
# Gemfile
gem "serokell_danger", git: "https://github.com/serokell/danger"
```

## Usage

Require it and call the checks you want from your `Dangerfile`:

```ruby
# Dangerfile
require "serokell_danger"

check_commits_style
check_premerge_commits
check_merge_request
check_merge_commits
check_license_headers
check_trailing_whitespace
```

Each check accepts an optional config, built by overriding its defaults:

```ruby
check_commits_style(commits_style_default_config.with(severity: :error))
```

See each check's `*_default_config` method under `lib/serokell_danger/checks/`
for the options it accepts.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MPL-2.0](LICENSE) © Serokell

## About Serokell

serokell_danger is maintained and funded with ❤️ by [Serokell](https://serokell.io/).
The names and logo for Serokell are trademark of Serokell OÜ.

We love open source software! See [our other projects](https://serokell.io/projects?utm_source=github) or [hire us](https://serokell.io/contacts?utm_source=github) to design, develop and grow your idea!
