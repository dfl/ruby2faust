# frozen_string_literal: true

require_relative "lib/ruby2faust/version"

Gem::Specification.new do |spec|
  spec.name = "ruby2faust"
  spec.version = Ruby2Faust::VERSION
  spec.authors = ["David Lowenfels"]
  spec.email = ["dfl@alum.mit.edu"]

  spec.summary = "A Ruby DSL that generates Faust DSP code"
  spec.description = "Build DSP graphs in Ruby, emit valid Faust source. Ruby describes; Faust executes."
  spec.homepage = "https://github.com/dfl/ruby2faust"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.glob("{lib,bin}/**/*") + %w[README.md LICENSE.txt]
  spec.bindir = "bin"
  spec.executables = ["ruby2faust", "faust2ruby"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "yard"
end
