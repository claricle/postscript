# frozen_string_literal: true

module Postscript
  module Source
    # Tokenizes PS source with the vendored PARG grammar on parsanol's
    # native engine: Source.parse(source, engine: :native).
    #
    # The result is the Model::Token stream Lexer produces for the same
    # source: the same types, values (with Lexer's encodings) and 1-based
    # line/column positions counted in bytes. Where the grammar rejects
    # the source, Lexer tokenizes it instead, so errors, and Lexer's
    # tolerance of input the grammar rejects, are Lexer's.
    class NativeLexer
      # Captures that are one token each: capture name => token type.
      WORDS = {
        integer: :number, real: :number, radix: :operator, name: :operator
      }.freeze

      # Composite captures => [open token, close token].
      COMPOSITES = {
        array: [[:array_open, "["], [:array_close, "]"]],
        procedure: [[:proc_open, "{"], [:proc_close, "}"]],
        dictionary: [[:dict_open, "<<"], [:dict_close, ">>"]],
      }.freeze

      def self.tokenize(source)
        new(source).tokenize
      end

      def initialize(source)
        @source = source.to_s
        @bytes = @source.b
        @input = Input.new(@bytes)
        @lines = Lines.new(@bytes)
      end

      def tokenize
        tree = NativeEngine.parse(@input.text)
        return Lexer.tokenize(@source) if tree.nil?

        @tokens = []
        walk(tree)
        @tokens.freeze
      end

      private

      # Arrays hold captures in source order; a slice is uncaptured text
      # (whitespace and comments).
      def walk(node)
        case node
        when Array then node.each { |child| walk(child) }
        when Hash then node.each { |kind, value| emit(kind, value) }
        end
      end

      def emit(kind, value)
        if (type = WORDS[kind])
          token(type, word(slice(value)), value)
        elsif (delimiters = COMPOSITES[kind])
          composite(delimiters, value)
        else
          emit_other(kind, value)
        end
      end

      def emit_other(kind, value)
        case kind
        when :literal_name then emit_literal_name(value)
        when :string then emit_string(value)
        when :hex_string then emit_hex_string(value)
        when :dsc then emit_dsc(value)
        end
      end

      def emit_literal_name(value)
        token(:name, word(slice(value).byteslice(1..)), value, literal: true)
      end

      def emit_string(value)
        raw = slice(value).byteslice(1...-1)
        token(:string, Lexer.decode_string(raw), value)
      end

      def emit_hex_string(value)
        raw = slice(value).byteslice(1...-1)
        token(:hexstring, word(Lexer.decode_hex(raw)), value)
      end

      # Lexer reports a DSC comment from after its "%%", in the source's
      # encoding, and reports none for a "%%" that ends the source.
      def emit_dsc(value)
        range = span(value)
        return if range.size == 2 && range.end == @bytes.bytesize

        start = range.begin + 2
        add(:dsc, @source.byteslice(start, range.size - 2).chomp, start)
      end

      # Lexer reports a delimiter at the byte after it.
      def composite((open, close), value)
        add(*open, span(value[:open]).end)
        walk(value[:items])
        add(*close, span(value[:close]).end)
      end

      def token(type, text, value, literal: false)
        add(type, text, @input.offset(value.offset), literal: literal)
      end

      def add(type, value, offset, literal: false)
        line, column = @lines.position(offset)
        @tokens << Model::Token.new(type, value, line: line, column: column,
                                                 literal: literal)
      end

      # The source bytes a capture covers.
      def slice(value)
        range = span(value)
        @bytes.byteslice(range.begin, range.size)
      end

      def span(value)
        start = @input.offset(value.offset)
        start...@input.offset(value.offset + value.to_s.bytesize)
      end

      # Lexer builds word values byte by byte: UTF-8 when ASCII-only,
      # binary otherwise.
      def word(raw)
        raw.ascii_only? ? raw.force_encoding(Encoding::UTF_8) : raw.b
      end

      # The source as parsanol reads it: UTF-8. A source with non-ASCII
      # bytes is read as Latin-1, so every byte is one character whatever
      # the encoding, and offsets are mapped back to source bytes.
      class Input
        attr_reader :text

        def initialize(bytes)
          if bytes.ascii_only?
            @text = bytes.dup.force_encoding(Encoding::UTF_8)
            @widened = []
          else
            latin1 = bytes.dup.force_encoding(Encoding::ISO_8859_1)
            @text = latin1.encode(Encoding::UTF_8)
            @widened = widened_offsets(bytes)
          end
        end

        # The source byte offset of +text+ byte offset +offset+.
        def offset(offset)
          before = @widened.bsearch_index { |at| at >= offset }
          offset - (before || @widened.size)
        end

        private

        # Offsets in +text+ of the characters that take two bytes there.
        def widened_offsets(bytes)
          offsets = []
          bytes.each_byte.with_index do |byte, index|
            offsets << (index + offsets.size) if byte >= 0x80
          end
          offsets
        end
      end

      # Lexer's positions: lines end at LF; columns count bytes from 1.
      class Lines
        def initialize(bytes)
          @newlines = []
          index = -1
          @newlines << index while (index = bytes.index("\n", index + 1))
        end

        def position(offset)
          line = @newlines.bsearch_index { |at| at >= offset } || @newlines.size
          start = line.zero? ? 0 : @newlines[line - 1] + 1
          [line + 1, offset - start + 1]
        end
      end
      private_constant :Input, :Lines
    end
  end
end
