# frozen_string_literal: true

require_relative "test_helper"

class EmitterTest < Minitest::Test
  include Ruby2Faust::DSL

  def emit(dsp)
    Ruby2Faust::Emitter.emit(dsp.node)
  end

  def test_emit_osc
    assert_equal "os.osc(440)", emit(osc(440))
  end

  def test_emit_saw
    assert_equal "os.sawtooth(440)", emit(saw(440))
  end

  def test_emit_square
    assert_equal "os.square(440)", emit(square(440))
  end

  def test_emit_triangle
    assert_equal "os.triangle(440)", emit(triangle(440))
  end

  def test_emit_noise
    assert_equal "no.noise", emit(noise)
  end

  def test_emit_gain
    assert_equal "*(0.5)", emit(gain(0.5))
  end

  def test_emit_lp
    assert_equal "fi.lowpass(1, 800)", emit(lp(800))
  end

  def test_emit_lp_order4
    assert_equal "fi.lowpass(4, 800)", emit(lp(800, order: 4))
  end

  def test_emit_hp
    assert_equal "fi.highpass(1, 200)", emit(hp(200))
  end

  def test_emit_bp
    assert_equal "fi.bandpass(1, 800, 2)", emit(bp(800, q: 2))
  end

  def test_emit_slider
    dsp = slider("freq", init: 440, min: 20, max: 20000, step: 1)
    assert_equal 'hslider("freq", 440, 20, 20000, 1)', emit(dsp)
  end

  def test_emit_button
    assert_equal 'button("trig")', emit(button("trig"))
  end

  def test_emit_checkbox
    assert_equal 'checkbox("enable")', emit(checkbox("enable"))
  end

  def test_emit_wire
    assert_equal "_", emit(wire)
  end

  def test_emit_literal
    assert_equal "ma.SR", emit(literal("ma.SR"))
  end

  def test_emit_add
    assert_equal "+", emit(add)
  end

  def test_emit_mul
    assert_equal "*", emit(mul)
  end

  def test_emit_seq
    dsp = osc(440).then(gain(0.3))
    assert_equal "(os.osc(440) : *(0.3))", emit(dsp)
  end

  def test_emit_par
    dsp = osc(440).par(osc(880))
    assert_equal "(os.osc(440), os.osc(880))", emit(dsp)
  end

  def test_emit_split
    dsp = osc(440).split(gain(0.5), gain(0.3))
    assert_equal "(os.osc(440) <: *(0.5), *(0.3))", emit(dsp)
  end

  def test_emit_merge
    dsp = osc(440).par(noise).merge(add)
    assert_equal "((os.osc(440), no.noise) :> +)", emit(dsp)
  end

  def test_emit_feedback
    dsp = wire.feedback(gain(0.99))
    assert_equal "(_ ~ *(0.99))", emit(dsp)
  end

  def test_emit_chained
    dsp = osc(440)
      .then(lp(800))
      .then(gain(0.3))
    
    expected = "((os.osc(440) : fi.lowpass(1, 800)) : *(0.3))"
    assert_equal expected, emit(dsp)
  end

  def test_program_output
    dsp = osc(440).then(gain(0.3))
    code = Ruby2Faust::Emitter.program(dsp)

    assert_includes code, 'import("stdfaust.lib");'
    assert_includes code, "process ="
    assert_includes code, "os.osc(440)"
  end

  def test_program_custom_imports
    dsp = osc(440)
    code = Ruby2Faust::Emitter.program(dsp, imports: ["stdfaust.lib", "analyzers.lib"])

    assert_includes code, 'import("stdfaust.lib");'
    assert_includes code, 'import("analyzers.lib");'
  end
end
