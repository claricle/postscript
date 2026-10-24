# frozen_string_literal: true

module Postscript
  # Combines source and model checks, stopping at invalid grammar.
  module Validator
    class << self
      def call(source, level: nil, engine: :auto, timestamp: nil)
        if engine == :auto
          engine = Source::NativeEngine.available? ? :native : :ruby
        end
        report, target = validation_report(source, level, engine)
        LensReport.call(report, level: target, engine: engine,
                                timestamp: timestamp)
      end

      private

      def validation_report(source, level, engine)
        diagnostics = Validation::Grammar.check(source, engine: engine)
        unless diagnostics.empty?
          return [Validation::Report.new(diagnostics: diagnostics), level || 3]
        end

        program = Source.parse(source, engine: engine)
        level = resolved_level(program, level)
        diagnostics = level_diagnostics(program, level)
        diagnostics.concat(unknown_diagnostics(program))
        [Validation::Report.new(diagnostics: diagnostics), level]
      end

      def unknown_diagnostics(program)
        Validation::Vocabulary.unknown_names(program).map do |name|
          Diagnostic.new(
            code: :unknown_name, kind: :unknown_name,
            severity: :warning, message: "Unknown name: #{name}"
          )
        end
      end

      def resolved_level(program, level)
        return level unless level.nil?

        header = program.header.language_level
        (1..3).cover?(header) ? header : 3
      end

      def level_diagnostics(program, level)
        Validation::Levels.violations(program, level: level).map do |violation|
          Diagnostic.new(
            code: :level, kind: :level, severity: :error,
            message: "#{violation.keyword} is Level #{violation.level}; " \
                     "this program targets Level #{level}",
            entry: Model::Vocabulary.entry(violation.keyword)
          )
        end
      end
    end
  end
end
