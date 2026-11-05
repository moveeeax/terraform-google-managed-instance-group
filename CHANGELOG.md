# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- CI: bump actions to their current majors, pin tool versions, and restrict the
  workflow token to `contents: read`.
- Example: set `load_balancing_scheme = "EXTERNAL"` on the backend service so
  the google 8.x default change (`EXTERNAL_MANAGED`) does not alter it.
- Docs: pin the README usage `source` to a release tag; fix the LICENSE year.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit). The tag sits on top of
three Dependabot CI bumps that are not on `main`; the module code is the same
as `5056d76`.

[Unreleased]: https://github.com/moveeeax/terraform-google-managed-instance-group/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/moveeeax/terraform-google-managed-instance-group/releases/tag/v1.0.0
