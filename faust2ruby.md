# faust2ruby

Convert Faust DSP code to Ruby DSL code compatible with ruby2faust.

## Installation

faust2ruby is included with the ruby2faust gem:

```bash
gem install ruby2faust
```

## Usage

### Command Line

```bash
# Convert a Faust file to Ruby
faust2ruby input.dsp -o output.rb

# Output only the process expression (no boilerplate)
faust2ruby -e input.dsp

# Read from stdin
echo 'process = os.osc(440) : *(0.5);' | faust2ruby -e
```

### Options

```
Usage: faust2ruby [options] <input.dsp>
  -o, --output FILE    Output Ruby file (default: stdout)
  -e, --expression     Output only process expression (no boilerplate)
  -v, --verbose        Verbose output (show parsing info)
  -t, --tokens         Show lexer tokens (debug mode)
  -a, --ast            Show AST (debug mode)
  --version            Show version
  -h, --help           Show help
```

### Ruby API

```ruby
require 'faust2ruby'

# Convert Faust to Ruby code
faust_code = 'process = os.osc(440) : *(0.5);'
ruby_code = Faust2Ruby.to_ruby(faust_code)
puts ruby_code

# Expression only
ruby_expr = Faust2Ruby.to_ruby(faust_code, expression_only: true)
# => "(osc(440) >> gain(0.5))"

# Parse to AST
program = Faust2Ruby.parse(faust_code)

# Tokenize
tokens = Faust2Ruby.tokenize(faust_code)
```

## Examples

### Simple Oscillator

**Input (Faust):**
```faust
process = os.osc(440) : *(0.5);
```

**Output (Ruby):**
```ruby
require 'ruby2faust'
include Ruby2Faust::DSL

process = (osc(440) >> gain(0.5))

puts Ruby2Faust::Emitter.program(process)
```

### Synthesizer with Controls

**Input (Faust):**
```faust
import("stdfaust.lib");
declare name "synth";

freq = hslider("freq", 440, 20, 20000, 1);
gain = hslider("gain", 0.5, 0, 1, 0.01);

process = os.osc(freq) : *(gain);
```

**Output (Ruby):**
```ruby
require 'ruby2faust'
include Ruby2Faust::DSL

# declare name "synth"

freq = slider("freq", init: 440, min: 20, max: 20000, step: 1)

gain = slider("gain", init: 0.5, min: 0, max: 1, step: 0.01)

process = (osc(freq) >> gain(gain))

puts Ruby2Faust::Emitter.program(process)
```

### Parallel Composition

**Input (Faust):**
```faust
process = os.osc(440) , os.osc(880);
```

**Output (Ruby):**
```ruby
(osc(440) | osc(880))
```

### Feedback Loop

**Input (Faust):**
```faust
process = _ ~ (de.delay(44100, 22050) : *(0.5));
```

**Output (Ruby):**
```ruby
(wire ~ (delay(44100, 22050) >> gain(0.5)))
```

### Iteration

**Input (Faust):**
```faust
process = par(i, 4, os.osc(i * 100));
```

**Output (Ruby):**
```ruby
fpar(:i, 4) { |i| osc((i * 100)) }
```

## Supported Faust Constructs

### Composition Operators

| Faust | Ruby |
|-------|------|
| `a : b` | `a >> b` |
| `a , b` | `a \| b` |
| `a <: b` | `a.split(b)` |
| `a :> b` | `a.merge(b)` |
| `a ~ b` | `a ~ b` |

### Arithmetic

| Faust | Ruby |
|-------|------|
| `a + b` | `a + b` |
| `a - b` | `a - b` |
| `a * b` | `a * b` |
| `a / b` | `a / b` |
| `a % b` | `a % b` |
| `*(x)` | `gain(x)` |

### Comparison

| Faust | Ruby |
|-------|------|
| `a < b` | `a < b` |
| `a > b` | `a > b` |
| `a <= b` | `a <= b` |
| `a >= b` | `a >= b` |
| `a == b` | `a.eq(b)` |
| `a != b` | `a.neq(b)` |

Note: `eq()` and `neq()` are methods because Ruby's `==` must return boolean.

### Bitwise

| Faust | Ruby |
|-------|------|
| `a & b` | `a & b` |
| `a \| b` (bitwise) | `a.bor(b)` |
| `xor(a, b)` | `a ^ b` |

Note: `bor()` is a method because `\|` is used for parallel composition in the DSL.

### Library Functions

| Faust | Ruby |
|-------|------|
| `os.osc(f)` | `osc(f)` |
| `os.sawtooth(f)` | `saw(f)` |
| `os.square(f)` | `square(f)` |
| `os.triangle(f)` | `triangle(f)` |
| `no.noise` | `noise` |
| `fi.lowpass(n, f)` | `lp(f, order: n)` |
| `fi.highpass(n, f)` | `hp(f, order: n)` |
| `fi.resonlp(f, q, g)` | `resonlp(f, q, g)` |
| `de.delay(m, d)` | `delay(m, d)` |
| `de.fdelay(m, d)` | `fdelay(m, d)` |
| `en.adsr(a,d,s,r,g)` | `adsr(a, d, s, r, g)` |
| `ba.db2linear(x)` | `db2linear(x)` |
| `si.smoo` | `smoo` |
| `sp.panner(p)` | `panner(p)` |

### UI Elements

| Faust | Ruby |
|-------|------|
| `hslider("n", i, mn, mx, s)` | `slider("n", init: i, min: mn, max: mx, step: s)` |
| `vslider(...)` | `vslider(...)` |
| `nentry(...)` | `nentry(...)` |
| `button("n")` | `button("n")` |
| `checkbox("n")` | `checkbox("n")` |
| `hgroup("n", e)` | `hgroup("n") { e }` |
| `vgroup("n", e)` | `vgroup("n") { e }` |

### Iteration

| Faust | Ruby |
|-------|------|
| `par(i, n, e)` | `fpar(:i, n) { \|i\| e }` |
| `seq(i, n, e)` | `fseq(:i, n) { \|i\| e }` |
| `sum(i, n, e)` | `fsum(:i, n) { \|i\| e }` |
| `prod(i, n, e)` | `fprod(:i, n) { \|i\| e }` |

### Tables

| Faust | Ruby |
|-------|------|
| `waveform{v1, v2, ...}` | `waveform(v1, v2, ...)` |
| `rdtable(n, i, r)` | `rdtable(n, i, r)` |
| `rwtable(n, i, w, s, r)` | `rwtable(n, i, w, s, r)` |

### Primitives

| Faust | Ruby |
|-------|------|
| `_` | `wire` |
| `!` | `cut` |
| `mem` | `mem` |
| `ma.SR` | `sr` |
| `ma.PI` | `pi` |

## Round-trip Conversion

faust2ruby is designed to work with ruby2faust for round-trip conversion:

```ruby
require 'faust2ruby'
require 'ruby2faust'

# Faust → Ruby
faust_input = 'process = os.osc(440) : *(0.5);'
ruby_code = Faust2Ruby.to_ruby(faust_input, expression_only: true)

# Ruby → Faust
include Ruby2Faust::DSL
process = eval(ruby_code)
faust_output = Ruby2Faust::Emitter.program(process)
```

## With Clauses

`with` clauses are converted to Ruby lambdas for proper scoping:

**Input (Faust):**
```faust
myDSP = result with {
    gain = 0.5;
    result = _ * gain;
};
```

**Output (Ruby):**
```ruby
myDSP = -> {
  gain = 0.5
  result = (wire * gain)
  result
}.call
```

Function-style local definitions use `flambda`:
```ruby
adaa = flambda(:x0, :x1) { |x0, x1| select2(...) }
```

## Partial Application

Faust's partial application creates reusable signal processors by providing some arguments upfront.

### Clipping / Limiting

**Input (Faust):**
```faust
// Clip signal to [-1, 1] range
safetyLimit = min(1) : max(-1);
process = osc(440) : safetyLimit;
```

**Output (Ruby):**
```ruby
safetyLimit = (flambda(:x) { |x| min_(x, 1) } >> flambda(:x) { |x| max_(x, (-1)) })
process = (osc(440) >> safetyLimit)
```

### Conditional Routing

**Input (Faust):**
```faust
// Switch between two signals based on condition
useWet = checkbox("wet");
effect = _ <: _, reverb : select2(useWet);
```

**Output (Ruby):**
```ruby
useWet = checkbox("wet")
effect = wire.split(wire, reverb) >> flambda(:x, :y) { |x, y| select2(useWet, x, y) }
```

### Gain Stages

**Input (Faust):**
```faust
// Partial application of multiplication
halfGain = *(0.5);
quarterGain = *(0.25);
process = osc(440) : halfGain;
```

**Output (Ruby):**
```ruby
halfGain = gain(0.5)
quarterGain = gain(0.25)
process = (osc(440) >> halfGain)
```

### Filter Configuration

**Input (Faust):**
```faust
// Second-order lowpass waiting for cutoff frequency
smoothFilter = fi.lowpass(2);
process = _ : smoothFilter(1000);
```

**Output (Ruby):**
```ruby
smoothFilter = flambda(:x) { |x| lp(x, order: 2) }
process = (wire >> smoothFilter.call(1000))  # Note: needs .call in Ruby
```

### Math Functions as Processors

**Input (Faust):**
```faust
// 0-arg functions applied to signals
softclip(x) = tanh(x);
process = osc(440) * 2 : softclip;
```

**Output (Ruby):**
```ruby
def softclip(x)
  (x >> tanh_)
end
process = ((osc(440) * 2) >> softclip(wire))
```

## What Uses `literal()`

Some Faust constructs are emitted as `literal()` calls to preserve semantics:

| Construct | Example | Reason |
|-----------|---------|--------|
| Letrec blocks | `letrec { 'x = ... }` | Complex state semantics |
| Unmapped library functions | `an.amp_follower(t)` | Not in library mapper |
| Partial app (4+ args) | `route(4, 4, ...)` | Requires complex curry |

Most common Faust library functions are mapped, including `fi.*`, `os.*`, `de.*`, `en.*`, `ba.*`, `si.*`, `aa.*`, and math primitives.

## Limitations

**Supported with limitations:**
- `with` clauses: Local definitions work, scoped via Ruby lambda
- Partial application: Works for 1-3 missing arguments
- Forward references: Functions defined later in `with` blocks are resolved

**Not supported:**
- Pattern matching on function arguments (see below)
- Foreign functions (`ffunction`)
- Component/library imports beyond path tracking

### Case Expressions

Case expressions with integer patterns are converted to `select2` chains:

**Input (Faust):**
```faust
process = case {
  (0) => 1;
  (1) => 2;
  (n) => n * 2;
};
```

**Output (Ruby):**
```ruby
flambda(:n) { |n| select2(n.eq(0), select2(n.eq(1), (n * 2), 2), 1) }
```

The variable pattern `(n)` becomes the default/else case, and integer patterns are checked in order.

**Limitations:**
- Only integer patterns are converted to `select2` (variable patterns become default)
- Complex patterns (tuples, nested expressions) fall back to `literal()`
- Recursive functions like `fact(0) = 1; fact(n) = n * fact(n-1)` require compile-time evaluation not available at runtime

### Pattern Matching on Function Arguments

Multi-rule function definitions with single-parameter pattern matching are now supported:

**Input (Faust):**
```faust
fact(0) = 1;
fact(n) = n * fact(n - 1);
```

**Output (Ruby):**
```ruby
fact = flambda(:n) { |n| select2(n.eq(0), (n * fact((n - 1))), 1) }
```

Multiple definitions with the same name are automatically merged into a case expression, then converted to `select2` chains.

**Limitations:**
- Only single-parameter pattern matching is supported
- Multi-parameter patterns (e.g., `foo(0, 0) = a; foo(x, y) = b;`) are not merged
- Recursive functions like factorial require compile-time evaluation (the Ruby output is syntactically correct but may not produce the same runtime behavior)

## Known Issues

### letrec Blocks

`letrec` blocks are emitted as `literal()` calls because they implement complex recursive state semantics that don't have a direct Ruby DSL equivalent.

**Example Faust:**
```faust
// Spring-damper physics simulation
follower(input) = pos letrec {
    'v = v + step * (-damping * v - stiffness * (pos - input));
    'pos = pos + step * v;
};
```

**Generated Ruby:**
```ruby
literal("letrec { 'v = (v + (step * ...)); 'pos = (pos + (step * v)) } pos")
```

**Why this happens:**
- `'v` means "next value of v" (sample n+1)
- `v` means "current value of v" (sample n)
- This creates mutually recursive signals with feedback
- Ruby lacks native syntax for this pattern

**Workarounds:**
1. **Accept the literal** - Round-trip conversion still works; the Faust code is preserved
2. **Use simple feedback** - For single-variable recursion, use `wire ~ expr` instead
3. **Refactor in Faust** - Sometimes letrec can be rewritten using standard feedback

**Impact:** In practice, letrec is rare. Complex DSP files like triode.lib (500+ lines) convert with only 1 literal remaining (the letrec block).

### Unmapped Library Functions

The following Faust library namespaces are not yet mapped and will emit `literal()`:

| Namespace | Description | Status |
|-----------|-------------|--------|
| `an.*` | Analyzers (amp followers, pitch detection) | Not mapped |
| `ef.*` | Effects (flangers, phasers, wahs) | Not mapped |
| `ve.*` | Virtual analog (Moog filters, etc.) | Not mapped |
| `pm.*` | Physical modeling | Not mapped |
| `sy.*` | Synthesizers | Not mapped |
| `dx.*` | DX7 emulation | Not mapped |
| `pf.*` | Phaflangers | Not mapped |
| `dm.*` | Demos | Not mapped |

**Currently mapped:**
- `os.*` - Oscillators (osc, saw, square, triangle, phasor, lf_*)
- `no.*` - Noise (noise, pink_noise)
- `fi.*` - Filters (lowpass, highpass, resonlp, svf.*, allpass, dcblocker, peak_eq, tf1/tf2, etc.)
- `de.*` - Delays (delay, fdelay, sdelay)
- `en.*` - Envelopes (ar, asr, adsr, adsre)
- `ba.*` - Basics (db2linear, linear2db, tau2pole, midikey2hz, selectn, if, take)
- `si.*` - Signals (smooth, smoo, bus, block)
- `ma.*` - Math (SR, PI, tempo, tanh)
- `re.*` - Reverbs (mono_freeverb, zita_rev1_stereo, jpverb)
- `co.*` - Compressors (compressor_mono, limiter_1176_R4_mono)
- `sp.*` - Spatial (panner)
- `aa.*` - Antialiasing (tanh1, tanh2, arctan, softclip, hardclip, etc.)
- Math primitives (sin, cos, tan, tanh, sinh, cosh, abs, min, max, pow, sqrt, exp, log, floor, ceil, etc.)

**Contributing:** To add support for unmapped functions, edit `lib/faust2ruby/library_mapper.rb` and add corresponding entries to `lib/ruby2faust/ir.rb`, `lib/ruby2faust/dsl.rb`, and `lib/ruby2faust/emitter.rb`.

## Architecture

```
Faust Source → Lexer → Parser → AST → Ruby Generator → Ruby DSL
```

- **Lexer** (`lexer.rb`): StringScanner-based tokenizer
- **Parser** (`parser.rb`): Recursive descent parser
- **AST** (`ast.rb`): Abstract syntax tree nodes
- **Generator** (`ruby_generator.rb`): Produces Ruby DSL code
- **Library Mapper** (`library_mapper.rb`): Maps Faust functions to Ruby methods
