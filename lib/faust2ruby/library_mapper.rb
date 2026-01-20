# frozen_string_literal: true

module Faust2Ruby
  # Maps Faust library function calls to Ruby2Faust NodeTypes and DSL methods.
  module LibraryMapper
    # Mapping from Faust function names to Ruby DSL info
    # Each entry: faust_name => { type: NodeType, dsl: method_name, args: arg_count }
    MAPPINGS = {
      # Oscillators (os.)
      "os.osc" => { dsl: :osc, args: 1 },
      "os.sawtooth" => { dsl: :saw, args: 1 },
      "os.square" => { dsl: :square, args: 1 },
      "os.triangle" => { dsl: :triangle, args: 1 },
      "os.phasor" => { dsl: :phasor, args: 2 },
      "os.lf_sawpos" => { dsl: :lf_saw, args: 1 },
      "os.lf_trianglepos" => { dsl: :lf_triangle, args: 1 },
      "os.lf_squarewavepos" => { dsl: :lf_square, args: 1 },
      "os.lf_imptrain" => { dsl: :imptrain, args: 1 },
      "os.lf_pulsetrain" => { dsl: :pulsetrain, args: 2 },

      # Noise (no.)
      "no.noise" => { dsl: :noise, args: 0 },
      "no.pink_noise" => { dsl: :pink_noise, args: 0 },

      # Filters (fi.)
      "fi.lowpass" => { dsl: :lp, args: 2, opts: { order: 0 } },
      "fi.highpass" => { dsl: :hp, args: 2, opts: { order: 0 } },
      "fi.bandpass" => { dsl: :bp, args: 3 },
      "fi.resonlp" => { dsl: :resonlp, args: 3 },
      "fi.resonhp" => { dsl: :resonhp, args: 3 },
      "fi.resonbp" => { dsl: :resonbp, args: 3 },
      "fi.allpass_comb" => { dsl: :allpass, args: 3 },
      "fi.dcblocker" => { dsl: :dcblock, args: 0 },
      "fi.peak_eq" => { dsl: :peak_eq, args: 3 },

      # Delays (de.)
      "de.delay" => { dsl: :delay, args: 2 },
      "de.fdelay" => { dsl: :fdelay, args: 2 },
      "de.sdelay" => { dsl: :sdelay, args: 3 },

      # Envelopes (en.)
      "en.ar" => { dsl: :ar, args: 3 },
      "en.asr" => { dsl: :asr, args: 4 },
      "en.adsr" => { dsl: :adsr, args: 5 },
      "en.adsre" => { dsl: :adsre, args: 5 },

      # Conversion (ba.)
      "ba.db2linear" => { dsl: :db2linear, args: 1 },
      "ba.linear2db" => { dsl: :linear2db, args: 1 },
      "ba.samp2sec" => { dsl: :samp2sec, args: 1 },
      "ba.sec2samp" => { dsl: :sec2samp, args: 1 },
      "ba.midikey2hz" => { dsl: :midi2hz, args: 1 },
      "ba.hz2midikey" => { dsl: :hz2midi, args: 1 },
      "ba.selectn" => { dsl: :selectn, args: :variadic },
      "ba.tau2pole" => { dsl: :tau2pole, args: 1 },
      "ba.pole2tau" => { dsl: :pole2tau, args: 1 },
      "ba.if" => { dsl: :ba_if, args: 3 },
      "ba.selector" => { dsl: :selector, args: 3 },
      "ba.selectmulti" => { dsl: :selectmulti, args: :variadic },
      "ba.count" => { dsl: :ba_count, args: :variadic },
      "ba.take" => { dsl: :ba_take, args: 2 },

      # Smoothing (si.)
      "si.smooth" => { dsl: :smooth, args: 1 },
      "si.smoo" => { dsl: :smoo, args: 0 },
      "si.bus" => { dsl: :bus, args: 1 },
      "si.block" => { dsl: :block, args: 1 },

      # Reverbs (re.)
      "re.mono_freeverb" => { dsl: :freeverb, args: 4 },
      "re.zita_rev1_stereo" => { dsl: :zita_rev, args: 6 },
      "re.jpverb" => { dsl: :jpverb, args: 11 },

      # Compressors (co.)
      "co.compressor_mono" => { dsl: :compressor, args: 4 },
      "co.limiter_1176_R4_mono" => { dsl: :limiter, args: 0 },

      # Spatial (sp.)
      "sp.panner" => { dsl: :panner, args: 1 },

      # Math (ma.)
      "ma.SR" => { dsl: :sr, args: 0 },
      "ma.PI" => { dsl: :pi, args: 0 },
      "ma.tempo" => { dsl: :tempo, args: 0 },
      "ma.tanh" => { dsl: :tanh_, args: 0 },
    }.freeze

    # Primitive functions that map directly to DSL
    PRIMITIVES = {
      # Math operators (used as functions)
      "abs" => { dsl: :abs_, args: 0 },
      "min" => { dsl: :min_, args: 2 },
      "max" => { dsl: :max_, args: 2 },
      "pow" => { dsl: :pow, args: 2 },
      "sqrt" => { dsl: :sqrt_, args: 0 },
      "exp" => { dsl: :exp_, args: 0 },
      "log" => { dsl: :log_, args: 0 },
      "log10" => { dsl: :log10_, args: 0 },
      "sin" => { dsl: :sin_, args: 0 },
      "cos" => { dsl: :cos_, args: 0 },
      "tan" => { dsl: :tan_, args: 0 },
      "asin" => { dsl: :asin_, args: 0 },
      "acos" => { dsl: :acos_, args: 0 },
      "atan" => { dsl: :atan_, args: 0 },
      "atan2" => { dsl: :atan2, args: 2 },
      "floor" => { dsl: :floor_, args: 0 },
      "ceil" => { dsl: :ceil_, args: 0 },
      "rint" => { dsl: :rint_, args: 0 },
      "fmod" => { dsl: :fmod, args: 2 },
      "int" => { dsl: :int_, args: 0 },
      "float" => { dsl: :float_, args: 0 },

      # Tables
      "rdtable" => { dsl: :rdtable, args: 3 },
      "rwtable" => { dsl: :rwtable, args: 5 },

      # Selectors
      "select2" => { dsl: :select2, args: 3 },
      "select3" => { dsl: :select3, args: 4 },

      # Primitives
      "mem" => { dsl: :mem, args: 0 },
    }.freeze

    # UI element types
    UI_ELEMENTS = {
      "hslider" => :slider,
      "vslider" => :vslider,
      "nentry" => :nentry,
      "button" => :button,
      "checkbox" => :checkbox,
    }.freeze

    UI_GROUPS = {
      "hgroup" => :hgroup,
      "vgroup" => :vgroup,
      "tgroup" => :tgroup,
    }.freeze

    module_function

    def lookup(name)
      MAPPINGS[name] || PRIMITIVES[name]
    end

    def ui_element?(name)
      UI_ELEMENTS.key?(name)
    end

    def ui_group?(name)
      UI_GROUPS.key?(name)
    end

    def ui_element_method(name)
      UI_ELEMENTS[name]
    end

    def ui_group_method(name)
      UI_GROUPS[name]
    end

    def known_function?(name)
      MAPPINGS.key?(name) || PRIMITIVES.key?(name)
    end
  end
end
