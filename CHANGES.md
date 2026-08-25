<!--
   - SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
   -
   - SPDX-License-Identifier: CC0-1.0
   -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- `check_merge_request` no longer calls the GitHub-only `mr_title`/`mr_body`
  methods against a GitHub PR, which raised instead of reading the PR's
  title/body (#6).
- Fixed a typo in `check_merge_request`'s `ticket_links.scan` error message
  ("expecs" → "expects") (#6).
