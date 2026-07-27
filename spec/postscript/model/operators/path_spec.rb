# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Path do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Moveto" do
    it "pops y first then x" do
      stack.push(10)  # x
      stack.push(20)  # y (top)
      op = described_class::Moveto.from_operands(stack)
      expect(op.x).to eq(10)
      expect(op.y).to eq(20)
    end
  end

  describe "::Lineto" do
    it "has same shape as Moveto" do
      stack.push(5)
      stack.push(7)
      op = described_class::Lineto.from_operands(stack)
      expect(op.x).to eq(5)
      expect(op.y).to eq(7)
    end
  end

  describe "::Rmoveto / ::Rlineto" do
    it "exposes dx/dy" do
      stack.push(3); stack.push(4)
      op = described_class::Rmoveto.from_operands(stack)
      expect(op.dx).to eq(3)
      expect(op.dy).to eq(4)
    end
  end

  describe "::Curveto" do
    it "pops 6 operands in reverse source order" do
      stack.push(1); stack.push(2)   # x1 y1
      stack.push(3); stack.push(4)   # x2 y2
      stack.push(5); stack.push(6)   # x3 y3 (top)
      op = described_class::Curveto.from_operands(stack)
      expect([op.x1, op.y1]).to eq([1, 2])
      expect([op.x2, op.y2]).to eq([3, 4])
      expect([op.x3, op.y3]).to eq([5, 6])
    end
  end

  describe "::Arc" do
    it "pops angle2, angle1, radius, y, x in that order" do
      stack.push(50); stack.push(50)  # x y
      stack.push(25)                  # radius
      stack.push(0); stack.push(360)  # angle1 angle2 (top)
      op = described_class::Arc.from_operands(stack)
      expect(op.x).to eq(50)
      expect(op.y).to eq(50)
      expect(op.radius).to eq(25)
      expect(op.angle1).to eq(0)
      expect(op.angle2).to eq(360)
    end
  end

  describe "::Newpath / ::Closepath" do
    it "are zero-arity" do
      expect(described_class::Newpath.consumes).to eq(0)
      expect(described_class::Closepath.consumes).to eq(0)
    end
  end

  describe "::Currentpoint" do
    it "is zero-arity (consumes nothing)" do
      expect(described_class::Currentpoint.consumes).to eq(0)
    end
  end
end
