# encoding: UTF-8
# frozen_string_literal: true

module Worker
  class OrderProcessor
    def process(payload)
      case payload['action']
      when 'submit'
        submit(payload['order'])
      when 'cancel'
        order = Order.find_by_id(payload.dig('order', 'id'))
        cancel(order) if order
      end
    end

  private

    def cancel(order)
      Ordering.new(order).cancel!
    rescue StandardError => e
      report_exception_to_screen(e)
    end

    def submit(order_attributes)
      Order.new(order_attributes)
        .tap { |o| o.hold_account!.lock_funds!(o.locked) }
        .tap { |o| o.record_submit_operations! }
        .tap { |o| AMQPQueue.enqueue(:matching, action: 'submit', order: o.to_matching_attributes) }
    end
  end
end

