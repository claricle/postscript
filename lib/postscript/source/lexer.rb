# frozen_string_literal: true

module Postscript
  module Source
    # Comment-aware PS lexer.
    #
    # Distinguishes +#+ line comments from +%+ inside string literals,
    # captures DSC comments (lines beginning with +%%+), and tags every
    # token with its source position (line, column).
    #
    # The legacy Tokenizer stripped comments with a global
    # +gsub(/%[^\n\r]*/, " ")+ before lexing, which corrupted +%+ chars
    # inside string literals. This implementation walks the source as a
    # state machine so +%+ inside (...) or <...> survives.
    class Lexer
      attr_reader :source, :position, :line, :column

      def initialize(source)
        @source = source.to_s
        @position = 0
        @line = 1
        @column = 1
        @tokens = []
        @state = :top
      end

      def tokenize
        until eos?
          case @state
          when :top        then scan_top
          when :string     then scan_string_body
          when :hexstring  then scan_hexstring_body
          when :comment    then scan_comment_body
          when :dsc        then scan_dsc_body
          end
        end
        @tokens.freeze
      end

      def self.tokenize(source)
        new(source).tokenize
      end

      # Escapes in a literal string that stand for one character. Any
      # other escaped character stands for itself, except octal digits.
      ESCAPES = {
        "n" => "\n", "r" => "\r", "t" => "\t", "b" => "\b", "f" => "\f",
        "\\" => "\\", "(" => "(", ")" => ")"
      }.freeze

      # The value of a literal string from the bytes between its outer
      # parentheses: escapes expanded, \ddd octal (1-3 digits) taken
      # modulo 256.
      def self.decode_string(raw)
        value = +""
        index = 0
        while index < raw.bytesize
          byte = raw.getbyte(index)
          index += 1
          if byte == 92 && index < raw.bytesize # backslash
            index = decode_escape(raw, index, value)
          else
            value << byte.chr
          end
        end
        value
      end

      # The value of a hex string from the bytes between < and >.
      def self.decode_hex(raw)
        raw.delete("^0-9a-fA-F")
      end

      def self.decode_escape(raw, index, value)
        char = raw.getbyte(index).chr
        if (replacement = ESCAPES[char])
          value << replacement
          index + 1
        elsif ("0".."7").cover?(char)
          digits = raw.byteslice(index, 3)[/\A[0-7]+/]
          value << (digits.to_i(8) & 0xFF).chr
          index + digits.bytesize
        else
          value << char
          index + 1
        end
      end
      private_class_method :decode_escape

      private

      def eos? = @position >= @source.bytesize

      def peek(offset = 0)
        @source.getbyte(@position + offset)
      end

      def advance
        byte = @source.getbyte(@position)
        @position += 1
        if byte == 10 # \n
          @line += 1
          @column = 1
        else
          @column += 1
        end
        byte
      end

      def scan_top
        skip_whitespace and return
        byte = peek
        return if byte.nil?

        char = byte.chr

        case char
        when "%"        then start_dsc_or_comment
        when "("        then start_string
        when "<"
          if peek(1) == 60 # <<
            emit(:dict_open, "<<")
          else
            start_hexstring
          end
        when ">"        then maybe_close_dict
        when ")"        then unbalanced_paren!
        when "{"        then emit(:proc_open, "{")
        when "}"        then emit(:proc_close, "}")
        when "["        then emit(:array_open, "[")
        when "]"        then emit(:array_close, "]")
        when "/", "\\"
          start_name_with_slash(char)
        else
          scan_word_or_number
        end
      end

      def skip_whitespace
        consumed = false
        until eos?
          byte = peek
          break unless whitespace_byte?(byte)

          advance
          consumed = true
        end
        consumed
      end

      def whitespace_byte?(byte)
        byte && [32, 9, 10, 13, 12, 11, 0].include?(byte)
      end

      def start_dsc_or_comment
        advance # consume first %
        if peek == 37 # second %
          advance # consume second %
          @state = :dsc
        else
          @state = :comment
        end
      end

      def scan_dsc_body
        start_pos = @position
        start_line = @line
        start_col = @column
        advance until eos? || @source.getbyte(@position) == 10
        text = @source.byteslice(start_pos, @position - start_pos)
        @tokens << Model::Token.new(:dsc, text.chomp, line: start_line,
                                                      column: start_col)
        @state = :top
      end

      def scan_comment_body
        advance until eos? || @source.getbyte(@position) == 10
        @state = :top
      end

      def start_string
        start_line = @line
        start_col = @column
        advance # consume (
        @string_start = { line: start_line, column: start_col, bytes: +"" }
        @string_depth = 1
        @state = :string
      end

      def scan_string_body
        until eos?
          byte = @source.getbyte(@position)
          advance
          case byte
          when 92 # backslash: kept raw, with the byte it escapes
            @string_start[:bytes] << "\\"
            @string_start[:bytes] << advance.chr unless eos?
          when 40 # (
            @string_depth += 1
            @string_start[:bytes] << "("
          when 41 # )
            @string_depth -= 1
            if @string_depth.zero?
              emit_string
              return
            end
            @string_start[:bytes] << ")"
          else
            @string_start[:bytes] << byte.chr
          end
        end
        raise LexError.new("unterminated string literal",
                           source_position: [@string_start[:line],
                                             @string_start[:column]])
      end

      def emit_string
        value = self.class.decode_string(@string_start[:bytes])
        @tokens << Model::Token.new(:string, value,
                                    line: @string_start[:line], column: @string_start[:column])
        @string_start = nil
        @state = :top
      end

      def start_hexstring
        start_line = @line
        start_col = @column
        advance # consume <
        @hex_start = { line: start_line, column: start_col, bytes: +"" }
        @state = :hexstring
      end

      def scan_hexstring_body
        until eos?
          byte = @source.getbyte(@position)
          case byte
          when 62 # >
            advance
            emit_hexstring
            return
          when 32, 9, 10, 13, 12
            advance
          else
            advance
            @hex_start[:bytes] << byte.chr
          end
        end
        raise LexError.new("unterminated hex string literal",
                           source_position: [@hex_start[:line],
                                             @hex_start[:column]])
      end

      def emit_hexstring
        hex = self.class.decode_hex(@hex_start[:bytes])
        @tokens << Model::Token.new(:hexstring, hex,
                                    line: @hex_start[:line], column: @hex_start[:column])
        @hex_start = nil
        @state = :top
      end

      # A ")" outside a string closes nothing. Every other delimiter is
      # consumed above; this one would reach scan_word_or_number, which
      # consumes no delimiter, and the lexer would never advance.
      def unbalanced_paren!
        raise LexError.new("unbalanced ')' outside a string literal",
                           source_position: [@line, @column])
      end

      def maybe_close_dict
        if peek(1) == 62 # >>
          emit(:dict_close, ">>")
        else
          # Lone '>' is not a valid token in PS; skip and warn via token.
          advance
        end
      end

      def start_name_with_slash(_prefix)
        start_line = @line
        start_col = @column
        advance
        bytes = +""
        until eos?
          byte = peek
          break if byte.nil? || whitespace_byte?(byte) || delimiter_byte?(byte)

          bytes << byte.chr
          advance
        end
        @tokens << Model::Token.new(:name, bytes, line: start_line,
                                                  column: start_col, literal: true)
      end

      def delimiter_byte?(byte)
        return false unless byte

        char = byte.chr
        "%()<>{}/[]".include?(char)
      end

      def scan_word_or_number
        start_line = @line
        start_col = @column
        bytes = +""
        until eos?
          byte = peek
          break if byte.nil? || whitespace_byte?(byte) || delimiter_byte?(byte)

          bytes << byte.chr
          advance
        end
        emit_word(bytes, start_line, start_col)
      end

      def emit_word(bytes, line, col)
        type =
          if NUMBER_RE.match?(bytes)
            :number
          else
            :operator
          end
        @tokens << Model::Token.new(type, bytes, line: line, column: col)
      end

      NUMBER_RE = /\A[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?\z/

      def emit(type, value)
        @tokens << Model::Token.new(type, value, line: @line, column: @column)
        value.bytesize.times { advance }
      end
    end
  end
end
