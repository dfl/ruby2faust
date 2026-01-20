# frozen_string_literal: true

require "digest"

module Ruby2Faust
  # Intermediate Representation node for DSP graphs.
  # Nodes are immutable value objects representing DSP operations.
  Node = Struct.new(:type, :args, :inputs, :channels, keyword_init: true) do
    def initialize(type:, args: [], inputs: [], channels: 1)
      super(type: type, args: args.freeze, inputs: inputs.freeze, channels: channels)
    end

    def fingerprint
      content = [type, args, inputs.map(&:fingerprint)].inspect
      Digest::SHA1.hexdigest(content)
    end

    def same_structure?(other)
      fingerprint == other.fingerprint
    end
  end

  # Node type constants - comprehensive Faust library coverage
  module NodeType
    # === Comments/Documentation ===
    COMMENT = :comment  # // line comment
    DOC     = :doc      # /* inline comment */ attached to node

    # === Oscillators (os.) ===
    OSC       = :osc        # os.osc(freq) - sine
    SAW       = :saw        # os.sawtooth(freq)
    SQUARE    = :square     # os.square(freq)
    TRIANGLE  = :triangle   # os.triangle(freq)
    PHASOR    = :phasor     # os.phasor(tablesize, freq)
    LF_SAW    = :lf_saw     # os.lf_sawpos(freq) - low-freq sawtooth 0-1
    LF_TRIANGLE = :lf_triangle
    LF_SQUARE = :lf_square
    IMPTRAIN  = :imptrain   # os.lf_imptrain(freq) - impulse train
    PULSETRAIN = :pulsetrain # os.lf_pulsetrain(freq, duty)

    # === Noise (no.) ===
    NOISE      = :noise      # no.noise - white
    PINK_NOISE = :pink_noise # no.pink_noise

    # === Filters (fi.) ===
    LP = :lp  # fi.lowpass(order, freq)
    HP = :hp  # fi.highpass(order, freq)
    BP = :bp  # fi.bandpass(order, freq, q)
    RESONLP = :resonlp  # fi.resonlp(freq, q, gain)
    RESONHP = :resonhp
    RESONBP = :resonbp
    ALLPASS = :allpass  # fi.allpass_comb(maxdelay, delay, feedback)
    DCBLOCK = :dcblock  # fi.dcblocker
    PEAK_EQ = :peak_eq  # fi.peak_eq(freq, q, gain_db)

    # SVF (State Variable Filter)
    SVF_LP    = :svf_lp    # fi.svf.lp(freq, q)
    SVF_HP    = :svf_hp    # fi.svf.hp(freq, q)
    SVF_BP    = :svf_bp    # fi.svf.bp(freq, q)
    SVF_NOTCH = :svf_notch # fi.svf.notch(freq, q)
    SVF_AP    = :svf_ap    # fi.svf.ap(freq, q)
    SVF_BELL  = :svf_bell  # fi.svf.bell(freq, q, gain)
    SVF_LS    = :svf_ls    # fi.svf.ls(freq, q, gain) - low shelf
    SVF_HS    = :svf_hs    # fi.svf.hs(freq, q, gain) - high shelf

    # Other filters
    LOWPASS3E  = :lowpass3e   # fi.lowpass3e(freq) - 3rd order elliptic
    HIGHPASS3E = :highpass3e  # fi.highpass3e(freq)
    LOWPASS6E  = :lowpass6e   # fi.lowpass6e(freq) - 6th order elliptic
    HIGHPASS6E = :highpass6e  # fi.highpass6e(freq)
    BANDSTOP   = :bandstop    # fi.bandstop(order, freq, q)
    NOTCHW     = :notchw      # fi.notchw(freq, width)
    LOW_SHELF  = :low_shelf   # fi.low_shelf(freq, q, gain)
    HIGH_SHELF = :high_shelf  # fi.high_shelf(freq, q, gain)
    PEAK_EQ_CQ = :peak_eq_cq  # fi.peak_eq_cq(freq, q, gain)
    FI_POLE    = :fi_pole     # fi.pole(p)
    FI_ZERO    = :fi_zero     # fi.zero(z)
    TF1        = :tf1         # fi.tf1(b0, b1, a1)
    TF2        = :tf2         # fi.tf2(b0, b1, b2, a1, a2)
    TF1S       = :tf1s        # fi.tf1s(b0, b1, a1)
    TF2S       = :tf2s        # fi.tf2s(b0, b1, b2, a1, a2)
    IIR        = :iir         # fi.iir(bcoeffs, acoeffs)
    FIR        = :fir         # fi.fir(coeffs)
    CONV       = :conv        # fi.conv(impulse, size)
    FBCOMBFILTER = :fbcombfilter # fi.fbcombfilter(maxdel, del, fb)
    FFCOMBFILTER = :ffcombfilter # fi.ffcombfilter(maxdel, del)

    # === Delays (de.) ===
    DELAY  = :delay   # de.delay(maxdelay, delay)
    FDELAY = :fdelay  # de.fdelay(maxdelay, delay) - fractional
    SDELAY = :sdelay  # de.sdelay(maxdelay, interp, delay) - smooth

    # === Envelopes (en.) ===
    AR    = :ar    # en.ar(attack, release, gate)
    ASR   = :asr   # en.asr(attack, sustain_level, release, gate)
    ADSR  = :adsr  # en.adsr(attack, decay, sustain, release, gate)
    ADSRE = :adsre # en.adsre with exponential segments

    # === Math (primitives + ma.) ===
    GAIN = :gain       # *(x)
    ADD  = :add        # +
    MUL  = :mul        # *
    SUB  = :sub        # -
    DIV  = :div        # /
    NEG  = :neg        # 0 - x
    ABS  = :abs        # abs
    MIN  = :min        # min(a, b)
    MAX  = :max        # max(a, b)
    CLIP = :clip       # max(min_val, min(max_val, x))
    POW  = :pow        # pow(base, exp)
    SQRT = :sqrt       # sqrt
    EXP  = :exp        # exp
    LOG  = :log        # log
    LOG10 = :log10     # log10
    SIN  = :sin        # sin
    COS  = :cos        # cos
    TAN  = :tan        # tan
    ASIN = :asin
    ACOS = :acos
    ATAN = :atan
    ATAN2 = :atan2
    TANH = :tanh       # ma.tanh - saturating
    SINH = :sinh
    COSH = :cosh
    ASINH = :asinh
    ACOSH = :acosh
    ATANH = :atanh
    FLOOR = :floor
    CEIL = :ceil
    RINT = :rint       # round to int
    FMOD = :fmod       # fmod(x, y)
    REMAINDER = :remainder
    MOD  = :mod        # %

    # === Comparison ===
    LT  = :lt   # <
    GT  = :gt   # >
    LE  = :le   # <=
    GE  = :ge   # >=
    EQ  = :eq   # ==
    NEQ = :neq  # !=

    # === Bitwise ===
    BAND = :band  # &
    BOR  = :bor   # | (bitwise, not parallel)
    XOR  = :xor   # xor

    # === Conversion (ba.) ===
    DB2LINEAR = :db2linear  # ba.db2linear
    LINEAR2DB = :linear2db  # ba.linear2db
    SAMP2SEC  = :samp2sec   # ba.samp2sec
    SEC2SAMP  = :sec2samp   # ba.sec2samp
    MIDI2HZ   = :midi2hz    # ba.midikey2hz
    HZ2MIDI   = :hz2midi    # ba.hz2midikey
    TAU2POLE  = :tau2pole   # ba.tau2pole
    POLE2TAU  = :pole2tau   # ba.pole2tau
    BA_IF     = :ba_if      # ba.if(cond, then, else)
    SELECTOR  = :selector   # ba.selector(n, sel, inputs)
    BA_TAKE   = :ba_take    # ba.take(idx, tuple)

    # === Smoothing (si.) ===
    SMOOTH    = :smooth     # si.smooth(ba.tau2pole(tau))
    SMOO      = :smoo       # si.smoo - default 5ms smooth
    POLYSMOOTH = :polysmooth # si.polySmooth(s, n)

    # === Selectors ===
    SELECT2 = :select2  # select2(cond, a, b)
    SELECTN = :selectn  # ba.selectn(n, idx, ...)

    # === Routing (si./ro.) ===
    BUS   = :bus    # si.bus(n) - n parallel wires
    BLOCK = :block  # si.block(n) - terminate n signals

    # === Reverbs (re.) ===
    FREEVERB = :freeverb  # re.mono_freeverb(fb1, fb2, damp, spread)
    ZITA_REV = :zita_rev  # re.zita_rev1_stereo(...)
    JPVERB   = :jpverb    # re.jpverb(...)

    # === Compressors (co.) ===
    COMPRESSOR = :compressor  # co.compressor_mono(ratio, thresh, attack, release)
    LIMITER    = :limiter     # co.limiter_1176_R4_mono

    # === Spatial (sp.) ===
    PANNER = :panner  # sp.panner(pan) - stereo pan

    # === UI Controls ===
    SLIDER   = :slider
    VSLIDER  = :vslider
    NENTRY   = :nentry
    BUTTON   = :button
    CHECKBOX = :checkbox
    HGROUP   = :hgroup
    VGROUP   = :vgroup
    TGROUP   = :tgroup

    # === Composition ===
    SEQ      = :seq       # :
    PAR      = :par       # ,
    SPLIT    = :split     # <:
    MERGE    = :merge     # :>
    FEEDBACK = :feedback  # ~
    REC      = :rec       # letrec style
    LETREC   = :letrec    # letrec { 'x = expr; 'y = expr; } result

    # === Iteration ===
    FPAR  = :fpar   # par(i, n, expr)
    FSEQ  = :fseq   # seq(i, n, expr)
    FSUM  = :fsum   # sum(i, n, expr)
    FPROD = :fprod  # prod(i, n, expr)

    # === Lambda ===
    LAMBDA = :lambda  # \(x).(body)
    PARAM  = :param   # Parameter reference

    # === Tables ===
    RDTABLE  = :rdtable   # rdtable(n, init, ridx)
    RWTABLE  = :rwtable   # rwtable(n, init, widx, wsig, ridx)
    WAVEFORM = :waveform  # waveform{...}

    # === Additional Routing ===
    ROUTE   = :route    # route(ins, outs, connections)
    SELECT3 = :select3  # select3(sel, a, b, c)

    # === Utility ===
    WIRE    = :wire    # _
    CUT     = :cut     # !
    LITERAL = :literal # raw Faust expression
    MEM     = :mem     # mem (1-sample delay)
    INT     = :int     # int(x)
    FLOAT   = :float   # float(x)

    # === Constants ===
    SR = :sr      # ma.SR
    PI = :pi      # ma.PI
    TEMPO = :tempo # ma.tempo

    # === Antialiasing (aa.) ===
    AA_TANH1    = :aa_tanh1    # aa.tanh1
    AA_TANH2    = :aa_tanh2    # aa.tanh2
    AA_ARCTAN   = :aa_arctan   # aa.arctan
    AA_SOFTCLIP = :aa_softclip # aa.softclip
    AA_HARDCLIP = :aa_hardclip # aa.hardclip
    AA_PARABOLIC = :aa_parabolic # aa.parabolic
    AA_SIN      = :aa_sin      # aa.sin
    AA_CUBIC1   = :aa_cubic1   # aa.cubic1
    AA_CUBIC2   = :aa_cubic2   # aa.cubic2

    # === Metadata ===
    DECLARE = :declare
  end
end
