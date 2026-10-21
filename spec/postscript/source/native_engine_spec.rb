# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe Postscript::Source::NativeEngine do
  describe ".check!" do
    it "accepts a recent parsanol with its native extension" do
      expect { described_class.check!("1.3.96", native: true) }
        .not_to raise_error
    end

    it "rejects parsanol releases that mis-parse large inputs" do
      expect { described_class.check!("1.3.95", native: true) }
        .to raise_error(Postscript::NativeEngineUnavailable,
                        "engine: :native needs parsanol >= 1.3.96, " \
                        "found 1.3.95")
    end

    it "rejects parsanol without its native extension" do
      expect { described_class.check!("1.3.96", native: false) }
        .to raise_error(Postscript::NativeEngineUnavailable,
                        /no native extension/)
    end
  end

  # In a child process whose load path puts a parsanol.rb that raises
  # LoadError first, as when the gem is not installed.
  describe "without parsanol" do
    let(:script) do
      <<~RUBY
        begin
          Postscript.parse("1", engine: :native)
        rescue Postscript::NativeEngineUnavailable => e
          print e.message
        end
        print " | available: \#{Postscript::Source::NativeEngine.available?}"
        print " | ruby engine: \#{Postscript.parse('1 2 add').body.size}"
      RUBY
    end

    let(:lib) { File.expand_path("../../../lib", __dir__) }

    it "raises NativeEngineUnavailable and leaves the Ruby engine working" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "parsanol.rb"), "raise LoadError\n")
        output, = Open3.capture2e(RbConfig.ruby, "-I", dir, "-I", lib,
                                  "-rpostscript", "-e", script)
        expect(output).to eq(
          "engine: :native needs the parsanol gem (>= 1.3.96, Ruby >= 3.2) " \
          "| available: false | ruby engine: 3",
        )
      end
    end
  end
end
