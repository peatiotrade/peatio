require_relative '../injectors'

module Bench
  module Injectors
    class Dummy < Base
      extend Memoist

      def initialize(config)
        super
        config.reverse_merge!(default_config)
        %i[min_volume max_volume min_price max_price].each do |var|
          instance_variable_set(:"@#{var}", config[var])
        end
      end

      def generate!(members = nil)
        @members = members || Member.all
        @queue = Queue.new
        ActiveRecord::Base.transaction do
          Array.new(@number) do
            create_order.tap { |o| @queue << o }
          end
        end
      end

      def pop
        @queue.empty? ? nil : @queue.pop
      end

      def size
        @queue.size
      end

      private
      def create_order
        Order.new(construct_order)
             .tap(&:fix_number_precision)
             .tap { |o| o.locked = o.origin_locked = o.compute_locked }
             .tap { |o| o.hold_account!.lock_funds(o.locked) }
             .tap(&:save)
      end

      def construct_order
        market = @markets.sample
        type = %w[OrderBid OrderAsk].sample
        { type:     type,
          state:    Order::WAIT,
          member:   @members.sample,
          market:   market,
          ask:      market.base_unit,
          bid:      market.quote_unit,
          ord_type: :limit,
          price:    rand(@min_price..@max_price),
          volume:   rand(@min_volume..@max_volume) }
      end

      def default_config
        { min_volume: 0.1,
          max_volume: 1,
          min_price:  0.5,
          max_price:  2 }
      end
      memoize :default_config
    end
  end
end
