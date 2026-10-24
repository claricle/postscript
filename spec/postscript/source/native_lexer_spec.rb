# frozen_string_literal: true

require "spec_helper"

# NativeLexer must produce exactly Lexer's tokens. Token#== compares
# strings, which ignores encodings for ASCII-only values, so the
# encodings are compared as well.
RSpec.describe Postscript::Source::NativeLexer do
  before do
    skip "parsanol native engine unavailable" unless
      Postscript::Source::NativeEngine.available?
  end

  let(:lexer) { Postscript::Source::Lexer }

  def outcome(source, &tokenize)
    yield(source).map do |t|
      [t.type, t.value, t.value.encoding, t.line, t.column, t.literal]
    end
  rescue Postscript::Error => e
    [e.class, e.message, e.source_position]
  end

  def ruby_outcome(source)
    outcome(source) { |s| lexer.tokenize(s) }
  end

  # Native tokens, and whether the grammar accepted the source (Lexer
  # is not called) or rejected it (Lexer tokenizes it instead).
  def native_outcome(source)
    calls = 0
    allow(lexer).to receive(:tokenize).and_wrap_original do |original, *args|
      calls += 1
      original.call(*args)
    end
    result = outcome(source) { |s| described_class.tokenize(s) }
    [result, calls.zero?]
  end

  def expect_parity(source, accepted: true)
    result, grammar_accepted = native_outcome(source)
    expect(result).to eq(ruby_outcome(source))
    expect(grammar_accepted).to be(accepted)
  end

  describe "sources the grammar accepts" do
    it "positions adjacent delimiters and words at their opening byte" do
      source = "{1}[2]<<>>name"
      expect_parity(source)

      tokens = described_class.tokenize(source)
      expected = [
        ["{", 1, 1], ["1", 1, 2], ["}", 1, 3],
        ["[", 1, 4], ["2", 1, 5], ["]", 1, 6],
        ["<<", 1, 7], [">>", 1, 9], ["name", 1, 11]
      ]
      expect(tokens.map { |t| [t.value, t.line, t.column] }).to eq(expected)
    end

    it "counts delimiter columns in bytes across LF and CRLF lines" do
      source = "(é){}\r\n[]\n(é)<<\n>>"
      expect_parity(source)

      tokens = described_class.tokenize(source)
      expected = [
        ["é".b, 1, 1], ["{", 1, 5], ["}", 1, 6],
        ["[", 2, 1], ["]", 2, 2],
        ["é".b, 3, 1], ["<<", 3, 5], [">>", 4, 1]
      ]
      expect(tokens.map { |t| [t.value, t.line, t.column] }).to eq(expected)
    end

    {
      "every token type" =>
        "%!PS\n%%Title: t\n/a 1 def { 2 3 add } [ (s) <4f 4b> ] " \
        "<< /K 16#FF >> -.5 6.02E23 x",
      "LF, CRLF and CR line ends" => "1 2\r\n3\n\n4\r5 %c\r6\n7",
      "string escapes" =>
        "(a\\n\\r\\t\\b\\f\\\\\\(\\)\\q\\101\\7\\0123 (nested) \\\nx)",
      "a hex string with whitespace" => "< 4f\n4B\t00 >",
      "DSC comments inside composites" => "{ %%Page: 1\n 1 } [ %%A\n ]",
      "a DSC comment ending at CR" => "%%A\rB 1\n2",
      "an empty DSC comment" => "%%\n1",
      "a %% ending the source" => "1 %%",
      "VT and NUL as whitespace" => "1\v2\x003",
      "backslash and empty literal names" => "\\Name //x / y",
      "empty and nested composites" => "[[] {} << >>] { % }\n }",
      "word boundaries" => "1e 1.5e 123abc +-1 . - 1# 16#FF +5 5. .5e3",
      "an empty source" => "",
      "only whitespace and comments" => " \n% c\n\t",
    }.each do |name, source|
      it("tokenizes #{name}") { expect_parity(source) }
    end

    it "keeps byte positions and values for UTF-8 sources" do
      expect_parity("(café) /né café %%Té\n1")
    end

    it "keeps byte positions and values for non-UTF-8 sources" do
      expect_parity("(caf\xE9) /n\xE9 %%T\xE9\n\xE9".b)
    end
  end

  describe "sources the grammar rejects" do
    {
      "an unterminated string" => "1 (abc",
      "an unterminated hex string" => "<4f",
      "a stray )" => "1 ) 2",
      "non-hex bytes in a hex string" => "<4g>",
      "a lone >" => "1 > 2",
      "an unclosed array" => "[1 2",
      "ASCII85 text" => "<~abc~>",
    }.each do |name, source|
      it("leaves #{name} to Lexer") { expect_parity(source, accepted: false) }
    end
  end

  describe "the fixture corpus" do
    def self.fixtures
      Dir[File.join(__dir__, "../../fixtures/**/*.{ps,eps}")]
    end

    def self.fixture_name(path)
      path.split("fixtures/").last
    end

    # Its "[% ... ]" comments out the "]", so the array never closes.
    let(:unbalanced) { %w[ps2svg/new_tests/11_level2_level3.ps] }

    fixtures.each do |path|
      it "tokenizes #{fixture_name(path)} as Lexer does" do
        accepted = !unbalanced.include?(self.class.fixture_name(path))
        expect_parity(File.binread(path), accepted: accepted)
      end
    end

    it "builds the same programs" do
      self.class.fixtures.map { |path| File.read(path) }.each do |source|
        ruby = Postscript.parse(source)
        native = Postscript.parse(source, engine: :native)
        expect(Postscript.serialize(native)).to eq(Postscript.serialize(ruby))
      rescue Postscript::SyntaxError
        expect { Postscript.parse(source, engine: :native) }
          .to raise_error(Postscript::SyntaxError)
      end
    end
  end

  describe "generated programs" do
    def words
      %w[1 -2 +3.5 .5 6. 1e5 -1.5E-3 16#FF 36#Z moveto 123abc . - + a1] +
        ["\xC3\xA9t\xC3\xA9", "caf\xE9".b]
    end

    def strings
      ["()", "(a b)", "(\\n\\101\\\\)", "(x (y) z)", "(%not)", "(\\\n)",
       "(\xE9)".b]
    end

    def trivia
      [" ", "\n", "\r\n", "\r", "\t", "\v", "\0", " % c\n", "\n%%DSC x\n"]
    end

    def hex_strings
      ["<4f>", "<4B 00>", "< >"]
    end

    def literal_names
      ["/n1", "\\n2", "/n3", "/"]
    end

    def object(rng, depth)
      pick = rng.rand(depth.positive? ? 6 : 5)
      return composite(rng, depth - 1) if pick == 5

      [words, words, strings, hex_strings, literal_names][pick]
        .sample(random: rng).b
    end

    def composite(rng, depth)
      open, close = [%w[[ ]], %w[{ }], %w[<< >>]].sample(random: rng)
      "#{open}#{program(rng, depth)}#{close}"
    end

    def program(rng, depth)
      Array.new(rng.rand(0..6)) do
        trivia.sample(random: rng).b + object(rng, depth)
      end.join(trivia.sample(random: rng).b)
    end

    it "tokenizes 300 random valid programs as Lexer does" do
      rng = Random.new(20_261_020)
      300.times { expect_parity(program(rng, 3)) }
    end
  end
end
