# frozen_string_literal: true

module Postscript
  # PS domain model. Every value object that participates in the AST
  # or in round-trip is a Model::* class. The lexer emits Model::Token;
  # the parser emits Model::Program; the renderer / serializer consume
  # Model::Program.
  module Model
    autoload :Token, "postscript/model/token"
    autoload :Program, "postscript/model/program"
    autoload :Literals, "postscript/model/literals"
    autoload :Operator, "postscript/model/operator"
    autoload :UnknownOperator, "postscript/model/operator"
    autoload :InvokeProcedure, "postscript/model/operator"
    autoload :Operators, "postscript/model/operators"
  end
end
