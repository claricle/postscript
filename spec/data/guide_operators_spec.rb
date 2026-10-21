# frozen_string_literal: true

require "yaml"

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe "data/guide_operators.yml" do
  let(:path) do
    File.expand_path("../../data/guide_operators.yml", __dir__)
  end
  let(:data) { YAML.safe_load_file(path) }
  let(:operators) { data.fetch("operators") }
  let(:overrides_path) do
    File.expand_path("../../data/operator_overrides.yml", __dir__)
  end
  let(:overrides) { YAML.safe_load_file(overrides_path).fetch("operators") }

  it "identifies the Guide repository" do
    expect(data.fetch("guide").fetch("repository"))
      .to eq("claricle/postscript-guide")
  end

  it "records the Guide commit" do
    expect(data.fetch("guide").fetch("commit"))
      .to eq("c45f337f0112acc6a771cdc101a663858d23ee12")
  end

  it "contains exactly 163 operators" do
    expect(operators.size).to eq(163)
  end

  it "gives exactly 150 operators an integer level" do
    levels = operators.values.map { |entry| entry.fetch("level") }
    expect(levels.count { |level| level.is_a?(Integer) }).to eq(150)
  end

  it "assigns level 1 to 133 operators and level 2 to 17 operators" do
    levels = operators.values.map { |entry| entry.fetch("level") }
    expect(levels.compact.tally).to eq(1 => 133, 2 => 17)
  end

  it "leaves exactly the font and text operators without a level" do
    names = operators.select { |_, entry| entry.fetch("level").nil? }.keys
    expected = %w[
      ashow awidthshow charpath currentfont definefont findfont kshow
      makefont scalefont setfont show stringwidth widthshow
    ]
    expect(names).to eq(expected)
  end

  it "includes index at level 1" do
    expect(operators.fetch("index")).to include("level" => 1)
  end

  it "excludes psindex" do
    expect(operators).not_to have_key("psindex")
  end

  it "excludes brackets" do
    expect(operators).not_to have_key("brackets")
  end

  it "sorts operator names alphabetically" do
    expect(operators.keys).to eq(operators.keys.sort)
  end

  it "gives every operator a categories array" do
    expect(operators.values).to all(include("categories" => be_an(Array)))
  end

  it "provides an override for every operator without a Guide level" do
    names = operators.select { |_, entry| entry.fetch("level").nil? }.keys
    expect(names - overrides.keys).to be_empty
  end

  it "has no overrides for operators with a Guide level" do
    names = operators.reject { |_, entry| entry.fetch("level").nil? }.keys
    expect(names & overrides.keys).to be_empty
  end
end
