# frozen_string_literal: true

require_relative "ir"

module Ruby2Faust
  # Emitter generates Faust source code from an IR graph.
  module Emitter
    module_function

    # Default imports for Faust programs
    DEFAULT_IMPORTS = ["stdfaust.lib"].freeze

    # Emit a complete Faust program from a Program object or DSP
    #
    # @param process [DSP, Program] The main process DSP or Program with metadata
    # @param imports [Array<String>] Libraries to import (default: stdfaust.lib)
    # @param declarations [Hash] Metadata declarations (name, author, etc.)
    # @return [String] Complete Faust source code
    def program(process, imports: nil, declarations: {})
      if process.is_a?(Program)
        node = process.process.is_a?(DSP) ? process.process.node : process.process
        imports ||= process.imports
        declarations = process.declarations.merge(declarations)
      else
        node = process.is_a?(DSP) ? process.node : process
        imports ||= DEFAULT_IMPORTS
      end

      lines = []

      # Declarations
      declarations.each do |key, value|
        lines << "declare #{key} \"#{value}\";"
      end
      lines << "" if declarations.any?

      # Imports
      imports.each do |lib|
        lines << "import(\"#{lib}\");"
      end
      lines << ""

      # Process
      lines << "process = #{emit(node)};"

      lines.join("\n") + "\n"
    end

    # Emit Faust expression for a node
    #
    # @param node [Node] IR node to emit
    # @return [String] Faust expression
    def emit(node)
      case node.type
      # Oscillators
      when NodeType::OSC
        "os.osc(#{emit(node.inputs[0])})"
      when NodeType::SAW
        "os.sawtooth(#{emit(node.inputs[0])})"
      when NodeType::SQUARE
        "os.square(#{emit(node.inputs[0])})"
      when NodeType::TRIANGLE
        "os.triangle(#{emit(node.inputs[0])})"

      # Noise
      when NodeType::NOISE
        "no.noise"

      # Filters
      when NodeType::LP
        order = node.args[0] || 1
        "fi.lowpass(#{order}, #{emit(node.inputs[0])})"
      when NodeType::HP
        order = node.args[0] || 1
        "fi.highpass(#{order}, #{emit(node.inputs[0])})"
      when NodeType::BP
        "fi.bandpass(1, #{emit(node.inputs[0])}, #{emit(node.inputs[1])})"

      # Math
      when NodeType::GAIN
        "*(#{emit(node.inputs[0])})"
      when NodeType::ADD
        "+"
      when NodeType::MUL
        "*"
      when NodeType::ABS
        "abs"
      when NodeType::POW
        "pow(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"

      # Conversion
      when NodeType::DB2LINEAR
        "ba.db2linear(#{emit(node.inputs[0])})"

      # Smoothing
      when NodeType::SMOOTH
        "si.smooth(ba.tau2pole(#{emit(node.inputs[0])}))"

      # Selectors
      when NodeType::SELECT2
        cond = emit(node.inputs[0])
        a = emit(node.inputs[1])
        b = emit(node.inputs[2])
        "select2(#{cond}, #{a}, #{b})"
      when NodeType::SELECTN
        n = node.args[0]
        index = emit(node.inputs[0])
        signals = node.inputs[1..].map { |i| emit(i) }.join(", ")
        "ba.selectn(#{n}, #{index}, #{signals})"

      # UI Controls
      when NodeType::SLIDER
        name, init, min, max, step = node.args
        "hslider(\"#{name}\", #{init}, #{min}, #{max}, #{step})"
      when NodeType::BUTTON
        "button(\"#{node.args[0]}\")"
      when NodeType::CHECKBOX
        "checkbox(\"#{node.args[0]}\")"
      when NodeType::HGROUP
        name = node.args[0]
        content = emit(node.inputs[0])
        "hgroup(\"#{name}\", #{content})"
      when NodeType::VGROUP
        name = node.args[0]
        content = emit(node.inputs[0])
        "vgroup(\"#{name}\", #{content})"

      # Composition
      when NodeType::SEQ
        left = emit(node.inputs[0])
        right = emit(node.inputs[1])
        "(#{left} : #{right})"
      when NodeType::PAR
        left = emit(node.inputs[0])
        right = emit(node.inputs[1])
        "(#{left}, #{right})"
      when NodeType::SPLIT
        source = emit(node.inputs[0])
        targets = node.inputs[1..].map { |n| emit(n) }.join(", ")
        "(#{source} <: #{targets})"
      when NodeType::MERGE
        source = emit(node.inputs[0])
        target = emit(node.inputs[1])
        "(#{source} :> #{target})"
      when NodeType::FEEDBACK
        forward = emit(node.inputs[0])
        back = emit(node.inputs[1])
        "(#{forward} ~ #{back})"

      # Utility
      when NodeType::WIRE
        "_"
      when NodeType::LITERAL
        node.args[0].to_s

      else
        raise ArgumentError, "Unknown node type: #{node.type}"
      end
    end
  end
end
