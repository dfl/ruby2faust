# frozen_string_literal: true

require "strscan"

module Faust2Ruby
  # Lexer for Faust DSP source code.
  # Uses StringScanner for efficient tokenization.
  class Lexer
    # Token struct for lexer output
    Token = Struct.new(:type, :value, :line, :column, keyword_init: true)

    # Keywords in Faust
    KEYWORDS = %w[
      import declare process with letrec where
      par seq sum prod
      case of
      environment library component
      inputs outputs
    ].freeze

    # Multi-character operators (must check before single-char)
    MULTI_CHAR_OPS = {
      "<:" => :SPLIT,
      ":>" => :MERGE,
      "==" => :EQ,
      "!=" => :NEQ,
      "<=" => :LE,
      ">=" => :GE,
      "<<" => :LSHIFT,
      ">>" => :RSHIFT,
    }.freeze

    # Single-character operators and punctuation
    SINGLE_CHAR_OPS = {
      ":" => :SEQ,
      "," => :PAR,
      "~" => :REC,
      "+" => :ADD,
      "-" => :SUB,
      "*" => :MUL,
      "/" => :DIV,
      "%" => :MOD,
      "^" => :POW,
      "@" => :DELAY,
      "'" => :PRIME,
      "=" => :DEF,
      ";" => :ENDDEF,
      "(" => :LPAREN,
      ")" => :RPAREN,
      "{" => :LBRACE,
      "}" => :RBRACE,
      "[" => :LBRACKET,
      "]" => :RBRACKET,
      "<" => :LT,
      ">" => :GT,
      "&" => :AND,
      "|" => :OR,
      "!" => :CUT,
      "_" => :WIRE,
      "." => :DOT,
      "\\" => :LAMBDA,
    }.freeze

    attr_reader :tokens, :errors

    def initialize(source)
      @source = source
      @scanner = StringScanner.new(source)
      @tokens = []
      @errors = []
      @line = 1
      @line_start = 0
    end

    def tokenize
      until @scanner.eos?
        token = next_token
        @tokens << token if token
      end
      @tokens << Token.new(type: :EOF, value: nil, line: @line, column: current_column)
      @tokens
    end

    private

    def current_column
      @scanner.pos - @line_start + 1
    end

    def next_token
      skip_whitespace_and_comments

      return nil if @scanner.eos?

      start_line = @line
      start_col = current_column

      # Try to match each token type
      token = try_string ||
              try_number ||
              try_multi_char_op ||
              try_single_char_op ||
              try_identifier

      unless token
        # Unknown character - report error and skip
        char = @scanner.getch
        @errors << "Unknown character '#{char}' at line #{start_line}, column #{start_col}"
        return nil
      end

      token
    end

    def skip_whitespace_and_comments
      loop do
        # Skip whitespace, tracking newlines
        while @scanner.scan(/[ \t]+/) || @scanner.scan(/\r?\n/)
          if @scanner.matched.include?("\n")
            @line += 1
            @line_start = @scanner.pos
          end
        end

        # Skip line comments
        if @scanner.scan(%r{//[^\n]*})
          next
        end

        # Skip block comments
        if @scanner.scan(%r{/\*})
          depth = 1
          until depth.zero? || @scanner.eos?
            if @scanner.scan(%r{/\*})
              depth += 1
            elsif @scanner.scan(%r{\*/})
              depth -= 1
            elsif @scanner.scan(/\n/)
              @line += 1
              @line_start = @scanner.pos
            else
              @scanner.getch
            end
          end
          next
        end

        break
      end
    end

    def try_string
      start_line = @line
      start_col = current_column

      # Double-quoted string
      if @scanner.scan(/"/)
        value = String.new
        until @scanner.eos?
          if @scanner.scan(/\\(.)/)
            # Escape sequence
            case @scanner[1]
            when "n" then value << "\n"
            when "t" then value << "\t"
            when "r" then value << "\r"
            when "\\" then value << "\\"
            when '"' then value << '"'
            else value << @scanner[1]
            end
          elsif @scanner.scan(/"/)
            return Token.new(type: :STRING, value: value, line: start_line, column: start_col)
          elsif @scanner.scan(/[^"\\]+/)
            value << @scanner.matched
          else
            break
          end
        end
        @errors << "Unterminated string at line #{start_line}, column #{start_col}"
        return Token.new(type: :STRING, value: value, line: start_line, column: start_col)
      end

      nil
    end

    def try_number
      start_line = @line
      start_col = current_column

      # Float with optional exponent
      if @scanner.scan(/\d+\.\d+([eE][+-]?\d+)?/)
        return Token.new(type: :FLOAT, value: @scanner.matched.to_f, line: start_line, column: start_col)
      end

      # Float with exponent (no decimal point)
      if @scanner.scan(/\d+[eE][+-]?\d+/)
        return Token.new(type: :FLOAT, value: @scanner.matched.to_f, line: start_line, column: start_col)
      end

      # Integer
      if @scanner.scan(/\d+/)
        return Token.new(type: :INT, value: @scanner.matched.to_i, line: start_line, column: start_col)
      end

      nil
    end

    def try_multi_char_op
      start_line = @line
      start_col = current_column

      MULTI_CHAR_OPS.each do |op, type|
        if @scanner.scan(Regexp.new(Regexp.escape(op)))
          return Token.new(type: type, value: op, line: start_line, column: start_col)
        end
      end

      nil
    end

    def try_single_char_op
      start_line = @line
      start_col = current_column

      char = @scanner.peek(1)
      if SINGLE_CHAR_OPS.key?(char)
        @scanner.getch
        return Token.new(type: SINGLE_CHAR_OPS[char], value: char, line: start_line, column: start_col)
      end

      nil
    end

    def try_identifier
      start_line = @line
      start_col = current_column

      # Identifiers: start with letter or underscore (but not just _)
      # Allow dots for qualified names like os.osc
      if @scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
        value = @scanner.matched

        # Check if it's a keyword
        if KEYWORDS.include?(value)
          type = value.upcase.to_sym
          return Token.new(type: type, value: value, line: start_line, column: start_col)
        end

        return Token.new(type: :IDENT, value: value, line: start_line, column: start_col)
      end

      nil
    end
  end
end
