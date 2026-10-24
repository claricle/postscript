# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Validator do
  def validate(source, **options)
    Postscript.validate(source, engine: :ruby, **options)
  end

  it "reports a level error with its keyword, required level and target" do
    report = validate("0 0 moveto shfill", level: 1)

    expect(report).to be_a(LensCore::Report)
    expect(report.valid).to be(false)
    expect(report.diagnostics.size).to eq(1)
    expect(report.diagnostics.find(&:error?).to_h).to include(
      "kind" => "level", "severity" => "error",
      "message" => "shfill is Level 3; this program targets Level 1",
      "context" => { "keyword" => "shfill", "required_level" => 3,
                     "target_level" => 1 }
    )
  end

  it "accepts Level 3 operators at Level 3" do
    report = validate("0 0 moveto shfill", level: 3)

    expect(report.valid).to be(true)
    expect(report.diagnostics).to be_empty
    expect(report.profile.id).to eq("postscript-level-3")
  end

  it "uses the declared language level in its message" do
    report = validate("%!PS\n%%LanguageLevel: 2\nshfill")

    expect(report.profile.id).to eq("postscript-level-2")
    expect(report.diagnostics.select(&:error?).map(&:message)).to eq(
      ["shfill is Level 3; this program targets Level 2"],
    )
  end

  it "lets an explicit level override the header" do
    report = validate("%!PS\n%%LanguageLevel: 2\nshfill", level: 1)

    expect(report.diagnostics.find(&:error?).message)
      .to end_with("targets Level 1")
    expect(validate("%!PS\n%%LanguageLevel: 1\nshfill",
                    level: 3).valid).to be(true)
  end

  [nil, 0, 4].each do |header|
    it "defaults to Level 3 with header #{header.inspect}" do
      source = header ? "%!PS\n%%LanguageLevel: #{header}\nshfill" : "shfill"

      report = validate(source)
      expect(report.diagnostics).to be_empty
      expect(report.profile.id).to eq("postscript-level-3")
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
    allow(Postscript::Validation::Vocabulary).to receive(:unknown_names)
      .and_call_original
    token = Postscript.tokenize("{ unclosed", engine: :ruby).first
    report = validate("{ unclosed", level: 1)

    expect(Postscript::Validation::Levels).not_to have_received(:violations)
    expect(Postscript::Validation::Vocabulary)
      .not_to have_received(:unknown_names)

    expect(report.diagnostics.size).to eq(1)
    expect(report.diagnostics.find(&:error?).to_h).to include(
      "kind" => "grammar", "severity" => "error",
      "context" => include("line" => token.line, "column" => token.column,
                           "offset" => token.column - 1, "engine" => "ruby")
    )
  end

  it "reports unknown names as warnings that do not invalidate the report" do
    report = validate("mystery_name")

    expect(report.valid).to be(true)
    expect(report.diagnostics.size).to eq(1)
    expect(report.diagnostics.find(&:warning?).to_h).to include(
      "kind" => "unknown-name", "severity" => "warning",
      "context" => { "keyword" => "mystery_name" }
    )
    expect(report.diagnostics.find(&:warning?).message)
      .to include("mystery_name")
  end

  it "combines level errors and unknown-name warnings" do
    report = validate("shfill mystery_name", level: 1)

    expect(report.diagnostics.select(&:error?).map(&:kind)).to eq(["level"])
    expect(report.diagnostics.select(&:warning?).map(&:kind))
      .to eq(["unknown-name"])
  end

  it "recognizes defined names" do
    expect(validate("/p { 1 } def p /x 5 def x").diagnostics).to be_empty
  end

  it "falls back to Ruby by default when native is unavailable" do
    allow(Postscript::Source::NativeEngine).to receive(:available?)
      .and_return(false)
    allow(Postscript::Source::NativeLexer).to receive(:tokenize)
      .and_call_original

    expect(Postscript.validate("0 0 moveto").valid).to be(true)
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
                               level: 1).diagnostics.first.kind).to eq("level")
    expect(Postscript::Validation::Grammar).to have_received(:check)
      .with("shfill", engine: :native).once
    expect(Postscript::Source::NativeLexer).to have_received(:tokenize)
      .with("shfill").once
  end

  it "honors explicit Ruby without probing native availability" do
    allow(Postscript::Source::NativeEngine).to receive(:available?)
      .and_call_original

    expect(validate("").valid).to be(true)
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
