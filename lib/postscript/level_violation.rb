# frozen_string_literal: true

module Postscript
  # An operator keyword and the PostScript language level it needs.
  LevelViolation = Struct.new(:keyword, :level, keyword_init: true)
end
