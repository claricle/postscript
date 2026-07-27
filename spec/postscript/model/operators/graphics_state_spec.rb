# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::GraphicsState do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Gsave / ::Grestore / ::Grestoreall" do
    it "are zero-arity" do
      expect(described_class::Gsave.consumes).to eq(0)
      expect(described_class::Grestore.consumes).to eq(0)
      expect(described_class::Grestoreall.consumes).to eq(0)
    end
  end

  describe "::Setlinewidth" do
    it "pops one number" do
      stack.push(2.5)
      op = described_class::Setlinewidth.from_operands(stack)
      expect(op.width).to eq(2.5)
    end
  end

  describe "::Setlinecap" do
    it "coerces to integer cap code" do
      stack.push(1.0)
      op = described_class::Setlinecap.from_operands(stack)
      expect(op.cap_code).to eq(1)
    end
  end

  describe "::Setlinejoin" do
    it "coerces to integer join code" do
      stack.push(2)
      op = described_class::Setlinejoin.from_operands(stack)
      expect(op.join_code).to eq(2)
    end
  end

  describe "::Setdash" do
    it "pops offset then pattern (an array)" do
      stack.push([5.0, 3.0])
      stack.push(1.0)
      op = described_class::Setdash.from_operands(stack)
      expect(op.pattern).to eq([5.0, 3.0])
      expect(op.offset).to eq(1.0)
    end
  end
end
