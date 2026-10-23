# frozen_string_literal: true

module Postscript
  # A grammar, language-level, or unknown-name finding. Severity is
  # :error or :warning; source locations and vocabulary entry may be nil.
  Diagnostic = Struct.new(:code, :kind, :severity, :message, :offset,
                          :line, :column, :rule, :expected, :entry,
                          keyword_init: true) do
    def initialize(expected: [], **attributes)
      super(**attributes, expected: expected.dup.freeze)
      freeze
    end
  end
end
