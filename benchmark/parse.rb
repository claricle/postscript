#!/usr/bin/env ruby
# frozen_string_literal: true

# Times Postscript.parse on the fixture corpus with one engine.
#
#   bundle exec ruby benchmark/parse.rb --engine ruby [--corpus]
#   bundle exec ruby benchmark/parse.rb --engine native [--corpus]
#
# Inputs are the fixtures that parse, plus ps2svg/img.ps repeated to
# about 250 KB and 1 MB. A requested native run fails if parsanol's
# native engine is unavailable.

require "benchmark"
require "digest"
require "fileutils"
require "net/http"
require "optparse"
require "tmpdir"
require "yaml"
require_relative "../lib/postscript"

def download_corpus_file(base_url, path, cache)
  response = Net::HTTP.get_response(URI("#{base_url}/#{path}"))
  unless response.is_a?(Net::HTTPSuccess)
    abort("corpus: #{path}: HTTP #{response.code} #{response.message}")
  end

  FileUtils.mkdir_p(File.dirname(cache))
  File.binwrite(cache, response.body)
end

def read_corpus_file(entry, commit, base_url)
  path = entry.fetch("path")
  cache = File.join(Dir.tmpdir, "postscript-corpus", commit, path)
  download_corpus_file(base_url, path, cache) unless File.exist?(cache)
  source = File.binread(cache)
  expected = entry.fetch("sha256")
  actual = Digest::SHA256.hexdigest(source)
  unless actual == expected
    abort("corpus: #{path}: SHA-256 mismatch: " \
          "expected #{expected}, actual #{actual}")
  end
  source
end

def corpus_inputs
  manifest = YAML.safe_load_file(File.join(__dir__, "corpus.yml"))
  repository = manifest.fetch("repository")
  commit = manifest.fetch("commit")
  files = manifest.fetch("files")
  puts "corpus: #{repository}@#{commit}, #{files.length} files"
  base_url = "https://raw.githubusercontent.com/#{repository}/#{commit}"
  files.to_h do |entry|
    [entry.fetch("path"), read_corpus_file(entry, commit, base_url)]
  end
end

engine = :ruby
corpus = false
OptionParser.new do |opts|
  opts.on("--corpus", "Use the pinned corpus manifest") { corpus = true }
  opts.on("--engine ENGINE", %w[ruby native], "ruby (default) or native") do |e|
    engine = e.to_sym
  end
end.parse!

if corpus
  inputs = corpus_inputs
else
  fixtures = File.expand_path("../spec/fixtures", __dir__)
  img = File.read(File.join(fixtures, "ps2svg/img.ps"))
  inputs = Dir[File.join(fixtures, "**/*.{ps,eps}")].to_h do |path|
    [path.delete_prefix("#{fixtures}/"), File.read(path)]
  end
  inputs["img.ps x8"] = ([img] * 8).join("\n")
  inputs["img.ps x30"] = ([img] * 30).join("\n")
end

if engine == :native
  require_relative "../lib/postscript/source/native_engine"
  Postscript::Source::NativeEngine.available? ||
    abort("engine: native is unavailable (needs parsanol >= " \
          "#{Postscript::Source::NativeEngine::MINIMUM_VERSION})")
  puts "engine: native, parsanol #{Parsanol::VERSION}"
else
  puts "engine: ruby"
end
puts "ruby #{RUBY_VERSION}, #{RUBY_PLATFORM}"

parsed = failed = 0
total = 0.0
inputs.each do |name, source|
  Postscript.parse(source, engine: engine) # warm up
  reps = source.bytesize < 50_000 ? 10 : 1
  seconds = Benchmark.realtime do
    reps.times { Postscript.parse(source, engine: engine) }
  end / reps
  total += seconds
  parsed += 1
  printf("  %-44s %9d B %10.1f ms\n", name, source.bytesize, seconds * 1000)
rescue Postscript::ParseError => e
  failed += 1
  printf("  %-44s %9d B  fails: %s\n", name, source.bytesize, e.class)
end
printf("%d parsed, %d failed (expected: invalid input), %.1f ms in all\n",
       parsed, failed, total * 1000)
