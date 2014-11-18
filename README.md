# PBS Ruby

## Description

Trimmed down Ruby wrapper for the Torque C Library utilizing Ruby-FFI.

## Requirements

At minimum you will need:
* Ruby 2.1
* Ruby-FFI gem
* Torque library installed on machine

## Installation

From rubygems (not added yet):

```bash
  $ [sudo] gem install pbs
```

or from the git repository on github, add this to your `Gemfile`:

```
  # Gemfile

  ...

  gem 'pbs', git: 'https://github.com/nickjer/pbs-ruby.git'
```

then run from command line:

```bash
  $ bundle exec ruby <example.rb>
```

## Usage

The usage follows very closely to the `pbs_python` usage documented here: https://oss.trac.surfsara.nl/pbs_python/wiki/TorqueUsage

Not all PBS functions are replicated in this project. The administrative functions have been neglected.

Most useful features are described in the `simplejob.rb` provided. To run this simple example, type:

```bash
  $ ruby -Ilib samples/simplejob.rb
```


