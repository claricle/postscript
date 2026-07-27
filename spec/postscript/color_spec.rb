# frozen_string_literal: true

require "postscript"

RSpec.describe Postscript::Color do
  describe ".rgb" do
    it "converts PS [0,1] floats to integer [0,255]" do
      c = Postscript::Color.rgb(1, 0.5, 0)
      expect(c.red).to eq(255)
      expect(c.green).to eq(128)
      expect(c.blue).to eq(0)
    end
  end

  describe ".gray" do
    it "produces equal channels" do
      c = Postscript::Color.gray(0.5)
      expect(c.red).to eq(c.green)
      expect(c.green).to eq(c.blue)
      expect(c.gray?).to be true
    end
  end

  describe ".cmyk" do
    it "converts CMYK to RGB" do
      c = Postscript::Color.cmyk(0, 0, 0, 0)
      expect(c).to eq(Postscript::Color::WHITE)

      c2 = Postscript::Color.cmyk(1, 1, 1, 0)
      expect(c2).to eq(Postscript::Color::BLACK)
    end
  end

  describe ".parse" do
    it "parses #rrggbb" do
      expect(Postscript::Color.parse("#aabbcc").to_svg).to eq("#aabbcc")
    end

    it "parses #rgb (3-digit)" do
      expect(Postscript::Color.parse("#abc").to_svg).to eq("#aabbcc")
    end

    it "parses named colors" do
      expect(Postscript::Color.parse("red")).to eq(Postscript::Color.rgb(1, 0, 0))
    end

    it "returns nil for none" do
      expect(Postscript::Color.parse("none")).to be_nil
    end
  end

  describe "#to_ps_rgb" do
    it "emits space-separated [0,1] floats" do
      c = Postscript::Color.rgb(1, 0, 0)
      expect(c.to_ps_rgb).to eq("1 0 0")
    end
  end

  describe "#to_svg" do
    it "emits #rrggbb" do
      expect(Postscript::Color.rgb(0.5, 0.5, 0.5).to_svg).to eq("#808080")
    end
  end

  describe "value equality" do
    it "treats equal colors as ==" do
      expect(Postscript::Color.rgb(1, 0, 0)).to eq(Postscript::Color.rgb(1, 0, 0))
    end
  end
end
