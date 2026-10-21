# frozen_string_literal: true

# Ensure the grammar recognizes every PostScript Language Guide operator.
require "spec_helper"
require "yaml"

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe "Guide operator vocabulary" do
  let(:names) do
    YAML.safe_load_file(
      File.expand_path("../../../data/guide_operators.yml", __dir__),
    ).fetch("operators").keys
  end

  def misread(engine)
    names.reject do |name|
      tokens = if engine.nil?
                 Postscript.tokenize(name)
               else
                 Postscript.tokenize(name, engine: engine)
               end
      tokens.size == 1 && tokens.first.type == :operator &&
        tokens.first.value == name
    rescue Postscript::Error
      false
    end
  end

  it "contains exactly 163 names" do
    expect(names.size).to eq(163)
  end

  it "contains only non-empty strings" do
    expect(names).to all(be_a(String).and(have_attributes(empty?: false)))
  end

  it "tokenizes every name as one operator token" do
    expect(misread(nil)).to be_empty
  end

  context "with the native engine" do
    before do
      skip "parsanol native engine unavailable" unless
        Postscript::Source::NativeEngine.available?
    end

    it "tokenizes every name as one operator token" do
      expect(misread(:native)).to be_empty
    end
  end
end
