# frozen_string_literal: true

require "set"
require_relative "ir"

module Ruby2Faust
  # Emitter generates Faust source code from an IR graph.
  module Emitter
    module_function

    DEFAULT_IMPORTS = ["stdfaust.lib"].freeze

    # Find nodes that are referenced by multiple different parent nodes
    # Returns a hash: { node.object_id => Set of parent object_ids }
    def find_parent_refs(node, parent_id = nil, refs = Hash.new { |h, k| h[k] = Set.new })
      refs[node.object_id].add(parent_id) if parent_id
      node.inputs.each { |input| find_parent_refs(input, node.object_id, refs) }
      refs
    end

    # Collect all unique nodes in the tree by object identity
    def collect_nodes(node, nodes = {})
      nodes[node.object_id] = node
      node.inputs.each { |input| collect_nodes(input, nodes) }
      nodes
    end

    # Find nodes that appear multiple times (candidates for extraction)
    # Only extracts nodes that are used as inputs to 2+ different parent nodes
    def find_reused_nodes(node)
      refs = find_parent_refs(node)
      all_nodes = collect_nodes(node)

      # Only extract nodes referenced by 2+ distinct parents and aren't trivial
      reused = {}
      refs.each do |obj_id, parent_ids|
        next if parent_ids.size < 2
        n = all_nodes[obj_id]
        # Skip trivial nodes (literals, wires, simple primitives)
        next if trivial_node?(n)
        reused[obj_id] = n
      end
      reused
    end

    # Check if a node is too trivial to be worth extracting
    def trivial_node?(node)
      case node.type
      when NodeType::LITERAL, NodeType::WIRE, NodeType::CUT, NodeType::MEM,
           NodeType::NOISE, NodeType::PINK_NOISE, NodeType::SR, NodeType::PI,
           NodeType::PARAM, NodeType::SMOO, NodeType::DCBLOCK, NodeType::ABS,
           NodeType::SQRT, NodeType::EXP, NodeType::LOG, NodeType::LOG10,
           NodeType::SIN, NodeType::COS, NodeType::TAN, NodeType::FLOOR, NodeType::CEIL
        true
      else
        false
      end
    end

    # Generate a readable variable name for a node
    def var_name_for_node(node, index)
      prefix = case node.type
      when NodeType::HSLIDER, NodeType::VSLIDER
        node.args[0].to_s.gsub(/[^a-zA-Z0-9_]/, "_")
      when NodeType::OSC then "osc"
      when NodeType::SAW then "saw"
      when NodeType::SQUARE then "square"
      when NodeType::TRIANGLE then "tri"
      when NodeType::LP then "lp"
      when NodeType::HP then "hp"
      when NodeType::BP then "bp"
      when NodeType::SEQ then "chain"
      else
        "v"
      end
      # Add index suffix if needed to ensure uniqueness
      "#{prefix}#{index}"
    end

    # Scalar types produce constant values (not signal processors)
    SCALAR_TYPES = [
      NodeType::DB2LINEAR, NodeType::LINEAR2DB,
      NodeType::MIDI2HZ, NodeType::HZ2MIDI,
      NodeType::SEC2SAMP, NodeType::SAMP2SEC
    ].freeze

    # Operator precedence (higher = binds tighter)
    PREC = {
      seq: 1,      # :
      par: 2,      # ,
      split: 3,    # <:
      merge: 3,    # :>
      rec: 4,      # ~
      add: 5,      # +
      sub: 5,      # -
      mul: 6,      # *
      div: 6,      # /
      mod: 6,      # %
      cmp: 7,      # < > <= >= == !=
      primary: 100 # literals, function calls - never need parens
    }.freeze

    # Check if a node represents a scalar/constant value
    def scalar?(node)
      return true if SCALAR_TYPES.include?(node.type)
      return true if node.type == NodeType::LITERAL && node.args[0].to_s.match?(/\A-?\d+\.?\d*\z/)
      false
    end

    # Wrap expression in parens if needed based on precedence
    def wrap(expr, my_prec, parent_prec)
      my_prec < parent_prec ? "(#{expr})" : expr
    end

    def program(process, imports: nil, declarations: {}, pretty: false, output: "process", extract_common: false)
      if process.is_a?(Program)
        node = process.process.is_a?(DSP) ? process.process.node : process.process
        imports ||= process.imports
        declarations = process.declarations.merge(declarations)
      else
        node = process.is_a?(DSP) ? process.node : process
        imports ||= DEFAULT_IMPORTS
      end

      lines = []
      declarations.each { |k, v| lines << "declare #{k} \"#{v}\";" }
      lines << "" if declarations.any?
      imports.each { |lib| lines << "import(\"#{lib}\");" }
      lines << ""

      # Extract common subexpressions if requested
      var_map = {}
      if extract_common
        reused = find_reused_nodes(node)
        # Assign variable names and emit definitions
        reused.each_with_index do |(obj_id, reused_node), idx|
          name = var_name_for_node(reused_node, idx + 1)
          var_map[obj_id] = name
          # Emit the definition (without using var_map for this node itself)
          body = emit(reused_node, pretty: pretty, prec: 0, var_map: {})
          lines << "#{name} = #{body};"
        end
        lines << "" if reused.any?
      end

      body = emit(node, pretty: pretty, prec: 0, var_map: var_map)
      lines << "#{output} = #{body};"
      lines.join("\n") + "\n"
    end

    def emit(node, indent: 0, pretty: false, prec: 0, var_map: {})
      sp = "  " * indent
      next_sp = "  " * (indent + 1)

      # If this node was extracted as a common variable, just return the name
      if var_map.key?(node.object_id)
        return var_map[node.object_id]
      end

      case node.type

      # === COMMENTS ===
      when NodeType::COMMENT
        "// #{node.args[0]}\n"
      when NodeType::DOC
        # Inline comment wrapped around the inner expression
        "/* #{node.args[0]} */ #{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}"

      # === OSCILLATORS ===
      when NodeType::OSC
        "os.osc(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SAW
        "os.sawtooth(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SQUARE
        "os.square(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::TRIANGLE
        "os.triangle(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::PHASOR
        "os.phasor(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LF_SAW
        "os.lf_sawpos(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LF_TRIANGLE
        "os.lf_trianglepos(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LF_SQUARE
        "os.lf_squarewavepos(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::IMPTRAIN
        "os.lf_imptrain(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::PULSETRAIN
        "os.lf_pulsetrain(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"

      # === NOISE ===
      when NodeType::NOISE
        "no.noise"
      when NodeType::PINK_NOISE
        "no.pink_noise"

      # === FILTERS ===
      when NodeType::LP
        "fi.lowpass(#{node.args[0] || 1}, #{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::HP
        "fi.highpass(#{node.args[0] || 1}, #{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::BP
        "fi.bandpass(1, #{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::RESONLP
        "fi.resonlp(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::RESONHP
        "fi.resonhp(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::RESONBP
        "fi.resonbp(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::ALLPASS
        "fi.allpass_comb(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::DCBLOCK
        "fi.dcblocker"
      when NodeType::PEAK_EQ
        "fi.peak_eq(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"

      # SVF (State Variable Filter)
      when NodeType::SVF_LP
        "fi.svf.lp(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SVF_HP
        "fi.svf.hp(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SVF_BP
        "fi.svf.bp(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SVF_NOTCH
        "fi.svf.notch(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SVF_AP
        "fi.svf.ap(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SVF_BELL
        "fi.svf.bell(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SVF_LS
        "fi.svf.ls(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SVF_HS
        "fi.svf.hs(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"

      # Other filters
      when NodeType::LOWPASS3E
        "fi.lowpass3e(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::HIGHPASS3E
        "fi.highpass3e(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LOWPASS6E
        "fi.lowpass6e(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::HIGHPASS6E
        "fi.highpass6e(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::BANDSTOP
        "fi.bandstop(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::NOTCHW
        "fi.notchw(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LOW_SHELF
        "fi.low_shelf(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::HIGH_SHELF
        "fi.high_shelf(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::PEAK_EQ_CQ
        "fi.peak_eq_cq(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::FI_POLE
        "fi.pole(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::FI_ZERO
        "fi.zero(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::TF1
        "fi.tf1(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::TF2
        "fi.tf2(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[4], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::TF1S
        "fi.tf1s(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::TF2S
        "fi.tf2s(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[4], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::IIR
        "fi.iir(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::FIR
        "fi.fir(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::CONV
        "fi.conv(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::FBCOMBFILTER
        "fi.fbcombfilter(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::FFCOMBFILTER
        "fi.ffcombfilter(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"

      # === DELAYS ===
      when NodeType::DELAY
        "de.delay(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::FDELAY
        "de.fdelay(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SDELAY
        "de.sdelay(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"

      # === ENVELOPES ===
      when NodeType::AR
        "en.ar(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::ASR
        "en.asr(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::ADSR
        "en.adsr(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[4], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::ADSRE
        "en.adsre(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[4], indent: indent, pretty: pretty, var_map: var_map)})"

      # === MATH ===
      when NodeType::GAIN
        "*(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::ADD
        if node.inputs.count == 2
          my_prec = PREC[:add]
          left = emit(node.inputs[0], indent: indent, pretty: pretty, prec: my_prec, var_map: var_map)
          right = emit(node.inputs[1], indent: indent, pretty: pretty, prec: my_prec + 1, var_map: var_map)
          wrap("#{left} + #{right}", my_prec, prec)
        else
          "+"
        end
      when NodeType::MUL
        if node.inputs.count == 2
          left_node, right_node = node.inputs
          # Always emit idiomatic Faust: signal : *(gain)
          # Normalize scalar-on-left to signal : *(scalar)
          if scalar?(left_node) && !scalar?(right_node)
            # Swap: put signal on left
            left_node, right_node = right_node, left_node
          end
          my_prec = PREC[:seq]
          left = emit(left_node, indent: indent, pretty: pretty, prec: my_prec, var_map: var_map)
          # Don't require high precedence for gain arg - *(x) already groups it
          right = emit(right_node, indent: indent, pretty: pretty, prec: 0, var_map: var_map)
          wrap("#{left} : *(#{right})", my_prec, prec)
        else
          "*"
        end
      when NodeType::SUB
        if node.inputs.count == 2
          my_prec = PREC[:sub]
          left = emit(node.inputs[0], indent: indent, pretty: pretty, prec: my_prec, var_map: var_map)
          right = emit(node.inputs[1], indent: indent, pretty: pretty, prec: my_prec + 1, var_map: var_map)
          wrap("#{left} - #{right}", my_prec, prec)
        else
          "-"
        end
      when NodeType::DIV
        if node.inputs.count == 2
          left_node, right_node = node.inputs
          # Idiomatic Faust: signal : /(scalar) (uses SEQ precedence)
          if scalar?(right_node) && !scalar?(left_node)
            my_prec = PREC[:seq]
            left = emit(left_node, indent: indent, pretty: pretty, prec: my_prec, var_map: var_map)
            right = emit(right_node, indent: indent, pretty: pretty, prec: PREC[:primary], var_map: var_map)
            wrap("#{left} : /(#{right})", my_prec, prec)
          else
            my_prec = PREC[:div]
            left = emit(left_node, indent: indent, pretty: pretty, prec: my_prec, var_map: var_map)
            right = emit(right_node, indent: indent, pretty: pretty, prec: my_prec + 1, var_map: var_map)
            wrap("#{left} / #{right}", my_prec, prec)
          end
        else
          "/"
        end
      when NodeType::MOD
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} % #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"

      # Comparison operators
      when NodeType::LT
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} < #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::GT
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} > #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LE
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} <= #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::GE
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} >= #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::EQ
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} == #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::NEQ
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} != #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"

      # Bitwise operators
      when NodeType::BAND
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} & #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::BOR
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} | #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::XOR
        "(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)} xor #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"

      when NodeType::NEG
        "0 - #{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}"
      when NodeType::ABS
        "abs"
      when NodeType::MIN
        "min(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::MAX
        "max(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::CLIP
        "max(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}) : min(#{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::POW
        "pow(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SQRT
        "sqrt"
      when NodeType::EXP
        "exp"
      when NodeType::LOG
        "log"
      when NodeType::LOG10
        "log10"
      when NodeType::SIN
        "sin"
      when NodeType::COS
        "cos"
      when NodeType::TAN
        "tan"
      when NodeType::TANH
        "ma.tanh"
      when NodeType::SINH
        "sinh"
      when NodeType::COSH
        "cosh"
      when NodeType::ASINH
        "asinh"
      when NodeType::ACOSH
        "acosh"
      when NodeType::ATANH
        "atanh"
      when NodeType::ASIN
        "asin"
      when NodeType::ACOS
        "acos"
      when NodeType::ATAN
        "atan"
      when NodeType::ATAN2
        "atan2(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::FLOOR
        "floor"
      when NodeType::CEIL
        "ceil"
      when NodeType::RINT
        "rint"
      when NodeType::FMOD
        "fmod(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::INT
        "int"
      when NodeType::FLOAT
        "float"

      # === CONVERSION ===
      when NodeType::DB2LINEAR
        node.inputs.empty? ? "ba.db2linear" : "ba.db2linear(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LINEAR2DB
        node.inputs.empty? ? "ba.linear2db" : "ba.linear2db(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SAMP2SEC
        node.inputs.empty? ? "ba.samp2sec" : "ba.samp2sec(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SEC2SAMP
        node.inputs.empty? ? "ba.sec2samp" : "ba.sec2samp(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::MIDI2HZ
        node.inputs.empty? ? "ba.midikey2hz" : "ba.midikey2hz(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::HZ2MIDI
        node.inputs.empty? ? "ba.hz2midikey" : "ba.hz2midikey(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::TAU2POLE
        "ba.tau2pole(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::POLE2TAU
        "ba.pole2tau(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::BA_IF
        cond = emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)
        then_val = emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)
        else_val = emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)
        "ba.if(#{cond}, #{then_val}, #{else_val})"
      when NodeType::SELECTOR
        n = node.args[0]
        sel = emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)
        inputs = node.inputs[1..].map { |i| emit(i, indent: indent, pretty: pretty, var_map: var_map) }.join(", ")
        "ba.selector(#{n}, #{sel}, #{inputs})"
      when NodeType::BA_TAKE
        idx = emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)
        tuple = emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)
        "ba.take(#{idx}, #{tuple})"

      # === SMOOTHING ===
      when NodeType::SMOOTH
        "si.smooth(ba.tau2pole(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}))"
      when NodeType::SMOO
        "si.smoo"

      # === SELECTORS ===
      when NodeType::SELECT2
        "select2(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::SELECTN
        n = node.args[0]
        idx = emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)
        signals = node.inputs[1..].map { |i| emit(i, indent: indent, pretty: pretty, var_map: var_map) }.join(", ")
        "ba.selectn(#{n}, #{idx}, #{signals})"

      # === ROUTING ===
      when NodeType::BUS
        "si.bus(#{node.args[0]})"
      when NodeType::BLOCK
        "si.block(#{node.args[0]})"

      # === REVERBS ===
      when NodeType::FREEVERB
        "re.mono_freeverb(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::ZITA_REV
        args = node.args.join(", ")
        "re.zita_rev1_stereo(#{args})"
      when NodeType::JPVERB
        args = node.args.join(", ")
        "re.jpverb(#{args})"

      # === COMPRESSORS ===
      when NodeType::COMPRESSOR
        "co.compressor_mono(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)}, #{emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::LIMITER
        "co.limiter_1176_R4_mono"

      # === SPATIAL ===
      when NodeType::PANNER
        "sp.panner(#{emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)})"

      # === UI CONTROLS ===
      when NodeType::HSLIDER
        name, init, min, max, step = node.args
        "hslider(\"#{name}\", #{init}, #{min}, #{max}, #{step})"
      when NodeType::VSLIDER
        name, init, min, max, step = node.args
        "vslider(\"#{name}\", #{init}, #{min}, #{max}, #{step})"
      when NodeType::NENTRY
        name, init, min, max, step = node.args
        "nentry(\"#{name}\", #{init}, #{min}, #{max}, #{step})"
      when NodeType::BUTTON
        "button(\"#{node.args[0]}\")"
      when NodeType::CHECKBOX
        "checkbox(\"#{node.args[0]}\")"
      when NodeType::HGROUP
        content = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        if pretty
          "hgroup(\"#{node.args[0]}\",\n#{next_sp}#{content}\n#{sp})"
        else
          "hgroup(\"#{node.args[0]}\", #{content})"
        end
      when NodeType::VGROUP
        content = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        if pretty
          "vgroup(\"#{node.args[0]}\",\n#{next_sp}#{content}\n#{sp})"
        else
          "vgroup(\"#{node.args[0]}\", #{content})"
        end
      when NodeType::TGROUP
        content = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        if pretty
          "tgroup(\"#{node.args[0]}\",\n#{next_sp}#{content}\n#{sp})"
        else
          "tgroup(\"#{node.args[0]}\", #{content})"
        end

      # === ITERATION ===
      when NodeType::FPAR
        var, count, block = node.args
        # Evaluate the block with each index to get the expression
        # For emission, we generate the Faust par() syntax
        body = emit_iteration_body(var, block, indent, pretty, var_map)
        "par(#{var}, #{count}, #{body})"
      when NodeType::FSEQ
        var, count, block = node.args
        body = emit_iteration_body(var, block, indent, pretty, var_map)
        "seq(#{var}, #{count}, #{body})"
      when NodeType::FSUM
        var, count, block = node.args
        body = emit_iteration_body(var, block, indent, pretty, var_map)
        "sum(#{var}, #{count}, #{body})"
      when NodeType::FPROD
        var, count, block = node.args
        body = emit_iteration_body(var, block, indent, pretty, var_map)
        "prod(#{var}, #{count}, #{body})"

      # === LAMBDA ===
      when NodeType::LAMBDA
        params, block = node.args
        param_str = params.map(&:to_s).join(", ")
        # Create param DSP nodes for each parameter
        param_dsps = params.map { |p| DSL.param(p) }
        body = block.call(*param_dsps)
        body = DSL.send(:to_dsp, body)
        "\\(#{param_str}).(#{emit(body.node, indent: indent, pretty: pretty, var_map: var_map)})"
      when NodeType::PARAM
        node.args[0].to_s
      when NodeType::CASE
        var_name, patterns, default_node = node.args
        branches = patterns.map do |val, result_node|
          "(#{val}) => #{emit(result_node, indent: indent, pretty: pretty, var_map: var_map)}"
        end
        default_expr = emit(default_node, indent: indent, pretty: pretty, var_map: var_map)
        branches << "(#{var_name}) => #{default_expr}"
        "case { #{branches.join('; ')}; }"

      # === TABLES ===
      when NodeType::RDTABLE
        size = emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)
        init = emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)
        ridx = emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)
        "rdtable(#{size}, #{init}, #{ridx})"
      when NodeType::RWTABLE
        size = emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)
        init = emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)
        widx = emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)
        wsig = emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)
        ridx = emit(node.inputs[4], indent: indent, pretty: pretty, var_map: var_map)
        "rwtable(#{size}, #{init}, #{widx}, #{wsig}, #{ridx})"
      when NodeType::WAVEFORM
        values = node.args.join(", ")
        "waveform{#{values}}"

      # === ADDITIONAL ROUTING ===
      when NodeType::ROUTE
        ins, outs, connections = node.args
        conn_str = connections.map { |from, to| "(#{from}, #{to})" }.join(", ")
        "route(#{ins}, #{outs}, #{conn_str})"
      when NodeType::SELECT3
        sel = emit(node.inputs[0], indent: indent, pretty: pretty, var_map: var_map)
        a = emit(node.inputs[1], indent: indent, pretty: pretty, var_map: var_map)
        b = emit(node.inputs[2], indent: indent, pretty: pretty, var_map: var_map)
        c = emit(node.inputs[3], indent: indent, pretty: pretty, var_map: var_map)
        "select3(#{sel}, #{a}, #{b}, #{c})"

      # === COMPOSITION ===
      when NodeType::SEQ
        my_prec = PREC[:seq]
        # Left child: same precedence (left-associative, no parens needed)
        # Right child: higher precedence required (would need parens if it's another SEQ)
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty, prec: my_prec, var_map: var_map)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty, prec: my_prec + 1, var_map: var_map)
        expr = if pretty
          "\n#{next_sp}#{left}\n#{next_sp}: #{right}\n#{sp}"
        else
          "#{left} : #{right}"
        end
        wrap(expr, my_prec, prec)
      when NodeType::PAR
        my_prec = PREC[:par]
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty, prec: my_prec, var_map: var_map)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty, prec: my_prec + 1, var_map: var_map)
        expr = if pretty
          "\n#{next_sp}#{left},\n#{next_sp}#{right}\n#{sp}"
        else
          "#{left}, #{right}"
        end
        wrap(expr, my_prec, prec)
      when NodeType::SPLIT
        my_prec = PREC[:split]
        source = emit(node.inputs[0], indent: indent + 1, pretty: pretty, prec: my_prec, var_map: var_map)
        targets = node.inputs[1..].map { |n| emit(n, indent: indent + 1, pretty: pretty, prec: my_prec + 1, var_map: var_map) }
        expr = if pretty
          "\n#{next_sp}#{source}\n#{next_sp}<: #{targets.join(",\n#{next_sp}   ")}\n#{sp}"
        else
          "#{source} <: #{targets.join(", ")}"
        end
        wrap(expr, my_prec, prec)
      when NodeType::MERGE
        my_prec = PREC[:merge]
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty, prec: my_prec, var_map: var_map)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty, prec: my_prec + 1, var_map: var_map)
        expr = if pretty
          "\n#{next_sp}#{left}\n#{next_sp}:> #{right}\n#{sp}"
        else
          "#{left} :> #{right}"
        end
        wrap(expr, my_prec, prec)
      when NodeType::FEEDBACK
        my_prec = PREC[:rec]
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty, prec: my_prec, var_map: var_map)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty, prec: my_prec + 1, var_map: var_map)
        expr = if pretty
          "\n#{next_sp}#{left}\n#{next_sp}~ #{right}\n#{sp}"
        else
          "#{left} ~ #{right}"
        end
        wrap(expr, my_prec, prec)

      # === UTILITY ===
      when NodeType::WIRE
        "_"
      when NodeType::CUT
        "!"
      when NodeType::MEM
        "mem"
      when NodeType::LITERAL
        node.args[0].to_s

      # === CONSTANTS ===
      when NodeType::SR
        "ma.SR"
      when NodeType::PI
        "ma.PI"
      when NodeType::TEMPO
        "ma.tempo"

      # === ANTIALIASING ===
      when NodeType::AA_TANH1
        "aa.tanh1"
      when NodeType::AA_TANH2
        "aa.tanh2"
      when NodeType::AA_ARCTAN
        "aa.arctan"
      when NodeType::AA_SOFTCLIP
        "aa.softclip"
      when NodeType::AA_HARDCLIP
        "aa.hardclip"
      when NodeType::AA_PARABOLIC
        "aa.parabolic"
      when NodeType::AA_SIN
        "aa.sin"
      when NodeType::AA_CUBIC1
        "aa.cubic1"
      when NodeType::AA_CUBIC2
        "aa.cubic2"

      # Analyzers (an.)
      when NodeType::AMP_FOLLOWER
        "an.amp_follower(#{emit_args(node, indent, pretty)})"
      when NodeType::AMP_FOLLOWER_AR
        "an.amp_follower_ar(#{emit_args(node, indent, pretty)})"
      when NodeType::AMP_FOLLOWER_UD
        "an.amp_follower_ud(#{emit_args(node, indent, pretty)})"
      when NodeType::RMS_ENVELOPE_RECT
        "an.rms_envelope_rect(#{emit_args(node, indent, pretty)})"
      when NodeType::RMS_ENVELOPE_TAU
        "an.rms_envelope_tau(#{emit_args(node, indent, pretty)})"
      when NodeType::ABS_ENVELOPE_RECT
        "an.abs_envelope_rect(#{emit_args(node, indent, pretty)})"
      when NodeType::ABS_ENVELOPE_TAU
        "an.abs_envelope_tau(#{emit_args(node, indent, pretty)})"
      when NodeType::MS_ENVELOPE_RECT
        "an.ms_envelope_rect(#{emit_args(node, indent, pretty)})"
      when NodeType::MS_ENVELOPE_TAU
        "an.ms_envelope_tau(#{emit_args(node, indent, pretty)})"
      when NodeType::PEAK_ENVELOPE
        "an.peak_envelope(#{emit_args(node, indent, pretty)})"

      # Effects (ef.)
      when NodeType::CUBICNL
        "ef.cubicnl(#{emit_args(node, indent, pretty)})"
      when NodeType::GATE_MONO
        "ef.gate_mono(#{emit_args(node, indent, pretty)})"
      when NodeType::GATE_STEREO
        "ef.gate_stereo(#{emit_args(node, indent, pretty)})"
      when NodeType::EF_COMPRESSOR_MONO
        "ef.compressor_mono(#{emit_args(node, indent, pretty)})"
      when NodeType::EF_COMPRESSOR_STEREO
        "ef.compressor_stereo(#{emit_args(node, indent, pretty)})"
      when NodeType::EF_LIMITER_1176_MONO
        "ef.limiter_1176_R4_mono"
      when NodeType::EF_LIMITER_1176_STEREO
        "ef.limiter_1176_R4_stereo"
      when NodeType::ECHO
        "ef.echo(#{emit_args(node, indent, pretty)})"
      when NodeType::TRANSPOSE
        "ef.transpose(#{emit_args(node, indent, pretty)})"
      when NodeType::FLANGER_MONO
        "ef.flanger_mono(#{emit_args(node, indent, pretty)})"
      when NodeType::FLANGER_STEREO
        "ef.flanger_stereo(#{emit_args(node, indent, pretty)})"
      when NodeType::PHASER2_MONO
        "ef.phaser2_mono(#{emit_args(node, indent, pretty)})"
      when NodeType::PHASER2_STEREO
        "ef.phaser2_stereo(#{emit_args(node, indent, pretty)})"
      when NodeType::WAH4
        "ef.wah4(#{emit_args(node, indent, pretty)})"
      when NodeType::AUTO_WAH
        "ef.auto_wah(#{emit_args(node, indent, pretty)})"
      when NodeType::CRYBABY
        "ef.crybaby(#{emit_args(node, indent, pretty)})"
      when NodeType::VOCODER
        "ef.vocoder(#{emit_args(node, indent, pretty)})"
      when NodeType::SPEAKERBP
        "ef.speakerbp(#{emit_args(node, indent, pretty)})"
      when NodeType::DRY_WET_MIXER
        "ef.dryWetMixer(#{emit_args(node, indent, pretty)})"
      when NodeType::DRY_WET_MIXER_CP
        "ef.dryWetMixerConstantPower(#{emit_args(node, indent, pretty)})"

      else
        raise ArgumentError, "Unknown node type: #{node.type}"
      end
    end

    # Helper to emit iteration body for par/seq/sum/prod
    # Creates a symbolic parameter to capture the iterator variable
    def emit_iteration_body(var, block, indent, pretty, var_map)
      # Create a context that provides the iterator variable as a symbol
      context = Object.new
      context.extend(DSL)
      # The block receives a symbolic representation of the iterator
      iter_param = DSL.param(var)
      body = block.call(iter_param)
      body = DSL.send(:to_dsp, body)
      emit(body.node, indent: indent, pretty: pretty, var_map: var_map)
    end
  end
end
