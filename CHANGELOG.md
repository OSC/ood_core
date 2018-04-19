# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Added a `Batch#submit` method to submit directly with a `qsub` call.
  [#29](https://github.com/OSC/pbs-ruby/issues/29)
- Add Travis CI support.

### Changed
- Changed the `CHANGELOG.md` formatting.
- Updated date in `LICENSE.txt`.

## [2.1.0] - 2017-06-02
### Added
- Added helpful scripts to setup and launch console.
- Provide support to get status of selected jobs on batch server.

## [2.0.4] - 2017-03-28
### Fixed
- Support reservation id for submitting job with `qsub`.
- Added workaround for users who specify queue in batch script.

## [2.0.3] - 2016-11-04
### Fixed
- Better support `qsub` CLI arguments.

## [2.0.2] - 2016-08-17
### Fixed
- Fixes Ruby version requirement to 2.2.0+.

### Removed
- Removes unused prefix directory option.

## [2.0.1] - 2016-08-10
### Changed
- Batch object can be initialized with lib/bin directories.

## 2.0.0 - 2016-08-05
### Added
- Initial release of 2.0.0!

[Unreleased]: https://github.com/OSC/pbs-ruby/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/OSC/pbs-ruby/compare/v2.0.4...v2.1.0
[2.0.4]: https://github.com/OSC/pbs-ruby/compare/v2.0.3...v2.0.4
[2.0.3]: https://github.com/OSC/pbs-ruby/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/OSC/pbs-ruby/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/OSC/pbs-ruby/compare/v2.0.0...v2.0.1
