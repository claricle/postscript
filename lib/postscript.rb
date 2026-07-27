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
end
