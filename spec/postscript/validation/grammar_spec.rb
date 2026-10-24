# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Validation::Grammar do
  {
    "{ unclosed" => [0, 1, "unbalanced procedure braces"],
    "(unterminated" => [0, 1, "unterminated string literal"],
    "<hex" => [0, 1, "unterminated hex string literal"],
    "[1 2" => [0, 1, "unbalanced array_close"],
    "<< /key 1" => [0, 1, "unbalanced dict_close"],
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

  describe "native diagnostics" do
    before do
      skip "parsanol native engine unavailable" unless
        Postscript::Source::NativeEngine.available?
    end

    {
      "{ unclosed" => [10, "'}'"],
      "(unterminated" => [13, "')'"],
      "<hex" => [1, "'>'"],
      "[1 2" => [4, "']'"],
      "<< /key 1" => [9, "'>>'"],
    }.each do |source, (offset, expected)|
      it "reports PARG's failure for #{source.inspect}" do
        diagnostics = described_class.check(source, engine: :native)

        expect(diagnostics.size).to eq(1)
        expect(diagnostics.first).to be_a(Postscript::Diagnostic)
        expect(diagnostics.first.to_h).to include(
          code: :syntax, kind: :grammar, severity: :error,
          offset: offset, line: 1, column: offset + 1,
          rule: "main", message: a_string_matching(/expected/),
          expected: a_collection_including(expected)
        )
      end

      it "reports multiline byte positions for #{source.inspect}" do
        prefix = "% é\r\n\n(é) \r"
        diagnostic = described_class.check(prefix + source,
                                           engine: :native).first

        expect(diagnostic.to_h).to include(
          code: :syntax, kind: :grammar, severity: :error,
          offset: prefix.bytesize + offset, line: 3, column: 7 + offset,
          rule: "main", message: a_string_matching(/expected/),
          expected: a_collection_including(expected)
        )
      end
    end

    it "maps UTF-8 text offsets to source bytes, LF lines and byte columns" do
      prefix = "% é\r\n\n(é) \r"
      source = "#{prefix}<hex"
      diagnostic = described_class.check(source, engine: :native).first

      expect(diagnostic.to_h).to include(offset: prefix.bytesize + 1,
                                         line: 3, column: 8)
      expect(source.b.byteslice(diagnostic.offset, 1)).to eq("h")
    end

    it "maps binary source offsets back from the native UTF-8 input" do
      source = "(\xE9) <hex".b
      diagnostic = described_class.check(source, engine: :native).first

      expect(diagnostic.to_h).to include(offset: 5, line: 1, column: 6)
      expect(source.byteslice(diagnostic.offset, 1)).to eq("h")
    end

    it "returns no diagnostics for valid source" do
      expect(described_class.check("{ (é) } [1] << /a 2 >> <ab>",
                                   engine: :native)).to eq([])
    end

    it "keeps PARG rejections even when Lexer accepts the source" do
      expect(described_class.check("<4g>", engine: :ruby)).to eq([])
      expect(described_class.check("<4g>", engine: :native).first.to_h)
        .to include(offset: 2, expected: a_collection_including("'>'"))
    end

    it "uses native diagnostics in auto mode when available" do
      expect(described_class.check("<4g>", engine: :auto))
        .to eq(described_class.check("<4g>", engine: :native))
    end
  end

  it "uses Ruby diagnostics in auto mode when native is unavailable" do
    allow(Postscript::Source::NativeEngine).to receive(:available?)
      .and_return(false)

    expect(described_class.check("{ unclosed", engine: :auto))
      .to eq(described_class.check("{ unclosed", engine: :ruby))
  end

  it "propagates native availability errors" do
    allow(Postscript::Source::NativeEngine).to receive(:diagnose)
      .and_raise(Postscript::NativeEngineUnavailable, "native unavailable")

    expect { described_class.check("", engine: :native) }
      .to raise_error(Postscript::NativeEngineUnavailable, "native unavailable")
  end
end
