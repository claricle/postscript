# frozen_string_literal: true

module Postscript
  # Source-reading layer: PS source text -> Model::Program.
  #
  # Lexer produces an array of Model::Token; AstBuilder walks tokens and
  # emits a typed Model::Program. Errors are raised as Postscript::LexError
  # and Postscript::SyntaxError respectively.
  module Source
    autoload :Lexer, "postscript/source/lexer"
    autoload :AstBuilder, "postscript/source/ast_builder"
    autoload :OperandStack, "postscript/source/operand_stack"

    module_function

    # One-shot convenience: PS source -> Model::Program.
    def parse(source)
      AstBuilder.build(Lexer.tokenize(source))
    end
  end
end
