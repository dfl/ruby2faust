# frozen_string_literal: true

require_relative "test_helper"
require "tempfile"

class IntegrationTest < Minitest::Test
  include Ruby2Faust::DSL

  def test_generate_simple_synth
    code = Ruby2Faust.generate do
      osc(440).then(gain(0.3))
    end

    assert_includes code, 'import("stdfaust.lib");'
    assert_includes code, "process = (os.osc(440) : *(0.3));"
  end

  def test_generate_with_slider
    code = Ruby2Faust.generate do
      freq = slider("freq", init: 440, min: 20, max: 2000)
      amp = slider("amp", init: 0.3, min: 0, max: 1)
      osc(freq).then(gain(amp))
    end

    assert_includes code, 'hslider("freq"'
    assert_includes code, 'hslider("amp"'
    assert_includes code, "os.osc"
  end

  def test_generate_stereo
    code = Ruby2Faust.generate do
      left = osc(440).then(gain(0.3))
      right = osc(442).then(gain(0.3))
      left.par(right)
    end

    # Should have two parallel oscillators
    assert_includes code, "os.osc(440)"
    assert_includes code, "os.osc(442)"
    assert_includes code, ", "  # parallel composition
  end

  def test_generate_filter_chain
    code = Ruby2Faust.generate do
      saw(100)
        .then(lp(800))
        .then(hp(50))
        .then(gain(0.5))
    end

    assert_includes code, "os.sawtooth(100)"
    assert_includes code, "fi.lowpass(1, 800)"
    assert_includes code, "fi.highpass(1, 50)"
    assert_includes code, "*(0.5)"
  end

  def test_generate_feedback
    code = Ruby2Faust.generate do
      noise
        .then(lp(400))
        .feedback(gain(0.95))
    end

    assert_includes code, "no.noise"
    assert_includes code, "~"  # feedback operator
    assert_includes code, "*(0.95)"
  end

  def test_generate_split_merge
    code = Ruby2Faust.generate do
      osc(440)
        .split(gain(0.5), gain(0.3))
        .merge(add)
    end

    assert_includes code, "<:"  # split
    assert_includes code, ":>"  # merge
  end

  def test_live_changed_detection
    graph1 = osc(440).then(gain(0.3))
    graph2 = osc(440).then(gain(0.3))
    graph3 = osc(880).then(gain(0.3))

    refute Ruby2Faust::Live.changed?(graph1, graph2)
    assert Ruby2Faust::Live.changed?(graph1, graph3)
  end

  def test_live_compile_to_file
    graph = osc(440).then(gain(0.3))

    Tempfile.create(["test", ".dsp"]) do |f|
      path = Ruby2Faust::Live.compile(graph, output: f.path)
      assert_equal f.path, path

      content = File.read(f.path)
      assert_includes content, "process ="
      assert_includes content, "os.osc(440)"
    end
  end

  def test_crossfade_dsp_generation
    code = Ruby2Faust::Live.crossfade_dsp("old_process", "new_process")

    assert_includes code, "xfade"
    assert_includes code, "old_process"
    assert_includes code, "new_process"
    assert_includes code, ":>"  # merge for crossfade
  end
end
