# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.17.6] - 8-24-2021

### Added

- kubernetes now allows for arbitrary labels to be set in [317](https://github.com/OSC/ood_core/pull/317).
- kubernetes now allows for limits and requests to be different in [318](https://github.com/OSC/ood_core/pull/318).

## [0.17.5] - 8-20-2021

### Fixed

- kubernetes jobs delete without waiting in [314](https://github.com/OSC/ood_core/pull/314).

## [0.17.4] - 7-29-2021

Functionally the same as [0.17.3] but with some CI updates.

## [0.17.3] - 7-29-2021

### Fixed

- Fixed handling of pods in a startup phase in [303](https://github.com/OSC/ood_core/pull/303).

### Added

- Enable automatic population of supplemental groups in [305](https://github.com/OSC/ood_core/pull/305).

## [0.17.2] - 7-14-2021

### Fixed

- Fixed k8s adapter to only show Running pods as running in [300](https://github.com/OSC/ood_core/pull/300).

## [0.17.1] - 6-14-2021

### Fixed

- Fixed [278](https://github.com/OSC/ood_core/pull/278) where unschedulable pods will now show up as
  queued_held status.

### Changed

- KUBECONFIG now defaults to /dev/null in the kubernetes adapter in [292](https://github.com/OSC/ood_core/pull/292).

### Added

- Sites can now set `batch_connect.ssh_allow` on the cluster to disable the buttons to start
  a shell session to compute nodes in [289](https://github.com/OSC/ood_core/pull/289).
- `POD_PORT` is now available to jobs in the kubernetes adapter in [290](https://github.com/OSC/ood_core/pull/290).
- Kubernetes pods now support a startProbe in [291](https://github.com/OSC/ood_core/pull/291).

## [0.17.0] - 5-26-2021

### Fixed

- All Kubernetes resources now have the same labels in [280](https://github.com/OSC/ood_core/pull/280).
- Kubernetes does not crash when no configmap is defined in [282](https://github.com/OSC/ood_core/pull/282).
- Kubernetes will not specify init containers if there are none in
  [284](https://github.com/OSC/ood_core/pull/284).

### Added

- Kubernetes, Slurm and Torque now support the script option `gpus_per_node` in
  [266](https://github.com/OSC/ood_core/pull/266).
- Kubernetes will now save the pod.yml into the staged root in
  [277](https://github.com/OSC/ood_core/pull/277).
- Kubernetes now allows for node selector in [264](https://github.com/OSC/ood_core/pull/264).
- Kubernetes pods now have access the environment variable POD_NAMESPACE in
  [275](https://github.com/OSC/ood_core/pull/275).
- Kubernetes pods can now specify the image pull policy in [272](https://github.com/OSC/ood_core/pull/272).
- Cluster config's batch_connect now support `ssh_allow` to disable sshing to compute
  nodes per cluster in [286](https://github.com/OSC/ood_core/pull/286).
- Kubernetes will now add the templated script content to a configmap in
  [273](https://github.com/OSC/ood_core/pull/273).

### Changed

- Kubernetes username prefix no longer appends a - in [271](https://github.com/OSC/ood_core/pull/271).



## [0.16.1] - 2021-04-23
### Fixed
- memorized some allow? variables to have better support around ACLS in
  [267](https://github.com/OSC/ood_core/pull/267)

## [0.16.0] - 2021-04-20
### Fixed
- tmux 2.7+ bug in the linux host adapter in [2.5.8](https://github.com/OSC/ood_core/pull/258)
  and [259](https://github.com/OSC/ood_core/pull/259).

### Changed

- Changed how k8s configmaps in are defined in [251](https://github.com/OSC/ood_core/pull/251).
  The data structure now expects a key called files which is an array of objects that hold
  filename, data, mount_path, sub_path and init_mount_path.
  [255](https://github.com/OSC/ood_core/pull/255) also relates to this interface change.

### Added

- The k8s adapter can now specify environment variables and creates defaults 
  in [252](https://github.com/OSC/ood_core/pull/252).
- The k8s adapter can now specify image pull secrets in [253](https://github.com/OSC/ood_core/pull/253).

## [0.15.1] - 2021-02-25
### Fixed
- kubernetes adapter uses the full module for helpers in [245](https://github.com/OSC/ood_core/pull/245).

### Changed
- kubernetes pods spawn with runAsNonRoot set to true in [247](https://github.com/OSC/ood_core/pull/247).
- kubernetes pods can spawn with supplemental groups along with some other in security defaults in
  [246](https://github.com/OSC/ood_core/pull/246).

## [0.15.0] - 2021-01-26
### Fixed
- ccq adapter now accepts job names with spaces in [210](https://github.com/OSC/ood_core/pull/209)
- k8s correctly handles having no mount volumes in [239](https://github.com/OSC/ood_core/pull/239)

### Added
- k8s adapter now applies account metadata to resources in [216](https://github.com/OSC/ood_core/pull/216) and
  [231](https://github.com/OSC/ood_core/pull/231)
- k8s adapter can now prefix namespaces in [218](https://github.com/OSC/ood_core/pull/218)
- k8s adapter now applies time limits to pods in [224](https://github.com/OSC/ood_core/pull/224)

### Changed
- testing automation is now done in github actions in [221](https://github.com/OSC/ood_core/pull/218)
- update bunlder to 2.1.4 and ruby to 2.7 in [235](https://github.com/OSC/ood_core/pull/218) updated bundler and ruby
- k8s adapter more appropriately labels unschedulable pods as queued in [230](https://github.com/OSC/ood_core/pull/230)
- k8s adapter now uses the script#ood_connection_info API instead of script#native in
  [222](https://github.com/OSC/ood_core/pull/222)

## [0.14.0] - 2020-10-01
### Added 
- Kubernetes adapter in PR [156](https://github.com/OSC/ood_core/pull/156)

### Fixed
- Catch Slurm times. [209](https://github.com/OSC/ood_core/pull/209)
- LHA race condition in deleteing tmp files. [212](https://github.com/OSC/ood_core/pull/212)

## [0.13.0] - 2020-08-10
### Added
- CloudyCluster CCQ Adapter

## [0.12.0] - 2020-08-05
### Added
- qos option to Slurm and Torque [#205](https://github.com/OSC/ood_core/pull/205)
- native hash returned in qstat for SGE adapter [#198](https://github.com/OSC/ood_core/pull/198)
- option for specifying `submit_host` to submit jobs via ssh on other host [#204](https://github.com/OSC/ood_core/pull/204)

### Fixed
- SGE handle milliseconds instead of seconds when milliseconds used [#206](https://github.com/OSC/ood_core/issues/206)
- Torque's native "hash" for job submission now handles env vars values with spaces [#202](https://github.com/OSC/ood_core/pull/202)

## [0.11.4] - 2020-05-27
### Fixed
- Environment exports in SLURM while implementing [#158](https://github.com/OSC/ood_core/issues/158)
  and [#109](https://github.com/OSC/ood_core/issues/109) in [#163](https://github.com/OSC/ood_core/pull/163)

## [0.11.3] - 2020-05-11
### Fixed
- LinuxhHost Adapter to work with any login shell ([#188](https://github.com/OSC/ood_core/pull/188))
- LinuxhHost Adapter needs to display long lines in pstree to successfully parse
  output ([#188](https://github.com/OSC/ood_core/pull/188))

## [0.11.2] - 2020-04-23
### Fixed
- fix signature of `LinuxHost#info_where_owner`

## [0.11.1] - 2020-03-18
### Changed
- Only the version changed. Had to republish to rubygems.org

## [0.11.0] - 2020-03-18
### Added
- Added directive prefixes to each adapter (e.g. `#QSUB`) ([#161](https://github.com/OSC/ood_core/issues/161))
- LHA supports `submit_host` field in native ([#164](https://github.com/OSC/ood_core/issues/164))
- Cluster files can be yaml or yml extensions ([#171](https://github.com/OSC/ood_core/issues/171))
- Users can add a flag `OOD_JOB_NAME_ILLEGAL_CHARS` to sanitize job names ([#183](https://github.com/OSC/ood_core/issues/183)

### Changed
- Simplified job array parsing ([#144](https://github.com/OSC/ood_core/issues/144))

### Fixed
- Issue where environment variables were not properly exported to the job ([#158](https://github.com/OSC/ood_core/issues/158))
- Parsing bad cluster files ([#150](https://github.com/OSC/ood_core/issues/150) and [#178](https://github.com/OSC/ood_core/issues/178))
- netcat is no longer a hard dependency. Now lsof, python and bash can be used ([153](https://github.com/OSC/ood_core/issues/153))
- GE crash when nil config file was given ([#175](https://github.com/OSC/ood_core/issues/175))
- GE sometimes reported incorrect core count ([#168](https://github.com/OSC/ood_core/issues/168))


## [0.10.0] - 2019-11-05
### Added
- Added an adapter for submitting work on Linux hosted systems without using a scheduler

### Fixed
- Fixed bug where an unreadable cluster config would cause crashes

## [0.9.3] - 2019-05-08
### Fixed
- Fixed bug relating to cluster comparison

## [0.9.2] - 2019-05-08
### Changed
- When `squeue` returns '(null)' for an account the Slurm adapter will now convert that to `nil`

## [0.9.1] - 2019-05-07
### Added
- Added logic to `OodCore::Job::ArrayIds` to return an empty array when the array request is invalid

## [0.9.0] - 2019-05-04
### Added
- Job array support for LSF and PBSPro
- Slurm adapter uses `squeue` owner filter (`-u`) for `info_where_owner`

### Fixed
- Grid Engine adapter now starts scripts in the current directory like all other adapters
- Fixed issue where Slurm comment field might break job info parsing
- Fixed possible crash when comparing two clusters if the id of one of the clusters is nil
- Fixed bug with the live system test that impacted non-LSF systems
- Fixed bug with Slurm adapter when submit time is not available

## [0.8.0] - 2019-01-29
### Added
- info_all_each and info_where_owner_each super class methods
- job array support for Torque, Slurm, and SGE (currently missing from LSF and PBSPro)
- `OodCore::Job::Status#precedence` for the ability to get an overall status for a group of jobs

### Fixed
- Fix SGE adapter to specify `-u '*'` when calling qstat to get all jobs

## [0.7.1] - 2019-01-11
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

[Unreleased]: https://github.com/OSC/ood_core/compare/v0.17.6...HEAD
[0.17.6]: https://github.com/OSC/ood_core/compare/v0.17.5...v0.17.6
[0.17.5]: https://github.com/OSC/ood_core/compare/v0.17.4...v0.17.5
[0.17.4]: https://github.com/OSC/ood_core/compare/v0.17.3...v0.17.4
[0.17.3]: https://github.com/OSC/ood_core/compare/v0.17.2...v0.17.3
[0.17.2]: https://github.com/OSC/ood_core/compare/v0.17.1...v0.17.2
[0.17.1]: https://github.com/OSC/ood_core/compare/v0.17.0...v0.17.1
[0.17.0]: https://github.com/OSC/ood_core/compare/v0.16.1...v0.17.0
[0.16.1]: https://github.com/OSC/ood_core/compare/v0.16.0...v0.16.1
[0.16.0]: https://github.com/OSC/ood_core/compare/v0.15.1...v0.16.0
[0.15.1]: https://github.com/OSC/ood_core/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/OSC/ood_core/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/OSC/ood_core/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/OSC/ood_core/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/OSC/ood_core/compare/v0.11.4...v0.12.0
[0.11.4]: https://github.com/OSC/ood_core/compare/v0.11.3...v0.11.4
[0.11.3]: https://github.com/OSC/ood_core/compare/v0.11.2...v0.11.3
[0.11.2]: https://github.com/OSC/ood_core/compare/v0.11.1...v0.11.2
[0.11.1]: https://github.com/OSC/ood_core/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/OSC/ood_core/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/OSC/ood_core/compare/v0.9.3...v0.10.0
[0.9.3]: https://github.com/OSC/ood_core/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/OSC/ood_core/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/OSC/ood_core/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/OSC/ood_core/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/OSC/ood_core/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/OSC/ood_core/compare/v0.7.0...v0.7.1
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
