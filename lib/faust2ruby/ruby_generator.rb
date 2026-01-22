# frozen_string_literal: true

require_relative "ast"
require_relative "library_mapper"

module Faust2Ruby
  # Generates idiomatic Ruby DSL code from Faust AST.
  # Produces code compatible with the ruby2faust gem.
  class RubyGenerator
    def initialize(options = {})
      @indent = options.fetch(:indent, 2)
      @expression_only = options.fetch(:expression_only, false)
      @definitions = {}
    end

    # Generate Ruby code from a parsed Faust program
    def generate(program)
      lines = []

      # Merge multi-rule functions into case expressions
      merged_statements = merge_multirule_functions(program.statements)

      # Collect definitions for reference
      merged_statements.each do |stmt|
        @definitions[stmt.name] = stmt if stmt.is_a?(AST::Definition)
      end

      # Collect imports and declares
      imports = program.statements.select { |s| s.is_a?(AST::Import) }.map(&:path)
      declares = program.statements.select { |s| s.is_a?(AST::Declare) }

      # Standard Faust output names
      output_names = %w[process effect]

      unless @expression_only
        lines << "require 'ruby2faust'"
        lines << "include Ruby2Faust::DSL"
        lines << ""

        # Generate declares as comments
        declares.each do |stmt|
          lines << "# declare #{stmt.key} \"#{stmt.value}\""
        end

        lines << "" if declares.any?

        # Generate helper definitions (excluding outputs)
        merged_statements.each do |stmt|
          if stmt.is_a?(AST::Definition) && !output_names.include?(stmt.name)
            lines << generate_definition(stmt)
            lines << ""
          end
        end
      end

      # Find the main output (process or effect)
      output_name = output_names.find { |name| @definitions[name] }
      output_def = @definitions[output_name] if output_name

      if output_def
        if @expression_only
          lines << generate_expression(output_def.expression)
        else
          lines << "#{output_name} = #{generate_expression(output_def.expression)}"
          lines << ""

          # Build program with imports and declares
          lines << "prog = Ruby2Faust::Program.new(#{output_name})"
          imports.each do |imp|
            lines << "  .import(#{imp.inspect})" unless imp == "stdfaust.lib"
          end
          declares.each do |d|
            lines << "  .declare(:#{d.key}, #{d.value.inspect})"
          end
          lines << ""
          lines << "puts Ruby2Faust::Emitter.program(prog, output: #{output_name.inspect})"
        end
      end

      lines.join("\n")
    end

    # Generate just the expression part (for embedding)
    def generate_expression(node)
      case node
      when AST::IntLiteral
        node.value.to_s

      when AST::FloatLiteral
        node.value.to_s

      when AST::StringLiteral
        node.value.inspect

      when AST::Wire
        "wire"

      when AST::Cut
        "cut"

      when AST::Identifier
        generate_identifier(node)

      when AST::QualifiedName
        generate_qualified_name(node)

      when AST::BinaryOp
        generate_binary_op(node)

      when AST::UnaryOp
        generate_unary_op(node)

      when AST::FunctionCall
        generate_function_call(node)

      when AST::UIElement
        generate_ui_element(node)

      when AST::UIGroup
        generate_ui_group(node)

      when AST::Iteration
        generate_iteration(node)

      when AST::Lambda
        generate_lambda(node)

      when AST::Waveform
        generate_waveform(node)

      when AST::Table
        generate_table(node)

      when AST::Route
        generate_route(node)

      when AST::Prime
        generate_prime(node)

      when AST::Access
        generate_access(node)

      when AST::Paren
        "(#{generate_expression(node.expression)})"

      when AST::With
        generate_with(node)

      when AST::Letrec
        generate_letrec(node)

      when AST::CaseExpr
        generate_case_expr(node)

      else
        make_literal("/* unknown: #{node.class} */")
      end
    end

    private

    # Merge multi-rule function definitions into case expressions
    # e.g., fact(0) = 1; fact(n) = n * fact(n-1);
    # becomes: fact = case { (0) => 1; (n) => n * fact(n-1); }
    def merge_multirule_functions(statements)
      # Group definitions by name
      definition_groups = {}
      other_statements = []

      statements.each do |stmt|
        if stmt.is_a?(AST::Definition)
          (definition_groups[stmt.name] ||= []) << stmt
        else
          other_statements << stmt
        end
      end

      # Process each group
      merged_definitions = []
      definition_groups.each do |name, defs|
        if defs.length == 1
          # Single definition - keep as-is
          merged_definitions << defs[0]
        elsif defs.all? { |d| d.params.length == 1 }
          # Multiple definitions with single param each - merge into case
          # This handles patterns like fact(0) = 1; fact(n) = n * fact(n-1);
          merged_definitions << merge_to_case(name, defs)
        else
          # Multiple definitions but not simple pattern matching
          # Keep the last one (original behavior) with a warning comment
          merged_definitions << defs.last
        end
      end

      # Reconstruct statement order: imports, declares, definitions
      other_statements + merged_definitions
    end

    # Merge multiple definitions into a single definition with a case expression
    def merge_to_case(name, defs)
      branches = defs.map do |defn|
        # The param becomes the pattern
        param = defn.params[0]

        # Check if param looks like an integer literal pattern
        # In Faust, fact(0) means param is literally "0"
        pattern = if param =~ /^\d+$/
                    AST::IntLiteral.new(param.to_i, line: defn.line, column: defn.column)
                  else
                    AST::Identifier.new(param, line: defn.line, column: defn.column)
                  end

        AST::CaseBranch.new(pattern, defn.expression, line: defn.line, column: defn.column)
      end

      case_expr = AST::CaseExpr.new(branches, line: defs[0].line, column: defs[0].column)
      AST::Definition.new(name, case_expr, params: [], line: defs[0].line, column: defs[0].column)
    end

    # Check if a node is a numeric literal that needs wrapping for composition
    def numeric_literal?(node)
      node.is_a?(AST::IntLiteral) || node.is_a?(AST::FloatLiteral)
    end

    # Recursively check if a node is effectively a numeric value
    # (handles parens, negation, etc.)
    def effective_numeric?(node)
      case node
      when AST::IntLiteral, AST::FloatLiteral
        true
      when AST::UnaryOp
        node.op == :NEG && effective_numeric?(node.operand)
      when AST::Paren
        effective_numeric?(node.expression)
      else
        false
      end
    end

    # Wrap numeric literals with num() for composition operators
    # Without this, Ruby's >> would be bit-shift instead of DSL sequencing
    def wrap_for_composition(node)
      expr = generate_expression(node)
      if effective_numeric?(node)
        "num(#{expr})"
      else
        expr
      end
    end

    def generate_definition(stmt)
      if stmt.params.empty?
        "#{stmt.name} = #{generate_expression(stmt.expression)}"
      else
        # Downcase parameter names (Ruby doesn't allow constants as formal args)
        params_str = stmt.params.map { |p| ruby_safe_param(p) }.join(", ")
        "def #{stmt.name}(#{params_str})\n  #{generate_expression(stmt.expression)}\nend"
      end
    end

    # Convert parameter name to Ruby-safe lowercase
    def ruby_safe_param(name)
      # Downcase if it starts with uppercase (would be a constant)
      name[0] =~ /[A-Z]/ ? name.downcase : name
    end

    # Generate a literal() call with properly escaped content
    def make_literal(content)
      "literal(#{content.inspect})"
    end

    # Extract Faust code from a Ruby expression for embedding in literals
    # e.g., 'literal("foo")' -> 'foo', 'x' -> 'x'
    def to_faust(ruby_expr)
      if ruby_expr =~ /\Aliteral\(["'](.*)["']\)\z/
        $1.gsub(/\\"/, '"')  # Unescape quotes
      else
        ruby_expr
      end
    end

    def generate_identifier(node)
      name = node.name

      # Handle primitive operators used as identifiers
      case name
      when "+"
        "add"
      when "-"
        "sub"
      when "*"
        "mul"
      when "/"
        "div"
      when "mem"
        "mem"
      else
        # Check for known primitives that become method calls
        if LibraryMapper::PRIMITIVES.key?(name)
          mapping = LibraryMapper::PRIMITIVES[name]
          if mapping[:args] == 0
            mapping[:dsl].to_s
          else
            name  # Function reference
          end
        elsif @definitions.key?(name)
          # User-defined function used as signal processor
          defn = @definitions[name]
          if defn.params.length == 1
            # Single-param function used point-free: call with wire
            "#{name}(wire)"
          elsif defn.params.empty?
            name  # Variable reference
          else
            # Multi-param function - needs partial application
            name
          end
        else
          name
        end
      end
    end

    def generate_qualified_name(node)
      name = node.to_s

      # Check library mapping
      mapping = LibraryMapper.lookup(name)
      if mapping
        if mapping[:args] == 0
          mapping[:dsl].to_s
        else
          # Return as a method name for partial application
          mapping[:dsl].to_s
        end
      else
        "literal(#{name.inspect})"
      end
    end

    def generate_binary_op(node)
      # For composition operators, wrap numeric literals with num()
      # to avoid Ruby interpreting >> as bit-shift
      case node.op
      when :SEQ, :PAR, :SPLIT, :MERGE, :REC
        left = wrap_for_composition(node.left)
        right = wrap_for_composition(node.right)
      else
        left = generate_expression(node.left)
        right = generate_expression(node.right)
      end

      case node.op
      when :SEQ
        # Idiomatic Ruby: signal : *(x) becomes x * signal
        if node.right.is_a?(AST::FunctionCall) && node.right.name == "*" && node.right.args.length == 1
          arg = generate_expression(node.right.args[0])
          "(#{arg} * #{left})"
        # Idiomatic Ruby: signal : /(x) becomes signal / x
        elsif node.right.is_a?(AST::FunctionCall) && node.right.name == "/" && node.right.args.length == 1
          arg = generate_expression(node.right.args[0])
          "(#{left} / #{arg})"
        else
          "(#{left} >> #{right})"
        end
      when :PAR
        "(#{left} | #{right})"
      when :SPLIT
        "#{left}.split(#{right})"
      when :MERGE
        "#{left}.merge(#{right})"
      when :REC
        "(#{left} ~ #{right})"
      when :ADD
        "(#{left} + #{right})"
      when :SUB
        "(#{left} - #{right})"
      when :MUL
        "(#{left} * #{right})"
      when :DIV
        "(#{left} / #{right})"
      when :MOD
        "(#{left} % #{right})"
      when :POW
        "pow(#{left}, #{right})"
      when :DELAY
        "delay(#{left}, #{right})"
      when :AND
        "(#{left} & #{right})"
      when :OR
        # Use bor() method to avoid conflict with parallel composition |
        "#{left}.bor(#{right})"
      when :LT
        "(#{left} < #{right})"
      when :GT
        "(#{left} > #{right})"
      when :LE
        "(#{left} <= #{right})"
      when :GE
        "(#{left} >= #{right})"
      when :EQ
        # Use eq() method since Ruby's == must return boolean
        "#{left}.eq(#{right})"
      when :NEQ
        "#{left}.neq(#{right})"
      else
        make_literal("(#{to_faust(left)} #{node.op} #{to_faust(right)})")
      end
    end

    def generate_unary_op(node)
      operand = generate_expression(node.operand)

      case node.op
      when :NEG
        "(-#{operand})"
      else
        make_literal("#{node.op}(#{to_faust(operand)})")
      end
    end

    def generate_function_call(node)
      name = node.name
      args = node.args.map { |a| generate_expression(a) }

      # Handle prefix operator forms
      case name
      when "*"
        # *(x) -> gain(x)
        if args.length == 1
          return "gain(#{args[0]})"
        else
          return "(#{args.join(' * ')})"
        end
      when "+"
        # +(x) is a signal processor: input + x
        return args.length == 1 ? "(wire + #{args[0]})" : "(#{args.join(' + ')})"
      when "-"
        # -(x) is a signal processor: input - x
        return args.length == 1 ? "(wire - #{args[0]})" : "(#{args.join(' - ')})"
      when "/"
        return args.length == 1 ? make_literal("/(#{to_faust(args[0])})") : "(#{args.join(' / ')})"
      end

      # Check library mapping
      mapping = LibraryMapper.lookup(name)
      if mapping
        generate_mapped_call(mapping, args, name)
      elsif @definitions.key?(name)
        # User-defined function - call directly as Ruby method
        "#{name}(#{args.join(', ')})"
      else
        # Unknown function - emit as literal with Faust code
        faust_args = args.map { |a| to_faust(a) }.join(", ")
        make_literal("#{name}(#{faust_args})")
      end
    end

    def generate_mapped_call(mapping, args, original_name)
      dsl_method = mapping[:dsl]

      case dsl_method
      when :lp, :hp
        # fi.lowpass(order, freq) -> lp(freq, order: order)
        if args.length >= 2
          order = args[0]
          freq = args[1]
          "#{dsl_method}(#{freq}, order: #{order})"
        else
          "#{dsl_method}(#{args.join(', ')})"
        end

      when :slider
        # hslider already parsed as UIElement
        "#{dsl_method}(#{args.join(', ')})"

      when :selectn
        # ba.selectn(n, idx, ...) -> selectn(n, idx, ...)
        "selectn(#{args.join(', ')})"

      when :db2linear
        # ba.db2linear(-6) -> -6.db (idiomatic Ruby)
        # Handle both "-6" and "(-6)" forms
        arg = args[0]&.gsub(/\A\(|\)\z/, '') # strip outer parens
        if args.length == 1 && arg&.match?(/\A-?\d+\.?\d*\z/)
          "#{arg}.db"
        else
          "db2linear(#{args.join(', ')})"
        end

      when :midi2hz
        # ba.midikey2hz(60) -> 60.midi (idiomatic Ruby)
        if args.length == 1 && args[0].match?(/\A\d+\.?\d*\z/)
          "#{args[0]}.midi"
        else
          "midi2hz(#{args.join(', ')})"
        end

      when :sec2samp
        # ba.sec2samp(0.1) -> 0.1.sec (idiomatic Ruby)
        if args.length == 1 && args[0].match?(/\A\d+\.?\d*\z/)
          "#{args[0]}.sec"
        else
          "sec2samp(#{args.join(', ')})"
        end

      else
        # Standard call - check for partial application
        expected_args = mapping[:args]
        if expected_args.is_a?(Integer) && args.length < expected_args && args.length > 0
          # Partial application - generate flambda for remaining args
          missing = expected_args - args.length
          if missing == 1
            "flambda(:x) { |x| #{dsl_method}(#{args.join(', ')}, x) }"
          elsif missing == 2
            "flambda(:x, :y) { |x, y| #{dsl_method}(#{args.join(', ')}, x, y) }"
          elsif missing == 3
            "flambda(:x, :y, :z) { |x, y, z| #{dsl_method}(#{args.join(', ')}, x, y, z) }"
          else
            # Too many missing args - use literal
            faust_args = args.map { |a| to_faust(a) }.join(", ")
            make_literal("#{original_name}(#{faust_args})")
          end
        elsif args.empty?
          dsl_method.to_s
        else
          "#{dsl_method}(#{args.join(', ')})"
        end
      end
    end

    def generate_ui_element(node)
      case node.type
      when :hslider
        init = generate_expression(node.init)
        min = generate_expression(node.min)
        max = generate_expression(node.max)
        step = generate_expression(node.step)
        "hslider(#{node.label.inspect}, init: #{init}, min: #{min}, max: #{max}, step: #{step})"

      when :vslider
        init = generate_expression(node.init)
        min = generate_expression(node.min)
        max = generate_expression(node.max)
        step = generate_expression(node.step)
        "vslider(#{node.label.inspect}, init: #{init}, min: #{min}, max: #{max}, step: #{step})"

      when :nentry
        init = generate_expression(node.init)
        min = generate_expression(node.min)
        max = generate_expression(node.max)
        step = generate_expression(node.step)
        "nentry(#{node.label.inspect}, init: #{init}, min: #{min}, max: #{max}, step: #{step})"

      when :button
        "button(#{node.label.inspect})"

      when :checkbox
        "checkbox(#{node.label.inspect})"
      end
    end

    def generate_ui_group(node)
      content = generate_expression(node.content)

      case node.type
      when :hgroup
        "hgroup(#{node.label.inspect}) { #{content} }"
      when :vgroup
        "vgroup(#{node.label.inspect}) { #{content} }"
      when :tgroup
        "tgroup(#{node.label.inspect}) { #{content} }"
      end
    end

    def generate_iteration(node)
      var = node.var
      count = generate_expression(node.count)
      body = generate_expression(node.body)

      method = case node.type
               when :par then "fpar"
               when :seq then "fseq"
               when :sum then "fsum"
               when :prod then "fprod"
               end

      "#{method}(#{count}) { |#{var}| #{body} }"
    end

    def generate_lambda(node)
      params = node.params.join(", ")
      body = generate_expression(node.body)

      if node.params.length == 1
        "flambda(:#{node.params[0]}) { |#{params}| #{body} }"
      else
        params_syms = node.params.map { |p| ":#{p}" }.join(", ")
        "flambda(#{params_syms}) { |#{params}| #{body} }"
      end
    end

    def generate_waveform(node)
      values = node.values.map { |v| generate_expression(v) }
      "waveform(#{values.join(', ')})"
    end

    def generate_table(node)
      args = node.args.map { |a| generate_expression(a) }

      case node.type
      when :rdtable
        "rdtable(#{args.join(', ')})"
      when :rwtable
        "rwtable(#{args.join(', ')})"
      end
    end

    def generate_route(node)
      ins = generate_expression(node.ins)
      outs = generate_expression(node.outs)
      connections = node.connections.map do |from, to|
        "[#{generate_expression(from)}, #{generate_expression(to)}]"
      end
      "route(#{ins}, #{outs}, [#{connections.join(', ')}])"
    end

    def generate_prime(node)
      operand = generate_expression(node.operand)
      "(#{operand} >> mem)"
    end

    def generate_access(node)
      operand = generate_expression(node.operand)
      index = generate_expression(node.index)
      make_literal("#{to_faust(operand)}[#{to_faust(index)}]")
    end

    def generate_with(node)
      # Generate local definitions inside a lambda for proper scoping
      lines = ["-> {"]

      # Add local definitions to @definitions for forward reference support
      local_defs = {}
      node.definitions.each do |defn|
        local_defs[defn.name] = defn
        @definitions[defn.name] = defn
      end

      # Generate each local definition
      node.definitions.each do |defn|
        if defn.params.empty?
          # Simple variable definition
          lines << "  #{defn.name} = #{generate_expression(defn.expression)}"
        else
          # Function definition - generate as flambda (creates DSP node)
          params = defn.params.map { |p| ruby_safe_param(p) }
          params_syms = params.map { |p| ":#{p}" }.join(", ")
          params_str = params.join(", ")
          lines << "  #{defn.name} = flambda(#{params_syms}) { |#{params_str}| #{generate_expression(defn.expression)} }"
        end
      end

      # Generate the main expression
      lines << "  #{generate_expression(node.expression)}"
      lines << "}.call"

      # Remove local definitions from @definitions (restore scope)
      local_defs.each_key { |name| @definitions.delete(name) }

      lines.join("\n")
    end

    def generate_letrec(node)
      # Letrec is complex - generate as literal for now
      defs = node.definitions.map do |d|
        "#{d.name} = #{to_faust(generate_expression(d.expression))}"
      end.join("; ")
      expr = node.expression ? to_faust(generate_expression(node.expression)) : "_"
      make_literal("letrec { #{defs} } #{expr}")
    end

    # Generate code for case expressions
    # case { (0) => a; (1) => b; (n) => c; }
    # converts to: fcase(0 => a, 1 => b) { |n| c }
    def generate_case_expr(node)
      branches = node.branches

      # Separate integer patterns from variable patterns (catch-all)
      int_branches = []
      default_branch = nil

      branches.each do |branch|
        pattern = branch.pattern
        if pattern.is_a?(AST::IntLiteral) || (pattern.is_a?(AST::Paren) && pattern.expression.is_a?(AST::IntLiteral))
          # Integer pattern
          val = pattern.is_a?(AST::Paren) ? pattern.expression.value : pattern.value
          int_branches << { value: val, result: branch.result }
        elsif pattern.is_a?(AST::Identifier) || (pattern.is_a?(AST::Paren) && pattern.expression.is_a?(AST::Identifier))
          # Variable pattern - this is the default/catch-all case
          var_name = pattern.is_a?(AST::Paren) ? pattern.expression.name : pattern.name
          default_branch = { var: var_name, result: branch.result }
        else
          # Complex pattern - fall back to literal
          return generate_case_literal(node)
        end
      end

      # If no integer patterns at all, fall back to literal
      if int_branches.empty?
        return generate_case_literal(node)
      end

      # Get variable name from default branch if present, else use 'x'
      var = default_branch ? ruby_safe_param(default_branch[:var]) : "x"

      # Build the fcase pattern hash
      patterns = int_branches.map do |branch|
        "#{branch[:value]} => #{generate_expression(branch[:result])}"
      end.join(", ")

      # Build default expression
      if default_branch
        default_expr = generate_expression(default_branch[:result])
      else
        # No default - use 0 as fallback
        default_expr = "0"
      end

      "fcase(#{patterns}) { |#{var}| #{default_expr} }"
    end

    # Fall back to literal for complex case expressions
    def generate_case_literal(node)
      branches_str = node.branches.map do |branch|
        pattern_str = to_faust(generate_expression(branch.pattern))
        result_str = to_faust(generate_expression(branch.result))
        "(#{pattern_str}) => #{result_str}"
      end.join("; ")
      make_literal("case { #{branches_str}; }")
    end
  end
end
