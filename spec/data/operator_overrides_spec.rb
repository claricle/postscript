# frozen_string_literal: true

require "yaml"

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe "data/operator_overrides.yml" do
  let(:path) do
    File.expand_path("../../data/operator_overrides.yml", __dir__)
  end
  let(:data) { YAML.safe_load_file(path) }
  let(:operators) { data.fetch("operators") }

  it "has a top-level operators hash" do
    expect(data).to include("operators" => be_a(Hash))
  end

  it "contains exactly 45 operators" do
    expect(operators.size).to eq(45)
  end

  it "sorts operator names alphabetically" do
    expect(operators.keys).to eq(operators.keys.sort)
  end

  it "gives every operator an integer level from 1 to 3" do
    expect(operators.values).to all(
      include("level" => be_an(Integer).and(be_between(1, 3))),
    )
  end

  it "gives every operator a non-empty reason" do
    expect(operators.values).to all(
      include("reason" => be_a(String).and(satisfy { |s| !s.empty? })),
    )
  end

  it "cites the matching PLRM language level in every reason" do
    expect(operators.values).to all(satisfy do |entry|
      citation = /PLRM 3rd ed\.: LanguageLevel #{entry.fetch('level')}\b/
      entry.fetch("reason").match?(citation)
    end)
  end

  it "uses non-empty arrays of non-empty strings for categories" do
    entries = operators.values.select { |entry| entry.key?("categories") }
    expect(entries.map { |entry| entry["categories"] }).to all(
      be_an(Array).and(satisfy { |a| !a.empty? }).and(
        all(be_a(String).and(satisfy { |s| !s.empty? })),
      ),
    )
  end

  it "allows only categories, level, and reason keys" do
    expect(operators.values.map(&:keys)).to all(
      contain_exactly("level", "reason").or(
        contain_exactly("categories", "level", "reason"),
      ),
    )
  end

  it "has no duplicate operator names in the raw YAML" do
    section = File.read(path).split(/^operators:\s*$/, 2).last
    names = section.scan(/^  "?([a-z0-9]+)"?:\s*$/).flatten
    expect(names.uniq.size).to eq(names.size)
  end
end
