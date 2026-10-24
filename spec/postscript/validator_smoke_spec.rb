# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Postscript::Validator do
  path = File.expand_path("../../grammars/postscript.json", __dir__)
  corpus = JSON.parse(File.read(path)).fetch("tests")
  kinds = %w[accept reject]
  engines = %i[ruby native]

  # Capture cases check tokenizer output, not validator acceptance.
  corpus.select do |test|
    test.fetch("entry") == "main" && kinds.include?(test.fetch("kind"))
  end.each do |test|
    context "with PARG #{test.fetch('kind')} #{test.fetch('input').inspect}" do
      let(:source) { test.fetch("input") }

      engines.each do |engine|
        it "validates with #{engine}" do
          if engine == :native && !Postscript::Source::NativeEngine.available?
            skip "parsanol native engine unavailable"
          end

          diagnostics = Postscript.validate(source, engine: engine).diagnostics
          grammar = diagnostics.select do |diagnostic|
            diagnostic.kind == :grammar
          end

          expect(grammar.size).to eq(test.fetch("kind") == "accept" ? 0 : 1)
        end
      end

      it "matches diagnostic keys and kinds across engines" do
        skip "parsanol native engine unavailable" unless
          Postscript::Source::NativeEngine.available?

        ruby = Postscript.validate(source, engine: :ruby).diagnostics
        native = Postscript.validate(source, engine: :native).diagnostics

        expect(native.map { |diagnostic| diagnostic.to_h.keys })
          .to eq(ruby.map { |diagnostic| diagnostic.to_h.keys })
        expect(native.map(&:kind)).to eq(ruby.map(&:kind))
      end
    end
  end
end
