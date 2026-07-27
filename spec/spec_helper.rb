# frozen_string_literal: true

require "postscript"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

module PostscriptSpecHelpers
  def fixture_path(filename)
    File.join(__dir__, "fixtures", filename)
  end

  def read_fixture(filename)
    File.read(fixture_path(filename))
  end
end

RSpec.configure { |c| c.include PostscriptSpecHelpers }
