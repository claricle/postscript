# frozen_string_literal: true

module Postscript
  module Validation
    # Finds names absent from the vocabulary and the program's def bindings.
    # This is a static check: bindings anywhere in the body are considered,
    # without simulating execution or dictionary scope.
    module Vocabulary
      class << self
        def unknown_names(program)
          names = {}
          bindings = {}
          program.body.each { |node| walk(node, names, bindings) }
          names.keys.reject { |name| bindings.key?(name) }.freeze
        end

        private

        def walk(node, names, bindings)
          case node
          when Model::UnknownOperator
            names[node.keyword] = true unless Model::Vocabulary.entry(node.keyword)
          when Model::Operators::Dictionary::Def
            key = node.key
            bindings[key.value] = true if key.is_a?(Model::Literals::Name)
          else
            children(node).each { |child| walk(child, names, bindings) }
          end
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
