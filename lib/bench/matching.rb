require 'faraday'
require 'faraday_middleware'

# TODO: Add Bench::Error and better errors processing.
# TODO: Add Bench::Report and extract all metrics to it.
# TODO: Add missing frozen_string literal to whole module.
module Bench
  class Matching
    def initialize(config)
      @config = config

      endpoint = URI::HTTP.build(
        scheme:   :http,
        host:     ENV.fetch('RABBITMQ_HOST', 'localhost'),
        port:     15672,
        userinfo: "#{ENV.fetch('RABBITMQ_USER', 'guest')}:#{ENV.fetch('RABBITMQ_PASSWORD', 'guest')}"
      )

      @rmq_http_client = Faraday.new(url: endpoint.to_s) do |conn|
        conn.basic_auth endpoint.user, endpoint.password
        conn.use        FaradayMiddleware::FollowRedirects, limit: 3
        conn.use        Faraday::Response::RaiseError
        conn.adapter    Faraday.default_adapter
        conn.response   :json, content_type: /\bjson$/
      end

      @injector = Injectors.initialize_injector(@config[:orders])
      @currencies = Currency.where(id: @config[:currencies].split(',').map(&:squish).reject(&:blank?))
      # TODO: Print errors in the end of benchmark and include them into report.
      @errors = []
    end

    def run!
      # TODO: Check if Matching daemon is running before start (use queue_info[:consumers]).
      Kernel.puts "Creating members ..."
      @members = Factories.create_list(:member, @config[:traders])

      Kernel.puts "Depositing funds ..."
      @members.map(&method(:become_billionaire))

      Kernel.puts "Generating orders by injector and saving them in db..."
      @injector.generate!(@members)

      @orders_number = @injector.size

      Kernel.puts "Publishing messages to RabbitMQ..."
      @publish_started_at = Time.now
      # TODO: Add orders publishing progress bar.
      publish_messages

      @publish_finished_at = Time.now
      Kernel.puts "Messages are published to RabbitMQ."

      Kernel.puts "Waiting for order processing by matching daemon..."
      wait_for_matching
      @matching_finished_at = Time.now
    end

    def publish_messages
      number = @config[:threads]
      Array.new(number) do |i|
        Kernel.print "\rPublished #{i + 1}/#{number}"
        Thread.new do
          loop do
            order = @injector.pop
            break unless order
            AMQPQueue.enqueue(:matching, action: 'submit', order: order.to_matching_attributes)
          rescue StandardError => e
            Kernel.puts e
            @errors << e
          end
        end
      end.map(&:join)
      Kernel.puts
    end

    # TODO: Find better solution for getting message number in queue.
    # E.g there is rabbitmqctl list_queues.
    # TODO: Write useful queue info stats into file.
    def wait_for_matching
      logger = File.open('log/bench-matching.log', 'w')
      thread = Thread.new do
        loop do
          logger.puts matching_queue_status.to_json
          sleep 5
        end
      end

      loop do
        queue_status = matching_queue_status
        break if queue_status[:messages].zero? &&
                 queue_status[:idle_since].present? &&
                 Time.parse("#{queue_status[:idle_since]} UTC") >= @publish_started_at
        sleep 0.5
      end

      thread.exit
      logger.close
    end

    # TODO: Add more useful metrics to result.
    def result
      @result ||=
      begin
        publish_ops =  @orders_number / (@publish_finished_at - @publish_started_at)
        matching_ops =  @orders_number / (@matching_finished_at - @publish_started_at)

        # TODO: Deal with calling iso8601(6) everywhere.
        { config: @config,
          publish_started_at: @publish_started_at.iso8601(6),
          publish_finished_at: @publish_finished_at.iso8601(6),
          matching_started_at: @publish_started_at.iso8601(6),
          matching_finished_at: @matching_finished_at.iso8601(6),
          publish_ops: publish_ops,
          matching_ops: matching_ops }
      end
    end

    def matching_is_running?
      matching_queue_status[:consumers].positive?
    end

    def save_report
      report_name = "#{self.class.name.humanize.demodulize}-#{@config[:orders][:injector]}-"\
                    "#{@config[:orders][:number]}-#{Time.now.iso8601}.yml"
      binding.pry
        File.open(Rails.root.join(@config[:report_path], report_name), 'w') do |f|
        f.puts YAML.dump(result.deep_stringify_keys)
      end
    end

    private

    def matching_queue_status
      response = @rmq_http_client.get('/api/queues/')
      response.body.map!(&:deep_symbolize_keys).find do |q|
        q[:name] == AMQPConfig.binding_queue(:matching).first
      end
    end

    # TODO: Move to Helpers.
    def become_billionaire(member)
      @currencies.each do |c|
        Factories.create(:deposit, member_id: member.id, currency_id: c.id)
      end
    end
  end
end
