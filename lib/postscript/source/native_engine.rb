# frozen_string_literal: true

module Postscript
  module Source
    # The vendored PostScript grammar (grammars/postscript.json) on the
    # parsanol native engine.
    #
    # parsanol is an optional dependency. It is loaded on first use; a
    # missing, old, or extension-less install raises
    # NativeEngineUnavailable rather than running parsanol's pure-Ruby
    # runtime in its place.
    module NativeEngine
      MINIMUM_VERSION = "1.3.96"
      ARTIFACT = File.expand_path("../../../grammars/postscript.json",
                                  __dir__)
      ENTRY = "main"

      class << self
        # Whether engine: :native can run here.
        def available?
          artifact
          true
        rescue NativeEngineUnavailable
          false
        end

        # The capture tree for UTF-8 +input+, or nil when the grammar
        # rejects it.
        def parse(input)
          # Loaded first: until parsanol is, Parsanol::ParseFailed is not
          # a constant the rescue below can name.
          grammar = artifact
          begin
            grammar.parse(ENTRY, input)
          rescue Parsanol::ParseFailed
            nil
          end
        end

        # Raises NativeEngineUnavailable unless parsanol +version+ is
        # recent enough and its +native+ extension loaded.
        def check!(version, native:)
          if Gem::Version.new(version) < Gem::Version.new(MINIMUM_VERSION)
            unavailable!("needs parsanol >= #{MINIMUM_VERSION}, " \
                         "found #{version}")
          end
          return if native

          unavailable!("parsanol #{version} has no native extension " \
                       "for this platform")
        end

        private

        def artifact
          @artifact ||= begin
            load_parsanol
            Parsanol::PARG::Artifact.load(ARTIFACT)
          end
        end

        def load_parsanol
          require "parsanol"
        rescue LoadError
          unavailable!("needs the parsanol gem (>= #{MINIMUM_VERSION}, " \
                       "Ruby >= 3.2)")
        else
          check!(Parsanol::VERSION, native: Parsanol::Native.available?)
        end

        def unavailable!(reason)
          raise NativeEngineUnavailable, "engine: :native #{reason}"
        end
      end
    end
  end
end
