# frozen_string_literal: true

require_relative "../../script/operator_inventory"

RSpec.describe OperatorInventory do
  let(:keywords) { Postscript::Model::Vocabulary.keywords }
  let(:expected_rows) do
    keywords.to_h { |keyword| [keyword.gsub("|") { "\\|" }, 1] }
  end

  it "matches the committed operator inventory" do
    path = described_class::DOC
    committed = File.read(path) if File.file?(path)

    expect(committed).to eq(described_class.render),
                         "Run bundle exec rake vocabulary:doc"
  end

  it "includes each vocabulary keyword in exactly one table row" do
    rows = described_class.render.scan(/^\|`\+(.*?)\+` \|/).flatten

    expect(rows.tally).to eq(expected_rows)
  end

  it "keeps the generator and its rake task out of the gem" do
    gemspec = File.expand_path("../../postscript.gemspec", __dir__)
    files = Gem::Specification.load(gemspec).files

    expect(files.grep(%r{\A(?:rakelib|script)/})).to be_empty
  end
end
