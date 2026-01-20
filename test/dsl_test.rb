# frozen_string_literal: true

require_relative "test_helper"

class DSLTest < Minitest::Test
  include Ruby2Faust::DSL

  def test_osc_creates_node
    dsp = osc(440)
    assert_instance_of Ruby2Faust::DSP, dsp
    assert_equal :osc, dsp.node.type
    assert_equal 1, dsp.node.channels
  end

  def test_saw_creates_node
    dsp = saw(440)
    assert_equal :saw, dsp.node.type
  end

  def test_square_creates_node
    dsp = square(440)
    assert_equal :square, dsp.node.type
  end

  def test_triangle_creates_node
    dsp = triangle(440)
    assert_equal :triangle, dsp.node.type
  end

  def test_noise_creates_node
    dsp = noise
    assert_equal :noise, dsp.node.type
    assert_equal 1, dsp.channels
  end

  def test_gain_creates_node
    dsp = gain(0.5)
    assert_equal :gain, dsp.node.type
  end

  def test_lp_creates_node
    dsp = lp(800)
    assert_equal :lp, dsp.node.type
    assert_equal [1], dsp.node.args  # default order
  end

  def test_lp_with_order
    dsp = lp(800, order: 4)
    assert_equal [4], dsp.node.args
  end

  def test_hp_creates_node
    dsp = hp(200)
    assert_equal :hp, dsp.node.type
  end

  def test_bp_creates_node
    dsp = bp(800, q: 2)
    assert_equal :bp, dsp.node.type
  end

  def test_slider_creates_node
    dsp = slider("freq", init: 440, min: 20, max: 20000)
    assert_equal :slider, dsp.node.type
    assert_equal ["freq", 440, 20, 20000, 0.01], dsp.node.args
  end

  def test_button_creates_node
    dsp = button("trigger")
    assert_equal :button, dsp.node.type
    assert_equal ["trigger"], dsp.node.args
  end

  def test_checkbox_creates_node
    dsp = checkbox("enable")
    assert_equal :checkbox, dsp.node.type
  end

  def test_wire_creates_node
    dsp = wire
    assert_equal :wire, dsp.node.type
  end

  def test_literal_creates_node
    dsp = literal("ma.SR")
    assert_equal :literal, dsp.node.type
    assert_equal ["ma.SR"], dsp.node.args
  end

  def test_then_composition
    dsp = osc(440).then(gain(0.3))
    assert_equal :seq, dsp.node.type
    assert_equal 2, dsp.node.inputs.length
  end

  def test_then_alias
    dsp = osc(440) >> gain(0.3)
    assert_equal :seq, dsp.node.type
  end

  def test_par_composition
    dsp = osc(440).par(osc(880))
    assert_equal :par, dsp.node.type
    assert_equal 2, dsp.channels
  end

  def test_par_alias
    dsp = osc(440) | osc(880)
    assert_equal :par, dsp.node.type
  end

  def test_split_composition
    dsp = osc(440).split(gain(0.5), gain(0.3))
    assert_equal :split, dsp.node.type
    assert_equal 3, dsp.node.inputs.length  # source + 2 targets
  end

  def test_merge_composition
    dsp = osc(440).par(osc(880)).merge(add)
    assert_equal :merge, dsp.node.type
  end

  def test_feedback_composition
    dsp = wire.feedback(gain(0.99).then(lp(400)))
    assert_equal :feedback, dsp.node.type
  end

  def test_chaining
    dsp = osc(440)
      .then(lp(800))
      .then(gain(0.3))

    assert_equal :seq, dsp.node.type
    # Outer seq: inner_seq, gain
    # Inner seq: osc, lp
    inner = dsp.node.inputs[0]
    assert_equal :seq, inner.type
  end

  def test_to_dsp_from_numeric
    dsp = gain(0.5)
    # The 0.5 should be converted to a literal node
    assert_equal :literal, dsp.node.inputs[0].type
    assert_equal ["0.5"], dsp.node.inputs[0].args
  end

  def test_channels_tracking
    stereo = osc(440).par(osc(880))
    assert_equal 2, stereo.channels

    mono = stereo.merge(add)
    assert_equal 1, mono.channels
  end
end
