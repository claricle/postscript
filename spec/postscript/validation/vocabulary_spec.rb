# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Validation::Vocabulary do
  def unknown_names(source)
    described_class.unknown_names(Postscript.parse(source))
  end

  def procedure(keyword)
    Postscript::Model::Literals::Procedure.new(
      [Postscript::Model::UnknownOperator.new(keyword: keyword)],
    )
  end

  describe ".unknown_names" do
    it "reports names absent from the vocabulary" do
      expect(unknown_names("foo bar moveto")).to eq(%w[foo bar])
    end

    it "allows names bound with def" do
      expect(unknown_names("/x 5 def x")).to eq([])
    end

    it "allows user procedure calls" do
      expect(unknown_names("/p {1} def p")).to eq([])
    end

    it "finds names inside procedure bodies" do
      expect(unknown_names("/p { foo } def p")).to eq(["foo"])
    end

    it "walks nested containers in source order without duplicates" do
      expect(unknown_names("bar { foo [ { baz bar } ] } foo"))
        .to eq(%w[bar foo baz])
    end

    # Like Levels, build dictionaries directly: the parser does not put
    # dictionary literals into Program#body.
    it "walks dictionary keys before values in insertion order" do
      dictionary = Postscript::Model::Literals::Dictionary.new(
        procedure("foo") => procedure("bar"),
        "plain_key" => procedure("baz"),
      )
      program = Postscript::Model::Program.new(body: [dictionary])

      expect(described_class.unknown_names(program)).to eq(%w[foo bar baz])
    end

    it "allows vocabulary entries without registered operator classes" do
      body = %w[shfill moveto].map do |keyword|
        Postscript::Model::UnknownOperator.new(keyword: keyword)
      end
      program = Postscript::Model::Program.new(body: body)

      expect(described_class.unknown_names(program)).to eq([])
    end

    it "allows bindings referenced inside procedures before their definition" do
      expect(unknown_names("/p { x p } def /x 5 def p")).to eq([])
    end

    it "collects bindings inside nested bodies" do
      expect(unknown_names("{ /x 5 def x foo }")).to eq(["foo"])
    end

    it "does not treat literal names as unknown operators or bindings" do
      expect(unknown_names("/foo foo")).to eq(["foo"])
    end

    it "returns a frozen result" do
      expect(unknown_names("foo")).to be_frozen
      expect(unknown_names("")).to be_frozen
    end
  end
end
