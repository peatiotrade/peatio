module Bench
  module Injectors
    autoload :Dummy, 'bench/injectors/dummy'

    class << self
      # TODO: Rename.
      def initialize_injector(config)
        "#{self.name}/#{config[:injector]}"
          .camelize
          .constantize
          .new(config)
      end
    end
  end
end

