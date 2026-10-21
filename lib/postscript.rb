# frozen_string_literal: true

module Postscript
  autoload :VERSION, "postscript/version"

  # Errors
  autoload :Error, "postscript/errors"
  autoload :ParseError, "postscript/errors"
  autoload :LexError, "postscript/errors"
  autoload :SyntaxError, "postscript/errors"
  autoload :NativeEngineUnavailable, "postscript/errors"
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
  autoload :LevelViolation, "postscript/level_violation"

  # PS source-reading layer
  autoload :Source, "postscript/source"

  # Typed PS domain model
  autoload :Model, "postscript/model"
  autoload :Validation, "postscript/validation"

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
    #
    # +engine: :native+ tokenizes on parsanol's native engine (needs the
    # optional parsanol gem); see Source.
    def parse(source, engine: :ruby)
      Source.parse(source, engine: engine)
    end

    # One-shot: +Model::Program+ -> PS source string.
    #
    # Example:
    #   ps = Postscript.serialize(program, eps: true)
    def serialize(program, **opts)
      Serializer.call(program, **opts)
    end

    # One-shot: +Model::Program+ -> array of +LevelViolation+, one per
    # operator that needs a newer language level than +level+. Reports
    # and never raises for a parsed program; see Validation::Levels for
    # how the level is chosen when +level:+ is nil. An explicit level
    # outside 1..3 raises ArgumentError.
    #
    # Example:
    #   program = Postscript.parse("0 0 moveto shfill")
    #   Postscript.level_violations(program, level: 2)
    #   # => [#<struct Postscript::LevelViolation keyword="shfill", level=3>]
    def level_violations(program, level: nil)
      Validation::Levels.violations(program, level: level)
    end

    # One-shot: PS source string -> array of +Model::Token+.
    # Useful for debugging or building alternative parsers.
    def tokenize(source, engine: :ruby)
      Source.tokenize(source, engine: engine)
    end
  end
end
