# frozen_string_literal: true

module Postscript
  module Model
    # PS literal value objects. Each is immutable, has value equality,
    # and knows how to (a) emit itself to a serializer and (b) be
    # visited by a renderer. They never carry executable behaviour —
    # they are data.
    module Literals
      autoload :Number, "postscript/model/literals/number"
      autoload :Name, "postscript/model/literals/name"
      autoload :StringLiteral, "postscript/model/literals/string"
      autoload :HexLiteral, "postscript/model/literals/hex"
      autoload :ArrayLiteral, "postscript/model/literals/array"
      autoload :Procedure, "postscript/model/literals/procedure"
      autoload :Dictionary, "postscript/model/literals/dictionary"
    end
  end
end
