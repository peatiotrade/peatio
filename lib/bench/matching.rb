require_relative 'injectors'

module Bench
  class Matching
    # TODO: Custom config file support.
    def initialize(config_file_path = 'config/bench/matching.yml')
      @config = YAML.load_file(Rails.root.join(config_file_path)).deep_symbolize_keys
      @injector = Injectors.initialize_injector(@config[:orders])
    end

    def run!

    end
  end
end
