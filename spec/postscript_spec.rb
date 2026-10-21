# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript do
  describe ".level_violations" do
    let(:program) { described_class.parse("0 0 moveto shfill") }
    let(:header_program) do
      described_class.parse("%!PS\n%%LanguageLevel: 2\n0 0 moveto shfill\n")
    end
    let(:shfill_violation) do
      Postscript::LevelViolation.new(keyword: "shfill", level: 3)
    end

    it "returns the validator's violations" do
      result = described_class.level_violations(program, level: 2)

      expect(result).to eq(
        Postscript::Validation::Levels.violations(program, level: 2),
      )
      expect(result).to eq([shfill_violation])
    end

    it "uses the header language level by default" do
      expect(described_class.level_violations(header_program))
        .to eq([shfill_violation])
    end

    it "defaults to level 3 without a header" do
      expect(described_class.level_violations(program)).to eq([])
    end

    it "passes an explicit level through to override the header" do
      expect(described_class.level_violations(header_program, level: 3))
        .to eq([])
    end

    it "rejects an explicit level outside 1..3" do
      expect do
        described_class.level_violations(header_program, level: 4)
      end.to raise_error(ArgumentError)
    end
  end
end
