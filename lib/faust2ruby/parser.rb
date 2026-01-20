# frozen_string_literal: true

require_relative "lexer"
require_relative "ast"

module Faust2Ruby
  # Recursive descent parser for Faust DSP programs.
  # Grammar based on Faust's official grammar with simplified precedence.
  class Parser
    class ParseError < StandardError
      attr_reader :line, :column

      def initialize(message, line: nil, column: nil)
        @line = line
        @column = column
        super("#{message} at line #{line}, column #{column}")
      end
    end

    # Operator precedence (lowest to highest)
    # In Faust: SEQ < PAR < SPLIT/MERGE < REC < arithmetic
    PRECEDENCE = {
      PAR: 1,      # , (parallel - lowest, used as arg separator)
      SEQ: 2,      # : (sequential)
      SPLIT: 3,    # <:
      MERGE: 3,    # :>
      REC: 4,      # ~
      OR: 5,       # |
      AND: 6,      # &
      LT: 7, GT: 7, LE: 7, GE: 7, EQ: 7, NEQ: 7,  # comparison
      ADD: 8, SUB: 8,  # + -
      MUL: 9, DIV: 9, MOD: 9,  # * / %
      POW: 10,     # ^
      DELAY: 11,   # @
    }.freeze

    def initialize(source)
      @lexer = Lexer.new(source)
      @tokens = @lexer.tokenize
      @pos = 0
      @errors = @lexer.errors.dup
    end

    def parse
      statements = []
      until current_type == :EOF
        stmt = parse_statement
        statements << stmt if stmt
      end
      AST::Program.new(statements)
    end

    attr_reader :errors

    private

    def current
      @tokens[@pos]
    end

    def current_type
      current&.type || :EOF
    end

    def current_value
      current&.value
    end

    def peek(offset = 1)
      @tokens[@pos + offset]
    end

    def advance
      token = current
      @pos += 1
      token
    end

    def expect(type)
      if current_type == type
        advance
      else
        error("Expected #{type}, got #{current_type}")
        nil
      end
    end

    def error(message)
      token = current || @tokens.last
      @errors << "#{message} at line #{token&.line}, column #{token&.column}"
      # Skip to next statement boundary for recovery
      advance until [:ENDDEF, :EOF].include?(current_type)
      advance if current_type == :ENDDEF
      nil
    end

    def parse_statement
      case current_type
      when :IMPORT
        parse_import
      when :DECLARE
        parse_declare
      when :IDENT, :PROCESS
        # PROCESS is also a valid definition target
        parse_definition
      else
        advance  # skip unknown
        nil
      end
    end

    def parse_import
      token = advance  # consume 'import'
      expect(:LPAREN)
      path_token = expect(:STRING)
      path = path_token&.value
      expect(:RPAREN)
      expect(:ENDDEF)
      AST::Import.new(path, line: token.line, column: token.column)
    end

    def parse_declare
      token = advance  # consume 'declare'
      key_token = expect(:IDENT)
      key = key_token&.value
      value_token = expect(:STRING)
      value = value_token&.value
      expect(:ENDDEF)
      AST::Declare.new(key, value, line: token.line, column: token.column)
    end

    def parse_definition
      token = current
      name_token = advance  # consume identifier or process keyword
      name = name_token.type == :PROCESS ? "process" : name_token.value

      # Check for parameters: name(x, y) = ... or name(0) = ... (pattern matching)
      params = []
      if current_type == :LPAREN
        advance  # consume (
        until current_type == :RPAREN || current_type == :EOF
          # Accept both identifiers and integer literals (for pattern matching)
          if current_type == :IDENT
            params << advance.value
          elsif current_type == :INT
            # Integer pattern - store as string so merge_to_case can detect it
            params << advance.value.to_s
          else
            error("Expected identifier or integer pattern")
            break
          end
          break unless current_type == :PAR
          advance  # consume ,
        end
        expect(:RPAREN)
      end

      expect(:DEF)
      expr = parse_expression

      # Handle 'with' clause: expr with { definitions }
      if current_type == :WITH
        expr = parse_with_clause(expr)
      end

      expect(:ENDDEF)
      AST::Definition.new(name, expr, params: params, line: token.line, column: token.column)
    end

    def parse_with_clause(expr)
      token = advance  # consume 'with'
      expect(:LBRACE)
      definitions = []
      until current_type == :RBRACE || current_type == :EOF
        if current_type == :IDENT
          def_token = current
          name = advance.value
          # Check for parameters
          params = []
          if current_type == :LPAREN
            advance
            until current_type == :RPAREN || current_type == :EOF
              param_token = expect(:IDENT)
              params << param_token.value if param_token
              break unless current_type == :PAR
              advance
            end
            expect(:RPAREN)
          end
          expect(:DEF)
          def_expr = parse_expression
          # Handle nested with
          if current_type == :WITH
            def_expr = parse_with_clause(def_expr)
          end
          expect(:ENDDEF)
          definitions << AST::Definition.new(name, def_expr, params: params, line: def_token.line, column: def_token.column)
        else
          break
        end
      end
      expect(:RBRACE)
      AST::With.new(expr, definitions, line: token.line, column: token.column)
    end

    def parse_expression(min_prec = 0)
      left = parse_unary

      while binary_op?(current_type) && PRECEDENCE[current_type] >= min_prec
        op_token = advance
        op = op_token.type
        # Right associativity for some operators
        next_prec = right_associative?(op) ? PRECEDENCE[op] : PRECEDENCE[op] + 1
        right = parse_expression(next_prec)
        left = AST::BinaryOp.new(op, left, right, line: op_token.line, column: op_token.column)
      end

      left
    end

    def binary_op?(type)
      PRECEDENCE.key?(type)
    end

    def right_associative?(op)
      [:POW, :SEQ].include?(op)
    end

    def parse_unary
      if current_type == :SUB
        # Check if this is a prefix operator form: - (x) vs unary negation -x
        # If followed by LPAREN, it's a prefix operator (subtract from input)
        if peek&.type == :LPAREN
          return parse_postfix  # Will handle as prefix operator in parse_primary
        end
        token = advance
        operand = parse_unary
        return AST::UnaryOp.new(:NEG, operand, line: token.line, column: token.column)
      end

      parse_postfix
    end

    def parse_postfix
      expr = parse_primary

      loop do
        case current_type
        when :PRIME
          # Delay: expr'
          token = advance
          expr = AST::Prime.new(expr, line: token.line, column: token.column)
        when :LBRACKET
          # Access: expr[n]
          token = advance
          index = parse_expression
          expect(:RBRACKET)
          expr = AST::Access.new(expr, index, line: token.line, column: token.column)
        when :LPAREN
          # Function call when following an identifier
          if expr.is_a?(AST::Identifier) || expr.is_a?(AST::QualifiedName)
            name = expr.is_a?(AST::QualifiedName) ? expr.to_s : expr.name
            args = parse_call_args
            expr = AST::FunctionCall.new(name, args, line: expr.line, column: expr.column)
          else
            break
          end
        when :DOT
          # Qualified name continuation
          advance
          if current_type == :IDENT
            name_token = advance
            parts = expr.is_a?(AST::QualifiedName) ? expr.parts.dup : [expr.name]
            parts << name_token.value
            expr = AST::QualifiedName.new(parts, line: expr.line, column: expr.column)
          else
            error("Expected identifier after '.'")
            break
          end
        when :LETREC
          # Postfix letrec: expr letrec { ... }
          letrec = parse_letrec_expr
          expr = AST::Letrec.new(letrec.definitions, expr, line: letrec.line, column: letrec.column)
        else
          break
        end
      end

      expr
    end

    def parse_call_args
      args = []
      expect(:LPAREN)
      until current_type == :RPAREN || current_type == :EOF
        # Parse argument with minimum precedence above PAR to stop at commas
        args << parse_expression(PRECEDENCE[:PAR] + 1)
        break unless current_type == :PAR
        advance  # consume ,
      end
      expect(:RPAREN)
      args
    end

    def parse_primary
      token = current

      case current_type
      when :INT
        advance
        AST::IntLiteral.new(token.value, line: token.line, column: token.column)

      when :FLOAT
        advance
        AST::FloatLiteral.new(token.value, line: token.line, column: token.column)

      when :STRING
        advance
        AST::StringLiteral.new(token.value, line: token.line, column: token.column)

      when :WIRE
        advance
        AST::Wire.new(line: token.line, column: token.column)

      when :CUT
        advance
        AST::Cut.new(line: token.line, column: token.column)

      when :MUL, :ADD, :SUB, :DIV, :MOD
        # Could be prefix form *(0.5) or standalone primitive +
        if peek&.type == :LPAREN
          parse_prefix_operator
        else
          # Standalone primitive operator
          token = advance
          name = case token.type
                 when :MUL then "*"
                 when :ADD then "+"
                 when :SUB then "-"
                 when :DIV then "/"
                 when :MOD then "%"
                 end
          AST::Identifier.new(name, line: token.line, column: token.column)
        end

      when :IDENT
        parse_identifier_or_call

      when :LPAREN
        parse_paren

      when :LBRACE
        parse_waveform_or_environment

      when :LAMBDA
        parse_lambda

      when :PAR, :SEQ, :SUM, :PROD
        parse_iteration

      when :LETREC
        parse_letrec_expr

      when :CASE
        parse_case_expr

      else
        error("Unexpected token #{current_type}")
        nil
      end
    end

    def parse_prefix_operator
      token = advance  # consume the operator
      op = token.type
      args = parse_call_args  # Parse arguments in parentheses

      # Create a function call AST node for prefix operators
      name = case op
             when :MUL then "*"
             when :ADD then "+"
             when :SUB then "-"
             when :DIV then "/"
             end
      AST::FunctionCall.new(name, args, line: token.line, column: token.column)
    end

    def parse_identifier_or_call
      token = advance
      name = token.value

      # Check for UI elements
      case name
      when "hslider", "vslider", "nentry"
        return parse_slider(name, token)
      when "button", "checkbox"
        return parse_button(name, token)
      when "hgroup", "vgroup", "tgroup"
        return parse_group(name, token)
      when "rdtable", "rwtable"
        return parse_table(name, token)
      when "route"
        return parse_route(token)
      when "waveform"
        return parse_waveform_call(token)
      end

      # Simple identifier - qualified names handled in postfix
      AST::Identifier.new(name, line: token.line, column: token.column)
    end

    def parse_slider(type, token)
      expect(:LPAREN)
      label = expect(:STRING)&.value
      expect(:PAR)
      init = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:PAR)
      min = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:PAR)
      max = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:PAR)
      step = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:RPAREN)
      AST::UIElement.new(type.to_sym, label, init: init, min: min, max: max, step: step,
                         line: token.line, column: token.column)
    end

    def parse_button(type, token)
      expect(:LPAREN)
      label = expect(:STRING)&.value
      expect(:RPAREN)
      AST::UIElement.new(type.to_sym, label, line: token.line, column: token.column)
    end

    def parse_group(type, token)
      expect(:LPAREN)
      label = expect(:STRING)&.value
      expect(:PAR)
      content = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:RPAREN)
      AST::UIGroup.new(type.to_sym, label, content, line: token.line, column: token.column)
    end

    def parse_table(type, token)
      args = parse_call_args
      AST::Table.new(type.to_sym, args, line: token.line, column: token.column)
    end

    def parse_route(token)
      expect(:LPAREN)
      ins = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:PAR)
      outs = parse_expression(PRECEDENCE[:PAR] + 1)
      connections = []
      while current_type == :PAR
        advance
        expect(:LPAREN)
        from = parse_expression(PRECEDENCE[:PAR] + 1)
        expect(:PAR)
        to = parse_expression(PRECEDENCE[:PAR] + 1)
        expect(:RPAREN)
        connections << [from, to]
      end
      expect(:RPAREN)
      AST::Route.new(ins, outs, connections, line: token.line, column: token.column)
    end

    def parse_waveform_call(token)
      if current_type == :LBRACE
        advance  # consume {
        values = []
        until current_type == :RBRACE || current_type == :EOF
          # Parse with minimum precedence above PAR to stop at commas
          values << parse_expression(PRECEDENCE[:PAR] + 1)
          break unless current_type == :PAR
          advance
        end
        expect(:RBRACE)
        AST::Waveform.new(values, line: token.line, column: token.column)
      else
        # Just an identifier named 'waveform'
        AST::Identifier.new("waveform", line: token.line, column: token.column)
      end
    end

    def parse_paren
      token = advance  # consume (
      expr = parse_expression
      expect(:RPAREN)
      AST::Paren.new(expr, line: token.line, column: token.column)
    end

    def parse_waveform_or_environment
      token = advance  # consume {
      values = []
      until current_type == :RBRACE || current_type == :EOF
        # Parse with minimum precedence above PAR to stop at commas
        values << parse_expression(PRECEDENCE[:PAR] + 1)
        break unless current_type == :PAR
        advance
      end
      expect(:RBRACE)
      AST::Waveform.new(values, line: token.line, column: token.column)
    end

    def parse_lambda
      token = advance  # consume \
      expect(:LPAREN)
      params = []
      until current_type == :RPAREN || current_type == :EOF
        param = expect(:IDENT)
        params << param.value if param
        break unless current_type == :PAR
        advance
      end
      expect(:RPAREN)
      expect(:DOT)
      expect(:LPAREN)
      body = parse_expression
      expect(:RPAREN)
      AST::Lambda.new(params, body, line: token.line, column: token.column)
    end

    def parse_iteration
      token = advance  # consume par/seq/sum/prod
      type = token.value.to_sym
      expect(:LPAREN)
      var = expect(:IDENT)&.value
      expect(:PAR)
      count = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:PAR)
      body = parse_expression(PRECEDENCE[:PAR] + 1)
      expect(:RPAREN)
      AST::Iteration.new(type, var, count, body, line: token.line, column: token.column)
    end

    def parse_letrec_expr
      token = advance  # consume letrec
      expect(:LBRACE)
      definitions = []
      until current_type == :RBRACE || current_type == :EOF
        # Handle prime notation for state variables: 'x = expr;
        has_prime = false
        if current_type == :PRIME
          has_prime = true
          advance  # consume '
        end

        if current_type == :IDENT
          name = advance.value
          name = "'#{name}" if has_prime  # Mark as state variable
          expect(:DEF)
          expr = parse_expression
          # Handle nested with
          if current_type == :WITH
            expr = parse_with_clause(expr)
          end
          expect(:ENDDEF)
          definitions << AST::Definition.new(name, expr)
        else
          break
        end
      end
      expect(:RBRACE)
      AST::Letrec.new(definitions, nil, line: token.line, column: token.column)
    end

    # Parse case expression: case { (pattern) => expr; ... }
    def parse_case_expr
      token = advance  # consume 'case'
      expect(:LBRACE)
      branches = []

      until current_type == :RBRACE || current_type == :EOF
        # Parse pattern: (pattern)
        expect(:LPAREN)
        pattern = parse_expression(PRECEDENCE[:PAR] + 1)
        expect(:RPAREN)

        # Parse arrow: =>
        expect(:ARROW)

        # Parse result expression
        result = parse_expression

        # End of branch: ;
        expect(:ENDDEF)

        branches << AST::CaseBranch.new(pattern, result, line: token.line, column: token.column)
      end

      expect(:RBRACE)
      AST::CaseExpr.new(branches, line: token.line, column: token.column)
    end
  end
end
