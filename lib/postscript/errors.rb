# frozen_string_literal: true

module Postscript
  # Base class for every Postscript gem error. rescue this to catch
  # anything the gem raises.
  class Error < StandardError; end

  # Lexing or parsing failed. Carries +source_position+ when known.
  class ParseError < Error
    attr_reader :source_position

    def initialize(message, source_position: nil)
      @source_position = source_position
      super(message)
    end
  end

  # Lexer hit a character or construct it could not consume.
  class LexError < ParseError; end

  # Tokens did not form a valid PostScript program (unbalanced braces,
  # missing operands, malformed literal).
  class SyntaxError < ParseError; end

  # PS -> SVG / serializer execution failed.
  class RenderError < Error
    attr_reader :operator_name

    def initialize(message, operator_name: nil)
      @operator_name = operator_name
      super(message)
    end
  end

  # An operator tried to pop more values than the stack held.
  class StackUnderflowError < RenderError; end

  # An operator referenced a name that has no definition in any
  # active dictionary.
  class UndefinedOperatorError < RenderError; end

  # A procedure invocation chain exceeded the depth limit.
  class RecursionLimitError < RenderError; end

  # Output exceeded the configured byte limit.
  class SizeLimitError < RenderError; end

  # Model -> PS source serialization failed.
  class SerializeError < Error; end

  # Internal control-flow signals used by visitors to unwind loops
  # and stop program execution. NOT user-facing errors; caught by
  # the orchestrator (e.g. Postscript::Renderer).
  class ExitSignal < StandardError; end
  class QuitSignal < StandardError; end
end
