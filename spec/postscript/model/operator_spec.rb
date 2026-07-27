# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operator do
  before(:all) { Postscript::Model::Operators.load_all! }

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
