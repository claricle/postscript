# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Diagnostic do
  let(:entry) { Postscript::Model::Vocabulary.entry("shfill") }
  let(:attributes) do
    { code: :unsupported_level, kind: :level, severity: :error,
      message: "shfill requires level 3", offset: 10, line: 2, column: 4,
      rule: :operator, expected: ["level 2 operator"], entry: entry }
  end

  it "constructs a finding from keyword arguments" do
    diagnostic = described_class.new(**attributes)

    attributes.each do |name, value|
      expect(diagnostic.public_send(name)).to eq(value)
    end
  end

  it "exports all fields as a hash" do
    expect(described_class.new(**attributes).to_h).to eq(attributes)
  end

  it "freezes the finding" do
    diagnostic = described_class.new(**attributes)

    expect(diagnostic).to be_frozen
    expect { diagnostic.severity = :warning }.to raise_error(FrozenError)
  end

  it "copies and freezes the expected array" do
    expected = ["name"]
    diagnostic = described_class.new(expected: expected)
    expected << "number"

    expect(diagnostic.expected).to eq(["name"])
    expect(diagnostic.expected).to be_frozen
  end

  it "defaults optional fields to nil and expected to an empty frozen array" do
    diagnostic = described_class.new(code: :unknown_name, kind: :unknown_name,
                                     severity: :warning,
                                     message: "Unknown name")

    expect(diagnostic.to_h).to include(offset: nil, line: nil, column: nil,
                                       rule: nil, entry: nil, expected: [])
    expect(diagnostic.expected).to be_frozen
  end

  it "rejects positional construction" do
    expect { described_class.new(:invalid) }.to raise_error(ArgumentError)
  end

  describe Postscript::Validation::Report do
    let(:error) do
      Postscript::Diagnostic.new(code: :syntax, kind: :grammar,
                                 severity: :error, message: "Expected a name")
    end
    let(:warning) do
      Postscript::Diagnostic.new(code: :unknown_name, kind: :unknown_name,
                                 severity: :warning, message: "Unknown name")
    end

    it "is ok with no diagnostics" do
      report = described_class.new

      expect(report).to be_ok
      expect(report.errors).to eq([])
      expect(report.warnings).to eq([])
      expect(report.diagnostics).to be_frozen
    end

    it "is ok with warnings only" do
      expect(described_class.new(diagnostics: [warning])).to be_ok
    end

    it "is not ok when any diagnostic is an error" do
      expect(described_class.new(diagnostics: [warning, error])).not_to be_ok
    end

    it "filters errors and warnings in their original order" do
      report = described_class.new(diagnostics: [warning, error, warning,
                                                 error])

      expect(report.errors).to eq([error, error])
      expect(report.warnings).to eq([warning, warning])
    end

    it "copies and freezes the diagnostics array" do
      diagnostics = [warning]
      report = described_class.new(diagnostics: diagnostics)
      diagnostics << error

      expect(report).to be_frozen
      expect(report.diagnostics).to eq([warning])
      expect { report.diagnostics << error }.to raise_error(FrozenError)
      expect(report).to be_ok
    end

    it "exports diagnostics as hashes in their original order" do
      report = described_class.new(diagnostics: [warning, error])

      expect(report.to_h).to eq(diagnostics: [warning.to_h, error.to_h])
    end
  end
end
