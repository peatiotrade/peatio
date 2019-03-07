# frozen_string_literal: true

# TODO: Add descriptions.
# TODO: Save reports directly after running bench (in case next will error).

namespace :bench do
  desc 'Matching'
  task :matching, [:config_load_path] => [:environment] do |_t, args|
    args.with_defaults(:config_load_path => 'config/bench/matching.yml')

    benches =
      YAML.load_file(Rails.root.join(args[:config_load_path]))
        .map(&:deep_symbolize_keys)
        .each_with_object([]) do |config, memo|
          Kernel.pp config

          matching = Bench::Matching.new(config)

          unless matching.matching_is_running?
            Kernel.puts 'Trade Executor daemon is not running!'
            exit 1
          end

          matching.run!
          memo << matching
          matching.save_report
          Kernel.puts "Sleep before next bench"
          sleep 5
        end

    benches.each {|b| Kernel.pp b.result}
  end

  desc 'Trade Execution'
  task :trade_execution, [:config_load_path] => [:environment] do |_t, args|
    args.with_defaults(:config_load_path => 'config/bench/trade_execution.yml')

    benches =
      YAML.load_file(Rails.root.join(args[:config_load_path]))
        .map(&:deep_symbolize_keys)
        .each_with_object([]) do |config, memo|
        Kernel.pp config

        trade_execution = Bench::TradeExecution.new(config)

        unless trade_execution.trade_executor_is_running?
          Kernel.puts 'Trade Executor daemon is not running!'
          exit 1
        end

        trade_execution.run!
        memo << trade_execution
        trade_execution.save_report
        Kernel.puts "Sleep before next bench"
        sleep 5
      end

    benches.each {|b| Kernel.pp b.result}
  end

  desc 'Order Processing'
  task :order_processing, [:config_load_path] => [:environment] do |_t, args|
    args.with_defaults(:config_load_path => 'config/bench/order_processing.yml')

    benches =
      YAML.load_file(Rails.root.join(args[:config_load_path]))
        .map(&:deep_symbolize_keys)
        .each_with_object([]) do |config, memo|
        Kernel.pp config

        order_processing = Bench::OrderProcessing.new(config)

        unless matching.order_processor_is_running?
          Kernel.puts 'Trade Executor daemon is not running!'
          exit 1
        end

        order_processing.run!
        memo << order_processing
        order_processing.save_report
        Kernel.puts "Sleep before next bench"
        sleep 5
      end

    benches.each {|b| Kernel.pp b.result}
  end
end
