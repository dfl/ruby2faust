# Ruby2Faust

A Ruby DSL that generates Faust DSP code. Ruby describes the graph; Faust compiles and runs it.

## Installation

```bash
gem install ruby2faust
```

Or add to your Gemfile:

```ruby
gem 'ruby2faust'
```

## Quick Start

```ruby
require 'ruby2faust'
include Ruby2Faust::DSL

# Build a simple synth
process = osc(440).then(gain(0.3))

# Generate Faust code
puts Ruby2Faust::Emitter.program(process)
```

Output:
```faust
import("stdfaust.lib");

process = (os.osc(440) : *(0.3));
```

## DSL Reference

### Oscillators
```ruby
osc(freq)      # Sine wave
saw(freq)      # Sawtooth
square(freq)   # Square wave
triangle(freq) # Triangle wave
noise          # White noise
```

### Filters
```ruby
lp(freq)              # Lowpass (1st order)
lp(freq, order: 4)    # Lowpass (4th order)
hp(freq)              # Highpass
bp(freq, q: 2)        # Bandpass
```

### Math
```ruby
gain(x)   # Multiply by x
add       # Sum inputs
mul       # Multiply inputs
```

### UI Controls
```ruby
slider("freq", init: 440, min: 20, max: 2000)
button("trigger")
checkbox("enable")
```

### Composition Operators

| Ruby        | Faust | Meaning    |
|-------------|-------|------------|
| `.then(b)`  | `:`   | Sequential |
| `.par(b)`   | `,`   | Parallel   |
| `.split(*bs)` | `<:` | Fan-out   |
| `.merge(b)` | `:>`  | Fan-in     |
| `.feedback(b)` | `~` | Feedback  |

Aliases: `>>` for `.then`, `|` for `.par`

### Examples

**Subtractive synth:**
```ruby
freq = slider("freq", init: 200, min: 50, max: 2000)
cutoff = slider("cutoff", init: 800, min: 100, max: 5000)
amp = slider("amp", init: 0.3, min: 0, max: 1)

saw(freq)
  .then(lp(cutoff))
  .then(gain(amp))
```

**Stereo output:**
```ruby
left = osc(440).then(gain(0.3))
right = osc(442).then(gain(0.3))
left.par(right)
```

**Feedback delay:**
```ruby
wire.feedback(
  gain(0.7).then(lp(2000))
)
```

**Mix parallel signals:**
```ruby
osc(440).par(noise.then(gain(0.1))).merge(add)
```

## CLI Usage

```bash
# Compile Ruby DSL to .dsp
ruby2faust compile synth.rb

# Compile with custom output
ruby2faust compile -o output.dsp synth.rb

# Compile and run Faust (requires faust in PATH)
ruby2faust run synth.rb
```

Example `synth.rb`:
```ruby
# synth.rb
freq = slider("freq", init: 440, min: 20, max: 2000)
osc(freq).then(gain(0.3))
```

## Architecture

```
Ruby DSL → IR (Graph AST) → Faust Emitter → .dsp → faust2wasm/faust2cpp
```

- Ruby builds an intermediate representation (IR)
- IR enables graph diffing for live reload
- Faust handles all DSP execution

## Live Reload

The gem includes support for hot-reloading DSP graphs:

```ruby
require 'ruby2faust'
include Ruby2Faust::DSL

old_graph = osc(440).then(gain(0.3))
new_graph = osc(880).then(gain(0.3))

if Ruby2Faust::Live.changed?(old_graph, new_graph)
  Ruby2Faust::Live.compile(new_graph, output: "synth.dsp")
end
```

## License

MIT
