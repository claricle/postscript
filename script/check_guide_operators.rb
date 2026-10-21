#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the operator inventory against its pinned Guide commit.
# Usage: ruby script/check_guide_operators.rb

require "open3"
require "tmpdir"
require "yaml"
require_relative "guide_operators"

def fail!(message)
  abort("FAIL #{message}")
end

def step(name)
  yield
  puts "ok   #{name}"
end

def git(dir, *args)
  command = ["git", "-C", dir, *args]
  output, status = Open3.capture2e(*command)
  fail!("#{command.join(' ')}\n#{output}") unless status.success?
end

path = File.expand_path("../data/guide_operators.yml", __dir__)
pin = YAML.safe_load_file(path).fetch("guide")
repository = pin.fetch("repository")
commit = pin.fetch("commit")

step("data/guide_operators.yml matches #{repository}@#{commit[0, 7]}") do
  Dir.mktmpdir do |dir|
    git(dir, "init", "--quiet")
    git(dir, "fetch", "--quiet", "--depth", "1",
        "https://github.com/#{repository}.git", commit)
    git(dir, "checkout", "--quiet", "FETCH_HEAD")
    fresh = GuideOperators.to_yaml(GuideOperators.extract(dir), commit)
    next if fresh == File.read(path)

    fail!("data/guide_operators.yml is stale or edited: regenerate with " \
          "ruby script/guide_operators.rb GUIDE_CHECKOUT")
  end
end
