#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks the vendored PostScript grammar in grammars/:
#
# - the files are the upstream files at the commit in upstream.yml
# - the grammar's embedded tests pass
# - postscript.json is what the released parsanol compiles from
#   postscript.parg, ignoring the envelope's checksum and compiler version
# - postscript.json loads, which verifies its checksum
# - the gem packages both files
#
# Needs the parsanol gem (Ruby >= 3.2), which this gem does not depend
# on. Usage: ruby script/check_grammar.rb

require "json"
require "net/http"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"
require "parsanol"

ROOT = File.expand_path("..", __dir__)
GRAMMARS = File.join(ROOT, "grammars")
SOURCE = File.join(GRAMMARS, "postscript.parg")
ARTIFACT = File.join(GRAMMARS, "postscript.json")
PACKAGED = %w[grammars/postscript.parg grammars/postscript.json].freeze
ENVELOPE_ONLY = %w[checksum compiler_version].freeze

def fail!(message)
  abort("FAIL #{message}")
end

def step(name)
  yield
  puts "ok   #{name}"
end

def parsanol(*args)
  bin = Gem.bin_path("parsanol", "parsanol")
  output, status = Open3.capture2e(RbConfig.ruby, bin, *args)
  fail!("parsanol #{args.join(' ')}\n#{output}") unless status.success?
end

def upstream_file(pin, name)
  uri = URI("https://raw.githubusercontent.com/" \
            "#{pin['repository']}/#{pin['commit']}/#{name}")
  response = Net::HTTP.get_response(uri)
  fail!("#{uri}: HTTP #{response.code}") unless response.is_a?(Net::HTTPOK)
  response.body.b
end

def payload(path)
  JSON.parse(File.read(path)).except(*ENVELOPE_ONLY)
end

puts "parsanol #{Parsanol::VERSION}"
pin = YAML.safe_load_file(File.join(GRAMMARS, "upstream.yml"))

step("files match #{pin['repository']}@#{pin['commit'][0, 7]}") do
  pin["files"].each do |name|
    next if File.binread(File.join(GRAMMARS, name)) == upstream_file(pin, name)

    fail!("grammars/#{name} differs from upstream; see grammars/README.md")
  end
end

step("embedded grammar tests") { parsanol("parg", "test", SOURCE) }

step("artifact payload matches a fresh compile") do
  Dir.mktmpdir do |dir|
    fresh = File.join(dir, "postscript.json")
    parsanol("parg", "compile", SOURCE, "-o", fresh)
    next if payload(fresh) == payload(ARTIFACT)

    fail!("postscript.json is stale: recompile it upstream")
  end
end

step("artifact checksum") { Parsanol::PARG::Artifact.load(ARTIFACT) }

step("gem packages the grammar") do
  spec = Gem::Specification.load(File.join(ROOT, "postscript.gemspec"))
  missing = PACKAGED - spec.files
  fail!("not packaged: #{missing.join(', ')}") unless missing.empty?
end
