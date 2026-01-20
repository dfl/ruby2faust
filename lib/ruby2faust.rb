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
  # @yield Block that returns a DSP
  # @return [String] Faust source code
  def self.generate(&block)
    context = Object.new
    context.extend(DSL)
    process = context.instance_eval(&block)
    Emitter.program(process)
  end
end
