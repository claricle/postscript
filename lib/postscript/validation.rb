# frozen_string_literal: true

module Postscript
  # Checks on the typed PostScript model.
  module Validation
    autoload :Grammar, "postscript/validation/grammar"
    autoload :Levels, "postscript/validation/levels"
  end
end
