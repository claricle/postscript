# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Validation::Grammar do
  {
    "{ unclosed" => [1, 2, "unbalanced procedure braces"],
    "(unterminated" => [0, 1, "unterminated string literal"],
    "<hex" => [0, 1, "unterminated hex string literal"],
    "[1 2" => [1, 2, "unbalanced array_close"],
    "<< /key 1" => [2, 3, "unbalanced dict_close"],
  }.each do |source, (offset, column, message)|
    it "reports the lexer position for #{source.inspect}" do
      diagnostics = described_class.check(source)

      expect(diagnostics.size).to eq(1)
      expect(diagnostics.first).to be_a(Postscript::Diagnostic)
      expect(diagnostics.first.to_h).to include(
        code: :syntax, kind: :grammar, severity: :error, message: message,
        offset: offset, line: 1, column: column, rule: nil, expected: []
      )
    end

    it "counts byte columns and LF lines for #{source.inspect}" do
      prefix = "% é\r\n\n(é) \r"
      diagnostic = described_class.check(prefix + source, engine: :ruby).first

      expect(diagnostic.to_h).to include(offset: prefix.bytesize + offset,
                                         line: 3, column: column + 6)
    end
  end

  it "returns no diagnostics for valid source" do
    source = "{ 1 2 } [1 2] (text) <abcd> 10 20 moveto"
    expect(described_class.check(source)).to eq([])
  end

  it "retains unknown positions on parse errors" do
    allow(Postscript::Source).to receive(:parse).with("", engine: :ruby)
      .and_raise(Postscript::ParseError.new("unknown position"))

    expect(described_class.check("").first.to_h).to include(
      message: "unknown position", offset: nil, line: nil, column: nil,
    )
  end

  it "does not turn engine configuration errors into grammar diagnostics" do
    expect { described_class.check("", engine: :unknown) }
      .to raise_error(ArgumentError, /unknown engine/)
  end
end
