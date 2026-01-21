# ruby2faust

A Ruby DSL that generates Faust DSP code. Ruby describes the graph; Faust compiles and runs it.

## Quick Start

```ruby
require 'ruby2faust'

# Idiomatic Ruby style
code = Ruby2Faust.generate do
  # Use numeric extensions: .midi, .hz, .db
  freq = 60.midi >> smoo
  
  # Arithmetic operators for signal mixing
  (osc(freq) + noise) * -6.db
end

puts code
```

Output:
```faust
import("stdfaust.lib");

process = ((os.osc(ba.midikey2hz(60)) + no.noise) * ba.db2linear(-6));
```

## Composition

Ruby2Faust maps Faust's composition operators to Ruby methods and operators:

```ruby
# Sequential: signal flows through a chain
osc(440) >> lp(800) >> gain(0.3)      

# Arithmetic operators (Infix) - work with numeric on either side
osc(440) + noise                        # Mix / Sum
osc(440) * 0.3                          # Gain
0.3 * osc(440)                          # Gain (numeric on left)
osc(440) - osc(442)                     # Subtraction
-osc(440)                               # Negate

# Parallel: signals run side by side
osc(440) | osc(442)                     # Stereo

# Split (fan-out)
osc(440).split(gain(0.5) | gain(0.3))

# Feedback loop
wire ~ (delay(44100, 22050) * 0.5)
```

| Faust | Meaning | Ruby | Method |
|-------|---------|-----------|--------|
| `:` | Sequential | `>>` | `.then` |
| `+` | Add / Mix | `+` | n/a |
| `-` | Subtract | `-` | n/a |
| `*(x)` | Gain | `* x` | `gain(x)` |
| `,` | Parallel | `\|` | `.par` |
| `<:` | Fan-out | n/a | `.split` |
| `:>` | Fan-in | n/a | `.merge` |
| `~` | Feedback | `~` | `.feedback` |

## Ruby-isms

### Numeric Extensions
Convenient conversions for common audio units:
```ruby
60.midi   # ba.midikey2hz(60)
-6.db     # ba.db2linear(-6)
0.1.sec   # ba.sec2samp(0.1)
10.ms     # ba.sec2samp(0.01)
440.hz    # 440
```

### Block UI Groups
```ruby
hgroup("Master") {
  vgroup("Osc") { osc(freq) } | 
  vgroup("FX") { reverb }
}
```

## DSL Reference

### Oscillators (os.)
```ruby
osc(freq)       # Sine wave
saw(freq)       # Sawtooth
square(freq)    # Square wave
triangle(freq)  # Triangle wave
lf_saw(freq)    # Low-freq sawtooth (0-1)
imptrain(freq)  # Impulse train
phasor(n, freq) # Table phasor
```

### Noise (no.)
```ruby
noise       # White noise
pink_noise  # Pink noise
```

### Filters (fi.)
```ruby
lp(freq, order: 1)       # Lowpass
hp(freq, order: 1)       # Highpass
bp(freq, q: 1)           # Bandpass
resonlp(freq, q, gain)   # Resonant lowpass
resonhp(freq, q, gain)   # Resonant highpass
allpass(max, d, fb)      # Allpass comb
dcblock                  # DC blocker
peak_eq(freq, q, db)     # Parametric EQ
```

### Delays (de.)
```ruby
delay(max, samples)      # Integer delay
fdelay(max, samples)     # Fractional delay
sdelay(max, interp, d)   # Smooth delay
```

### Envelopes (en.)
```ruby
ar(attack, release, gate)
asr(attack, sustain, release, gate)
adsr(attack, decay, sustain, release, gate)
adsre(attack, decay, sustain, release, gate)  # Exponential
```

### Math
```ruby
gain(x)     # Multiply
add         # Sum (+)
mul         # Multiply (*)
sub         # Subtract (-)
div         # Divide (/)
abs_        # Absolute value
min_(a, b)  # Minimum
max_(a, b)  # Maximum
clip(min, max)  # Clamp
pow(base, exp)
sqrt_, exp_, log_, log10_
sin_, cos_, tan_, tanh_
floor_, ceil_, rint_
```

### Conversion (ba.)
```ruby
db2linear(x)   # dB to linear
linear2db(x)   # Linear to dB
midi2hz(x)     # MIDI note to Hz
hz2midi(x)     # Hz to MIDI note
samp2sec(x)    # Samples to seconds
sec2samp(x)    # Seconds to samples
```

### Smoothing (si.)
```ruby
smooth(tau)    # Smooth with time constant
smoo           # Default 5ms smooth
```

### Selectors
```ruby
select2(cond, a, b)          # 2-way select
select3(sel, a, b, c)        # 3-way select
selectn(n, index, *signals)  # N-way select
```

### Iteration
Ruby blocks map to Faust's iteration constructs:
```ruby
fpar(4) { |i| osc((i + 1) * 100) }    # par(i, 4, osc((i+1)*100)) - 4 parallel oscillators
fseq(3) { |i| lp(1000 * (i + 1)) }    # seq(i, 3, fi.lowpass(1, 1000*(i+1))) - cascaded filters
fsum(4) { |i| osc((i + 1) * 100) }    # sum(i, 4, osc((i+1)*100)) - sum of 4 oscillators
fprod(3) { |i| osc((i + 1) * 100) }   # prod(i, 3, osc((i+1)*100)) - ring modulation

# Ruby 3.4+ implicit 'it' parameter also works:
fpar(4) { osc((it + 1) * 100) }       # par(it, 4, osc((it+1)*100))
```

### Lambda
```ruby
flambda(:x) { |x| x * 2 }    # \(x).(x * 2)
```

### Tables
```ruby
waveform(0, 0.5, 1, 0.5)              # waveform{0, 0.5, 1, 0.5}
rdtable(size, init, ridx)             # Read-only table
rwtable(size, init, widx, wsig, ridx) # Read/write table
```

### Routing (si./ro.)
```ruby
bus(n)                           # N parallel wires
block(n)                         # Terminate N signals
route(ins, outs, [[1,2],[2,1]])  # Signal routing matrix
```

### Reverbs (re.)
```ruby
freeverb(fb1, fb2, damp, spread)
zita_rev(rdel, f1, f2, t60dc, t60m, fsmax)
jpverb(t60, damp, size, ...)
```

### Compressors (co.)
```ruby
compressor(ratio, thresh, attack, release)
limiter
```

### Spatial (sp.)
```ruby
panner(pan)  # Stereo panner (0-1)
```

### UI Controls
```ruby
slider("name", init:, min:, max:, step: 0.01)
vslider("name", init:, min:, max:, step: 0.01)
nentry("name", init:, min:, max:, step: 1)
button("name")
checkbox("name")
hgroup("name", content)
vgroup("name", content)
```

**Slider metadata kwargs:**
```ruby
slider("freq", init: 440, min: 20, max: 2000,
  style: :knob,     # [style:knob]
  unit: "Hz",       # [unit:Hz]
  tooltip: "Freq",  # [tooltip:Freq]
  order: 0,         # [0] (UI ordering)
  scale: :log       # [scale:log]
)
```

Or use inline Faust metadata:
```ruby
slider("[0]freq[style:knob][unit:Hz]", init: 440, min: 20, max: 2000)
```

### Comments / Documentation
```ruby
# Inline comment attached to a node
saw(freq).doc("Main oscillator")

```

### Constants
```ruby
sr, SR       # Sample rate (ma.SR)
pi, PI       # Pi (ma.PI)
tempo, TEMPO # BPM tempo (ma.tempo)
```

### Utility
```ruby
wire     # Pass-through (_)
cut      # Terminate (!)
mem      # 1-sample delay
literal("expr")  # Raw Faust expression
```

## Metadata & Emitter Options

```ruby
prog = Ruby2Faust::Program.new do
  declare :name, "MySynth"
  declare :author, "Me"
  import "analyzers.lib"
  
  osc(440) * 0.5
end

# Generate pretty-printed Faust with indentation and newlines
puts Ruby2Faust::Emitter.program(prog, pretty: true)

# The generate helper also supports pretty: true
puts Ruby2Faust.generate(pretty: true) do
  hgroup("Synth") { osc(440) + noise }
end
```

## Example: Subtractive Synth

```ruby
require 'ruby2faust'
include Ruby2Faust::DSL

gate = button("gate")
freq = slider("freq", init: 220, min: 20, max: 2000, style: :knob) >> smoo
cutoff = slider("cutoff", init: 1000, min: 100, max: 8000, style: :knob) >> smoo

env = adsr(0.01, 0.2, 0.6, 0.3, gate)

process = saw(freq) >> resonlp(cutoff, 4, 1) >> gain(env) >> panner(0.5)

prog = Ruby2Faust::Program.new(process)
  .declare(:name, "SubSynth")

puts Ruby2Faust::Emitter.program(prog)
```

## CLI

```bash
ruby2faust compile synth.rb           # Generate .dsp
ruby2faust compile -o out.dsp synth.rb
ruby2faust run synth.rb               # Compile + run Faust
```

## faust2ruby

The reverse converter is also included: convert Faust DSP code to Ruby DSL. See [faust2ruby.md](faust2ruby.md) for details.

```bash
faust2ruby input.dsp -o output.rb
```

## Live Reload

```ruby
if Ruby2Faust::Live.changed?(old_graph, new_graph)
  Ruby2Faust::Live.compile(new_graph, output: "synth.dsp")
end
```

## License

MIT
