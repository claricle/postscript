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

  describe ".diagnose" do
    before do
      skip "parsanol native engine unavailable" unless
        described_class.available?
    end

    let(:artifact) { described_class.send(:artifact) }

    it "returns nil for valid input" do
      expect(described_class.diagnose("1 2 add")).to be_nil
    end

    it "retains native labels, offsets and messages on rejection" do
      expect(described_class.diagnose("(unterminated")).to include(
        offset: 13, expected: a_collection_including("')'"), rule: "main",
        message: a_string_matching(/expected/)
      )
    end

    it "prefers structured expected labels and a supplied PARG rule" do
      allow(artifact).to receive(:parse_with_diagnostics).with("main", "bad")
        .and_return("ok" => false, "offset" => 2, "expected" => ["closing"],
                    "message" => "expected closing", "rule" => "procedure")

      expect(described_class.diagnose("bad")).to eq(
        offset: 2, expected: ["closing"], message: "expected closing",
        rule: "procedure"
      )
    end

    context "with an artifact without parse_with_diagnostics" do
      let(:legacy) { instance_double(Parsanol::PARG::Artifact) }
      let(:cause_type) do
        Struct.new(:position, :children, :expected, :message, :rule)
      end

      before do
        native_artifact = artifact
        allow(legacy).to receive(:parse) do |entry, input|
          native_artifact.parse(entry, input)
        end
        allow(described_class).to receive(:artifact).and_return(legacy)
      end

      it "returns nil for valid input" do
        expect(described_class.diagnose("1 2 add")).to be_nil
      end

      it "reads the failure cause from the native parser" do
        expect(described_class.diagnose("(unterminated")).to include(
          offset: 13, expected: a_collection_including("')'"), rule: "main",
          message: a_string_matching(/expected/)
        )
      end

      it "reads structured fields from the furthest nested cause" do
        child = instance_double(cause_type, position: 7, children: [],
                                            expected: ["close"], rule: "array",
                                            message: ["expected close"])
        earlier = instance_double(Parsanol::Cause, position: 3, children: [])
        root = instance_double(Parsanol::Cause, position: 0,
                                                children: [child, earlier])
        error = Parsanol::ParseFailed.new("outer failure", root)
        allow(legacy).to receive(:parse).with("main", "bad").and_raise(error)

        expect(described_class.diagnose("bad")).to eq(
          offset: 7, expected: ["close"], message: "expected close",
          rule: "array"
        )
      end
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
