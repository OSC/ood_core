# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- Fixed crash when libdrmaa is used to query for a job no longer in the queue

## [0.7.0] - 2018-12-26
### Added
- Addition of an optional live system test of a configurable job adapter

### Fixed
- Fix Torque adapter crash by fixing scope resolution on Attrl and Attropl
- Fix SGE adapter crash in `OodCore::Job::Adapters::Sge::Batch#get_info_enqueued_job` when libdrmma is not available (DRMMA constant not defined)

### Changed
- Always set `SGE_ROOT` env var, for both SGE commands via popen and when using libdrmaa
- Use libdrmaa only when libdrmaa is set in the cluster config


## [0.6.0] - 2018-12-19
### Added
- Added ability to override the default password length
- Merge the pbs-ruby gem removing that as a dependency, but adding FFI
- Added support for overriding resource manager client executables using `bin_overrides` in the cluster configs
- Add support for the Grid Engine resource manager (tested on GE 6.2u5 and UGE 8.0.1)

### Fixed
- Fixed a bug in password creation where certain locales resulted in invalid passwords [#91](https://github.com/OSC/ood_core/issues/91)

## [0.5.1] - 2018-05-14
### Fixed
- Fixed mistyped `random_number` call in VNC template.
  [#88](https://github.com/OSC/ood_core/pull/88)
  ([@travigd](https://github.com/travigd))

## [0.5.0] - 2018-04-30
### Added
- Added missing "Waiting" state to the Torque adapter as `:queued_held`.

### Changed
- Changed the "Waiting" state in the PBSPro adapter to `:queued_held`.

## [0.4.0] - 2018-04-20
### Changed
- Updated Torque adapter to take into account the new `Script#native` format
  allowing for arrays. [#65](https://github.com/OSC/ood_core/issues/65)

## [0.3.0] - 2018-04-05
### Added
- Basic multi-cluster support for LSF by specifying name of cluster for -m
  argument. [#24](https://github.com/OSC/ood_core/issues/24)
- Added `OodCore::Job::Script#shell_path` as an option to all adapters.
  [#82](https://github.com/OSC/ood_core/issues/82)
- Added `header` and `footer` options to a Batch Connect template.
  [#64](https://github.com/OSC/ood_core/issues/64)

### Fixed
- Replaced `Fixnum` code comments with `Integer`.
  [#67](https://github.com/OSC/ood_core/issues/67)

## [0.2.1] - 2018-01-26
### Changed
- Updated the date in the `LICENSE.txt` file.

### Fixed
- Fixed bug where LSF adapter would sometimes return `nil` when getting job
  info. [#75](https://github.com/OSC/ood_core/issues/75)
- Fixed list of allocated nodes for LSF adapter when single node is expanded
  for each core. [#71](https://github.com/OSC/ood_core/issues/71)
- Clean up children processes in forked Batch Connect main script before
  cleaning up batch script. [#69](https://github.com/OSC/ood_core/issues/69)
- Fix bug when detecting open ports using the bash helpers in the Batch Connect
  template. [#70](https://github.com/OSC/ood_core/issues/70)

## [0.2.0] - 2017-10-11
### Added
- Added Batch Connect helper function to wait for port to be used.
  [#57](https://github.com/OSC/ood_core/issues/57)
- Can include Batch Connect helper functions when writing to files or running
  remote code. [#58](https://github.com/OSC/ood_core/issues/58)
- The Batch Connect helper functions are now available to use in the forked
  Batch Connect main script. [#59](https://github.com/OSC/ood_core/issues/59)
- The `host` and `port` environment variables are now available to use in the
  forked Batch Connect main script.
  [#60](https://github.com/OSC/ood_core/issues/60)

### Fixed
- Fixed a bug with the `nc` command used in the Batch Connect helper functions
  for CentOS 7. [#55](https://github.com/OSC/ood_core/issues/55)
- Fixed not correctly detecting open ports for specific ip address in Batch
  Connect helper functions. [#56](https://github.com/OSC/ood_core/issues/56)
- Fixed a bug when parsing nodes in the Slurm adapter.
  [#54](https://github.com/OSC/ood_core/issues/54)

## [0.1.1] - 2017-09-08
### Fixed
- fix crash when calling `Adapters::Lsf#info(id:)` with "invalid" id
- optimize `Adapters::Lsf#info_where_owner` by using `bjobs -u $USER` when a single user is specified

## [0.1.0] - 2017-07-17
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

[Unreleased]: https://github.com/OSC/ood_core/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/OSC/ood_core/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/OSC/ood_core/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/OSC/ood_core/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/OSC/ood_core/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/OSC/ood_core/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/OSC/ood_core/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/OSC/ood_core/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/OSC/ood_core/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/OSC/ood_core/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/OSC/ood_core/compare/v0.0.5...v0.1.0
[0.0.5]: https://github.com/OSC/ood_core/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/OSC/ood_core/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/OSC/ood_core/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/OSC/ood_core/compare/v0.0.1...v0.0.2
