# frozen_string_literal: true

require_relative "../test_helper"
require "faust2ruby"

class Faust2Ruby::ParserTest < Minitest::Test
  def parse(source)
    Faust2Ruby::Parser.new(source).parse
  end

  def test_parse_import
    program = parse('import("stdfaust.lib");')
    assert_equal 1, program.statements.length
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Import, stmt
    assert_equal "stdfaust.lib", stmt.path
  end

  def test_parse_declare
    program = parse('declare name "test";')
    assert_equal 1, program.statements.length
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Declare, stmt
    assert_equal "name", stmt.key
    assert_equal "test", stmt.value
  end

  def test_parse_simple_definition
    program = parse("process = 42;")
    assert_equal 1, program.statements.length
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Definition, stmt
    assert_equal "process", stmt.name
    assert_instance_of Faust2Ruby::AST::IntLiteral, stmt.expression
    assert_equal 42, stmt.expression.value
  end

  def test_parse_wire
    program = parse("process = _;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Wire, stmt.expression
  end

  def test_parse_cut
    program = parse("process = !;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Cut, stmt.expression
  end

  def test_parse_sequential_composition
    program = parse("process = a : b;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::BinaryOp, stmt.expression
    assert_equal :SEQ, stmt.expression.op
  end

  def test_parse_parallel_composition
    program = parse("process = a , b;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::BinaryOp, stmt.expression
    assert_equal :PAR, stmt.expression.op
  end

  def test_parse_split
    program = parse("process = a <: b;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::BinaryOp, stmt.expression
    assert_equal :SPLIT, stmt.expression.op
  end

  def test_parse_merge
    program = parse("process = a :> b;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::BinaryOp, stmt.expression
    assert_equal :MERGE, stmt.expression.op
  end

  def test_parse_feedback
    program = parse("process = a ~ b;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::BinaryOp, stmt.expression
    assert_equal :REC, stmt.expression.op
  end

  def test_parse_arithmetic
    program = parse("process = a + b * c;")
    stmt = program.statements[0]
    # Should be a + (b * c) due to precedence
    assert_instance_of Faust2Ruby::AST::BinaryOp, stmt.expression
    assert_equal :ADD, stmt.expression.op
  end

  def test_parse_function_call
    program = parse("process = func(1, 2);")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::FunctionCall, stmt.expression
    assert_equal "func", stmt.expression.name
    assert_equal 2, stmt.expression.args.length
  end

  def test_parse_qualified_function_call
    program = parse("process = os.osc(440);")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::FunctionCall, stmt.expression
    assert_equal "os.osc", stmt.expression.name
  end

  def test_parse_hslider
    program = parse('process = hslider("freq", 440, 20, 20000, 1);')
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::UIElement, stmt.expression
    assert_equal :hslider, stmt.expression.type
    assert_equal "freq", stmt.expression.label
  end

  def test_parse_button
    program = parse('process = button("trigger");')
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::UIElement, stmt.expression
    assert_equal :button, stmt.expression.type
    assert_equal "trigger", stmt.expression.label
  end

  def test_parse_hgroup
    program = parse('process = hgroup("controls", a);')
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::UIGroup, stmt.expression
    assert_equal :hgroup, stmt.expression.type
    assert_equal "controls", stmt.expression.label
  end

  def test_parse_par_iteration
    program = parse("process = par(i, 4, osc(i*100));")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Iteration, stmt.expression
    assert_equal :par, stmt.expression.type
    assert_equal "i", stmt.expression.var
  end

  def test_parse_seq_iteration
    program = parse("process = seq(i, 3, gain(0.5));")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Iteration, stmt.expression
    assert_equal :seq, stmt.expression.type
  end

  def test_parse_sum_iteration
    program = parse("process = sum(i, 4, osc(i*100));")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Iteration, stmt.expression
    assert_equal :sum, stmt.expression.type
  end

  def test_parse_lambda
    program = parse('process = \\(x).(x * 2);')
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Lambda, stmt.expression
    assert_equal ["x"], stmt.expression.params
  end

  def test_parse_prime_delay
    program = parse("process = x';")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Prime, stmt.expression
  end

  def test_parse_negation
    program = parse("process = -x;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::UnaryOp, stmt.expression
    assert_equal :NEG, stmt.expression.op
  end

  def test_parse_parentheses
    program = parse("process = (a + b) * c;")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::BinaryOp, stmt.expression
    assert_equal :MUL, stmt.expression.op
  end

  def test_parse_definition_with_parameters
    program = parse("osc(freq) = sin(freq * 2 * PI);")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Definition, stmt
    assert_equal "osc", stmt.name
    assert_equal ["freq"], stmt.params
  end

  def test_parse_multiple_statements
    source = <<~FAUST
      import("stdfaust.lib");
      declare name "test";
      freq = 440;
      process = os.osc(freq);
    FAUST
    program = parse(source)
    assert_equal 4, program.statements.length
    assert_instance_of Faust2Ruby::AST::Import, program.statements[0]
    assert_instance_of Faust2Ruby::AST::Declare, program.statements[1]
    assert_instance_of Faust2Ruby::AST::Definition, program.statements[2]
    assert_instance_of Faust2Ruby::AST::Definition, program.statements[3]
  end

  def test_parse_waveform
    program = parse("process = waveform{0, 0.5, 1, 0.5, 0};")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Waveform, stmt.expression
    assert_equal 5, stmt.expression.values.length
  end

  def test_parse_rdtable
    program = parse("process = rdtable(size, init, idx);")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::Table, stmt.expression
    assert_equal :rdtable, stmt.expression.type
  end

  def test_parser_errors_collected
    parser = Faust2Ruby::Parser.new("process = @#$;")
    parser.parse
    refute_empty parser.errors
  end

  def test_parse_case_expression
    program = parse("process = case { (0) => 1; (n) => n * 2; };")
    stmt = program.statements[0]
    assert_instance_of Faust2Ruby::AST::CaseExpr, stmt.expression
    assert_equal 2, stmt.expression.branches.length
  end

  def test_parse_case_branch_patterns
    program = parse("process = case { (0) => a; (1) => b; (x) => c; };")
    stmt = program.statements[0]
    branches = stmt.expression.branches

    # First branch: integer pattern
    assert_instance_of Faust2Ruby::AST::IntLiteral, branches[0].pattern
    assert_equal 0, branches[0].pattern.value

    # Second branch: integer pattern
    assert_instance_of Faust2Ruby::AST::IntLiteral, branches[1].pattern
    assert_equal 1, branches[1].pattern.value

    # Third branch: variable pattern
    assert_instance_of Faust2Ruby::AST::Identifier, branches[2].pattern
    assert_equal "x", branches[2].pattern.name
  end

  def test_parse_case_with_complex_results
    program = parse("process = case { (0) => a + b; (n) => n * n; };")
    stmt = program.statements[0]
    branches = stmt.expression.branches

    # First result is binary op
    assert_instance_of Faust2Ruby::AST::BinaryOp, branches[0].result
    assert_equal :ADD, branches[0].result.op

    # Second result is binary op
    assert_instance_of Faust2Ruby::AST::BinaryOp, branches[1].result
    assert_equal :MUL, branches[1].result.op
  end
end
