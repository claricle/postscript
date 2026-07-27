# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Painting do
  before(:all) { Postscript::Model::Operators.load_all! }

  %i[Stroke Fill Eofill Clip Eoclip].each do |op|
    describe "::#{op}" do
      it "is zero-arity (consumes nothing, produces nothing)" do
        klass = described_class.const_get(op)
        expect(klass.consumes).to eq(0)
        expect(klass.produces).to eq(0)
      end

      it "registers under the lowercase keyword" do
        klass = described_class.const_get(op)
        expect(Postscript::Model::Operators[op.to_s.downcase]).to be(klass)
      end
    end
  end
end
