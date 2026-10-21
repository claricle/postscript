# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe Postscript::Model::Vocabulary do
  describe ".entry" do
    it "reads moveto from the Guide" do
      entry = described_class.entry("moveto")

      expect(entry).to be_a(described_class::Entry)
      expect(entry.keyword).to eq("moveto")
      expect(entry.level).to eq(1)
      expect(entry.source).to eq(:guide)
      expect(entry.categories).to eq(["path-construction"])
    end

    it "overrides ashow's missing level and keeps its Guide categories" do
      entry = described_class.entry("ashow")

      expect(entry.level).to eq(1)
      expect(entry.source).to eq(:override)
      expect(entry.categories).to eq(["font-text"])
    end

    it "includes shfill from the overrides alone" do
      entry = described_class.entry("shfill")

      expect(entry.level).to eq(3)
      expect(entry.source).to eq(:override)
      expect(entry.categories).to eq(["painting"])
    end

    it "uses empty categories when neither file supplies them" do
      expect(described_class.entry("currentglobal").categories).to eq([])
    end

    it "returns nil for unknown keywords" do
      expect(described_class.entry("nonsense_12345")).to be_nil
    end

    it "freezes entries, keywords, categories, and category strings" do
      described_class.keywords.each do |keyword|
        entry = described_class.entry(keyword)

        expect(entry).to be_frozen
        expect(entry.keyword).to be_frozen
        expect(entry.categories).to be_frozen
        expect(entry.categories).to all(be_a(String).and(be_frozen))
      end
    end

    it "reuses the loaded entries" do
      entry = described_class.entry("moveto")

      expect(described_class.entry("moveto")).to equal(entry)
    end
  end

  describe ".level" do
    it "returns the corrected level for setblackgeneration" do
      expect(described_class.level("setblackgeneration")).to eq(2)
    end

    it "returns the Guide level for index" do
      expect(described_class.level("index")).to eq(1)
    end

    it "returns nil for unknown keywords" do
      expect(described_class.level("nonsense_12345")).to be_nil
    end
  end

  describe ".keywords" do
    it "returns a frozen, sorted union of both files' operator names" do
      guide = YAML.safe_load_file(described_class::GUIDE).fetch("operators")
      overrides =
        YAML.safe_load_file(described_class::OVERRIDES).fetch("operators")
      additions = overrides.keys - guide.keys
      keywords = described_class.keywords

      expect(guide.size).to eq(163)
      expect(keywords.size).to eq(guide.size + additions.size)
      expect(keywords).to eq((guide.keys | overrides.keys).sort)
      expect(keywords).to eq(keywords.sort)
      expect(keywords).to be_frozen
      expect(keywords).to all(be_a(String).and(be_frozen))
    end
  end

  describe "gem packaging" do
    it "includes both vocabulary data files" do
      path = File.expand_path("../../../postscript.gemspec", __dir__)
      specification = Gem::Specification.load(path)

      expect(specification.files).to include(
        "data/guide_operators.yml",
        "data/operator_overrides.yml",
      )
    end
  end
end
