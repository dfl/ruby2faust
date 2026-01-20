# frozen_string_literal: true

require_relative "ir"

module Ruby2Faust
  # DSP wrapper class for building graphs with method chaining.
  # Each DSP instance wraps an IR Node.
  class DSP
    attr_reader :node

    def initialize(node)
      @node = node
    end

    # Sequential composition (Faust :)
    # Connect output of self to input of other
    #
    # @param other [DSP] The DSP to connect to
    # @return [DSP] New composed DSP
    def then(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(
        type: NodeType::SEQ,
        inputs: [node, other.node],
        channels: other.node.channels
      ))
    end
    alias >> then

    # Parallel composition (Faust ,)
    # Run self and other in parallel
    #
    # @param other [DSP] The DSP to run in parallel
    # @return [DSP] New composed DSP
    def par(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(
        type: NodeType::PAR,
        inputs: [node, other.node],
        channels: node.channels + other.node.channels
      ))
    end
    alias | par

    # Fan-out / split (Faust <:)
    # Connect self's output to multiple destinations
    #
    # @param others [Array<DSP>] DSPs to split into
    # @return [DSP] New composed DSP
    def split(*others)
      others = others.map { |o| DSL.to_dsp(o) }
      total_channels = others.sum { |o| o.node.channels }
      DSP.new(Node.new(
        type: NodeType::SPLIT,
        inputs: [node] + others.map(&:node),
        channels: total_channels
      ))
    end

    # Fan-in / merge (Faust :>)
    # Merge multiple inputs into one output
    #
    # @param other [DSP] The DSP to merge into
    # @return [DSP] New composed DSP
    def merge(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(
        type: NodeType::MERGE,
        inputs: [node, other.node],
        channels: other.node.channels
      ))
    end

    # Feedback loop (Faust ~)
    # Create a feedback connection
    #
    # @param other [DSP] The feedback path DSP
    # @return [DSP] New composed DSP
    def feedback(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(
        type: NodeType::FEEDBACK,
        inputs: [node, other.node],
        channels: node.channels
      ))
    end
    alias ~ feedback

    # Number of output channels
    def channels
      node.channels
    end
  end

  # DSL module with primitive generators.
  # Include this module to get access to all DSP primitives.
  module DSL
    module_function

    # Convert various types to DSP
    def to_dsp(value)
      case value
      when DSP then value
      when Numeric then literal(value.to_s)
      when String then literal(value)
      else raise ArgumentError, "Cannot convert #{value.class} to DSP"
      end
    end

    # --- Oscillators ---

    # Sine oscillator
    # @param freq [DSP, Numeric] Frequency in Hz
    # @return [DSP]
    def osc(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::OSC, inputs: [freq.node], channels: 1))
    end

    # Sawtooth oscillator
    # @param freq [DSP, Numeric] Frequency in Hz
    # @return [DSP]
    def saw(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::SAW, inputs: [freq.node], channels: 1))
    end

    # Square wave oscillator
    # @param freq [DSP, Numeric] Frequency in Hz
    # @return [DSP]
    def square(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::SQUARE, inputs: [freq.node], channels: 1))
    end

    # Triangle wave oscillator
    # @param freq [DSP, Numeric] Frequency in Hz
    # @return [DSP]
    def triangle(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::TRIANGLE, inputs: [freq.node], channels: 1))
    end

    # --- Noise ---

    # White noise generator
    # @return [DSP]
    def noise
      DSP.new(Node.new(type: NodeType::NOISE, channels: 1))
    end

    # --- Filters ---

    # Lowpass filter
    # @param freq [DSP, Numeric] Cutoff frequency in Hz
    # @param order [Integer] Filter order (default 1)
    # @return [DSP]
    def lp(freq, order: 1)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::LP, args: [order], inputs: [freq.node], channels: 1))
    end

    # Highpass filter
    # @param freq [DSP, Numeric] Cutoff frequency in Hz
    # @param order [Integer] Filter order (default 1)
    # @return [DSP]
    def hp(freq, order: 1)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::HP, args: [order], inputs: [freq.node], channels: 1))
    end

    # Bandpass filter
    # @param freq [DSP, Numeric] Center frequency in Hz
    # @param q [DSP, Numeric] Q factor
    # @return [DSP]
    def bp(freq, q: 1)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::BP, inputs: [freq.node, q.node], channels: 1))
    end

    # --- Math ---

    # Gain / multiply by constant
    # @param x [DSP, Numeric] Gain value
    # @return [DSP]
    def gain(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::GAIN, inputs: [x.node], channels: 1))
    end

    # Add signals
    # @return [DSP]
    def add
      DSP.new(Node.new(type: NodeType::ADD, channels: 1))
    end

    # Multiply signals
    # @return [DSP]
    def mul
      DSP.new(Node.new(type: NodeType::MUL, channels: 1))
    end

    # Absolute value
    # @return [DSP]
    def abs_
      DSP.new(Node.new(type: NodeType::ABS, channels: 1))
    end

    # Power function (base^exponent)
    # @param base [DSP, Numeric] Base value
    # @param exponent [DSP, Numeric] Exponent value
    # @return [DSP]
    def pow(base, exponent)
      base = to_dsp(base)
      exponent = to_dsp(exponent)
      DSP.new(Node.new(type: NodeType::POW, inputs: [base.node, exponent.node], channels: 1))
    end

    # --- Conversion ---

    # Convert dB to linear gain
    # @param db [DSP, Numeric] Value in decibels
    # @return [DSP]
    def db2linear(db)
      db = to_dsp(db)
      DSP.new(Node.new(type: NodeType::DB2LINEAR, inputs: [db.node], channels: 1))
    end

    # --- Smoothing ---

    # Smooth signal with time constant
    # Uses si.smooth with ba.tau2pole internally
    # @param tau [DSP, Numeric] Time constant in seconds
    # @return [DSP]
    def smooth(tau)
      tau = to_dsp(tau)
      DSP.new(Node.new(type: NodeType::SMOOTH, inputs: [tau.node], channels: 1))
    end

    # --- Selectors ---

    # Select between two signals based on condition
    # @param condition [DSP, Numeric] 0 selects first, 1 selects second
    # @param a [DSP] First signal (selected when condition=0)
    # @param b [DSP] Second signal (selected when condition=1)
    # @return [DSP]
    def select2(condition, a, b)
      condition = to_dsp(condition)
      a = to_dsp(a)
      b = to_dsp(b)
      DSP.new(Node.new(
        type: NodeType::SELECT2,
        inputs: [condition.node, a.node, b.node],
        channels: a.node.channels
      ))
    end

    # Select from n signals based on index
    # @param n [Integer] Number of inputs
    # @param index [DSP, Numeric] Index to select (0 to n-1)
    # @param signals [Array<DSP>] Signals to select from
    # @return [DSP]
    def selectn(n, index, *signals)
      index = to_dsp(index)
      signals = signals.map { |s| to_dsp(s) }
      DSP.new(Node.new(
        type: NodeType::SELECTN,
        args: [n],
        inputs: [index.node] + signals.map(&:node),
        channels: signals.first&.node&.channels || 1
      ))
    end

    # --- UI Controls ---

    # Horizontal slider
    # @param name [String] Parameter name (can include Faust metadata like [style:knob])
    # @param init [Numeric] Initial value
    # @param min [Numeric] Minimum value
    # @param max [Numeric] Maximum value
    # @param step [Numeric] Step size (default 0.01)
    # @return [DSP]
    def slider(name, init:, min:, max:, step: 0.01)
      DSP.new(Node.new(
        type: NodeType::SLIDER,
        args: [name, init, min, max, step],
        channels: 1
      ))
    end

    # Button (momentary)
    # @param name [String] Button name
    # @return [DSP]
    def button(name)
      DSP.new(Node.new(type: NodeType::BUTTON, args: [name], channels: 1))
    end

    # Checkbox (toggle)
    # @param name [String] Checkbox name
    # @return [DSP]
    def checkbox(name)
      DSP.new(Node.new(type: NodeType::CHECKBOX, args: [name], channels: 1))
    end

    # Horizontal group for UI organization
    # @param name [String] Group name
    # @param content [DSP] Content inside the group
    # @return [DSP]
    def hgroup(name, content)
      content = to_dsp(content)
      DSP.new(Node.new(
        type: NodeType::HGROUP,
        args: [name],
        inputs: [content.node],
        channels: content.node.channels
      ))
    end

    # Vertical group for UI organization
    # @param name [String] Group name
    # @param content [DSP] Content inside the group
    # @return [DSP]
    def vgroup(name, content)
      content = to_dsp(content)
      DSP.new(Node.new(
        type: NodeType::VGROUP,
        args: [name],
        inputs: [content.node],
        channels: content.node.channels
      ))
    end

    # --- Utility ---

    # Wire (pass-through)
    # @return [DSP]
    def wire
      DSP.new(Node.new(type: NodeType::WIRE, channels: 1))
    end

    # Raw Faust expression literal
    # @param expr [String] Faust expression
    # @param channels [Integer] Number of output channels (default 1)
    # @return [DSP]
    def literal(expr, channels: 1)
      DSP.new(Node.new(type: NodeType::LITERAL, args: [expr], channels: channels))
    end
  end

  # Program-level metadata for Faust declarations
  class Program
    attr_reader :process, :declarations, :imports

    def initialize(process)
      @process = process
      @declarations = {}
      @imports = ["stdfaust.lib"]
    end

    # Add a declaration (name, author, license, etc.)
    def declare(key, value)
      @declarations[key] = value
      self
    end

    # Add an import
    def import(lib)
      @imports << lib unless @imports.include?(lib)
      self
    end
  end
end
