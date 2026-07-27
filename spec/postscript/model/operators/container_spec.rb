# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Container do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Length" do
    it "pops the collection, produces 1" do
      stack.push([1, 2, 3])
      described_class::Length.from_operands(stack)
      expect(stack.empty?).to be true
      expect(described_class::Length.produces).to eq(1)
    end
  end

  describe "::Get" do
    it "pops key then collection" do
      stack.push({ "a" => 1 })
      stack.push("a")
      op = described_class::Get.from_operands(stack)
      expect(op.key).to eq("a")
    end
  end

  describe "::Put" do
    it "pops value, key, collection" do
      stack.push({})
      stack.push("k")
      stack.push(99)
      op = described_class::Put.from_operands(stack)
      expect(op.key).to eq("k")
      expect(op.value).to eq(99)
    end
  end

  describe "::Search" do
    it "pops pattern then target" do
      stack.push("hello world")
      stack.push("world")
      op = described_class::Search.from_operands(stack)
      expect(op.target).to eq("hello world")
      expect(op.pattern).to eq("world")
    end
  end

  describe "::String" do
    it "pops count and produces a buffer" do
      stack.push(10)
      op = described_class::String.from_operands(stack)
      expect(op.count).to eq(10)
      expect(described_class::String.produces).to eq(1)
    end
  end
end
