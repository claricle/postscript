# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe Postscript::Model do
  let(:lib) { File.expand_path("../../lib", __dir__) }

  # A child process checks cold autoloads because the suite preloads operators.
  it "autoloads procedure calls and unknown operators" do
    output, = Open3.capture2e(
      RbConfig.ruby, "-I", lib, "-rpostscript", "-e",
      "print Postscript::Model::InvokeProcedure, ' ', " \
      "Postscript::Model::UnknownOperator"
    )
    expect(output).to eq(
      "Postscript::Model::InvokeProcedure Postscript::Model::UnknownOperator",
    )
  end
end
