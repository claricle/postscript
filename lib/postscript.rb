# frozen_string_literal: true

module Postscript
  autoload :VERSION, "postscript/version"

  # Errors
  autoload :Error, "postscript/errors"
  autoload :ParseError, "postscript/errors"
  autoload :LexError, "postscript/errors"
  autoload :SyntaxError, "postscript/errors"
  autoload :RenderError, "postscript/errors"
  autoload :StackUnderflowError, "postscript/errors"
  autoload :UndefinedOperatorError, "postscript/errors"
  autoload :RecursionLimitError, "postscript/errors"
  autoload :SizeLimitError, "postscript/errors"
  autoload :SerializeError, "postscript/errors"
  autoload :ExitSignal, "postscript/errors"
  autoload :QuitSignal, "postscript/errors"

  # General-purpose value types
  autoload :FormatNumber, "postscript/format_number"
  autoload :Matrix, "postscript/matrix"
  autoload :Color, "postscript/color"

  # PS source-reading layer
  autoload :Source, "postscript/source"

  # Typed PS domain model
  autoload :Model, "postscript/model"

  # PS source serializer
  autoload :Serializer, "postscript/serializer"

  # CLI (only loaded when explicitly required or via the +postscript+
  # executable). Avoids pulling in +thor+ for users who only need
  # the library API.
  autoload :CLI, "postscript/cli"

  class << self
    # One-shot: PS source string -> +Model::Program+.
    #
    # Example:
    #   program = Postscript.parse(ps_source)
    #   program.body.each { |node| puts node.class }
    def parse(source)
      Source.parse(source)
    end

    # One-shot: +Model::Program+ -> PS source string.
    #
    # Example:
    #   ps = Postscript.serialize(program, eps: true)
    def serialize(program, **opts)
      Serializer.call(program, **opts)
    end

    # One-shot: PS source string -> array of +Model::Token+.
    # Useful for debugging or building alternative parsers.
    def tokenize(source)
      Source::Lexer.tokenize(source)
    end
  end
end
