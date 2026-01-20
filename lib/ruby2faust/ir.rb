# frozen_string_literal: true

require "digest"

module Ruby2Faust
  # Intermediate Representation node for DSP graphs.
  # Nodes are immutable value objects representing DSP operations.
  #
  # @attr type [Symbol] Node type (:osc, :gain, :seq, :par, etc.)
  # @attr args [Array] Arguments to the node (frequencies, gains, names, etc.)
  # @attr inputs [Array<Node>] Input nodes (for composition operators)
  # @attr channels [Integer] Number of output channels this node produces
  Node = Struct.new(:type, :args, :inputs, :channels, keyword_init: true) do
    def initialize(type:, args: [], inputs: [], channels: 1)
      super(type: type, args: args.freeze, inputs: inputs.freeze, channels: channels)
    end

    # Generate a fingerprint for graph diffing.
    # Two graphs with the same fingerprint are structurally identical.
    #
    # @return [String] SHA1 hex digest
    def fingerprint
      content = [
        type,
        args,
        inputs.map(&:fingerprint)
      ].inspect
      Digest::SHA1.hexdigest(content)
    end

    # Check if two graphs are structurally identical.
    #
    # @param other [Node] Another node to compare
    # @return [Boolean]
    def same_structure?(other)
      fingerprint == other.fingerprint
    end
  end

  # Node type constants for clarity
  module NodeType
    # Oscillators
    OSC      = :osc
    SAW      = :saw
    SQUARE   = :square
    TRIANGLE = :triangle

    # Noise
    NOISE = :noise

    # Filters
    LP = :lp
    HP = :hp
    BP = :bp

    # Math
    GAIN = :gain
    ADD  = :add
    MUL  = :mul
    ABS  = :abs
    POW  = :pow

    # Conversion
    DB2LINEAR = :db2linear

    # Smoothing
    SMOOTH = :smooth

    # Selectors
    SELECT2 = :select2
    SELECTN = :selectn

    # UI Controls
    SLIDER   = :slider
    BUTTON   = :button
    CHECKBOX = :checkbox
    HGROUP   = :hgroup
    VGROUP   = :vgroup

    # Composition
    SEQ      = :seq       # Sequential (:)
    PAR      = :par       # Parallel (,)
    SPLIT    = :split     # Fan-out (<:)
    MERGE    = :merge     # Fan-in (:>)
    FEEDBACK = :feedback  # Feedback (~)

    # Utility
    WIRE    = :wire    # Pass-through (_)
    LITERAL = :literal # Raw Faust expression

    # Metadata
    DECLARE = :declare
  end
end
