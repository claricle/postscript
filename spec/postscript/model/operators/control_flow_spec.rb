# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::ControlFlow do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::If" do
    it "pops body then condition" do
      body = Postscript::Model::Literals::Procedure.new([])
      stack.push(true)
      stack.push(body)
      op = described_class::If.from_operands(stack)
      expect(op.condition).to be true
      expect(op.body).to be(body)
    end
  end

  describe "::Ifelse" do
    it "pops else_body, if_body, condition" do
      if_body = Postscript::Model::Literals::Procedure.new([])
      else_body = Postscript::Model::Literals::Procedure.new([])
      stack.push(false)
      stack.push(if_body)
      stack.push(else_body)
      op = described_class::Ifelse.from_operands(stack)
      expect(op.condition).to be false
      expect(op.if_body).to be(if_body)
      expect(op.else_body).to be(else_body)
    end
  end

  describe "::Repeat" do
    it "pops body then count" do
      body = Postscript::Model::Literals::Procedure.new([])
      stack.push(5)
      stack.push(body)
      op = described_class::Repeat.from_operands(stack)
      expect(op.count).to eq(5)
      expect(op.body).to be(body)
    end
  end

  describe "::For" do
    it "pops body, limit, increment, initial" do
      body = Postscript::Model::Literals::Procedure.new([])
      stack.push(0)      # initial
      stack.push(1)      # increment
      stack.push(10)     # limit
      stack.push(body)   # body (top)
      op = described_class::For.from_operands(stack)
      expect(op.initial).to eq(0)
      expect(op.increment).to eq(1)
      expect(op.limit).to eq(10)
    end
  end

  describe "::Exit / ::Quit" do
    it "are zero-arity" do
      expect(described_class::Exit.consumes).to eq(0)
      expect(described_class::Quit.consumes).to eq(0)
    end
  end
end
