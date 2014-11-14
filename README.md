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

