# frozen_string_literal: true

require_relative "test_helper"

class IRTest < Minitest::Test
  def test_node_creation
    node = Ruby2Faust::Node.new(type: :osc, args: [440], channels: 1)
    assert_equal :osc, node.type
    assert_equal [440], node.args
    assert_equal [], node.inputs
    assert_equal 1, node.channels
  end

  def test_node_with_inputs
    freq_node = Ruby2Faust::Node.new(type: :literal, args: [440])
    osc_node = Ruby2Faust::Node.new(type: :osc, inputs: [freq_node])

    assert_equal 1, osc_node.inputs.length
    assert_equal freq_node, osc_node.inputs[0]
  end

  def test_fingerprint_same_structure
    node1 = Ruby2Faust::Node.new(type: :osc, args: [440])
    node2 = Ruby2Faust::Node.new(type: :osc, args: [440])

    assert_equal node1.fingerprint, node2.fingerprint
  end

  def test_fingerprint_different_args
    node1 = Ruby2Faust::Node.new(type: :osc, args: [440])
    node2 = Ruby2Faust::Node.new(type: :osc, args: [880])

    refute_equal node1.fingerprint, node2.fingerprint
  end

  def test_fingerprint_different_type
    node1 = Ruby2Faust::Node.new(type: :osc, args: [440])
    node2 = Ruby2Faust::Node.new(type: :saw, args: [440])

    refute_equal node1.fingerprint, node2.fingerprint
  end

  def test_fingerprint_nested_structure
    freq1 = Ruby2Faust::Node.new(type: :literal, args: [440])
    freq2 = Ruby2Faust::Node.new(type: :literal, args: [440])
    osc1 = Ruby2Faust::Node.new(type: :osc, inputs: [freq1])
    osc2 = Ruby2Faust::Node.new(type: :osc, inputs: [freq2])

    assert_equal osc1.fingerprint, osc2.fingerprint
  end

  def test_same_structure
    node1 = Ruby2Faust::Node.new(type: :osc, args: [440])
    node2 = Ruby2Faust::Node.new(type: :osc, args: [440])

    assert node1.same_structure?(node2)
  end

  def test_args_are_frozen
    node = Ruby2Faust::Node.new(type: :osc, args: [440])
    assert node.args.frozen?
  end

  def test_inputs_are_frozen
    node = Ruby2Faust::Node.new(type: :seq, inputs: [])
    assert node.inputs.frozen?
  end
end
