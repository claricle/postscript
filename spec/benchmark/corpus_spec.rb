# frozen_string_literal: true

require "yaml"

RSpec.describe "benchmark/corpus.yml" do # rubocop:disable RSpec/DescribeClass
  let(:manifest) do
    YAML.safe_load_file(File.expand_path("../../benchmark/corpus.yml", __dir__))
  end
  let(:files) { manifest.fetch("files") }
  let(:paths) { files.map { |entry| entry.fetch("path") } }

  it "pins the corpus repository" do
    expect(manifest.fetch("repository")).to eq("claricle/postsvg")
  end

  it "pins a full commit hash" do
    expect(manifest.fetch("commit")).to match(/\A\h{40}\z/)
  end

  it "contains files" do
    expect(files).not_to be_empty
  end

  it "contains exactly a path and checksum for each file" do
    expect(files.map(&:keys)).to all(contain_exactly("path", "sha256"))
  end

  it "contains only PostScript paths" do
    expect(paths).to all(match(/\.(?:ps|eps)\z/))
  end

  it "pins SHA-256 checksums" do
    checksums = files.map { |entry| entry.fetch("sha256") }
    expect(checksums).to all(match(/\A\h{64}\z/))
  end

  it "sorts paths" do
    expect(paths).to eq(paths.sort)
  end

  it "contains unique paths" do
    expect(paths).to eq(paths.uniq)
  end
end
