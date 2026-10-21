# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Validation::Levels do
  def violations(source, level:)
    described_class.violations(Postscript.parse(source), level: level)
  end

  def violation(keyword, level)
    Postscript::LevelViolation.new(keyword: keyword, level: level)
  end

  def procedure(*keywords)
    Postscript::Model::Literals::Procedure.new(
      keywords.map { |k| Postscript::Model::UnknownOperator.new(keyword: k) },
    )
  end

  describe ".violations" do
    [1, 2].each do |level|
      it "reports shfill at level #{level}" do
        expect(violations("shfill", level: level))
          .to eq([violation("shfill", 3)])
      end
    end

    it "allows shfill at level 3" do
      expect(violations("shfill", level: 3)).to eq([])
    end

    it "reports registered level 2 operators at level 1" do
      expect(violations("0 0 0 1 setcmykcolor", level: 1))
        .to eq([violation("setcmykcolor", 2)])
    end

    [2, 3].each do |level|
      it "allows setcmykcolor at level #{level}" do
        expect(violations("0 0 0 1 setcmykcolor", level: level)).to eq([])
      end
    end

    it "walks nested procedures and arrays in source order" do
      source = "{ shfill } [ { 0 0 0 1 setcmykcolor } ]"

      expect(violations(source, level: 1))
        .to eq([violation("shfill", 3), violation("setcmykcolor", 2)])
    end

    # The parser never puts a << >> literal into Program#body, so the
    # dictionary is built directly.
    it "walks dictionary keys before values in insertion order" do
      dictionary = Postscript::Model::Literals::Dictionary.new(
        procedure("shfill") => procedure("rectfill"),
        "plain_key" => procedure("shfill"),
      )
      program = Postscript::Model::Program.new(body: [dictionary])

      expect(described_class.violations(program, level: 1)).to eq(
        [violation("shfill", 3), violation("rectfill", 2),
         violation("shfill", 3)],
      )
    end

    it "allows user procedure calls" do
      expect(violations("/myproc { 1 } def myproc", level: 1)).to eq([])
    end

    it "allows user procedures shadowing vocabulary operators" do
      expect(violations("/shfill { } def shfill", level: 1)).to eq([])
    end

    it "checks a procedure body only where it is defined" do
      expect(violations("/myproc { shfill } def myproc", level: 1))
        .to eq([violation("shfill", 3)])
    end

    it "allows level 1 operators at level 1" do
      source = "0 0 moveto 10 10 lineto stroke"

      expect(violations(source, level: 1)).to eq([])
    end

    it "ignores names absent from the vocabulary" do
      expect(violations("nonsense_12345", level: 1)).to eq([])
    end

    [0, 4, "2"].each do |level|
      it "rejects level #{level.inspect}" do
        expect { violations("", level: level) }.to raise_error(
          ArgumentError, "level must be 1, 2 or 3, got #{level.inspect}"
        )
      end
    end

    it "freezes the result and its violations" do
      result = violations("shfill", level: 1)

      expect(result).to be_frozen
      expect(result).to all(be_frozen)
    end

    it "freezes an empty result" do
      expect(violations("", level: 1)).to be_frozen
    end
  end
end
