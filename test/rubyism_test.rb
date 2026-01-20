# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/ruby2faust"

class RubyismTest < Minitest::Test
  include Ruby2Faust::DSL

  def test_signal_arithmetic
    # Test + (mix)
    expr = osc(440) + noise
    assert_equal "(os.osc(440) + no.noise)", Ruby2Faust::Emitter.emit(expr.node)

    # Test - (sub)
    expr = osc(440) - osc(442)
    assert_equal "(os.osc(440) - os.osc(442))", Ruby2Faust::Emitter.emit(expr.node)

    # Test * (mul/gain)
    expr = osc(440) * 0.5
    assert_equal "(os.osc(440) * 0.5)", Ruby2Faust::Emitter.emit(expr.node)

    # Test / (div)
    expr = osc(440) / 2
    assert_equal "(os.osc(440) / 2)", Ruby2Faust::Emitter.emit(expr.node)

    # Test negate
    expr = -osc(440)
    assert_equal "0 - os.osc(440)", Ruby2Faust::Emitter.emit(expr.node)
  end

  def test_numeric_extensions
    assert_equal "ba.midikey2hz(60)", Ruby2Faust::Emitter.emit(60.midi.node)
    assert_equal "ba.db2linear(-6)", Ruby2Faust::Emitter.emit((-6).db.node)
    assert_equal "ba.sec2samp(0.1)", Ruby2Faust::Emitter.emit(0.1.sec.node)
    assert_equal "ba.sec2samp(0.01)", Ruby2Faust::Emitter.emit(10.ms.node)
    assert_equal "440", Ruby2Faust::Emitter.emit(440.hz.node)
  end

  def test_block_ui_groups
    # Test hgroup with block
    expr = hgroup("Master") do
      osc(440) + noise
    end
    assert_equal 'hgroup("Master", (os.osc(440) + no.noise))', Ruby2Faust::Emitter.emit(expr.node)

    # Test nested vgroup with block
    expr = hgroup("Rack") do
      vgroup("Osc") { osc(440) } | vgroup("Filter") { lp(1000) }
    end
    assert_equal 'hgroup("Rack", (vgroup("Osc", os.osc(440)), vgroup("Filter", fi.lowpass(1, 1000))))', Ruby2Faust::Emitter.emit(expr.node)
  end

  def test_ruby2faust_generate
    code = Ruby2Faust.generate do
      (osc(440) + noise) * 0.3
    end
    assert_match(/process = \(\(os.osc\(440\) \+ no.noise\) \* 0.3\);/, code)
  end

  def test_program_with_block
    prog = Ruby2Faust::Program.new do
      declare :name, "Test"
      osc(440) * 0.5
    end
    code = Ruby2Faust::Emitter.program(prog)
    assert_match(/declare name "Test";/, code)
    assert_match(/process = \(os.osc\(440\) \* 0.5\);/, code)
  end
end
