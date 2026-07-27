# frozen_string_literal: true

require "spec_helper"

RSpec.describe Postscript::Model::Operators::Device do
  before(:all) { Postscript::Model::Operators.load_all! }

  %i[Showpage Copypage Nulldevice].each do |op|
    describe "::#{op}" do
      it "is zero-arity" do
        klass = described_class.const_get(op)
        expect(klass.consumes).to eq(0)
        expect(klass.produces).to eq(0)
      end
    end
  end
end
