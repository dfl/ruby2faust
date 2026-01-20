# frozen_string_literal: true

require_relative "ir"

module Ruby2Faust
  # DSP wrapper class for building graphs with method chaining.
  class DSP
    attr_reader :node

    def initialize(node)
      @node = node
    end

    # Sequential composition (Faust :)
    def then(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::SEQ, inputs: [node, other.node], channels: other.node.channels))
    end
    alias >> then

    # Parallel composition (Faust ,)
    def par(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::PAR, inputs: [node, other.node], channels: node.channels + other.node.channels))
    end
    alias | par

    # Fan-out / split (Faust <:)
    def split(*others)
      others = others.map { |o| DSL.to_dsp(o) }
      total_channels = others.sum { |o| o.node.channels }
      DSP.new(Node.new(type: NodeType::SPLIT, inputs: [node] + others.map(&:node), channels: total_channels))
    end

    # Fan-in / merge (Faust :>)
    def merge(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::MERGE, inputs: [node, other.node], channels: other.node.channels))
    end

    # Feedback loop (Faust ~)
    def feedback(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::FEEDBACK, inputs: [node, other.node], channels: node.channels))
    end
    alias ~ feedback

    def channels
      node.channels
    end

    # Attach a Faust comment to this node
    # @param text [String] Comment text
    # @return [DSP] New DSP with comment wrapper
    def doc(text)
      DSP.new(Node.new(type: NodeType::DOC, args: [text], inputs: [node], channels: node.channels))
    end

    # Multiply / gain (Faust *)
    # @param other [Numeric, DSP, Symbol] 
    # @return [DSP]
    def *(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::MUL, inputs: [node, other.node]))
    end

    def to_s
      Emitter.emit(node)
    end

    def inspect
      "#<Ruby2Faust::DSP #{to_s}>"
    end

    # Add / mix signals (Faust +)
    # @param other [Numeric, DSP, Symbol]
    # @return [DSP]
    def +(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::ADD, inputs: [node, other.node]))
    end

    # Subtract signals (Faust -)
    # @param other [Numeric, DSP, Symbol]
    # @return [DSP]
    def -(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::SUB, inputs: [node, other.node]))
    end

    # Divide signals (Faust /)
    # @param other [Numeric, DSP, Symbol]
    # @return [DSP]
    def /(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::DIV, inputs: [node, other.node]))
    end

    # Negative of signal (Faust 0 - x)
    # @return [DSP]
    def neg
      DSP.new(Node.new(type: NodeType::NEG, inputs: [node]))
    end
    alias -@ neg

    # Modulo (Faust %)
    # @param other [Numeric, DSP]
    # @return [DSP]
    def %(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::MOD, inputs: [node, other.node]))
    end

    # Comparison operators - return DSP nodes for Faust comparisons
    # Note: These return DSP, not boolean, for signal processing

    # Less than (Faust <)
    def <(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::LT, inputs: [node, other.node]))
    end

    # Greater than (Faust >)
    def >(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::GT, inputs: [node, other.node]))
    end

    # Less than or equal (Faust <=)
    def <=(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::LE, inputs: [node, other.node]))
    end

    # Greater than or equal (Faust >=)
    def >=(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::GE, inputs: [node, other.node]))
    end

    # Equal (Faust ==) - named method since Ruby == must return boolean
    def eq(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::EQ, inputs: [node, other.node]))
    end

    # Not equal (Faust !=)
    def neq(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::NEQ, inputs: [node, other.node]))
    end

    # Bitwise AND (Faust &)
    def &(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::BAND, inputs: [node, other.node]))
    end

    # Bitwise XOR (Faust xor)
    def ^(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::XOR, inputs: [node, other.node]))
    end

    # Bitwise OR - use method name to avoid conflict with parallel composition
    def bor(other)
      other = DSL.to_dsp(other)
      DSP.new(Node.new(type: NodeType::BOR, inputs: [node, other.node]))
    end
  end

  # DSL module with comprehensive Faust library primitives.
  module DSL
    module_function

    def to_dsp(value)
      case value
      when DSP then value
      when Numeric then literal(value.to_s)
      when String then literal(value)
      when Symbol then literal(value.to_s)
      else raise ArgumentError, "Cannot convert #{value.class} to DSP"
      end
    end

    # =========================================================================
    # COMMENTS / DOCUMENTATION
    # =========================================================================

    # Line comment (appears on its own line in Faust output)
    # @param text [String] Comment text
    # @return [DSP] Comment node
    def doc(text)
      DSP.new(Node.new(type: NodeType::COMMENT, args: [text], channels: 0))
    end

    # =========================================================================
    # OSCILLATORS (os.)
    # =========================================================================

    def osc(freq = wire)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::OSC, inputs: [freq.node]))
    end

    def saw(freq = wire)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::SAW, inputs: [freq.node]))
    end

    def square(freq = wire)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::SQUARE, inputs: [freq.node]))
    end

    def triangle(freq = wire)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::TRIANGLE, inputs: [freq.node]))
    end

    def phasor(tablesize, freq)
      tablesize = to_dsp(tablesize)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::PHASOR, inputs: [tablesize.node, freq.node]))
    end

    def lf_saw(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::LF_SAW, inputs: [freq.node]))
    end

    def lf_triangle(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::LF_TRIANGLE, inputs: [freq.node]))
    end

    def lf_square(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::LF_SQUARE, inputs: [freq.node]))
    end

    def imptrain(freq = wire)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::IMPTRAIN, inputs: [freq.node]))
    end

    def pulsetrain(freq, duty)
      freq = to_dsp(freq)
      duty = to_dsp(duty)
      DSP.new(Node.new(type: NodeType::PULSETRAIN, inputs: [freq.node, duty.node]))
    end

    # =========================================================================
    # NOISE (no.)
    # =========================================================================

    def noise
      DSP.new(Node.new(type: NodeType::NOISE))
    end

    def pink_noise
      DSP.new(Node.new(type: NodeType::PINK_NOISE))
    end

    # =========================================================================
    # FILTERS (fi.)
    # =========================================================================

    def lp(freq = wire, order: 1)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::LP, args: [order], inputs: [freq.node]))
    end

    def hp(freq = wire, order: 1)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::HP, args: [order], inputs: [freq.node]))
    end

    def bp(freq = wire, q: 1)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::BP, inputs: [freq.node, q.node]))
    end

    def resonlp(freq, q, gain = 1)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::RESONLP, inputs: [freq.node, q.node, gain.node]))
    end

    def resonhp(freq, q, gain = 1)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::RESONHP, inputs: [freq.node, q.node, gain.node]))
    end

    def resonbp(freq, q, gain = 1)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::RESONBP, inputs: [freq.node, q.node, gain.node]))
    end

    def allpass(maxdelay, delay, feedback)
      maxdelay = to_dsp(maxdelay)
      delay = to_dsp(delay)
      feedback = to_dsp(feedback)
      DSP.new(Node.new(type: NodeType::ALLPASS, inputs: [maxdelay.node, delay.node, feedback.node]))
    end

    def dcblock
      DSP.new(Node.new(type: NodeType::DCBLOCK))
    end

    def peak_eq(freq, q, gain_db)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain_db = to_dsp(gain_db)
      DSP.new(Node.new(type: NodeType::PEAK_EQ, inputs: [freq.node, q.node, gain_db.node]))
    end

    # SVF (State Variable Filter) filters

    def svf_lp(freq, q)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::SVF_LP, inputs: [freq.node, q.node]))
    end

    def svf_hp(freq, q)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::SVF_HP, inputs: [freq.node, q.node]))
    end

    def svf_bp(freq, q)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::SVF_BP, inputs: [freq.node, q.node]))
    end

    def svf_notch(freq, q)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::SVF_NOTCH, inputs: [freq.node, q.node]))
    end

    def svf_ap(freq, q)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::SVF_AP, inputs: [freq.node, q.node]))
    end

    def svf_bell(freq, q, gain)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::SVF_BELL, inputs: [freq.node, q.node, gain.node]))
    end

    def svf_ls(freq, q, gain)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::SVF_LS, inputs: [freq.node, q.node, gain.node]))
    end

    def svf_hs(freq, q, gain)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::SVF_HS, inputs: [freq.node, q.node, gain.node]))
    end

    # Convenience alias for svf_ls (low shelf)
    def svfLowShelf(freq, q, gain = 1)
      svf_ls(freq, q, gain)
    end

    # Other filter types

    def lowpass3e(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::LOWPASS3E, inputs: [freq.node]))
    end

    def highpass3e(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::HIGHPASS3E, inputs: [freq.node]))
    end

    def lowpass6e(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::LOWPASS6E, inputs: [freq.node]))
    end

    def highpass6e(freq)
      freq = to_dsp(freq)
      DSP.new(Node.new(type: NodeType::HIGHPASS6E, inputs: [freq.node]))
    end

    def bandstop(order, freq, q)
      order = to_dsp(order)
      freq = to_dsp(freq)
      q = to_dsp(q)
      DSP.new(Node.new(type: NodeType::BANDSTOP, inputs: [order.node, freq.node, q.node]))
    end

    def notchw(freq, width)
      freq = to_dsp(freq)
      width = to_dsp(width)
      DSP.new(Node.new(type: NodeType::NOTCHW, inputs: [freq.node, width.node]))
    end

    def low_shelf(freq, q, gain)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::LOW_SHELF, inputs: [freq.node, q.node, gain.node]))
    end

    def high_shelf(freq, q, gain)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::HIGH_SHELF, inputs: [freq.node, q.node, gain.node]))
    end

    def peak_eq_cq(freq, q, gain)
      freq = to_dsp(freq)
      q = to_dsp(q)
      gain = to_dsp(gain)
      DSP.new(Node.new(type: NodeType::PEAK_EQ_CQ, inputs: [freq.node, q.node, gain.node]))
    end

    def fi_pole(p)
      p = to_dsp(p)
      DSP.new(Node.new(type: NodeType::FI_POLE, inputs: [p.node]))
    end

    def fi_zero(z)
      z = to_dsp(z)
      DSP.new(Node.new(type: NodeType::FI_ZERO, inputs: [z.node]))
    end

    def tf1(b0, b1, a1)
      b0 = to_dsp(b0)
      b1 = to_dsp(b1)
      a1 = to_dsp(a1)
      DSP.new(Node.new(type: NodeType::TF1, inputs: [b0.node, b1.node, a1.node]))
    end

    def tf2(b0, b1, b2, a1, a2)
      b0 = to_dsp(b0)
      b1 = to_dsp(b1)
      b2 = to_dsp(b2)
      a1 = to_dsp(a1)
      a2 = to_dsp(a2)
      DSP.new(Node.new(type: NodeType::TF2, inputs: [b0.node, b1.node, b2.node, a1.node, a2.node]))
    end

    def tf1s(b0, b1, a1)
      b0 = to_dsp(b0)
      b1 = to_dsp(b1)
      a1 = to_dsp(a1)
      DSP.new(Node.new(type: NodeType::TF1S, inputs: [b0.node, b1.node, a1.node]))
    end

    def tf2s(b0, b1, b2, a1, a2)
      b0 = to_dsp(b0)
      b1 = to_dsp(b1)
      b2 = to_dsp(b2)
      a1 = to_dsp(a1)
      a2 = to_dsp(a2)
      DSP.new(Node.new(type: NodeType::TF2S, inputs: [b0.node, b1.node, b2.node, a1.node, a2.node]))
    end

    def iir(bcoeffs, acoeffs)
      bcoeffs = to_dsp(bcoeffs)
      acoeffs = to_dsp(acoeffs)
      DSP.new(Node.new(type: NodeType::IIR, inputs: [bcoeffs.node, acoeffs.node]))
    end

    def fir(coeffs)
      coeffs = to_dsp(coeffs)
      DSP.new(Node.new(type: NodeType::FIR, inputs: [coeffs.node]))
    end

    def conv(impulse, size)
      impulse = to_dsp(impulse)
      size = to_dsp(size)
      DSP.new(Node.new(type: NodeType::CONV, inputs: [impulse.node, size.node]))
    end

    def fbcombfilter(maxdel, del, fb)
      maxdel = to_dsp(maxdel)
      del = to_dsp(del)
      fb = to_dsp(fb)
      DSP.new(Node.new(type: NodeType::FBCOMBFILTER, inputs: [maxdel.node, del.node, fb.node]))
    end

    def ffcombfilter(maxdel, del)
      maxdel = to_dsp(maxdel)
      del = to_dsp(del)
      DSP.new(Node.new(type: NodeType::FFCOMBFILTER, inputs: [maxdel.node, del.node]))
    end

    # =========================================================================
    # DELAYS (de.)
    # =========================================================================

    def delay(maxdelay, d)
      maxdelay = to_dsp(maxdelay)
      d = to_dsp(d)
      DSP.new(Node.new(type: NodeType::DELAY, inputs: [maxdelay.node, d.node]))
    end

    def fdelay(maxdelay, d)
      maxdelay = to_dsp(maxdelay)
      d = to_dsp(d)
      DSP.new(Node.new(type: NodeType::FDELAY, inputs: [maxdelay.node, d.node]))
    end

    def sdelay(maxdelay, interp, d)
      maxdelay = to_dsp(maxdelay)
      interp = to_dsp(interp)
      d = to_dsp(d)
      DSP.new(Node.new(type: NodeType::SDELAY, inputs: [maxdelay.node, interp.node, d.node]))
    end

    # =========================================================================
    # ENVELOPES (en.)
    # =========================================================================

    def ar(attack, release, gate)
      attack = to_dsp(attack)
      release = to_dsp(release)
      gate = to_dsp(gate)
      DSP.new(Node.new(type: NodeType::AR, inputs: [attack.node, release.node, gate.node]))
    end

    def asr(attack, sustain_level, release, gate)
      attack = to_dsp(attack)
      sustain_level = to_dsp(sustain_level)
      release = to_dsp(release)
      gate = to_dsp(gate)
      DSP.new(Node.new(type: NodeType::ASR, inputs: [attack.node, sustain_level.node, release.node, gate.node]))
    end

    def adsr(attack, decay, sustain, release, gate)
      attack = to_dsp(attack)
      decay = to_dsp(decay)
      sustain = to_dsp(sustain)
      release = to_dsp(release)
      gate = to_dsp(gate)
      DSP.new(Node.new(type: NodeType::ADSR, inputs: [attack.node, decay.node, sustain.node, release.node, gate.node]))
    end

    def adsre(attack, decay, sustain, release, gate)
      attack = to_dsp(attack)
      decay = to_dsp(decay)
      sustain = to_dsp(sustain)
      release = to_dsp(release)
      gate = to_dsp(gate)
      DSP.new(Node.new(type: NodeType::ADSRE, inputs: [attack.node, decay.node, sustain.node, release.node, gate.node]))
    end

    # =========================================================================
    # MATH (primitives + ma.)
    # =========================================================================

    def gain(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::GAIN, inputs: [x.node]))
    end

    def add
      DSP.new(Node.new(type: NodeType::ADD))
    end

    def mul
      DSP.new(Node.new(type: NodeType::MUL))
    end

    def sub
      DSP.new(Node.new(type: NodeType::SUB))
    end

    def div
      DSP.new(Node.new(type: NodeType::DIV))
    end

    def neg
      DSP.new(Node.new(type: NodeType::NEG))
    end

    def abs_
      DSP.new(Node.new(type: NodeType::ABS))
    end

    def min_(a, b)
      a = to_dsp(a)
      b = to_dsp(b)
      DSP.new(Node.new(type: NodeType::MIN, inputs: [a.node, b.node]))
    end

    def max_(a, b)
      a = to_dsp(a)
      b = to_dsp(b)
      DSP.new(Node.new(type: NodeType::MAX, inputs: [a.node, b.node]))
    end

    def clip(min_val, max_val)
      min_val = to_dsp(min_val)
      max_val = to_dsp(max_val)
      DSP.new(Node.new(type: NodeType::CLIP, inputs: [min_val.node, max_val.node]))
    end

    def pow(base, exponent)
      base = to_dsp(base)
      exponent = to_dsp(exponent)
      DSP.new(Node.new(type: NodeType::POW, inputs: [base.node, exponent.node]))
    end

    def sqrt_
      DSP.new(Node.new(type: NodeType::SQRT))
    end

    def exp_
      DSP.new(Node.new(type: NodeType::EXP))
    end

    def log_
      DSP.new(Node.new(type: NodeType::LOG))
    end

    def log10_
      DSP.new(Node.new(type: NodeType::LOG10))
    end

    def sin_
      DSP.new(Node.new(type: NodeType::SIN))
    end

    def cos_
      DSP.new(Node.new(type: NodeType::COS))
    end

    def tan_
      DSP.new(Node.new(type: NodeType::TAN))
    end

    def tanh_
      DSP.new(Node.new(type: NodeType::TANH))
    end

    def sinh_
      DSP.new(Node.new(type: NodeType::SINH))
    end

    def cosh_
      DSP.new(Node.new(type: NodeType::COSH))
    end

    def asinh_
      DSP.new(Node.new(type: NodeType::ASINH))
    end

    def acosh_
      DSP.new(Node.new(type: NodeType::ACOSH))
    end

    def atanh_
      DSP.new(Node.new(type: NodeType::ATANH))
    end

    def asin_
      DSP.new(Node.new(type: NodeType::ASIN))
    end

    def acos_
      DSP.new(Node.new(type: NodeType::ACOS))
    end

    def atan_
      DSP.new(Node.new(type: NodeType::ATAN))
    end

    def atan2(y, x)
      y = to_dsp(y)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::ATAN2, inputs: [y.node, x.node]))
    end

    def floor_
      DSP.new(Node.new(type: NodeType::FLOOR))
    end

    def ceil_
      DSP.new(Node.new(type: NodeType::CEIL))
    end

    def rint_
      DSP.new(Node.new(type: NodeType::RINT))
    end

    def fmod(x, y)
      x = to_dsp(x)
      y = to_dsp(y)
      DSP.new(Node.new(type: NodeType::FMOD, inputs: [x.node, y.node]))
    end

    def int_
      DSP.new(Node.new(type: NodeType::INT))
    end

    def float_
      DSP.new(Node.new(type: NodeType::FLOAT))
    end

    # =========================================================================
    # CONVERSION (ba.)
    # =========================================================================

    def db2linear(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::DB2LINEAR, inputs: [x.node]))
    end

    def linear2db(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::LINEAR2DB, inputs: [x.node]))
    end

    def samp2sec(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::SAMP2SEC, inputs: [x.node]))
    end

    def sec2samp(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::SEC2SAMP, inputs: [x.node]))
    end

    def midi2hz(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::MIDI2HZ, inputs: [x.node]))
    end

    def hz2midi(x)
      x = to_dsp(x)
      DSP.new(Node.new(type: NodeType::HZ2MIDI, inputs: [x.node]))
    end

    def tau2pole(tau)
      tau = to_dsp(tau)
      DSP.new(Node.new(type: NodeType::TAU2POLE, inputs: [tau.node]))
    end

    def pole2tau(pole)
      pole = to_dsp(pole)
      DSP.new(Node.new(type: NodeType::POLE2TAU, inputs: [pole.node]))
    end

    def ba_if(cond, then_val, else_val)
      cond = to_dsp(cond)
      then_val = to_dsp(then_val)
      else_val = to_dsp(else_val)
      DSP.new(Node.new(type: NodeType::BA_IF, inputs: [cond.node, then_val.node, else_val.node]))
    end

    def selector(n, sel, *inputs)
      sel = to_dsp(sel)
      inputs = inputs.map { |i| to_dsp(i) }
      DSP.new(Node.new(type: NodeType::SELECTOR, args: [n], inputs: [sel.node] + inputs.map(&:node)))
    end

    def ba_take(idx, tuple)
      idx = to_dsp(idx)
      tuple = to_dsp(tuple)
      DSP.new(Node.new(type: NodeType::BA_TAKE, inputs: [idx.node, tuple.node]))
    end

    # =========================================================================
    # SMOOTHING (si.)
    # =========================================================================

    def smooth(tau)
      tau = to_dsp(tau)
      DSP.new(Node.new(type: NodeType::SMOOTH, inputs: [tau.node]))
    end

    def smoo
      DSP.new(Node.new(type: NodeType::SMOO))
    end

    # =========================================================================
    # SELECTORS
    # =========================================================================

    def select2(condition, a, b)
      condition = to_dsp(condition)
      a = to_dsp(a)
      b = to_dsp(b)
      DSP.new(Node.new(type: NodeType::SELECT2, inputs: [condition.node, a.node, b.node], channels: a.node.channels))
    end

    def selectn(n, index, *signals)
      index = to_dsp(index)
      signals = signals.map { |s| to_dsp(s) }
      DSP.new(Node.new(type: NodeType::SELECTN, args: [n], inputs: [index.node] + signals.map(&:node), channels: signals.first&.node&.channels || 1))
    end

    # =========================================================================
    # ROUTING (si./ro.)
    # =========================================================================

    def bus(n)
      DSP.new(Node.new(type: NodeType::BUS, args: [n], channels: n))
    end

    def block(n)
      DSP.new(Node.new(type: NodeType::BLOCK, args: [n], channels: 0))
    end

    # =========================================================================
    # REVERBS (re.)
    # =========================================================================

    def freeverb(fb1, fb2, damp, spread)
      fb1 = to_dsp(fb1)
      fb2 = to_dsp(fb2)
      damp = to_dsp(damp)
      spread = to_dsp(spread)
      DSP.new(Node.new(type: NodeType::FREEVERB, inputs: [fb1.node, fb2.node, damp.node, spread.node]))
    end

    def zita_rev(rdel, f1, f2, t60dc, t60m, fsmax)
      DSP.new(Node.new(type: NodeType::ZITA_REV, args: [rdel, f1, f2, t60dc, t60m, fsmax], channels: 2))
    end

    def jpverb(t60, damp, size, early_diff, mod_depth, mod_freq, low, mid, high, low_cut, high_cut)
      DSP.new(Node.new(type: NodeType::JPVERB, args: [t60, damp, size, early_diff, mod_depth, mod_freq, low, mid, high, low_cut, high_cut], channels: 2))
    end

    # =========================================================================
    # COMPRESSORS (co.)
    # =========================================================================

    def compressor(ratio, thresh, attack, release)
      ratio = to_dsp(ratio)
      thresh = to_dsp(thresh)
      attack = to_dsp(attack)
      release = to_dsp(release)
      DSP.new(Node.new(type: NodeType::COMPRESSOR, inputs: [ratio.node, thresh.node, attack.node, release.node]))
    end

    def limiter
      DSP.new(Node.new(type: NodeType::LIMITER))
    end

    # =========================================================================
    # SPATIAL (sp.)
    # =========================================================================

    def panner(pan)
      pan = to_dsp(pan)
      DSP.new(Node.new(type: NodeType::PANNER, inputs: [pan.node], channels: 2))
    end

    # =========================================================================
    # UI CONTROLS
    # =========================================================================

    # Build Faust metadata string from kwargs
    def self.build_metadata(name, order: nil, style: nil, unit: nil, tooltip: nil, scale: nil, **_)
      meta = ""
      meta += "[#{order}]" if order
      meta += "[style:#{style}]" if style
      meta += "[unit:#{unit}]" if unit
      meta += "[tooltip:#{tooltip}]" if tooltip
      meta += "[scale:#{scale}]" if scale
      # If name already has metadata, append; otherwise prefix
      name.to_s.include?("[") ? name.to_s : "#{meta}#{name}"
    end

    def slider(name, init:, min:, max:, step: 0.01, **meta)
      full_name = DSL.build_metadata(name, **meta)
      DSP.new(Node.new(type: NodeType::SLIDER, args: [full_name, init, min, max, step]))
    end

    def vslider(name, init:, min:, max:, step: 0.01)
      DSP.new(Node.new(type: NodeType::VSLIDER, args: [name, init, min, max, step]))
    end

    def nentry(name, init:, min:, max:, step: 1)
      DSP.new(Node.new(type: NodeType::NENTRY, args: [name, init, min, max, step]))
    end

    def button(name)
      DSP.new(Node.new(type: NodeType::BUTTON, args: [name]))
    end

    def checkbox(name)
      DSP.new(Node.new(type: NodeType::CHECKBOX, args: [name]))
    end

    def hgroup(name, content = nil, &block)
      content = block.call if block_given?
      raise ArgumentError, "hgroup requires content or a block" if content.nil?
      content = to_dsp(content)
      DSP.new(Node.new(type: NodeType::HGROUP, args: [name], inputs: [content.node], channels: content.node.channels))
    end

    def vgroup(name, content = nil, &block)
      content = block.call if block_given?
      raise ArgumentError, "vgroup requires content or a block" if content.nil?
      content = to_dsp(content)
      DSP.new(Node.new(type: NodeType::VGROUP, args: [name], inputs: [content.node], channels: content.node.channels))
    end

    def tgroup(name, content = nil, &block)
      content = block.call if block_given?
      raise ArgumentError, "tgroup requires content or a block" if content.nil?
      content = to_dsp(content)
      DSP.new(Node.new(type: NodeType::TGROUP, args: [name], inputs: [content.node], channels: content.node.channels))
    end

    # =========================================================================
    # ITERATION
    # =========================================================================

    # Parallel iteration: par(i, n, expr)
    # @param count [Integer] Number of iterations
    # @yield [DSP] Block receiving iteration index as DSP param
    # @example fpar(4) { |i| osc(i * 100) }
    # @example fpar(4) { osc(it * 100) }  # Ruby 3.4+ implicit it
    # @return [DSP]
    def fpar(count, &block)
      raise ArgumentError, "fpar requires a block" unless block_given?
      var = block.parameters.first&.last || :it
      DSP.new(Node.new(type: NodeType::FPAR, args: [var, count, block], channels: count))
    end

    # Sequential iteration: seq(i, n, expr)
    # @param count [Integer] Number of iterations
    # @yield [DSP] Block receiving iteration index as DSP param
    # @return [DSP]
    def fseq(count, &block)
      raise ArgumentError, "fseq requires a block" unless block_given?
      var = block.parameters.first&.last || :it
      DSP.new(Node.new(type: NodeType::FSEQ, args: [var, count, block]))
    end

    # Summation iteration: sum(i, n, expr)
    # @param count [Integer] Number of iterations
    # @yield [DSP] Block receiving iteration index as DSP param
    # @return [DSP]
    def fsum(count, &block)
      raise ArgumentError, "fsum requires a block" unless block_given?
      var = block.parameters.first&.last || :it
      DSP.new(Node.new(type: NodeType::FSUM, args: [var, count, block]))
    end

    # Product iteration: prod(i, n, expr)
    # @param count [Integer] Number of iterations
    # @yield [DSP] Block receiving iteration index as DSP param
    # @return [DSP]
    def fprod(count, &block)
      raise ArgumentError, "fprod requires a block" unless block_given?
      var = block.parameters.first&.last || :it
      DSP.new(Node.new(type: NodeType::FPROD, args: [var, count, block]))
    end

    # =========================================================================
    # LAMBDA
    # =========================================================================

    # Lambda expression: \(x).(body)
    # @param params [Array<Symbol>] Parameter names
    # @yield Block that receives parameters and returns body expression
    # @return [DSP]
    def flambda(*params, &block)
      raise ArgumentError, "flambda requires a block" unless block_given?
      DSP.new(Node.new(type: NodeType::LAMBDA, args: [params, block]))
    end

    # Parameter reference within a lambda
    # @param name [Symbol] Parameter name
    # @return [DSP]
    def param(name)
      DSP.new(Node.new(type: NodeType::PARAM, args: [name]))
    end

    # =========================================================================
    # TABLES
    # =========================================================================

    # Read-only table: rdtable(n, init, ridx)
    # @param size [Integer, DSP] Table size
    # @param init [DSP] Initialization signal
    # @param ridx [DSP] Read index
    # @return [DSP]
    def rdtable(size, init, ridx)
      size = to_dsp(size)
      init = to_dsp(init)
      ridx = to_dsp(ridx)
      DSP.new(Node.new(type: NodeType::RDTABLE, inputs: [size.node, init.node, ridx.node]))
    end

    # Read/write table: rwtable(n, init, widx, wsig, ridx)
    # @param size [Integer, DSP] Table size
    # @param init [DSP] Initialization signal
    # @param widx [DSP] Write index
    # @param wsig [DSP] Write signal
    # @param ridx [DSP] Read index
    # @return [DSP]
    def rwtable(size, init, widx, wsig, ridx)
      size = to_dsp(size)
      init = to_dsp(init)
      widx = to_dsp(widx)
      wsig = to_dsp(wsig)
      ridx = to_dsp(ridx)
      DSP.new(Node.new(type: NodeType::RWTABLE, inputs: [size.node, init.node, widx.node, wsig.node, ridx.node]))
    end

    # Waveform constant table: waveform{v1, v2, ...}
    # @param values [Array<Numeric>] Table values
    # @return [DSP]
    def waveform(*values)
      DSP.new(Node.new(type: NodeType::WAVEFORM, args: values))
    end

    # =========================================================================
    # ADDITIONAL ROUTING
    # =========================================================================

    # Route signals: route(ins, outs, connections)
    # @param ins [Integer] Number of inputs
    # @param outs [Integer] Number of outputs
    # @param connections [Array<Array<Integer>>] Connection pairs [[from, to], ...]
    # @return [DSP]
    def route(ins, outs, connections)
      DSP.new(Node.new(type: NodeType::ROUTE, args: [ins, outs, connections], channels: outs))
    end

    # 3-way selector: select3(sel, a, b, c)
    # @param sel [DSP] Selector (0, 1, or 2)
    # @param a [DSP] First signal
    # @param b [DSP] Second signal
    # @param c [DSP] Third signal
    # @return [DSP]
    def select3(sel, a, b, c)
      sel = to_dsp(sel)
      a = to_dsp(a)
      b = to_dsp(b)
      c = to_dsp(c)
      DSP.new(Node.new(type: NodeType::SELECT3, inputs: [sel.node, a.node, b.node, c.node], channels: a.node.channels))
    end

    # =========================================================================
    # UTILITY
    # =========================================================================

    def wire
      DSP.new(Node.new(type: NodeType::WIRE))
    end

    def cut
      DSP.new(Node.new(type: NodeType::CUT, channels: 0))
    end

    def mem
      DSP.new(Node.new(type: NodeType::MEM))
    end

    def literal(expr, channels: 1)
      DSP.new(Node.new(type: NodeType::LITERAL, args: [expr], channels: channels))
    end

    # Wrap a numeric value as a DSP node (constant signal)
    # Useful when composing with >> which would otherwise be Ruby's bit-shift
    def num(value)
      DSP.new(Node.new(type: NodeType::LITERAL, args: [value.to_s]))
    end

    # =========================================================================
    # CONSTANTS
    # =========================================================================

    def sr
      DSP.new(Node.new(type: NodeType::SR))
    end

    def pi
      DSP.new(Node.new(type: NodeType::PI))
    end

    def tempo
      DSP.new(Node.new(type: NodeType::TEMPO))
    end

    # =========================================================================
    # ANTIALIASING (aa.)
    # =========================================================================

    def aa_tanh1
      DSP.new(Node.new(type: NodeType::AA_TANH1))
    end

    def aa_tanh2
      DSP.new(Node.new(type: NodeType::AA_TANH2))
    end

    def aa_arctan
      DSP.new(Node.new(type: NodeType::AA_ARCTAN))
    end

    def aa_softclip
      DSP.new(Node.new(type: NodeType::AA_SOFTCLIP))
    end

    def aa_hardclip
      DSP.new(Node.new(type: NodeType::AA_HARDCLIP))
    end

    def aa_parabolic
      DSP.new(Node.new(type: NodeType::AA_PARABOLIC))
    end

    def aa_sin
      DSP.new(Node.new(type: NodeType::AA_SIN))
    end

    def aa_cubic1
      DSP.new(Node.new(type: NodeType::AA_CUBIC1))
    end

    def aa_cubic2
      DSP.new(Node.new(type: NodeType::AA_CUBIC2))
    end

    # Analyzers (an.)
    def amp_follower(t)
      DSP.new(Node.new(type: NodeType::AMP_FOLLOWER, args: [t]))
    end

    def amp_follower_ar(attack, release)
      DSP.new(Node.new(type: NodeType::AMP_FOLLOWER_AR, args: [attack, release]))
    end

    def amp_follower_ud(up, down)
      DSP.new(Node.new(type: NodeType::AMP_FOLLOWER_UD, args: [up, down]))
    end

    def rms_envelope_rect(period)
      DSP.new(Node.new(type: NodeType::RMS_ENVELOPE_RECT, args: [period]))
    end

    def rms_envelope_tau(tau)
      DSP.new(Node.new(type: NodeType::RMS_ENVELOPE_TAU, args: [tau]))
    end

    def abs_envelope_rect(period)
      DSP.new(Node.new(type: NodeType::ABS_ENVELOPE_RECT, args: [period]))
    end

    def abs_envelope_tau(tau)
      DSP.new(Node.new(type: NodeType::ABS_ENVELOPE_TAU, args: [tau]))
    end

    def ms_envelope_rect(period)
      DSP.new(Node.new(type: NodeType::MS_ENVELOPE_RECT, args: [period]))
    end

    def ms_envelope_tau(tau)
      DSP.new(Node.new(type: NodeType::MS_ENVELOPE_TAU, args: [tau]))
    end

    def peak_envelope(t)
      DSP.new(Node.new(type: NodeType::PEAK_ENVELOPE, args: [t]))
    end

    # Effects (ef.)
    def cubicnl(drive, offset)
      DSP.new(Node.new(type: NodeType::CUBICNL, args: [drive, offset]))
    end

    def gate_mono(thresh, attack, hold, release)
      DSP.new(Node.new(type: NodeType::GATE_MONO, args: [thresh, attack, hold, release]))
    end

    def gate_stereo(thresh, attack, hold, release)
      DSP.new(Node.new(type: NodeType::GATE_STEREO, args: [thresh, attack, hold, release], channels: 2))
    end

    def ef_compressor_mono(ratio, thresh, attack, release)
      DSP.new(Node.new(type: NodeType::EF_COMPRESSOR_MONO, args: [ratio, thresh, attack, release]))
    end

    def ef_compressor_stereo(ratio, thresh, attack, release)
      DSP.new(Node.new(type: NodeType::EF_COMPRESSOR_STEREO, args: [ratio, thresh, attack, release], channels: 2))
    end

    def ef_limiter_1176_mono
      DSP.new(Node.new(type: NodeType::EF_LIMITER_1176_MONO))
    end

    def ef_limiter_1176_stereo
      DSP.new(Node.new(type: NodeType::EF_LIMITER_1176_STEREO, channels: 2))
    end

    def echo(maxdel, del, fb)
      DSP.new(Node.new(type: NodeType::ECHO, args: [maxdel, del, fb]))
    end

    def transpose(w, x, s)
      DSP.new(Node.new(type: NodeType::TRANSPOSE, args: [w, x, s]))
    end

    def flanger_mono(dmax, delay_freq, level, feedback, invert)
      DSP.new(Node.new(type: NodeType::FLANGER_MONO, args: [dmax, delay_freq, level, feedback, invert]))
    end

    def flanger_stereo(dmax, delay_freq, level, feedback, invert, lfsr, lfsf)
      DSP.new(Node.new(type: NodeType::FLANGER_STEREO, args: [dmax, delay_freq, level, feedback, invert, lfsr, lfsf], channels: 2))
    end

    def phaser2_mono(nstages, freq, speed, depth, feedback, spread)
      DSP.new(Node.new(type: NodeType::PHASER2_MONO, args: [nstages, freq, speed, depth, feedback, spread]))
    end

    def phaser2_stereo(nstages, freq, speed, depth, feedback, spread)
      DSP.new(Node.new(type: NodeType::PHASER2_STEREO, args: [nstages, freq, speed, depth, feedback, spread], channels: 2))
    end

    def wah4(fr)
      DSP.new(Node.new(type: NodeType::WAH4, args: [fr]))
    end

    def auto_wah(level)
      DSP.new(Node.new(type: NodeType::AUTO_WAH, args: [level]))
    end

    def crybaby(wah)
      DSP.new(Node.new(type: NodeType::CRYBABY, args: [wah]))
    end

    def vocoder(bands, range)
      DSP.new(Node.new(type: NodeType::VOCODER, args: [bands, range]))
    end

    def speakerbp(flo, fhi)
      DSP.new(Node.new(type: NodeType::SPEAKERBP, args: [flo, fhi]))
    end

    def dry_wet_mixer(mix)
      DSP.new(Node.new(type: NodeType::DRY_WET_MIXER, args: [mix]))
    end

    def dry_wet_mixer_cp(mix)
      DSP.new(Node.new(type: NodeType::DRY_WET_MIXER_CP, args: [mix]))
    end

    # Constant aliases for those who prefer the capitalized look
    SR    = DSP.new(Node.new(type: NodeType::SR))
    PI    = DSP.new(Node.new(type: NodeType::PI))
    TEMPO = DSP.new(Node.new(type: NodeType::TEMPO))
  end

  # Program-level metadata for Faust declarations
  class Program
    attr_reader :process, :declarations, :imports

    def initialize(process = nil, &block)
      @declarations = {}
      @imports = ["stdfaust.lib"]
      if block_given?
        extend DSL
        @process = instance_eval(&block)
      else
        @process = process
      end
    end

    def declare(key, value)
      @declarations[key] = value
      self
    end

    def import(lib)
      @imports << lib unless @imports.include?(lib)
      self
    end
  end
end

# Numeric extensions for audio conversions
# These return DSP nodes that can be used in signal chains
class Numeric
  # MIDI note number to Hz
  # 60.midi => ba.midikey2hz(60)
  def midi
    Ruby2Faust::DSL.midi2hz(self)
  end

  # dB to linear gain
  # -6.db => ba.db2linear(-6)
  def db
    Ruby2Faust::DSL.db2linear(self)
  end

  # Seconds to samples
  # 0.1.sec => ba.sec2samp(0.1)
  def sec
    Ruby2Faust::DSL.sec2samp(self)
  end

  # Milliseconds to samples
  # 100.ms => ba.sec2samp(0.1)
  def ms
    Ruby2Faust::DSL.sec2samp(self / 1000.0)
  end

  # Hz (pass-through for clarity)
  # 440.hz => 440
  def hz
    Ruby2Faust::DSL.literal(self.to_s)
  end
end
