# frozen_string_literal: true

module Postscript
  # Model::Program -> PostScript source text. Walks the program's
  # header (DSC comments) and body (Model records), emitting each as
  # PS source. Used by the SVG -> PS direction and by tests.
  #
  # OCP: adding serialization for a new operator class means adding
  # one +emit_<keyword>+ method (or falling through to the default
  # keyword+operands emitter). No switch edits.
  class Serializer
    DEFAULT_LANGUAGE_LEVEL = 3
    DEFAULT_CREATOR = "Postscript #{::Postscript::VERSION}".freeze

    def self.call(program, eps: false, creator: DEFAULT_CREATOR, **_options)
      new(program, eps: eps, creator: creator).call
    end

    attr_reader :program, :eps, :creator

    def initialize(program, eps:, creator:)
      unless program.is_a?(Model::Program)
        raise ArgumentError,
              "program must be a Model::Program"
      end

      @program = program
      @eps = eps
      @creator = creator
    end

    def call
      buffer = String.new(capacity: 4096)
      emit_header(buffer)
      emit_body(buffer)
      buffer << "showpage\n" unless body_has_showpage?
      buffer << "%%EOF\n"
      buffer
    end

    # Returns true if the program body already contains a +showpage+
    # operator, so the serializer doesn't append a duplicate.
    def body_has_showpage?
      program.body.any? { |s| s.is_a?(Model::Operators::Device::Showpage) }
    end

    # All methods below this point are public. They are intentionally
    # exposed (prefixed +emit_+) so dispatch can reach them via
    # +method_defined?+ without +respond_to?+.
    def emit_header(buffer)
      buffer << "%!PS-Adobe-#{DEFAULT_LANGUAGE_LEVEL}.0"
      buffer << " EPSF-3.0" if eps
      buffer << "\n"
      buffer << "%%Creator: #{creator}\n"
      bbox = program.header.bounding_box
      if bbox && !bbox.empty?
        buffer << "%%BoundingBox: " << bbox.map { |v|
          FormatNumber.call(v)
        }.join(" ") << "\n"
      end
      hires = program.header.hires_bounding_box
      if hires && !hires.empty?
        buffer << "%%HiResBoundingBox: " << hires.map { |v|
          FormatNumber.call(v)
        }.join(" ") << "\n"
      end
      buffer << "%%Title: #{program.header.title}\n" if program.header.title
      buffer << "%%LanguageLevel: #{DEFAULT_LANGUAGE_LEVEL}\n"
      buffer << "%%EndComments\n"
    end

    def emit_body(buffer)
      program.body.each do |statement|
        emit_statement(statement, buffer)
      end
    end

    def emit_statement(statement, buffer)
      case statement
      when Model::Literals::Number
        buffer << FormatNumber.call(statement.value) << "\n"
      when Model::Literals::Name
        prefix = statement.literal? ? "/" : ""
        buffer << prefix << statement.value << "\n"
      when Model::Literals::StringLiteral
        buffer << escape_string(statement.value) << "\n"
      when Model::Literals::HexLiteral
        buffer << "<" << statement.value << ">\n"
      when Model::Literals::ArrayLiteral
        buffer << "[ "
        statement.elements.each do |e|
          emit_inline(e, buffer)
          buffer << " "
        end
        buffer << "]\n"
      when Model::Literals::Procedure
        buffer << "{\n"
        statement.body.each { |s| emit_statement(s, buffer) }
        buffer << "}\n"
      when Model::Literals::Dictionary
        buffer << "<<\n"
        statement.entries.each do |k, v|
          buffer << "/#{k} "
          emit_inline(v, buffer)
          buffer << "\n"
        end
        buffer << ">>\n"
      when Model::Operator
        emit_operator(statement, buffer)
      when Model::UnknownOperator
        buffer << "% unhandled operator: #{statement.keyword}\n"
      when Model::InvokeProcedure
        buffer << statement.name << "\n"
      end
    end

    def emit_inline(statement, buffer)
      case statement
      when Model::Literals::Number then buffer << FormatNumber.call(statement.value)
      when Model::Literals::Name then buffer << (statement.literal? ? "/" : "") << statement.value
      when Model::Literals::StringLiteral then buffer << escape_string(statement.value)
      when Model::Literals::HexLiteral then buffer << "<" << statement.value << ">"
      else buffer << statement.class.name.to_s
      end
    end

    # Dispatch: just emit the keyword. Operands are already in the
    # program body as separate literal statements (added by the
    # AstBuilder). This keeps round-trip idempotent: serialized
    # output re-parses to an identical AST.
    def emit_operator(operator, buffer)
      buffer << operator.keyword << "\n"
    end

    # Path
    def escape_string(text)
      escaped = text.to_s.gsub(/[()\\]/) { |c| "\\#{c}" }
        .gsub("\n", '\\n')
        .gsub("\r", '\\r')
        .gsub("\t", '\\t')
      "(#{escaped})"
    end

  end
end
