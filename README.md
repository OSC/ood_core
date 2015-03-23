# PBS Ruby

## Description

Trimmed down Ruby wrapper for the Torque C Library utilizing Ruby-FFI.

## Requirements

At minimum you will need:
* Ruby 2.0
* Ruby-FFI gem
* Torque library installed on machine

## Installation

Add this to your `Gemfile`:

```
  # Gemfile

  ...

  gem 'pbs'
```

then run from command line:

```bash
  $ bundle exec ruby <example.rb>
```

## Usage

The usage follows very closely to the `pbs_python` usage documented here: https://oss.trac.surfsara.nl/pbs_python/wiki/TorqueUsage

Not all PBS functions are replicated in this project. The administrative functions have been neglected.

Most useful features are described in the `examples/simplejob.rb` provided. To run this simple example, type:

```bash
  $ bundle exec ruby -Ilib examples/simplejob.rb
```

