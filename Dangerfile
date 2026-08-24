# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

require "serokell_danger"

check_commits_style
check_premerge_commits
check_merge_request
check_merge_commits
check_license_headers(
  license_headers_default_config.with(ignore_paths: ["spec/fixtures/"])
)
check_trailing_whitespace(
  trailing_whitespace_default_config.with(
    ignore_paths: ["LICENSE", "LICENSES/", "spec/fixtures/"]
  )
)
