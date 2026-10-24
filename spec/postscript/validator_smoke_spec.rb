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
            diagnostic.kind == "grammar"
          end

          expect(grammar.size).to eq(test.fetch("kind") == "accept" ? 0 : 1)
          unless grammar.empty?
            expect_grammar_finding(grammar.first, source, engine)
          end
        end
      end

      it "matches accepted reports and rejected diagnostic shapes" do
        skip "parsanol native engine unavailable" unless
          Postscript::Source::NativeEngine.available?

        ruby = Postscript.validate(source, engine: :ruby)
        native = Postscript.validate(source, engine: :native)

        if test.fetch("kind") == "accept"
          expect(native.to_h).to eq(ruby.to_h)
        else
          expect(native.valid).to eq(ruby.valid)
          expect(native.summary).to eq(ruby.summary)
          expect(diagnostic_shapes(native)).to eq(diagnostic_shapes(ruby))
        end
      end
    end
  end

  def expect_grammar_finding(diagnostic, source, engine)
    original = Postscript::Validation::Grammar.check(source,
                                                     engine: engine).first
    context = original.to_h.slice(:line, :column, :offset, :rule, :expected)
      .transform_keys(&:to_s).merge("engine" => engine.to_s)

    expect(diagnostic.to_h).to include("message" => original.message,
                                       "context" => context)
  end

  def diagnostic_shapes(report)
    report.diagnostics.map do |diagnostic|
      diagnostic.to_h.slice("severity", "kind", "requirement_id", "citations")
        .merge("keys" => diagnostic.to_h.keys,
               "context_keys" => diagnostic.context.keys)
    end
  end
end
