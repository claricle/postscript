# frozen_string_literal: true

module Postscript
  # Source-reading layer: PS source text -> Model::Program.
  #
  # Lexer produces an array of Model::Token; AstBuilder walks tokens and
  # emits a typed Model::Program. Errors are raised as Postscript::LexError
  # and Postscript::SyntaxError respectively.
  #
  # +engine:+ picks the tokenizer: +:ruby+ (the default) is Lexer;
  # +:native+ is NativeLexer, the PARG grammar on parsanol's native
  # engine, which needs the optional parsanol gem and produces the same
  # tokens.
  module Source
    autoload :Lexer, "postscript/source/lexer"
    autoload :NativeLexer, "postscript/source/native_lexer"
    autoload :NativeEngine, "postscript/source/native_engine"
    autoload :AstBuilder, "postscript/source/ast_builder"
    autoload :OperandStack, "postscript/source/operand_stack"

    ENGINES = %i[ruby native].freeze

    module_function

    # One-shot convenience: PS source -> Model::Program.
    def parse(source, engine: :ruby)
      AstBuilder.build(tokenize(source, engine: engine))
    end

    # PS source -> array of Model::Token.
    def tokenize(source, engine: :ruby)
      case engine
      when :ruby then Lexer.tokenize(source)
      when :native then NativeLexer.tokenize(source)
      else
        raise ArgumentError,
              "unknown engine #{engine.inspect} (use one of #{ENGINES.inspect})"
      end
    end
  end
end
