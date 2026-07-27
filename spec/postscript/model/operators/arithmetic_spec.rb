# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Arithmetic do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  def binary_op(klass, a, b)
    stack.push(a)
    stack.push(b)
    klass.from_operands(stack)
  end

  def unary_op(klass, value)
    stack.push(value)
    klass.from_operands(stack)
  end

  describe "::Add" do
    it "pops operand_b first, then operand_a" do
      op = binary_op(described_class::Add, 2, 3)
      expect(op.operand_a).to eq(2)
      expect(op.operand_b).to eq(3)
    end

    it "declares consumes:2, produces:1" do
      expect(described_class::Add.consumes).to eq(2)
      expect(described_class::Add.produces).to eq(1)
    end
  end

  describe "::Sub" do
    it "preserves a - b ordering (a is operand_a)" do
      op = binary_op(described_class::Sub, 10, 3)
      expect(op.operand_a).to eq(10)
      expect(op.operand_b).to eq(3)
    end
  end

  describe "::Div" do
    it "is real-valued (not integer)" do
      op = binary_op(described_class::Div, 10, 4)
      expect(op.operand_a).to eq(10)
      expect(op.operand_b).to eq(4)
    end
  end

  describe "::Idiv" do
    it "coerces operands to integers" do
      op = binary_op(described_class::Idiv, 10.0, 3.0)
      expect(op.operand_a).to eq(10)
      expect(op.operand_b).to eq(3)
    end
  end

  describe "::Mod" do
    it "coerces operands to integers" do
      op = binary_op(described_class::Mod, 10.5, 3.5)
      expect(op.operand_a).to eq(10)
      expect(op.operand_b).to eq(3)
    end
  end

  %i[Neg Abs Ceiling Floor Round Truncate Sqrt Cos Sin Ln Log].each do |unary|
    describe "::#{unary}" do
      it "is unary (consumes:1, produces:1)" do
        klass = described_class.const_get(unary)
        expect(klass.consumes).to eq(1)
        expect(klass.produces).to eq(1)
      end
    end
  end

  describe "::Atan" do
    it "is binary (atan2 semantics)" do
      op = binary_op(described_class::Atan, 1, 1)
      expect(op.operand_a).to eq(1)
      expect(op.operand_b).to eq(1)
    end
  end

  describe "::Exp" do
    it "computes a ** b" do
      op = binary_op(described_class::Exp, 2, 8)
      expect(op.operand_a).to eq(2)
      expect(op.operand_b).to eq(8)
    end
  end
end
