# frozen_string_literal: true

require "yaml"

module Postscript
  module Model
    # The PostScript operator vocabulary. data/guide_operators.yml is
    # generated from the PostScript Language Guide; data/operator_overrides.yml
    # supplies levels and categories the Guide lacks, each with a reason.
    # Per operator, an override's fields replace the Guide's, and operators
    # listed only in the overrides are included.
    module Vocabulary
      GUIDE = File.expand_path("../../../data/guide_operators.yml", __dir__)
      OVERRIDES = File.expand_path("../../../data/operator_overrides.yml",
                                   __dir__)

      Entry = Struct.new(:keyword, :categories, :level, :source,
                         keyword_init: true)

      class << self
        def entry(keyword)
          entries[keyword]
        end

        def level(keyword)
          entry(keyword)&.level
        end

        def keywords
          @keywords ||= entries.keys.sort.freeze
        end

        private

        def entries
          @entries ||= load_entries
        end

        def load_entries
          guide = operators(GUIDE)
          overrides = operators(OVERRIDES)
          merged = guide.merge(overrides) do |_keyword, original, override|
            original.merge(override)
          end
          merged.each_with_object({}) do |(keyword, fields), result|
            source = overrides.key?(keyword) ? :override : :guide
            result[keyword] = build_entry(keyword, fields, source)
          end.freeze
        end

        # Not YAML.safe_load_file: it needs Psych 3.3.2, and Ruby 3.0
        # ships Psych 3.3.0.
        def operators(path)
          File.open(path) { |file| YAML.safe_load(file) }.fetch("operators")
        end

        def build_entry(keyword, fields, source)
          Entry.new(
            keyword: keyword.freeze,
            categories: Array(fields["categories"]).map(&:freeze).freeze,
            level: fields["level"],
            source: source,
          ).freeze
        end
      end
    end
  end
end
