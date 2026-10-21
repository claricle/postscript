# frozen_string_literal: true

module Postscript
  module Validation
    # Finds operators that need a newer PostScript language level than
    # the one given. An operator's level is the first level that has it;
    # names with no vocabulary entry and calls to user procedures are
    # never violations.
    module Levels
      LEVELS = (1..3)

      class << self
        def violations(program, level:)
          unless level.is_a?(Integer) && LEVELS.cover?(level)
            raise ArgumentError, "level must be 1, 2 or 3, got #{level.inspect}"
          end

          result = []
          program.body.each { |node| walk(node, level, result) }
          result.freeze
        end

        private

        def walk(node, level, result)
          if node.is_a?(Model::Operator)
            check(node, level, result)
          else
            children(node).each { |child| walk(child, level, result) }
          end
        end

        # Calls to user procedures are never violations: InvokeProcedure
        # has no language level, and the body is checked where it is
        # defined, as a Procedure literal.
        def check(operator, level, result)
          needed = operator.language_level
          return unless needed && needed > level

          result << LevelViolation.new(keyword: operator.keyword,
                                       level: needed).freeze
        end

        def children(node)
          case node
          when Model::Literals::Procedure then node.body
          when Model::Literals::ArrayLiteral then node.elements
          when Model::Literals::Dictionary then node.entries.to_a.flatten(1)
          else []
          end
        end
      end
    end
  end
end
