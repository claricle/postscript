# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Boolean do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::True" do
    it "is a zero-arity constant operator that produces 1" do
      expect(described_class::True.consumes).to eq(0)
      expect(described_class::True.produces).to eq(1)
    end
  end

  describe "::False" do
    it "is a zero-arity constant operator that produces 1" do
      expect(described_class::False.consumes).to eq(0)
      expect(described_class::False.produces).to eq(1)
    end
  end

  %i[Eq Ne Gt Ge Lt Le].each do |cmp|
    describe "::#{cmp}" do
      it "is binary comparison" do
        klass = described_class.const_get(cmp)
        expect(klass.consumes).to eq(2)
        expect(klass.produces).to eq(1)
      end
    end
  end

  describe "::And" do
    it "pops two operands" do
      stack.push(true)
      stack.push(false)
      op = described_class::And.from_operands(stack)
      expect(op.operand_a).to eq(true)
      expect(op.operand_b).to eq(false)
    end
  end

  describe "::Not" do
    it "is unary" do
      stack.push(true)
      op = described_class::Not.from_operands(stack)
      expect(op.operand).to eq(true)
      expect(described_class::Not.consumes).to eq(1)
    end
  end

  describe "::Bitshift" do
    it "pops shift then value (value is bottom)" do
      stack.push(8)    # value
      stack.push(2)    # shift (top)
      op = described_class::Bitshift.from_operands(stack)
      expect(op.operand).to eq(8)
      expect(op.shift).to eq(2)
    end
  end
end
