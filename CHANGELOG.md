# Changelog

All notable changes to this project will be documented in this file.

## [0.2.3] - 2025-01-21

### Added
- Numeric extensions in faust2ruby: `ba.db2linear(-6)` → `-6.db`, `ba.midikey2hz(60)` → `60.midi`, `ba.sec2samp(0.1)` → `0.1.sec`
- Precedence-aware parentheses in emitter - only adds parens when needed
- `rake release` task for publishing to RubyGems
- CHANGELOG.md

### Changed
- ruby2faust emits idiomatic Faust: `signal : *(scalar)` and `signal : /(scalar)`
- faust2ruby emits idiomatic Ruby: `scalar * signal` and `signal / scalar`
- Cleaner output with minimal parentheses
- README examples updated

## [0.2.2] - 2025-01-21

### Added
- `coerce` method on DSP class enabling numeric-on-left operations (`0.5 * osc(440)`)

### Changed
- README example updated to show numeric extensions (.midi, .db)

## [0.2.1] - 2025-01-20

### Added
- Include .yardopts in gem

## [0.2.0] - 2025-01-20

### Added
- Initial release with ruby2faust and faust2ruby tools
- Ruby DSL for generating Faust DSP code
- Faust to Ruby converter
- Numeric extensions (.midi, .db, .sec, .ms, .hz)
- Pretty printing option
- CLI tools
