# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Transformations do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Translate" do
    it "pops ty then tx" do
      stack.push(10); stack.push(20)
      op = described_class::Translate.from_operands(stack)
      expect(op.tx).to eq(10)
      expect(op.ty).to eq(20)
    end
  end

  describe "::Scale" do
    it "pops sy then sx" do
      stack.push(2); stack.push(3)
      op = described_class::Scale.from_operands(stack)
      expect(op.sx).to eq(2)
      expect(op.sy).to eq(3)
    end
  end

  describe "::Rotate" do
    it "pops one angle" do
      stack.push(45)
      op = described_class::Rotate.from_operands(stack)
      expect(op.angle).to eq(45)
    end
  end

  describe "::Concat" do
    it "pops a matrix (array of 6)" do
      stack.push([1, 0, 0, 1, 5, 7])
      op = described_class::Concat.from_operands(stack)
      expect(op.matrix).to eq([1, 0, 0, 1, 5, 7])
    end
  end

  describe "::Matrix" do
    it "produces 1 (the identity matrix as an array)" do
      expect(described_class::Matrix.produces).to eq(1)
      expect(described_class::Matrix.consumes).to eq(0)
    end
  end
end
