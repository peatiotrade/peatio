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

    class Base
      attr_reader :config

      def initialize(config)
        @config = config
        @number = config[:number].to_i
        @markets = ::Market.where(id: config[:markets].split(',').map(&:squish).reject(&:blank?))
      end
    end
  end
end

