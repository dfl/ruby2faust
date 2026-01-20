# frozen_string_literal: true

require_relative "ir"
require_relative "emitter"

module Ruby2Faust
  # Live reload support: graph diffing, compilation, crossfade.
  module Live
    module_function

    # Check if two graphs have different structure
    #
    # @param old_graph [DSP, Node] Previous graph
    # @param new_graph [DSP, Node] New graph
    # @return [Boolean] True if structures differ
    def changed?(old_graph, new_graph)
      old_node = old_graph.is_a?(DSP) ? old_graph.node : old_graph
      new_node = new_graph.is_a?(DSP) ? new_graph.node : new_graph
      !old_node.same_structure?(new_node)
    end

    # Compile a DSP graph to a Faust file
    #
    # @param graph [DSP] The DSP graph to compile
    # @param output [String] Output file path (.dsp)
    # @param imports [Array<String>] Libraries to import
    # @return [String] Path to the output file
    def compile(graph, output:, imports: Emitter::DEFAULT_IMPORTS)
      code = Emitter.program(graph, imports: imports)
      File.write(output, code)
      output
    end

    # Generate crossfade DSP code for smooth transitions
    # Creates a Faust program that crossfades between old and new DSP
    #
    # @param old_process [String] Faust expression for old process
    # @param new_process [String] Faust expression for new process
    # @param duration [Float] Crossfade duration in seconds (default 0.05)
    # @return [String] Faust source with crossfade
    def crossfade_dsp(old_process, new_process, duration: 0.05)
      <<~FAUST
        import("stdfaust.lib");

        // Crossfade envelope
        xfade = hslider("xfade", 0, 0, 1, 0.001) : si.smoo;

        // Old and new processes
        old = #{old_process};
        new = #{new_process};

        // Crossfade: (1-x)*old + x*new
        process = old * (1 - xfade), new * xfade :> _;
      FAUST
    end

    # Run the Faust compiler on a .dsp file
    # Requires faust to be in PATH
    #
    # @param dsp_file [String] Path to .dsp file
    # @param target [Symbol] Compilation target (:wasm, :cpp, :llvm)
    # @param output_dir [String] Output directory (default: same as input)
    # @return [Boolean] True if compilation succeeded
    def faust_compile(dsp_file, target: :cpp, output_dir: nil)
      output_dir ||= File.dirname(dsp_file)
      basename = File.basename(dsp_file, ".dsp")

      cmd = case target
            when :wasm
              "faust2wasm #{dsp_file} -o #{output_dir}/#{basename}.wasm"
            when :cpp
              "faust -a minimal.cpp #{dsp_file} -o #{output_dir}/#{basename}.cpp"
            when :llvm
              "faust -lang llvm #{dsp_file} -o #{output_dir}/#{basename}.ll"
            else
              raise ArgumentError, "Unknown target: #{target}"
            end

      system(cmd)
    end
  end
end
