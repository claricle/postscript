# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Dictionary do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Dict" do
    it "pops 1 (size hint), produces 1 (the dict)" do
      stack.push(4)
      described_class::Dict.from_operands(stack)
      expect(stack.empty?).to be true
      expect(described_class::Dict.consumes).to eq(1)
      expect(described_class::Dict.produces).to eq(1)
    end
  end

  describe "::Begin" do
    it "pops 1 (the dict)" do
      stack.push({})
      described_class::Begin.from_operands(stack)
      expect(stack.empty?).to be true
    end
  end

  describe "::End" do
    it "is zero-arity" do
      expect(described_class::End.consumes).to eq(0)
    end
  end

  describe "::Def" do
    it "pops value then key" do
      stack.push(Postscript::Model::Literals::Name.new("foo", literal: true))
      stack.push(42)
      op = described_class::Def.from_operands(stack)
      expect(op.key).to be_a(Postscript::Model::Literals::Name)
      expect(op.value).to eq(42)
    end
  end

  describe "::Load" do
    it "pops one key, produces 1" do
      stack.push("foo")
      op = described_class::Load.from_operands(stack)
      expect(op.key).to eq("foo")
      expect(described_class::Load.produces).to eq(1)
    end
  end

  describe "::Currentdict / ::Countdictstack" do
    it "produce 1 each" do
      expect(described_class::Currentdict.produces).to eq(1)
      expect(described_class::Countdictstack.produces).to eq(1)
    end
  end
end
