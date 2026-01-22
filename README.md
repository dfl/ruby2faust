# Frausto

[![Gem Version](https://badge.fury.io/rb/frausto.svg)](https://rubygems.org/gems/frausto)
[![CI](https://github.com/dfl/ruby2faust/actions/workflows/ci.yml/badge.svg)](https://github.com/dfl/ruby2faust/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-ruby.svg)](https://www.ruby-lang.org)

A Ruby toolkit for Faust DSP: generate Faust code from Ruby, or convert Faust to Ruby.

## Installation

```bash
gem install frausto
```

Or add to your Gemfile:

```ruby
gem 'frausto'
```

## Tools

- **[ruby2faust](ruby2faust.md)** - Ruby DSL that generates Faust DSP code
- **[faust2ruby](faust2ruby.md)** - Convert Faust DSP code to Ruby DSL

## Quick Examples

```ruby
require 'ruby2faust'

code = Ruby2Faust.generate do
  freq = hslider("freq", init: 48, min: 20, max: 100, step: 1) >> midi2hz >> smoo
  amp = hslider("amp", init: -12, min: -60, max: 0, step: 1) >> db2linear >> smoo
  osc(freq) >> lp(2000) >> gain(amp)
end

puts code
# import("stdfaust.lib");
#
# process =
#   os.osc(hslider("freq", 48, 20, 100, 1) : ba.midikey2hz : si.smoo)
#   : fi.lowpass(1, 2000)
#   : *(hslider("amp", -12, -60, 0, 1) : ba.db2linear : si.smoo);
```

```ruby
require 'faust2ruby'

ruby_code = Faust2Ruby.to_ruby('process = os.osc(440) : *(0.5);')
# => "0.5 * osc(440)"
```

## License

MIT
