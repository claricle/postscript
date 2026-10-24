# frozen_string_literal: true

module Postscript
  module Validation
    # Converts parse failures into grammar diagnostics using lexer coordinates.
    module Grammar
      class << self
        def check(source, engine: :ruby)
          source = source.to_s
          Source.parse(source, engine: engine)
          []
        rescue ParseError => e
          line, column = e.source_position
          [Diagnostic.new(code: :syntax, kind: :grammar, severity: :error,
                          message: e.message, line: line, column: column,
                          offset: byte_offset(source, line, column),
                          rule: nil, expected: [])]
        end

        private

        def byte_offset(source, line, column)
          return unless line && column

          source.each_line("\n").take(line - 1).sum(&:bytesize) + column - 1
        end
      end
    end
  end
end
