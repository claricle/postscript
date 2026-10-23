# frozen_string_literal: true

module Postscript
  module Validation
    # An immutable collection of validation findings in source order.
    class Report
      attr_reader :diagnostics

      def initialize(diagnostics: [])
        @diagnostics = diagnostics.dup.freeze
        freeze
      end

      def ok?
        diagnostics.none? { |diagnostic| diagnostic.severity == :error }
      end

      def errors
        diagnostics.select { |diagnostic| diagnostic.severity == :error }
      end

      def warnings
        diagnostics.select { |diagnostic| diagnostic.severity == :warning }
      end

      def to_h
        { diagnostics: diagnostics.map(&:to_h) }
      end
    end
  end
end
