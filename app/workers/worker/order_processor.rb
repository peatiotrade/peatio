# encoding: UTF-8
# frozen_string_literal: true

module Worker
  class OrderProcessor
    def initialize
      Order.where(state: ::Order::PENDING).find_each do |order|
        submit(order)
      end
    end

    def process(payload)
      case payload['action']
      when 'submit'
        submit(payload.dig('order', 'id'))
      when 'cancel'
        cancel(payload.dig('order', 'id'))
      end
    rescue => e
      AMQPQueue.enqueue(:trade_error, e.message)
    end

  private

    def submit(id)
      ActiveRecord::Base.transaction do
        order = Order.lock.find_by_id!(id)
        return unless order.state == ::Order::PENDING

        order.hold_account!.lock_funds!(order.locked)
        order.record_submit_operations!
        order.update!(state: ::Order::WAIT)

        AMQPQueue.enqueue(:matching, action: 'submit', order: order.to_matching_attributes)
      end
    rescue => e
      order.update!(state: ::Order::REJECT)
      report_exception_to_screen(e)
    end

    def cancel(id)
      ActiveRecord::Base.transaction do
        order = Order.lock.find_by_id!(id)
        return unless order.state == ::Order::WAIT

        order.hold_account!.unlock_funds!(order.locked)
        order.record_cancel_operations!

        order.update!(state: ::Order::CANCEL)
      end
    rescue => e
      report_exception_to_screen(e)
    end
  end
end
