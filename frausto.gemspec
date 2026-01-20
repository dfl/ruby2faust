# frozen_string_literal: true

require_relative "lib/ruby2faust/version"

Gem::Specification.new do |spec|
  spec.name = "frausto"
  spec.version = Ruby2Faust::VERSION
  spec.authors = ["David Lowenfels"]
  spec.email = ["dfl@alum.mit.edu"]

  spec.summary = "Ruby↔Faust DSP transpiler"
  spec.description = "Build faust-executable DSP graphs in Ruby DSL with ruby2faust; or convert Faust to Ruby with faust2ruby."
  spec.homepage = "https://github.com/dfl/ruby2faust"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.glob("{lib,bin}/**/*") + %w[README.md ruby2faust.md faust2ruby.md LICENSE.txt .yardopts]
  spec.bindir = "bin"
  spec.executables = ["ruby2faust", "faust2ruby"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "yard", "~> 0.9"
end
