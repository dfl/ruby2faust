# frozen_string_literal: true

require_relative "../test_helper"
require "faust2ruby"

class Faust2Ruby::GeneratorTest < Minitest::Test
  def generate(source, **options)
    Faust2Ruby.to_ruby(source, expression_only: true, **options)
  end

  def test_generate_integer
    assert_equal "42", generate("process = 42;")
  end

  def test_generate_float
    assert_equal "3.14", generate("process = 3.14;")
  end

  def test_generate_wire
    assert_equal "wire", generate("process = _;")
  end

  def test_generate_cut
    assert_equal "cut", generate("process = !;")
  end

  def test_generate_sequential
    result = generate("process = a : b;")
    assert_includes result, ">>"
  end

  def test_generate_parallel
    result = generate("process = a , b;")
    assert_includes result, "|"
  end

  def test_generate_split
    result = generate("process = a <: b;")
    assert_includes result, ".split"
  end

  def test_generate_merge
    result = generate("process = a :> b;")
    assert_includes result, ".merge"
  end

  def test_generate_feedback
    result = generate("process = a ~ b;")
    assert_includes result, "~"
  end

  def test_generate_arithmetic
    result = generate("process = a + b;")
    assert_includes result, "+"
  end

  def test_generate_osc
    result = generate("process = os.osc(440);")
    assert_includes result, "osc(440)"
  end

  def test_generate_sawtooth
    result = generate("process = os.sawtooth(440);")
    assert_includes result, "saw(440)"
  end

  def test_generate_noise
    result = generate("process = no.noise;")
    assert_includes result, "noise"
  end

  def test_generate_lowpass
    result = generate("process = fi.lowpass(2, 1000);")
    assert_includes result, "lp(1000, order: 2)"
  end

  def test_generate_slider
    result = generate('process = hslider("freq", 440, 20, 20000, 1);')
    assert_includes result, 'slider("freq"'
    assert_includes result, "init: 440"
    assert_includes result, "min: 20"
    assert_includes result, "max: 20000"
  end

  def test_generate_button
    result = generate('process = button("trigger");')
    assert_includes result, 'button("trigger")'
  end

  def test_generate_hgroup
    result = generate('process = hgroup("controls", a);')
    assert_includes result, 'hgroup("controls")'
  end

  def test_generate_par_iteration
    result = generate("process = par(i, 4, osc(i));")
    assert_includes result, "fpar(:i, 4)"
    assert_includes result, "|i|"
  end

  def test_generate_seq_iteration
    result = generate("process = seq(i, 3, gain(0.5));")
    assert_includes result, "fseq(:i, 3)"
  end

  def test_generate_sum_iteration
    result = generate("process = sum(i, 4, osc(i));")
    assert_includes result, "fsum(:i, 4)"
  end

  def test_generate_lambda
    result = generate('process = \\(x).(x * 2);')
    assert_includes result, "flambda"
  end

  def test_generate_prime
    result = generate("process = x';")
    assert_includes result, "mem"
  end

  def test_generate_negation
    result = generate("process = -x;")
    assert_includes result, "(-x)"
  end

  def test_generate_adsr
    result = generate("process = en.adsr(0.1, 0.2, 0.7, 0.3, gate);")
    assert_includes result, "adsr("
  end

  def test_generate_delay
    result = generate("process = de.delay(1000, 500);")
    assert_includes result, "delay(1000, 500)"
  end

  def test_generate_panner
    result = generate("process = sp.panner(0.5);")
    assert_includes result, "panner(0.5)"
  end

  def test_generate_waveform
    result = generate("process = waveform{0, 1, 0};")
    assert_includes result, "waveform(0, 1, 0)"
  end

  def test_generate_rdtable
    result = generate("process = rdtable(1024, init, idx);")
    assert_includes result, "rdtable("
  end

  def test_generate_select2
    result = generate("process = select2(cond, a, b);")
    assert_includes result, "select2("
  end

  def test_generate_mem
    result = generate("process = mem;")
    assert_includes result, "mem"
  end

  def test_generate_constants
    result = generate("process = ma.SR;")
    assert_includes result, "sr"
  end

  def test_generate_full_program
    source = <<~FAUST
      import("stdfaust.lib");
      declare name "test";
      process = os.osc(440) : *(0.5);
    FAUST
    result = Faust2Ruby.to_ruby(source)
    assert_includes result, "require 'ruby2faust'"
    assert_includes result, "include Ruby2Faust::DSL"
    assert_includes result, "process ="
    assert_includes result, "Ruby2Faust::Emitter.program"
  end

  def test_generate_complex_expression
    source = 'process = os.osc(hslider("freq", 440, 20, 20000, 1)) : *(0.5);'
    result = generate(source)
    assert_includes result, "osc"
    assert_includes result, "slider"
    assert_includes result, ">>"
  end

  def test_numeric_literals_wrapped_for_composition
    # This is the denormal flushing pattern - numeric literals need num() wrapper
    # Without it, Ruby's >> would be bit-shift instead of DSL sequencing
    source = "process = 1.0e-18 : (-(1.0e-18));"
    result = generate(source)
    # Should wrap literals with num() for composition
    assert_includes result, "num(1.0e-18)"
    assert_includes result, ">>"
  end

  def test_numeric_literals_in_parallel
    source = "process = 1 , 2;"
    result = generate(source)
    assert_includes result, "num(1)"
    assert_includes result, "num(2)"
    assert_includes result, "|"
  end

  def test_numeric_literals_not_wrapped_for_arithmetic
    # Arithmetic operators work fine with raw numbers
    source = "process = 1 + 2;"
    result = generate(source)
    assert_equal "(1 + 2)", result
    refute_includes result, "num("
  end

  def test_generate_case_with_default
    result = generate("process = case { (0) => 1; (n) => n * 2; };")
    assert_includes result, "flambda(:n)"
    assert_includes result, "select2"
    assert_includes result, "n.eq(0)"
  end

  def test_generate_case_multiple_branches
    result = generate("process = case { (0) => a; (1) => b; (2) => c; };")
    assert_includes result, "flambda(:x)"
    # Should have nested select2 calls
    assert_includes result, "select2(x.eq(0)"
    assert_includes result, "select2(x.eq(1)"
  end

  def test_generate_case_only_variable_pattern
    # When only variable pattern, falls back to literal
    result = generate("process = case { (n) => n * n; };")
    assert_includes result, "literal("
  end

  def test_generate_case_variable_becomes_default
    result = generate("process = case { (0) => 10; (x) => x; };")
    # The 'x' variable should be used in the flambda
    assert_includes result, "flambda(:x)"
    # Default case should be 'x' (the variable)
    assert_includes result, "select2(x.eq(0), x, 10)"
  end

  def test_generate_multirule_function
    # Multi-rule functions like fact(0) = 1; fact(n) = n * ... should merge
    source = "fact(0) = 1; fact(n) = n * 2; process = fact(5);"
    result = Faust2Ruby.to_ruby(source)
    # Should generate a flambda with select2
    assert_includes result, "fact = flambda(:n)"
    assert_includes result, "select2(n.eq(0)"
    assert_includes result, "process = fact(5)"
  end

  def test_generate_multirule_preserves_order
    # Integer patterns should be checked in definition order
    source = "foo(0) = a; foo(1) = b; foo(n) = c; process = foo(x);"
    result = Faust2Ruby.to_ruby(source)
    assert_includes result, "select2(n.eq(0)"
    assert_includes result, "select2(n.eq(1)"
  end
end
