# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Color do
  before(:all) { Postscript::Model::Operators.load_all! }

  let(:stack) { Postscript::Source::OperandStack.new }

  describe "::Setgray" do
    it "pops the gray level" do
      stack.push(0.5)
      op = described_class::Setgray.from_operands(stack)
      expect(op.gray).to eq(0.5)
    end
  end

  describe "::Setrgbcolor" do
    it "pops blue, green, red in that order" do
      stack.push(0.1)  # r
      stack.push(0.2)  # g
      stack.push(0.3)  # b (top)
      op = described_class::Setrgbcolor.from_operands(stack)
      expect(op.red).to eq(0.1)
      expect(op.green).to eq(0.2)
      expect(op.blue).to eq(0.3)
    end
  end

  describe "::Setcmykcolor" do
    it "pops key, yellow, magenta, cyan in that order" do
      stack.push(0.1); stack.push(0.2); stack.push(0.3); stack.push(0.4)
      op = described_class::Setcmykcolor.from_operands(stack)
      expect(op.cyan).to eq(0.1)
      expect(op.magenta).to eq(0.2)
      expect(op.yellow).to eq(0.3)
      expect(op.key).to eq(0.4)
    end
  end

  describe "::Sethsbcolor" do
    it "pops brightness, saturation, hue in that order" do
      stack.push(0.1); stack.push(0.2); stack.push(0.3)
      op = described_class::Sethsbcolor.from_operands(stack)
      expect(op.hue).to eq(0.1)
      expect(op.saturation).to eq(0.2)
      expect(op.brightness).to eq(0.3)
    end
  end
end
