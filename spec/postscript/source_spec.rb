# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Source do
  describe ".tokenize" do
    it "uses Lexer by default" do
      expect(described_class.tokenize("1 add"))
        .to eq(Postscript::Source::Lexer.tokenize("1 add"))
    end

    it "rejects an unknown engine" do
      expect { described_class.tokenize("1", engine: :fast) }
        .to raise_error(ArgumentError, /unknown engine :fast/)
    end
  end
end
