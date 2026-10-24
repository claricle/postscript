# frozen_string_literal: true

module Postscript
  # Combines source and model checks, stopping at invalid grammar.
  module Validator
    class << self
      def call(source, level: nil, engine: :auto)
        if engine == :auto
          engine = Source::NativeEngine.available? ? :native : :ruby
        end
        diagnostics = Validation::Grammar.check(source, engine: engine)
        unless diagnostics.empty?
          return Validation::Report.new(diagnostics: diagnostics)
        end

        program = Source.parse(source, engine: engine)
        diagnostics = level_diagnostics(program, level)
        Validation::Vocabulary.unknown_names(program).each do |name|
          diagnostics << Diagnostic.new(
            code: :unknown_name, kind: :unknown_name,
            severity: :warning, message: "Unknown name: #{name}"
          )
        end
        Validation::Report.new(diagnostics: diagnostics)
      end

      private

      def level_diagnostics(program, level)
        Validation::Levels.violations(program, level: level).map do |violation|
          # A violation can only occur below the default Level 3, so
          # Levels has accepted either the explicit level or the header.
          target = level || program.header.language_level
          Diagnostic.new(
            code: :level, kind: :level, severity: :error,
            message: "#{violation.keyword} is Level #{violation.level}; " \
                     "this program targets Level #{target}",
            entry: Model::Vocabulary.entry(violation.keyword)
          )
        end
      end
    end
  end
end
