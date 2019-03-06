require 'rabbitmq/http/client'

require_relative 'injectors'

module Bench
  class TradeExecution < Matching
    def run!
      super
      Kernel.puts 'Waiting for trades processing by trade execution daemon...'
      @execution_started_at = Time.now
      wait_for_execution
      @execution_finished_at = Time.now
    end

    def wait_for_execution
      # Wait for RMQ queue status update.
      loop do
        queue_status = trade_executor_queue
        break if queue_status[:messages].zero? &&
                 queue_status[:idle_since].present? &&
                 Time.parse("#{queue_status[:idle_since]} UTC") >= @execution_started_at
        sleep 0.5
      end
    end

    def trade_executor_queue
      @rmq_http_client.list_queues.find { |q| q[:name] == AMQPConfig.binding_queue(:trade_executor).first }
    end

    def result
      @result ||=
        begin
          trades_ops = trades_number / (@execution_finished_at - @publish_started_at)

          super.merge(
            trades_ops: trades_ops,
            execution_finished_at: @execution_finished_at
          )
        end
    end

    def trades_number
      Trade.where('created_at >= ?', @publish_started_at).length
    end
  end
end
