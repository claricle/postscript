# frozen_string_literal: true

require "lens_core"
require "postscript/model/vocabulary"
require "postscript/version"

module Postscript
  # Explicitly require this optional integration when LensCore is available.
  module LensCitations
    PLRM_URI = "https://www.adobe.com/products/postscript/pdfs/PLRM.pdf"

    class << self
      def profile(level)
        unless level.is_a?(Integer) && (1..3).cover?(level)
          raise ArgumentError, "level must be 1, 2 or 3, got #{level.inspect}"
        end

        citation = LensCore::Citation.new(
          uri: PLRM_URI, label: "PLRM 3rd ed.: LanguageLevel #{level}",
        )
        [citation].freeze
      end

      def entry(vocabulary_entry)
        guide = vocabulary_entry.source == :guide
        uri = guide ? guide_uri(vocabulary_entry.keyword) : override_uri
        title = if guide
                  "PostScript Language Guide"
                else
                  override_reason(vocabulary_entry.keyword)
                end
        LensCore::Citation.new(
          uri: uri,
          label: "#{title}: #{vocabulary_entry.keyword}, " \
                 "LanguageLevel #{vocabulary_entry.level}",
        )
      end

      private

      def override_uri
        "https://github.com/claricle/postscript/blob/" \
          "v#{VERSION}/data/operator_overrides.yml"
      end

      def override_reason(keyword)
        File.open(Model::Vocabulary::OVERRIDES) do |file|
          YAML.safe_load(file).fetch("operators").fetch(keyword).fetch("reason")
        end
      end

      def guide_uri(keyword)
        metadata = File.open(Model::Vocabulary::GUIDE) do |file|
          YAML.safe_load(file).fetch("guide")
        end
        "https://github.com/#{metadata.fetch('repository')}/blob/" \
          "#{metadata.fetch('commit')}/docs/commands/references/#{keyword}.adoc"
      end
    end
  end
end
