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
      Kernel.puts "Creating members ..."
      @members = Factories.create_list(:member, @config[:traders])
      Kernel.puts "Depositing funds ..."
      @members.map(&method(:become_billionaire))
      Kernel.puts "Generating orders by injector ..."
      @injector.generate!
      run_workers!
    end

    def run_workers!
      Array.new(@config[:threads]) do
        Thread.new do
          loop do
            order = @injector.pop
            break unless order
            AMQPQueue.enqueue(:matching, action: 'submit', order: order.to_matching_attributes)
          end
        end
      end.map(&:join)
    end

    def become_billionaire(member)
      @currencies.each do |c|
        Factories.create(:deposit, member_id: member.id, currency_id: c.id)
      end
    end
  end
end
