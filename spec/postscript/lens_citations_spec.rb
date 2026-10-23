# frozen_string_literal: true

require "spec_helper"
require "uri"

begin
  require "lens_core"
rescue LoadError
  lens_core_available = false
else
  require "postscript/lens_citations"
  lens_core_available = true
end

RSpec.describe "Postscript::LensCitations", skip: !lens_core_available do
  let(:citations) { Postscript::LensCitations }
  let(:vocabulary) { Postscript::Model::Vocabulary }

  [nil, 0, 4, -1, 1.5, 1.0, "1"].each do |level|
    it "rejects the invalid profile level #{level.inspect}" do
      expect { citations.profile(level) }.to raise_error(
        ArgumentError, "level must be 1, 2 or 3, got #{level.inspect}"
      )
    end
  end

  it "returns distinct, non-empty frozen profile citation lists" do
    profiles = (1..3).map { |level| citations.profile(level) }

    expect(profiles.map { |list| list.map(&:to_h) }.uniq.size).to eq(3)
    profiles.each_with_index do |list, index|
      expect(list).to be_frozen
      expect(list).not_to be_empty
      expect(list).to all(be_a(LensCore::Citation).and(be_frozen))
      expect(list.first.uri).to eq(
        "https://www.adobe.com/products/postscript/pdfs/PLRM.pdf",
      )
      expect(list.first.label).to eq("PLRM 3rd ed.: LanguageLevel #{index + 1}")
    end
  end

  it "cites moveto's Guide page at the recorded commit" do
    metadata = YAML.safe_load_file(vocabulary::GUIDE).fetch("guide")
    entry = vocabulary.entry("moveto")
    citation = citations.entry(entry)

    expect(entry.source).to eq(:guide)
    expect(citation.uri).to eq(
      "https://github.com/#{metadata.fetch('repository')}/blob/" \
      "#{metadata.fetch('commit')}/docs/commands/references/moveto.adoc",
    )
    expect(citation.label).to include("moveto", "LanguageLevel 1")
  end

  it "cites the versioned override data for currentglobal and shfill" do
    %w[shfill currentglobal].each do |keyword|
      entry = vocabulary.entry(keyword)
      citation = citations.entry(entry)

      expect(entry.source).to eq(:override)
      expect(citation.uri).to eq(
        "https://github.com/claricle/postscript/blob/" \
        "v#{Postscript::VERSION}/data/operator_overrides.yml",
      )
      expect(citation.label).to include(keyword,
                                        "LanguageLevel #{entry.level}")
    end
  end

  it "uses the gem version when constructing override citations" do
    stub_const("Postscript::VERSION", "1.2.3")

    expect(citations.entry(vocabulary.entry("currentglobal")).uri).to eq(
      "https://github.com/claricle/postscript/blob/" \
      "v1.2.3/data/operator_overrides.yml",
    )
  end

  it "uses absolute URIs for every entry and profile" do
    entries = vocabulary.keywords.map do |keyword|
      citations.entry(vocabulary.entry(keyword))
    end
    profiles = (1..3).flat_map { |level| citations.profile(level) }

    (entries + profiles).each do |citation|
      expect(citation).to be_a(LensCore::Citation)
      expect(citation).to be_frozen
      expect(URI.parse(citation.uri)).to be_absolute
    end
  end
end
