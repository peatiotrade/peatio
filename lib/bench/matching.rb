require "rabbitmq/http/client"

require_relative 'injectors'

module Bench
  class Matching
    # TODO: Custom config file support.
    def initialize(config_file_path = 'config/bench/matching.yml')
      @config = YAML.load_file(Rails.root.join(config_file_path)).deep_symbolize_keys
      @injector = Injectors.initialize_injector(@config[:orders])
      @currencies = Currency.where(id: @config[:currencies].split(',').map(&:squish).reject(&:blank?))
    end

    def run!
      # TODO: Check if Matching daemon is running before run.
      Kernel.puts "Creating members ..."
      @members = Factories.create_list(:member, @config[:traders])
      Kernel.puts "Depositing funds ..."
      @members.map(&method(:become_billionaire))
      Kernel.puts "Generating orders by injector and saving them in db..."
      @injector.generate!(@members)
      Kernel.puts "Publishing messages to RabbitMQ..."
      publish_messages
      wait_for_messages_ack
    end

    def publish_messages
      Array.new(@config[:threads]) do
        Thread.new do
          loop do
            order = @injector.pop
            break unless order
            AMQPQueue.enqueue(:matching, action: 'submit', order: order.to_matching_attributes)
          rescue StandardError => e
            Kernel.puts e
          end
        end
      end.map(&:join)
    end

    # Doesn't work correctly.
    def wait_for_messages_ack
      loop do
        # TODO: Write useful data
        queue_info.tap do |qi|
          Kernel.puts "Number of messages in queue is: #{qi[:messages]}"
          break if qi[:messages].zero?
        end
        sleep 0.5
      end
    end

    def queue_info
      @client ||= ::URI::HTTP.build(
                    scheme:   :http,
                    host:     ENV.fetch('RABBITMQ_HOST', 'localhost'),
                    port:     15672,
                    userinfo: "#{ENV.fetch('RABBITMQ_USER', 'guest')}:#{ENV.fetch('RABBITMQ_PASSWORD', 'guest')}"
      ).yield_self { |endpoint| RabbitMQ::HTTP::Client.new(endpoint.to_s) }

      binding.pry
      queue_info = @client.queue_info('/', 'peatio.matching').deep_symbolize_keys
      formatted = queue_info.slice(:messages, :name)
    end

    private
    # TODO: Move to Helpers.
    def become_billionaire(member)
      @currencies.each do |c|
        Factories.create(:deposit, member_id: member.id, currency_id: c.id)
      end
    end
  end
end
