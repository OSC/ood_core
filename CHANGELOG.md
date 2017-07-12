# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Setting the host in a batch_connect batch script can now be directly
  manipulated through the `set_host` initialization parameter.
  [#42](https://github.com/OSC/ood_core/issues/42)

## [0.0.5] - 2017-07-05

### Added

- Add wallclock time limit to `OodCore::Job::Info` object.
- Add further support for the LSF adapter.
- Add a new Batch Connect template feature that builds batch scripts to launch
  web servers.
- Add support for the PBS Professional resource manager.
- Add method to filter list of batch jobs for a given owner or owners.

### Changed

- Torque adapter provides nodes/procs info if available for non-running jobs.
- Slurm adapter provides node info if available for non-running jobs.
- Changed the `CHANGELOG.md` formatting.

### Removed

- Remove deprecated tests for the Slurm adapter.

### Fixed

- Fix parsing bjobs output for LSF 9.1, which has extra SLOTS column.

## [0.0.4] - 2017-05-17

### Changed

- By default all PBS jobs output stdout & stderr to output path unless an error
  path is specified (mimics behavior of Slurm and LSF)

### Removed

- Remove `OodCore::Job::Script#min_phys_memory` due to lack of commonality
  across resource managers.
- Remove `OodCore::Job::Script#join_files` due to lack of support in resource
  managers.

## [0.0.3] - 2017-04-28

### Added

- Provide support for Slurm conf file.

### Fixed

- Correct code documentation for `Script#min_phys_memory`.
- Add fix for login feature being allowed on all clusters even if not defined.

## [0.0.2] - 2017-04-27

### Removed

- Remove the `OodCore::Job::NodeRequest` object.

## 0.0.1 - 2017-04-17

### Added

- Initial release!

[Unreleased]: https://github.com/OSC/ood_core/compare/v0.0.5...HEAD
[0.0.5]: https://github.com/OSC/ood_core/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/OSC/ood_core/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/OSC/ood_core/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/OSC/ood_core/compare/v0.0.1...v0.0.2
