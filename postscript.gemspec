# frozen_string_literal: true

require_relative "lib/postscript/version"

Gem::Specification.new do |spec|
  spec.name = "postscript"
  spec.version = Postscript::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Pure Ruby PostScript (PS) / EPS parser, domain model, and serializer"
  spec.description = <<~HEREDOC
    Postscript is a pure-Ruby PostScript (PS) / EPS parser, typed
    domain model, and serializer. It is the lower layer of the
    postsvg converter and is independently reusable for any tool
    that needs to read, write, or transform PostScript source.
  HEREDOC

  spec.homepage = "https://github.com/claricle/postscript"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/claricle/postscript"
  spec.metadata["changelog_uri"] = "https://github.com/claricle/postscript/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/claricle/postscript/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
