# frozen_string_literal: true

module Postscript
  module Model
    # PS operator catalogue. Each subclass of Model::Operator registers
    # itself under its keyword. The parser looks keywords up here to
    # decide which class to instantiate.
    #
    # Categories (mirrors PLRM chapter structure):
    # - Stack, Arithmetic, Boolean, Path, Painting, Color,
    #   GraphicsState, Transformations, Dictionary, ControlFlow, Device
    module Operators
      autoload :Stack, "postscript/model/operators/stack"
      autoload :Arithmetic, "postscript/model/operators/arithmetic"
      autoload :Boolean, "postscript/model/operators/boolean"
      autoload :Path, "postscript/model/operators/path"
      autoload :Painting, "postscript/model/operators/painting"
      autoload :Color, "postscript/model/operators/color"
      autoload :GraphicsState, "postscript/model/operators/graphics_state"
      autoload :Transformations, "postscript/model/operators/transformations"
      autoload :Dictionary, "postscript/model/operators/dictionary"
      autoload :ControlFlow, "postscript/model/operators/control_flow"
      autoload :Device, "postscript/model/operators/device"
      autoload :Font, "postscript/model/operators/font"
      autoload :Container, "postscript/model/operators/container"

      @registry = {}
      @visit_names = {}

      class << self
        # @api private Used by Operator subclasses at load time.
        def register(keyword, klass)
          @registry[keyword] = klass
        end

        # Lookup by PS keyword. Returns nil for unknown keywords.
        def [](keyword)
          @registry[keyword]
        end

        def registered?(keyword)
          @registry.key?(keyword)
        end

        def keywords
          @registry.keys
        end

        # Force-load every operator category so the registry is fully
        # populated. Call this once before relying on [+].
        def load_all!
          constants.each { |c| const_get(c) }
        end
      end
    end

    # Wrapper for operator tokens with no registered class. Carries
    # the original keyword so the visitor can emit a comment / warn.
    class UnknownOperator < Operator
      attr_reader :keyword

      def initialize(keyword:)
        @keyword = keyword
        freeze
      end

      def visit_name = "unknown"

      def self.from_operands(_stack); end
    end

    # A bare name reference resolved to a user-defined procedure via
    # +def+. The renderer descends into +procedure+ with the current
    # context, mirroring how PostScript executes the procedure body.
    class InvokeProcedure < Operator
      attr_reader :name, :procedure

      def initialize(name:, procedure:)
        @name = name
        @procedure = procedure
        freeze
      end

      def visit_name = "invoke_procedure"

      def keyword = name.to_s
    end
  end
end
