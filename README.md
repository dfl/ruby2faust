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

## Quick Example

```ruby
require 'ruby2faust'

code = Ruby2Faust.generate do
  freq = 60.midi >> smoo
  (osc(freq) + noise * 0.1) >> lp(2000) * -6.db
end

puts code
# => import("stdfaust.lib");
#    process = ((os.osc((ba.midikey2hz(60) : si.smoo)) + (no.noise * 0.1)) : fi.lowpass(1, 2000) : *(ba.db2linear(-6)));
```

```ruby
require 'faust2ruby'

ruby_code = Faust2Ruby.to_ruby('process = os.osc(440) : *(0.5);')
# => "osc(440) >> gain(0.5)"
```

## License

MIT
