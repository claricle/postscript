# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "json_schemer", group: :test

# Temporary pin like svg_conform#103; lens_core needs Ruby >= 3.1.
# TODO: Switch to the released gem and add it to the gemspec when published.
gem "lens_core", git: "https://github.com/claricle/lens_core.git",
                 ref: "98c21c82bc97e3c8c4038048acdcec4a177c5f7c",
                 install_if: -> { RUBY_VERSION >= "3.1" }

# Optional native engine (Source.parse(source, engine: :native)); not a
# dependency of the gem. parsanol needs Ruby >= 3.2.
gem "parsanol", ">= 1.3.96", install_if: -> { RUBY_VERSION >= "3.2" }
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
