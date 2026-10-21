# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operator do
  describe "language_level" do
    it "returns level 1 for the Moveto class" do
      expect(Postscript::Model::Operators::Path::Moveto.language_level).to eq(1)
    end

    it "returns level 2 for a Setcmykcolor instance" do
      operator = Postscript::Model::Operators::Color::Setcmykcolor.new(
        cyan: 0, magenta: 0, yellow: 0, key: 1,
      )
      expect(operator.language_level).to eq(2)
    end

    it "looks up known vocabulary for an unknown operator class" do
      operator = Postscript::Model::UnknownOperator.new(keyword: "shfill")
      expect(operator.language_level).to eq(3)
    end

    it "returns nil for a keyword absent from the vocabulary" do
      operator = Postscript::Model::UnknownOperator.new(keyword: "nonsense")
      expect(operator.language_level).to be_nil
    end

    it "returns nil for a procedure named after an operator" do
      procedure = Postscript::Model::Literals::Procedure.new
      invocation = Postscript::Model::InvokeProcedure.new(
        name: "shfill", procedure: procedure,
      )
      expect(invocation.language_level).to be_nil
    end

    it "provides a language level for every registered operator class" do
      classes = Postscript::Model::Operators.keywords.map do |keyword|
        Postscript::Model::Operators[keyword]
      end.uniq
      missing = classes.select { |klass| klass.language_level.nil? }.map(&:name)
      expect(missing).to be_empty
    end

    it "returns nil for the unregistered base class" do
      expect(described_class.language_level).to be_nil
    end
  end

  describe "consumes / produces" do
    it "Font::Findfont has consumes=1, produces=1" do
      f = Postscript::Model::Operators::Font::Findfont
      expect([f.consumes, f.produces]).to eq([1, 1])
    end

    it "Stack::Exch has consumes=2, produces=2" do
      s = Postscript::Model::Operators::Stack::Exch
      expect([s.consumes, s.produces]).to eq([2, 2])
    end

    it "Arithmetic::Add has consumes=2, produces=1" do
      a = Postscript::Model::Operators::Arithmetic::Add
      expect([a.consumes, a.produces]).to eq([2, 1])
    end

    it "Path::Moveto has consumes=0 by default (parser uses pop_number in from_operands)" do
      m = Postscript::Model::Operators::Path::Moveto
      expect(m.consumes).to eq(0)
    end
  end

  describe "Computed sentinel" do
    it "carries the operator keyword" do
      c = Postscript::Model::Computed.new(operator_keyword: "add")
      expect(c.operator_keyword).to eq("add")
      expect(c.to_s).to include("add")
    end
  end
end
