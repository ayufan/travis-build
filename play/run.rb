#!/usr/bin/env ruby

$: << 'lib' << '/Users/ayufan/SDKs/travis-build/lib'
require 'travis/build'
require 'yaml'
require 'optparse'

# data = {
#     build: {
#         id: 1,
#         number: 1
#     },
#     job: {
#         id: 1,
#         number: 1,
#         branch: "master",
#         commit: "123123",
#         commit_range: "123123..123123",
#     },
#     repository: {
#         slug: "repo/test"
#     },
#     config: {
#       language: 'java',
#       env: [
#           "TEST=1",
#           "TEST=2"
#       ],
#       before_install: [
#           'wget http://dl.google.com/android/android-sdk_r18-linux.tgz',
#           'tar -zxf android-sdk_r18-linux.tgz',
#           'export ANDROID_HOME=`pwd`/android-sdk-linux',
#           'export PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools',
#           'android update sdk --filter 1,2,9 --no-ui --force'
#       ]
#     }
# }

travis_config = YAML.load_file('.travis.yml')

data = {
    config: {
    },
    repository: {
        source_url: `git config --get remote.origin.url`.strip!,
        slug: `basename "$PWD"`.strip!,
        pull_request: false
    },
    build: {
        id: 1,
        number: '0.0'
    },
    job: {
        id: 1,
        number: '0.0',
        branch: `git symbolic-ref --short HEAD`.strip!,
        commit: `git rev-parse HEAD`.strip!
    }
}

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-p", "--[no-]print", "Print script") do |v|
    options[:print] = v
  end

  opts.on("-s SLUG", "--slug SLUG", "Repository slug") do |v|
    data[:repository][:slug] = v
  end

  opts.on("-i ID", "--id ID", "Build ID") do |v|
    data[:build][:id] = v
    data[:job][:id] = v
  end

  opts.on("-v VERSION", "--version VERSION", "Build version") do |v|
    data[:build][:number] = v
    data[:job][:number] = v
  end

  opts.on("-b BRANCH", "--branch BRANCH", "Branch") do |v|
    data[:job][:branch] = v
  end

  opts.on("-c COMMIT", "--commit COMMIT", "Commit") do |v|
    data[:job][:commit] = v
  end
end.parse!

script = Travis::Build.script(data, logs: { build: true, state: false })
script = script.compile
puts script
