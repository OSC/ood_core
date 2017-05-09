## Unreleased

Features:

  - removed `OodCore::Job::Script#join_files` due to lack of support in
    resource managers
  - by default all PBS jobs output stdout & stderr to output path unless an
    error path is specified (mimics behavior of Slurm and LSF)

## 0.0.3 (2017-04-28)

Features:

  - provide support for slurm conf file

Bugfixes:

  - correct code documentation for `Script#min_phys_memory`
  - fix for login feature being allowed on all clusters even if not defined

## 0.0.2 (2017-04-27)

Features:

  - removed the `OodCore::Job::NodeRequest` object

## 0.0.1 (2017-04-17)

Initial release!
