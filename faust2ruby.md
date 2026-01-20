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

Faust's partial application (e.g., `min(1)`) is converted to lambdas:

**Input (Faust):**
```faust
safetyLimit = min(1) : max(-1);
```

**Output (Ruby):**
```ruby
safetyLimit = (flambda(:x) { |x| min_(x, 1) } >> flambda(:x) { |x| max_(x, (-1)) })
```

## What Uses `literal()`

Some Faust constructs are emitted as `literal()` calls to preserve semantics:

| Construct | Example | Reason |
|-----------|---------|--------|
| Unmapped library functions | `fi.svf.bp(f, q)` | Not in library mapper |
| Letrec blocks | `letrec { 'x = ... }` | Complex state semantics |
| Unknown functions | `customFunc(x)` | Not defined in file |
| Partial app (3+ args) | `route(4, 4, ...)` | Requires complex curry |

## Limitations

**Supported with limitations:**
- `with` clauses: Local definitions work, but variables from `with` blocks are scoped to a Ruby lambda
- `letrec`: Emitted as literals; full recursive state semantics not implemented in DSL
- Partial application: Works for 2-arg functions (e.g., `min(1)`); more complex cases use literals

**Not supported:**
- Pattern matching and case expressions
- Foreign functions (`ffunction`)
- Component/library imports beyond path tracking
- Recursive signal definitions (beyond what letrec provides)

## Architecture

```
Faust Source → Lexer → Parser → AST → Ruby Generator → Ruby DSL
```

- **Lexer** (`lexer.rb`): StringScanner-based tokenizer
- **Parser** (`parser.rb`): Recursive descent parser
- **AST** (`ast.rb`): Abstract syntax tree nodes
- **Generator** (`ruby_generator.rb`): Produces Ruby DSL code
- **Library Mapper** (`library_mapper.rb`): Maps Faust functions to Ruby methods
