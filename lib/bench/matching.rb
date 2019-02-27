require_relative 'injectors'

module Bench
  class Matching
    # TODO: Custom config file support.
    def initialize(config_file_path = 'config/bench/matching.yml')
      @config = YAML.load_file(Rails.root.join(config_file_path)).deep_symbolize_keys
      @injector = Injectors.initialize_injector(@config[:orders])
    end

    def run!
      Kernel.puts "Generating members ..."
      # TODO: Generate members dynamically.
      Kernel.puts "Generating orders by injector ..."
      @injector.generate!
      binding.pry
      run_workers!
    end

    def run_workers!
      Array.new(@config[:threads]) do
        Thread.new do
          loop do
            order = @injector.pop
            break unless order
            AMQPQueue.enqueue(:matching, action: 'submit', order: order.to_matching_attributes)
          end
        end
      end.map(&:join)
    end
  end
end
