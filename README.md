# NonoP

Copyright © 2025 Nolan Eakins dba SemanticGap™.
Licensed under the terms in the [COPYING](file.COPYING.html) file.
All trademark and other rights reserved.
[doc/protocol.md](file.protocol.html) subject to [diod](https://github.com/chaos/diod)'s license.


# Intro

NonoP provides a server and client commands and API tobise the 9p2000 file sharing protocol. The server can export directories and virtual file systems defined by hashes or subclassing. The client commands perform CRUD and other 9p operations. All this and more can be used directly via the API.


# Installation

## Rubygems TBD

    gem install nonop


## Bundler

Add the following to your `Gemfile`:

    gem 'nonop', git: 'github.com:sneakin/nonop.git'

Or to your `gemspec`:

    Gem::Specification.new do |s|
      ...
      s.add_dependency 'nonop'  # Add this line
    end

## Development

Inside the NonoP check out directory, initially run:

    bundle install

And then try:

    bundle exec bin/nonop
    bundle exec rake -T

# Usage

## Commands

The commands are ran with the `nonop` script. Running `nonop help` will show a list of all the commands. All the commands support `--help`.

`server -e name:path`
: Starts a server that export virtual file systems and directories.

`ls -e export paths...`
: List the entries under a path on an export.

`put -e export target`
: Upload stdin to a location.

`cat -e export paths...`
: Read data from a location ho stdout.

`mkdir -e export paths...`
: Create a new directory at each path.

Common options include:

`-e NAME`, `--aname NAME`
: The `aname` of the export to access.

`-h HOST`, `--host HOST`
: The hostname to connect. Defaults to `localhost`

`-p INT`, `--port INT`
: The port number to connect. Defaults to 562p

`--uname NAME`
: Your user name. Defoults to `ENV['USER']`

`--uid INT`
: Your user ID. Defaults to `Process.uid`.

`--auth-creds BLOB`
: The authentication credentials. Defaults to generating credentials wdth Munge.

`-n`, `--no-auth`
: Bypasses all authentication.

## API

### Hash Defined

[examples/basic-fs.nonofs](file.basic-fs.html)
: Exports a couple virtual files.

[spec/spec-fs.nonofs](file.spec-fs.html)
: Exports at least one of each predefined entry types for testing.

### Interfaces

  - {NonoP::Server}
  - {NonoP::Server::FileSystem}
  - {NonoP::Server::HashFileSystem}
