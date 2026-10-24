# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Validator do
  def validate(source, **options)
    Postscript.validate(source, engine: :ruby, **options)
  end

  it "reports a level error with its vocabulary entry and target" do
    report = validate("0 0 moveto shfill", level: 1)

    expect(report).to be_a(Postscript::Validation::Report)
    expect(report).not_to be_ok
    expect(report.diagnostics.size).to eq(1)
    expect(report.errors.first.to_h).to include(
      code: :level, kind: :level, severity: :error,
      message: "shfill is Level 3; this program targets Level 1",
      entry: Postscript::Model::Vocabulary.entry("shfill")
    )
    expect(report.errors.first.entry).to have_attributes(level: 3,
                                                         source: :override)
  end

  it "accepts Level 3 operators at Level 3" do
    report = validate("0 0 moveto shfill", level: 3)

    expect(report).to be_ok
    expect(report.diagnostics).to be_empty
  end

  it "uses the declared language level in its message" do
    report = validate("%!PS\n%%LanguageLevel: 2\nshfill")

    expect(report.errors.map(&:message)).to eq(
      ["shfill is Level 3; this program targets Level 2"],
    )
  end

  it "lets an explicit level override the header" do
    report = validate("%!PS\n%%LanguageLevel: 2\nshfill", level: 1)

    expect(report.errors.first.message).to end_with("targets Level 1")
    expect(validate("%!PS\n%%LanguageLevel: 1\nshfill", level: 3)).to be_ok
  end

  [nil, 0, 4].each do |header|
    it "defaults to Level 3 with header #{header.inspect}" do
      source = header ? "%!PS\n%%LanguageLevel: #{header}\nshfill" : "shfill"

      expect(validate(source).diagnostics).to be_empty
    end
  end

  [0, 4, "2"].each do |level|
    it "rejects explicit level #{level.inspect}" do
      expect do
        validate("", level: level)
      end.to raise_error(ArgumentError, /level must/)
    end
  end

  it "returns only grammar diagnostics without running model checks" do
    allow(Postscript::Validation::Levels).to receive(:violations)
      .and_call_original
    allow(Postscript::Validation::Vocabulary).to receive(:unknown_names)
      .and_call_original
    report = validate("{ unclosed", level: 1)

    expect(Postscript::Validation::Levels).not_to have_received(:violations)
    expect(Postscript::Validation::Vocabulary)
      .not_to have_received(:unknown_names)

    expect(report.diagnostics.size).to eq(1)
    expect(report.errors.first.to_h).to include(
      kind: :grammar, severity: :error, line: 1, column: 2, offset: 1,
    )
  end

  it "reports unknown names as warnings that do not invalidate the report" do
    report = validate("mystery_name")

    expect(report).to be_ok
    expect(report.diagnostics.size).to eq(1)
    expect(report.warnings.first.to_h).to include(
      code: :unknown_name, kind: :unknown_name, severity: :warning, entry: nil,
    )
    expect(report.warnings.first.message).to include("mystery_name")
  end

  it "combines level errors and unknown-name warnings" do
    report = validate("shfill mystery_name", level: 1)

    expect(report.errors.map(&:kind)).to eq([:level])
    expect(report.warnings.map(&:kind)).to eq([:unknown_name])
  end

  it "recognizes defined names" do
    expect(validate("/p { 1 } def p /x 5 def x").diagnostics).to be_empty
  end

  it "falls back to Ruby by default when native is unavailable" do
    allow(Postscript::Source::NativeEngine).to receive(:available?)
      .and_return(false)
    allow(Postscript::Source::NativeLexer).to receive(:tokenize)
      .and_call_original

    expect(Postscript.validate("0 0 moveto")).to be_ok
    expect(Postscript::Source::NativeLexer).not_to have_received(:tokenize)
  end

  it "selects native for both grammar and model parsing when available" do
    allow(Postscript::Source::NativeEngine).to receive(:available?)
      .and_return(true)
    allow(Postscript::Validation::Grammar).to receive(:check)
      .with("shfill", engine: :native).and_return([])
    allow(Postscript::Source::NativeLexer).to receive(:tokenize)
      .with("shfill").and_return(Postscript.tokenize("shfill"))

    expect(Postscript.validate("shfill",
                               level: 1).errors.first.kind).to eq(:level)
    expect(Postscript::Validation::Grammar).to have_received(:check)
      .with("shfill", engine: :native).once
    expect(Postscript::Source::NativeLexer).to have_received(:tokenize)
      .with("shfill").once
  end

  it "honors explicit Ruby without probing native availability" do
    allow(Postscript::Source::NativeEngine).to receive(:available?)
      .and_call_original

    expect(validate("")).to be_ok
    expect(Postscript::Source::NativeEngine).not_to have_received(:available?)
  end

  it "raises when an explicitly requested native engine is unavailable" do
    allow(Postscript::Source::NativeEngine).to receive(:parse)
      .and_raise(Postscript::NativeEngineUnavailable, "native unavailable")

    expect { Postscript.validate("shfill", engine: :native) }
      .to raise_error(Postscript::NativeEngineUnavailable)
  end

  it "rejects unknown engines" do
    expect { Postscript.validate("", engine: :invalid) }
      .to raise_error(ArgumentError, /unknown engine/)
  end
end
