# frozen_string_literal: true

module Postscript
  module Validation
    # Converts Ruby parse failures or native PARG failures into diagnostics.
    module Grammar
      class << self
        def check(source, engine: :ruby)
          source = source.to_s
          if engine == :auto
            engine = Source::NativeEngine.available? ? :native : :ruby
          end
          return native_check(source) if engine == :native

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

        def native_check(source)
          bytes = source.b
          input = Source::NativeLexer::Input.new(bytes)
          failure = Source::NativeEngine.diagnose(input.text)
          return [] unless failure

          offset = input.offset(failure[:offset]) if failure[:offset]
          if offset
            line, column = Source::NativeLexer::Lines.new(bytes).position(offset)
          end
          [Diagnostic.new(code: :syntax, kind: :grammar, severity: :error,
                          message: failure[:message], offset: offset,
                          line: line, column: column, rule: failure[:rule],
                          expected: failure[:expected])]
        end

        def byte_offset(source, line, column)
          return unless line && column

          source.each_line("\n").take(line - 1).sum(&:bytesize) + column - 1
        end
      end
    end
  end
end
