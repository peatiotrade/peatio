module Bench
  class TradeExecution < Matching
    def run!
      # TODO: Check if TradeExecutor daemon is running before start (use queue_info[:consumers]).
      super
      Kernel.puts 'Waiting for trades processing by trade execution daemon...'
      @execution_started_at = @publish_started_at
      wait_for_execution
      @execution_finished_at = Time.now
    end

    def wait_for_execution
      loop do
        queue_status = trade_execution_queue_status
        # NOTE: If no orders where matched idle_since would not change.
        break if queue_status[:messages].zero? &&
                 queue_status[:idle_since].present? &&
                 Time.parse("#{queue_status[:idle_since]} UTC") >= @execution_started_at

        sleep 0.5
      end
    end

    def result
      @result ||=
        begin
          trades_ops = trades_number / (@execution_finished_at - @publish_started_at)

          super.merge(
            execution_started_at: @execution_started_at.iso8601(6),
            execution_finished_at: @execution_finished_at.iso8601(6),
            trades_ops: trades_ops
          )
        end
    end

    def trade_executor_is_running?
      trade_execution_queue_status[:consumers].positive?
    end

    private

    def trade_execution_queue_status
      response = @rmq_http_client.get('/api/queues/')
      response.body.map!(&:deep_symbolize_keys).find do |q|
        q[:name] == AMQPConfig.binding_queue(:trade_executor).first
      end
    end

    def trades_number
      Trade.where('created_at >= ?', @publish_started_at).length
    end
  end
end
