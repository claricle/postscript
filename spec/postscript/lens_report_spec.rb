# frozen_string_literal: true

require "spec_helper"
require "json_schemer"
require "open3"
require "postscript/lens_report"

RSpec.describe Postscript::LensReport do
  def validate(source, **options)
    Postscript.validate(source, engine: :ruby, **options)
  end

  {
    "{ unclosed" => ["grammar", "postscript.grammar.syntax", false],
    "0 0 moveto shfill" => ["level", "postscript.level.operator-available",
                            false],
    "mystery_name" => ["unknown-name", "postscript.vocabulary.known-name",
                       true],
  }.each do |source, (kind, requirement, valid)|
    it "renders schema-valid, round-trippable JSON for #{kind}" do
      report = validate(source, level: 1)
      rendered = LensCore::Renderers::Json.render(report)
      document = JSON.parse(rendered)

      expect(JSONSchemer.schema(LensCore::Schema.document).validate(document).to_a)
        .to be_empty
      expect(LensCore::Parsers::Json.parse(rendered)).to eq(report)
      expect(report.valid).to eq(valid)
      expect(report.diagnostics.first).to have_attributes(
        kind: kind, requirement_id: requirement,
      )
      expect(report.diagnostics.map(&:location)).to all(be_nil)
      expect(document.fetch("diagnostics")).to all(satisfy do |diagnostic|
        !diagnostic.key?("location")
      end)
    end
  end

  let(:missing_dependency_script) do
    <<~RUBY
      require "postscript"
      abort "eager LensCore load" if defined?(LensCore)
      module MissingLensCore
        def require(path)
          raise LoadError, "unavailable lens_core" if path == "lens_core"
          super
        end
      end
      Kernel.prepend(MissingLensCore)
      Postscript.parse("0 0 moveto")
      begin
        Postscript.validate("0 0 moveto", engine: :ruby)
      rescue Postscript::Error => e
        puts e.message
      else
        abort "expected Postscript::Error"
      end
    RUBY
  end

  it "identifies the producer and profile and accepts Level 1 moveto" do
    report = validate("0 0 moveto", level: 1)

    expect(report.valid).to be(true)
    expect(report.producer.to_h).to eq("name" => "postscript",
                                       "version" => Postscript::VERSION)
    expect(report.profile.id).to eq("postscript-level-1")
    expect(report.profile.citations).to eq(Postscript::LensCitations.profile(1))
    expect(report.summary).to eq("errors" => 0, "warnings" => 0, "infos" => 0)
    expect(report.to_h).not_to have_key("timestamp")
  end

  it "uses a caller-supplied timestamp" do
    report = validate("", timestamp: "2026-10-24T12:00:00+05:00")

    expect(report.to_h.fetch("timestamp")).to eq("2026-10-24T07:00:00Z")
    allow(Time).to receive(:now).and_raise("must not default to the clock")
    expect(validate("").to_h).not_to have_key("timestamp")
  end

  it "preserves grammar messages and token positions in JSON-safe context" do
    original = Postscript::Validation::Grammar.check("{ unclosed").first
    report = validate("{ unclosed", level: 2)
    diagnostic = report.diagnostics.first

    expect(diagnostic.message).to eq(original.message)
    expect(diagnostic.context).to eq(
      "line" => original.line, "column" => original.column,
      "offset" => original.offset, "rule" => nil, "expected" => [],
      "engine" => "ruby"
    )
    expect(diagnostic.citations).to eq(report.profile.citations)
  end

  it "converts symbols recursively while retaining unknown coordinates" do
    diagnostic = Postscript::Diagnostic.new(
      kind: :grammar, severity: :error, message: "syntax error",
      rule: :main, expected: [:name, { token: :close }]
    )
    internal = Postscript::Validation::Report.new(diagnostics: [diagnostic])
    report = described_class.call(internal, level: 3, engine: :native)

    expect(report.diagnostics.first.context).to eq(
      "line" => nil, "column" => nil, "offset" => nil, "rule" => "main",
      "expected" => ["name", { "token" => "close" }], "engine" => "native"
    )
    expect(LensCore::Parsers::Json.parse(LensCore::Renderers::Json.render(report)))
      .to eq(report)
  end

  it "uses the same requirement ID for different operator names" do
    report = validate("shfill currentglobal", level: 1)

    expect(report.diagnostics.map(&:requirement_id).uniq)
      .to eq(["postscript.level.operator-available"])
  end

  it "uses entry citations and remediation for level findings" do
    errors = validate("shfill currentglobal", level: 1)
      .diagnostics.select(&:error?)

    errors.each do |diagnostic|
      keyword = diagnostic.context.fetch("keyword")
      entry = Postscript::Model::Vocabulary.entry(keyword)
      expect(diagnostic.citations).to eq([Postscript::LensCitations.entry(entry)])
      expect(diagnostic.citations.first.label).to include("PLRM 3rd ed.")
      expect(diagnostic.remediation)
        .to eq("declare %%LanguageLevel: #{entry.level} or remove #{keyword}")
      expect(diagnostic.context).to eq("keyword" => keyword,
                                       "required_level" => entry.level,
                                       "target_level" => 1)
    end
  end

  it "omits engine from model findings" do
    report = validate("shfill mystery_name", level: 1)

    expect(report.diagnostics.map(&:context)).to all(satisfy do |context|
      !context.key?("engine")
    end)
  end

  it "adapts Guide entries using the existing Guide citation policy" do
    entry = Postscript::Model::Vocabulary.entry("moveto")
    diagnostic = Postscript::Diagnostic.new(
      kind: :level, severity: :error,
      message: "example level finding", entry: entry
    )
    internal = Postscript::Validation::Report.new(diagnostics: [diagnostic])
    report = described_class.call(internal, level: 1, engine: :ruby)

    expect(entry.source).to eq(:guide)
    expect(report.diagnostics.first.citations)
      .to eq([Postscript::LensCitations.entry(entry)])
    expect(report.diagnostics.first.citations.first.label)
      .to include("PostScript Language Guide")
  end

  it "renders YAML and Human with requirement IDs, citations and coordinates" do
    report = validate("{ unclosed", level: 1)
    diagnostic = report.diagnostics.first
    yaml = LensCore::Renderers::Yaml.render(report)
    human = LensCore::Renderers::Human.render(report)

    expect(LensCore::Parsers::Yaml.parse(yaml)).to eq(report)
    expect([yaml, human]).to all(include(diagnostic.requirement_id,
                                         diagnostic.citations.first.uri))
    expect(YAML.safe_load(yaml).fetch("diagnostics").first.fetch("context"))
      .to include("line" => diagnostic.context.fetch("line"),
                  "column" => diagnostic.context.fetch("column"))
    expect(human).to include("\"line\":#{diagnostic.context.fetch('line')}",
                             "\"column\":#{diagnostic.context.fetch('column')}")
  end

  it "loads LensCore lazily and explains a missing dependency" do
    output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "-e",
                                     missing_dependency_script)

    expect(status).to be_success
    expect(output).to include("lens_core", "Ruby >= 3.1")
  end
end
