# frozen_string_literal: true

require_relative "ir"

module Ruby2Faust
  # Emitter generates Faust source code from an IR graph.
  module Emitter
    module_function

    DEFAULT_IMPORTS = ["stdfaust.lib"].freeze

    def program(process, imports: nil, declarations: {}, pretty: false)
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
      
      body = emit(node, pretty: pretty)
      lines << "process = #{body};"
      lines.join("\n") + "\n"
    end

    def emit(node, indent: 0, pretty: false)
      sp = "  " * indent
      next_sp = "  " * (indent + 1)

      case node.type

      # === COMMENTS ===
      when NodeType::COMMENT
        "// #{node.args[0]}\n"
      when NodeType::DOC
        # Inline comment wrapped around the inner expression
        "/* #{node.args[0]} */ #{emit(node.inputs[0], indent: indent, pretty: pretty)}"

      # === OSCILLATORS ===
      when NodeType::OSC
        "os.osc(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::SAW
        "os.sawtooth(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::SQUARE
        "os.square(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::TRIANGLE
        "os.triangle(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::PHASOR
        "os.phasor(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::LF_SAW
        "os.lf_sawpos(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::LF_TRIANGLE
        "os.lf_trianglepos(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::LF_SQUARE
        "os.lf_squarewavepos(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::IMPTRAIN
        "os.lf_imptrain(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::PULSETRAIN
        "os.lf_pulsetrain(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"

      # === NOISE ===
      when NodeType::NOISE
        "no.noise"
      when NodeType::PINK_NOISE
        "no.pink_noise"

      # === FILTERS ===
      when NodeType::LP
        "fi.lowpass(#{node.args[0] || 1}, #{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::HP
        "fi.highpass(#{node.args[0] || 1}, #{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::BP
        "fi.bandpass(1, #{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::RESONLP
        "fi.resonlp(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"
      when NodeType::RESONHP
        "fi.resonhp(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"
      when NodeType::RESONBP
        "fi.resonbp(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"
      when NodeType::ALLPASS
        "fi.allpass_comb(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"
      when NodeType::DCBLOCK
        "fi.dcblocker"
      when NodeType::PEAK_EQ
        "fi.peak_eq(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"

      # === DELAYS ===
      when NodeType::DELAY
        "de.delay(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::FDELAY
        "de.fdelay(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::SDELAY
        "de.sdelay(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"

      # === ENVELOPES ===
      when NodeType::AR
        "en.ar(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"
      when NodeType::ASR
        "en.asr(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)}, #{emit(node.inputs[3], indent: indent, pretty: pretty)})"
      when NodeType::ADSR
        "en.adsr(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)}, #{emit(node.inputs[3], indent: indent, pretty: pretty)}, #{emit(node.inputs[4], indent: indent, pretty: pretty)})"
      when NodeType::ADSRE
        "en.adsre(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)}, #{emit(node.inputs[3], indent: indent, pretty: pretty)}, #{emit(node.inputs[4], indent: indent, pretty: pretty)})"

      # === MATH ===
      when NodeType::GAIN
        "*(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::ADD
        node.inputs.count == 2 ? "(#{emit(node.inputs[0], indent: indent, pretty: pretty)} + #{emit(node.inputs[1], indent: indent, pretty: pretty)})" : "+"
      when NodeType::MUL
        node.inputs.count == 2 ? "(#{emit(node.inputs[0], indent: indent, pretty: pretty)} * #{emit(node.inputs[1], indent: indent, pretty: pretty)})" : "*"
      when NodeType::SUB
        node.inputs.count == 2 ? "(#{emit(node.inputs[0], indent: indent, pretty: pretty)} - #{emit(node.inputs[1], indent: indent, pretty: pretty)})" : "-"
      when NodeType::DIV
        node.inputs.count == 2 ? "(#{emit(node.inputs[0], indent: indent, pretty: pretty)} / #{emit(node.inputs[1], indent: indent, pretty: pretty)})" : "/"
      when NodeType::NEG
        "0 - #{emit(node.inputs[0], indent: indent, pretty: pretty)}"
      when NodeType::ABS
        "abs"
      when NodeType::MIN
        "min(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::MAX
        "max(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::CLIP
        "max(#{emit(node.inputs[0], indent: indent, pretty: pretty)}) : min(#{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::POW
        "pow(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
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
        "atan2(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::FLOOR
        "floor"
      when NodeType::CEIL
        "ceil"
      when NodeType::RINT
        "rint"
      when NodeType::FMOD
        "fmod(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)})"
      when NodeType::INT
        "int"
      when NodeType::FLOAT
        "float"

      # === CONVERSION ===
      when NodeType::DB2LINEAR
        "ba.db2linear(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::LINEAR2DB
        "ba.linear2db(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::SAMP2SEC
        "ba.samp2sec(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::SEC2SAMP
        "ba.sec2samp(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::MIDI2HZ
        "ba.midikey2hz(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::HZ2MIDI
        "ba.hz2midikey(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::TAU2POLE
        "ba.tau2pole(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::POLE2TAU
        "ba.pole2tau(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"
      when NodeType::BA_IF
        cond = emit(node.inputs[0], indent: indent, pretty: pretty)
        then_val = emit(node.inputs[1], indent: indent, pretty: pretty)
        else_val = emit(node.inputs[2], indent: indent, pretty: pretty)
        "ba.if(#{cond}, #{then_val}, #{else_val})"
      when NodeType::SELECTOR
        n = node.args[0]
        sel = emit(node.inputs[0], indent: indent, pretty: pretty)
        inputs = node.inputs[1..].map { |i| emit(i, indent: indent, pretty: pretty) }.join(", ")
        "ba.selector(#{n}, #{sel}, #{inputs})"
      when NodeType::BA_TAKE
        idx = emit(node.inputs[0], indent: indent, pretty: pretty)
        tuple = emit(node.inputs[1], indent: indent, pretty: pretty)
        "ba.take(#{idx}, #{tuple})"

      # === SMOOTHING ===
      when NodeType::SMOOTH
        "si.smooth(ba.tau2pole(#{emit(node.inputs[0], indent: indent, pretty: pretty)}))"
      when NodeType::SMOO
        "si.smoo"

      # === SELECTORS ===
      when NodeType::SELECT2
        "select2(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)})"
      when NodeType::SELECTN
        n = node.args[0]
        idx = emit(node.inputs[0], indent: indent, pretty: pretty)
        signals = node.inputs[1..].map { |i| emit(i, indent: indent, pretty: pretty) }.join(", ")
        "ba.selectn(#{n}, #{idx}, #{signals})"

      # === ROUTING ===
      when NodeType::BUS
        "si.bus(#{node.args[0]})"
      when NodeType::BLOCK
        "si.block(#{node.args[0]})"

      # === REVERBS ===
      when NodeType::FREEVERB
        "re.mono_freeverb(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)}, #{emit(node.inputs[3], indent: indent, pretty: pretty)})"
      when NodeType::ZITA_REV
        args = node.args.join(", ")
        "re.zita_rev1_stereo(#{args})"
      when NodeType::JPVERB
        args = node.args.join(", ")
        "re.jpverb(#{args})"

      # === COMPRESSORS ===
      when NodeType::COMPRESSOR
        "co.compressor_mono(#{emit(node.inputs[0], indent: indent, pretty: pretty)}, #{emit(node.inputs[1], indent: indent, pretty: pretty)}, #{emit(node.inputs[2], indent: indent, pretty: pretty)}, #{emit(node.inputs[3], indent: indent, pretty: pretty)})"
      when NodeType::LIMITER
        "co.limiter_1176_R4_mono"

      # === SPATIAL ===
      when NodeType::PANNER
        "sp.panner(#{emit(node.inputs[0], indent: indent, pretty: pretty)})"

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
        body = emit_iteration_body(var, block, indent, pretty)
        "par(#{var}, #{count}, #{body})"
      when NodeType::FSEQ
        var, count, block = node.args
        body = emit_iteration_body(var, block, indent, pretty)
        "seq(#{var}, #{count}, #{body})"
      when NodeType::FSUM
        var, count, block = node.args
        body = emit_iteration_body(var, block, indent, pretty)
        "sum(#{var}, #{count}, #{body})"
      when NodeType::FPROD
        var, count, block = node.args
        body = emit_iteration_body(var, block, indent, pretty)
        "prod(#{var}, #{count}, #{body})"

      # === LAMBDA ===
      when NodeType::LAMBDA
        params, block = node.args
        param_str = params.map(&:to_s).join(", ")
        # Create a context with param nodes for each parameter
        context = Object.new
        context.extend(DSL)
        param_dsps = params.map { |p| context.param(p) }
        body = block.call(*param_dsps)
        body = context.instance_exec { to_dsp(body) }
        "\\(#{param_str}).(#{emit(body.node, indent: indent, pretty: pretty)})"
      when NodeType::PARAM
        node.args[0].to_s

      # === TABLES ===
      when NodeType::RDTABLE
        size = emit(node.inputs[0], indent: indent, pretty: pretty)
        init = emit(node.inputs[1], indent: indent, pretty: pretty)
        ridx = emit(node.inputs[2], indent: indent, pretty: pretty)
        "rdtable(#{size}, #{init}, #{ridx})"
      when NodeType::RWTABLE
        size = emit(node.inputs[0], indent: indent, pretty: pretty)
        init = emit(node.inputs[1], indent: indent, pretty: pretty)
        widx = emit(node.inputs[2], indent: indent, pretty: pretty)
        wsig = emit(node.inputs[3], indent: indent, pretty: pretty)
        ridx = emit(node.inputs[4], indent: indent, pretty: pretty)
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
        sel = emit(node.inputs[0], indent: indent, pretty: pretty)
        a = emit(node.inputs[1], indent: indent, pretty: pretty)
        b = emit(node.inputs[2], indent: indent, pretty: pretty)
        c = emit(node.inputs[3], indent: indent, pretty: pretty)
        "select3(#{sel}, #{a}, #{b}, #{c})"

      # === COMPOSITION ===
      when NodeType::SEQ
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty)
        if pretty
          "(\n#{next_sp}#{left}\n#{next_sp}: #{right}\n#{sp})"
        else
          "(#{left} : #{right})"
        end
      when NodeType::PAR
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty)
        if pretty
          "(\n#{next_sp}#{left},\n#{next_sp}#{right}\n#{sp})"
        else
          "(#{left}, #{right})"
        end
      when NodeType::SPLIT
        source = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        targets = node.inputs[1..].map { |n| emit(n, indent: indent + 1, pretty: pretty) }
        if pretty
          "(\n#{next_sp}#{source}\n#{next_sp}<: #{targets.join(",\n#{next_sp}   ")}\n#{sp})"
        else
          "(#{source} <: #{targets.join(", ")})"
        end
      when NodeType::MERGE
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty)
        if pretty
          "(\n#{next_sp}#{left}\n#{next_sp}:> #{right}\n#{sp})"
        else
          "(#{left} :> #{right})"
        end
      when NodeType::FEEDBACK
        left = emit(node.inputs[0], indent: indent + 1, pretty: pretty)
        right = emit(node.inputs[1], indent: indent + 1, pretty: pretty)
        if pretty
          "(\n#{next_sp}#{left}\n#{next_sp}~ #{right}\n#{sp})"
        else
          "(#{left} ~ #{right})"
        end

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

      else
        raise ArgumentError, "Unknown node type: #{node.type}"
      end
    end

    # Helper to emit iteration body for par/seq/sum/prod
    # Creates a symbolic parameter to capture the iterator variable
    def emit_iteration_body(var, block, indent, pretty)
      # Create a context that provides the iterator variable as a symbol
      context = Object.new
      context.extend(DSL)
      # The block receives a symbolic representation of the iterator
      iter_param = context.param(var)
      body = block.call(iter_param)
      body = context.instance_exec(body) { |b| to_dsp(b) }
      emit(body.node, indent: indent, pretty: pretty)
    end
  end
end
