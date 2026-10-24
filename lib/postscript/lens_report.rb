# frozen_string_literal: true

begin
  require "lens_core"
rescue LoadError => e
  raise Postscript::Error,
        "Postscript.validate requires lens_core and Ruby >= 3.1: #{e.message}"
end

require "postscript/lens_citations"

module Postscript
  # Adapts the internal validation findings to LensCore diagnostics v1.
  module LensReport
    REQUIREMENTS = {
      grammar: "postscript.grammar.syntax",
      level: "postscript.level.operator-available",
      unknown_name: "postscript.vocabulary.known-name",
    }.freeze

    class << self
      def call(validation_report, level:, engine:, timestamp: nil)
        citations = LensCitations.profile(level)
        LensCore::Report.new(
          producer: LensCore::Producer.new(name: "postscript",
                                           version: VERSION),
          profile: LensCore::Profile.new(id: "postscript-level-#{level}",
                                         citations: citations),
          valid: validation_report.ok?, timestamp: timestamp,
          diagnostics: validation_report.diagnostics.map do |diagnostic|
            convert(diagnostic, level, engine, citations)
          end
        )
      end

      private

      def convert(diagnostic, level, engine, profile_citations)
        LensCore::Diagnostic.new(
          severity: diagnostic.severity.to_s,
          kind: diagnostic.kind.to_s.tr("_", "-"),
          requirement_id: REQUIREMENTS.fetch(diagnostic.kind),
          message: utf8(diagnostic.message),
          citations: citations(diagnostic, profile_citations),
          remediation: remediation(diagnostic),
          context: json_value(context(diagnostic, level, engine)),
        )
      end

      def citations(diagnostic, profile_citations)
        case diagnostic.kind
        when :grammar then profile_citations
        when :level then [LensCitations.entry(diagnostic.entry)]
        else []
        end
      end

      def remediation(diagnostic)
        return unless diagnostic.kind == :level

        "declare %%LanguageLevel: #{diagnostic.entry.level} " \
          "or remove #{diagnostic.entry.keyword}"
      end

      def context(diagnostic, level, engine)
        case diagnostic.kind
        when :grammar
          { line: diagnostic.line, column: diagnostic.column,
            offset: diagnostic.offset, rule: diagnostic.rule,
            expected: diagnostic.expected, engine: engine }
        when :level
          { "keyword" => diagnostic.entry.keyword,
            "required_level" => diagnostic.entry.level,
            "target_level" => level }
        when :unknown_name
          # The internal Diagnostic has no keyword field; Vocabulary's name
          # is carried verbatim after this prefix by Validator.
          { "keyword" => diagnostic.message.delete_prefix("Unknown name: ") }
        end
      end

      def json_value(value)
        case value
        when String, Symbol then utf8(value.to_s)
        when Array then value.map { |item| json_value(item) }
        when Hash
          value.to_h { |key, item| [utf8(key.to_s), json_value(item)] }
        else value
        end
      end

      # Lexers preserve source bytes in binary strings. LensCore requires
      # UTF-8 text; retain valid sequences and replace invalid ones for display.
      def utf8(value)
        value.dup.force_encoding(Encoding::UTF_8).scrub
      end
    end
  end
end
