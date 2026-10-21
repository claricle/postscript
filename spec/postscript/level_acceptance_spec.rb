# frozen_string_literal: true

require "spec_helper"

# Acceptance row in docs/plans/issue-4-native-parser.md:
# "A Level 3-only operator remains syntactically accepted in the same
# grammar and is marked as unavailable by Level 1/2 metadata validation."
#
# The AST builder currently drops << >> dictionaries from Program#body,
# so the plan's `/s << /ShadingType 2 >> def s shfill` would not keep the
# shading dictionary. This source keeps shfill (Level 3 only) as a top-level
# operator next to moveto (Level 1), so Level 1/2 checks must flag only shfill.
# rubocop:disable-next RSpec/DescribeClass
RSpec.describe "postscript language level acceptance" do
  let(:source) { "0 0 moveto shfill" }
  let(:ruby_program) { Postscript.parse(source, engine: :ruby) }
  let(:expected_violations) do
    [Postscript::LevelViolation.new(keyword: "shfill", level: 3)]
  end

  def violations(program, level)
    Postscript::Validation::Levels.violations(program, level: level)
  end

  context "with the Ruby engine" do
    it "accepts the syntax without raising" do
      expect { ruby_program }.not_to raise_error
    end

    [1, 2].each do |level|
      it "reports only shfill as unavailable at level #{level}" do
        expect(violations(ruby_program, level)).to eq(expected_violations)
      end
    end

    it "allows all operators at level 3" do
      expect(violations(ruby_program, 3)).to eq([])
    end
  end

  context "with the native engine" do
    let(:native_program) { Postscript.parse(source, engine: :native) }

    before do
      unless Postscript::Source::NativeEngine.available?
        skip "native engine not available"
      end
    end

    it "accepts the syntax without raising" do
      expect { native_program }.not_to raise_error
    end

    it "serializes identically to the Ruby program" do
      expect(Postscript.serialize(native_program))
        .to eq(Postscript.serialize(ruby_program))
    end

    [1, 2, 3].each do |level|
      it "matches Ruby metadata validation at level #{level}" do
        ruby_violations = violations(ruby_program, level)
        expect(violations(native_program, level)).to eq(ruby_violations)
      end
    end

    [1, 2].each do |level|
      it "reports only shfill as unavailable at level #{level}" do
        expect(violations(native_program, level)).to eq(expected_violations)
      end
    end

    it "allows all operators at level 3" do
      expect(violations(native_program, 3)).to eq([])
    end
  end
end
