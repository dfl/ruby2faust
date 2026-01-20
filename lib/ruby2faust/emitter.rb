# frozen_string_literal: true

require_relative "ir"

module Ruby2Faust
  # Emitter generates Faust source code from an IR graph.
  module Emitter
    module_function

    DEFAULT_IMPORTS = ["stdfaust.lib"].freeze

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
      declarations.each { |k, v| lines << "declare #{k} \"#{v}\";" }
      lines << "" if declarations.any?
      imports.each { |lib| lines << "import(\"#{lib}\");" }
      lines << ""
      lines << "process = #{emit(node)};"
      lines.join("\n") + "\n"
    end

    def emit(node)
      case node.type

      # === COMMENTS ===
      when NodeType::COMMENT
        "// #{node.args[0]}\n"
      when NodeType::DOC
        # Inline comment wrapped around the inner expression
        "/* #{node.args[0]} */ #{emit(node.inputs[0])}"

      # === OSCILLATORS ===
      when NodeType::OSC
        "os.osc(#{emit(node.inputs[0])})"
      when NodeType::SAW
        "os.sawtooth(#{emit(node.inputs[0])})"
      when NodeType::SQUARE
        "os.square(#{emit(node.inputs[0])})"
      when NodeType::TRIANGLE
        "os.triangle(#{emit(node.inputs[0])})"
      when NodeType::PHASOR
        "os.phasor(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::LF_SAW
        "os.lf_sawpos(#{emit(node.inputs[0])})"
      when NodeType::LF_TRIANGLE
        "os.lf_trianglepos(#{emit(node.inputs[0])})"
      when NodeType::LF_SQUARE
        "os.lf_squarewavepos(#{emit(node.inputs[0])})"
      when NodeType::IMPTRAIN
        "os.lf_imptrain(#{emit(node.inputs[0])})"
      when NodeType::PULSETRAIN
        "os.lf_pulsetrain(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"

      # === NOISE ===
      when NodeType::NOISE
        "no.noise"
      when NodeType::PINK_NOISE
        "no.pink_noise"

      # === FILTERS ===
      when NodeType::LP
        "fi.lowpass(#{node.args[0] || 1}, #{emit(node.inputs[0])})"
      when NodeType::HP
        "fi.highpass(#{node.args[0] || 1}, #{emit(node.inputs[0])})"
      when NodeType::BP
        "fi.bandpass(1, #{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::RESONLP
        "fi.resonlp(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"
      when NodeType::RESONHP
        "fi.resonhp(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"
      when NodeType::RESONBP
        "fi.resonbp(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"
      when NodeType::ALLPASS
        "fi.allpass_comb(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"
      when NodeType::DCBLOCK
        "fi.dcblocker"
      when NodeType::PEAK_EQ
        "fi.peak_eq(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"

      # === DELAYS ===
      when NodeType::DELAY
        "de.delay(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::FDELAY
        "de.fdelay(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::SDELAY
        "de.sdelay(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"

      # === ENVELOPES ===
      when NodeType::AR
        "en.ar(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"
      when NodeType::ASR
        "en.asr(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])}, #{emit(node.inputs[3])})"
      when NodeType::ADSR
        "en.adsr(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])}, #{emit(node.inputs[3])}, #{emit(node.inputs[4])})"
      when NodeType::ADSRE
        "en.adsre(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])}, #{emit(node.inputs[3])}, #{emit(node.inputs[4])})"

      # === MATH ===
      when NodeType::GAIN
        "*(#{emit(node.inputs[0])})"
      when NodeType::ADD
        node.inputs.count == 2 ? "(#{emit(node.inputs[0])} + #{emit(node.inputs[1])})" : "+"
      when NodeType::MUL
        node.inputs.count == 2 ? "(#{emit(node.inputs[0])} * #{emit(node.inputs[1])})" : "*"
      when NodeType::SUB
        node.inputs.count == 2 ? "(#{emit(node.inputs[0])} - #{emit(node.inputs[1])})" : "-"
      when NodeType::DIV
        node.inputs.count == 2 ? "(#{emit(node.inputs[0])} / #{emit(node.inputs[1])})" : "/"
      when NodeType::NEG
        "0 - #{emit(node.inputs[0])}"
      when NodeType::ABS
        "abs"
      when NodeType::MIN
        "min(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::MAX
        "max(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::CLIP
        "max(#{emit(node.inputs[0])}) : min(#{emit(node.inputs[1])})"
      when NodeType::POW
        "pow(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
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
      when NodeType::ASIN
        "asin"
      when NodeType::ACOS
        "acos"
      when NodeType::ATAN
        "atan"
      when NodeType::ATAN2
        "atan2(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::FLOOR
        "floor"
      when NodeType::CEIL
        "ceil"
      when NodeType::RINT
        "rint"
      when NodeType::FMOD
        "fmod(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::INT
        "int"
      when NodeType::FLOAT
        "float"

      # === CONVERSION ===
      when NodeType::DB2LINEAR
        "ba.db2linear(#{emit(node.inputs[0])})"
      when NodeType::LINEAR2DB
        "ba.linear2db(#{emit(node.inputs[0])})"
      when NodeType::SAMP2SEC
        "ba.samp2sec(#{emit(node.inputs[0])})"
      when NodeType::SEC2SAMP
        "ba.sec2samp(#{emit(node.inputs[0])})"
      when NodeType::MIDI2HZ
        "ba.midikey2hz(#{emit(node.inputs[0])})"
      when NodeType::HZ2MIDI
        "ba.hz2midikey(#{emit(node.inputs[0])})"

      # === SMOOTHING ===
      when NodeType::SMOOTH
        "si.smooth(ba.tau2pole(#{emit(node.inputs[0])}))"
      when NodeType::SMOO
        "si.smoo"

      # === SELECTORS ===
      when NodeType::SELECT2
        "select2(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])})"
      when NodeType::SELECTN
        n = node.args[0]
        idx = emit(node.inputs[0])
        signals = node.inputs[1..].map { |i| emit(i) }.join(", ")
        "ba.selectn(#{n}, #{idx}, #{signals})"

      # === ROUTING ===
      when NodeType::BUS
        "si.bus(#{node.args[0]})"
      when NodeType::BLOCK
        "si.block(#{node.args[0]})"

      # === REVERBS ===
      when NodeType::FREEVERB
        "re.mono_freeverb(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])}, #{emit(node.inputs[3])})"
      when NodeType::ZITA_REV
        args = node.args.join(", ")
        "re.zita_rev1_stereo(#{args})"
      when NodeType::JPVERB
        args = node.args.join(", ")
        "re.jpverb(#{args})"

      # === COMPRESSORS ===
      when NodeType::COMPRESSOR
        "co.compressor_mono(#{emit(node.inputs[0])}, #{emit(node.inputs[1])}, #{emit(node.inputs[2])}, #{emit(node.inputs[3])})"
      when NodeType::LIMITER
        "co.limiter_1176_R4_mono"

      # === SPATIAL ===
      when NodeType::PANNER
        "sp.panner(#{emit(node.inputs[0])})"

      # === UI CONTROLS ===
      when NodeType::SLIDER
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
        "hgroup(\"#{node.args[0]}\", #{emit(node.inputs[0])})"
      when NodeType::VGROUP
        "vgroup(\"#{node.args[0]}\", #{emit(node.inputs[0])})"
      when NodeType::TGROUP
        "tgroup(\"#{node.args[0]}\", #{emit(node.inputs[0])})"

      # === COMPOSITION ===
      when NodeType::SEQ
        "(#{emit(node.inputs[0])} : #{emit(node.inputs[1])})"
      when NodeType::PAR
        "(#{emit(node.inputs[0])}, #{emit(node.inputs[1])})"
      when NodeType::SPLIT
        source = emit(node.inputs[0])
        targets = node.inputs[1..].map { |n| emit(n) }.join(", ")
        "(#{source} <: #{targets})"
      when NodeType::MERGE
        "(#{emit(node.inputs[0])} :> #{emit(node.inputs[1])})"
      when NodeType::FEEDBACK
        "(#{emit(node.inputs[0])} ~ #{emit(node.inputs[1])})"

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

      else
        raise ArgumentError, "Unknown node type: #{node.type}"
      end
    end
  end
end
