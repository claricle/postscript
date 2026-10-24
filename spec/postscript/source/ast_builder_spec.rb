# frozen_string_literal: true

require "postscript"

RSpec.describe Postscript::Source::AstBuilder do
  def parse(src)
    Postscript::Source.parse(src)
  end

  {
    "{ { 1 }" => [3, "unbalanced procedure braces"],
    "[ [1]" => [3, "unbalanced array_close"],
    "<< /key << /nested 1 >>" => [3, "unbalanced dict_close"],
  }.each do |source, (column, message)|
    it "positions #{message} at the opening token" do
      expect { parse("% heading\n  #{source}") }
        .to raise_error(Postscript::SyntaxError, message) { |error|
          expect(error.source_position).to eq([2, column])
        }
    end
  end

  it "finds each adjacent token by its exact line and byte column" do
    tokens = Postscript::Source::Lexer.tokenize("{1}[2]<<>>name\n{3}[4]<<>>name")
    builder = described_class.new(tokens)
    columns = [1, 2, 3, 4, 5, 6, 7, 9, 11]
    positions = [1, 2].flat_map do |line|
      columns.map { |column| [line, column] }
    end

    tokens.each_with_index do |token, index|
      expect(builder.send(:token_position, token)).to eq(positions[index])
      expect(builder.send(:find_index, positions[index])).to eq(index)
    end
    expect(builder.send(:find_index, [1, 8])).to eq(tokens.length)
  end

  it "builds adjacent composites at repeated columns on different lines" do
    program = parse("{1}{2}\n[3][4]")

    expect(program.body.map { |node| node.map(&:value) }).to eq([[1], [2], [3], [4]])
  end

  it "captures BoundingBox in header" do
    program = parse("%!PS-Adobe-3.0 EPSF-3.0\n%%BoundingBox: 0 0 100 100\nshowpage\n")
    expect(program.header.bounding_box).to eq([0.0, 0.0, 100.0, 100.0])
  end

  it "captures HiResBoundingBox when present" do
    program = parse("%%HiResBoundingBox: 0.0 0.0 99.5 99.5\n")
    expect(program.header.hires_bounding_box).to eq([0.0, 0.0, 99.5, 99.5])
  end

  it "builds Moveto from operands" do
    program = parse("10 20 moveto\n")
    op = program.body.last
    expect(op).to be_a(Postscript::Model::Operators::Path::Moveto)
    expect(op.x).to eq(10)
    expect(op.y).to eq(20)
  end

  it "builds Setrgbcolor from operands" do
    program = parse("1 0 0 setrgbcolor\n")
    op = program.body.last
    expect(op.red).to eq(1)
    expect(op.green).to eq(0)
    expect(op.blue).to eq(0)
  end

  it "captures Procedure as a literal node" do
    program = parse("{ 10 20 moveto }\n")
    proc = program.body.first
    expect(proc).to be_a(Postscript::Model::Literals::Procedure)
    # Procedure body has Number, Number, Moveto in source order.
    expect(proc.body.length).to eq(3)
    expect(proc.body.last).to be_a(Postscript::Model::Operators::Path::Moveto)
  end

  it "captures InvokeProcedure when def'd name is invoked" do
    program = parse("/foo { 10 10 moveto } def\nfoo\n")
    inv = program.body.last
    expect(inv).to be_a(Postscript::Model::InvokeProcedure)
    expect(inv.name).to eq("foo")
  end

  it "preserves unknown operators" do
    program = parse("nonsense_operator\n")
    op = program.body.first
    expect(op).to be_a(Postscript::Model::UnknownOperator)
    expect(op.keyword).to eq("nonsense_operator")
  end
end
