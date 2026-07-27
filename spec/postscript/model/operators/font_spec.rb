# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Font do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Findfont" do
    it "pops the font name, produces 1" do
      stack.push("Helvetica")
      op = described_class::Findfont.from_operands(stack)
      expect(op.name).to eq("Helvetica")
      expect(described_class::Findfont.produces).to eq(1)
    end
  end

  describe "::Scalefont" do
    it "pops size then font" do
      stack.push("font_ref")
      stack.push(14)
      op = described_class::Scalefont.from_operands(stack)
      expect(op.size).to eq(14)
      expect(op.font).to eq("font_ref")
    end
  end

  describe "::Setfont" do
    it "pops the font ref" do
      stack.push("font_ref")
      op = described_class::Setfont.from_operands(stack)
      expect(op.font).to eq("font_ref")
    end
  end

  describe "::Show" do
    it "pops the text" do
      stack.push("Hello")
      op = described_class::Show.from_operands(stack)
      expect(op.text).to eq("Hello")
    end
  end
end
