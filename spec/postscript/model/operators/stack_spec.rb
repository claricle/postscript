# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Stack do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Pop" do
    it "registers as 'pop' with consumes:1, produces:0" do
      klass = described_class::Pop
      expect(klass.consumes).to eq(1)
      expect(klass.produces).to eq(0)
    end

    it "pops one operand" do
      stack.push(42)
      described_class::Pop.from_operands(stack)
      expect(stack.empty?).to be true
    end
  end

  describe "::Exch" do
    it "pops two operands (consumes:2, produces:2)" do
      stack.push(1)
      stack.push(2)
      described_class::Exch.from_operands(stack)
      expect(stack.length).to eq(0)
    end
  end

  describe "::Dup" do
    it "pops one operand (consumes:1, produces:2)" do
      stack.push("x")
      described_class::Dup.from_operands(stack)
      expect(stack.empty?).to be true
    end
  end

  describe "::Index" do
    it "pops the index, exposes it as attr" do
      stack.push(3)
      op = described_class::Index.from_operands(stack)
      expect(op.index).to eq(3)
    end
  end

  describe "::Roll" do
    it "pops positions then count from the stack" do
      stack.push(2)  # count
      stack.push(1)  # positions (top)
      op = described_class::Roll.from_operands(stack)
      expect(op.count).to eq(2)
      expect(op.positions).to eq(1)
    end
  end

  describe "::Clear" do
    it "is a no-arity op" do
      expect(described_class::Clear.consumes).to eq(0)
      expect(described_class::Clear.produces).to eq(0)
    end
  end

  describe "::Count" do
    it "produces 1 (the count)" do
      expect(described_class::Count.consumes).to eq(0)
      expect(described_class::Count.produces).to eq(1)
    end
  end
end
