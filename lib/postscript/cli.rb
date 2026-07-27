# frozen_string_literal: true

require "thor"

module Postscript
  # CLI for the postscript gem. Available via the +postscript+
  # executable. Provides parse/serialize/tokenize/version
  # subcommands for ad-hoc PS source inspection without writing
  # Ruby.
  class CLI < Thor
    package_name "postscript"

    desc "parse INPUT", "Parse a PS/EPS file and dump the AST shape"
    long_desc <<~DESC
      Read INPUT, lex + parse to a Model::Program, and print one
      line per body statement showing its class. Useful for
      verifying that the parser sees the structure you expect.
    DESC
    def parse(input_path)
      source = read_input(input_path)
      program = Postscript.parse(source)
      say "Program: #{program.body.length} statement(s)"
      say "BoundingBox: #{program.header.bounding_box.inspect}" if program.header.bounding_box
      program.body.each do |node|
        say "  #{node.class}"
      end
    rescue Postscript::Error => e
      say "Parse error: #{e.message}", :red
      exit 1
    end

    desc "serialize INPUT [OUTPUT]", "Round-trip a PS file through parse + serialize"
    long_desc <<~DESC
      Read INPUT, parse to a Model::Program, serialize back to PS
      source. Writes to OUTPUT if given, otherwise stdout.
    DESC
    option :eps, type: :boolean, default: false, desc: "Emit EPSF-3.0 header"
    def serialize(input_path, output_path = nil)
      source = read_input(input_path)
      program = Postscript.parse(source)
      output = Postscript.serialize(program, eps: options[:eps])
      if output_path
        File.write(output_path, output)
        say "Wrote #{output_path} (#{output.bytesize} bytes)", :green
      else
        puts output
      end
    rescue Postscript::Error => e
      say "Error: #{e.message}", :red
      exit 1
    end

    desc "tokenize INPUT", "Lex a PS file and dump the token stream"
    long_desc <<~DESC
      Read INPUT and dump one line per token showing type, value,
      and source position. Useful for debugging lexer issues.
    DESC
    def tokenize(input_path)
      source = read_input(input_path)
      Postscript.tokenize(source).each do |token|
        puts "%4d:%-4d %-12s %s" % [token.line, token.column, token.type, token.value]
      end
    rescue Postscript::Error => e
      say "Lex error: #{e.message}", :red
      exit 1
    end

    desc "version", "Show the postscript gem version"
    def version
      say "postscript #{Postscript::VERSION}"
    end

    private

    def read_input(path)
      unless File.exist?(path)
        say "Error: input file '#{path}' not found", :red
        exit 1
      end
      File.read(path)
    end
  end
end
