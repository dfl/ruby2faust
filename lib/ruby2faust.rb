# frozen_string_literal: true

require_relative "ruby2faust/version"
require_relative "ruby2faust/ir"
require_relative "ruby2faust/dsl"
require_relative "ruby2faust/emitter"
require_relative "ruby2faust/live"

module Ruby2Faust
  class Error < StandardError; end

  # Convenience method to generate Faust code from a block
  #
  # @example
  #   code = Ruby2Faust.generate do
  #     osc(440).then(gain(0.3))
  #   end
  #
  # @example Generate an effect instead of process
  #   code = Ruby2Faust.generate(output: "effect") do
  #     wire >> delay(48000, 0.5.sec) * 0.5
  #   end
  #
  # @yield Block that returns a DSP
  # @return [String] Faust source code
  def self.generate(pretty: true, output: "process", extract_common: false, &block)
    context = Object.new
    context.extend(DSL)
    result = context.instance_eval(&block)
    Emitter.program(result, pretty: pretty, output: output, extract_common: extract_common)
  end
end
