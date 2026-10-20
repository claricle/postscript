# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Optional native engine (Source.parse(source, engine: :native)); not a
# dependency of the gem. parsanol needs Ruby >= 3.2.
gem "parsanol", ">= 1.3.96", install_if: -> { RUBY_VERSION >= "3.2" }
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
