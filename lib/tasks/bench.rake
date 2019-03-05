# frozen_string_literal: true

namespace :bench do
  desc 'Mathing'
  task matching: :environment do
    matching = Bench::Matching.new
    matching.run!

    # Temporary just print benchmark results.
    Kernel.puts matching.results
  end
end
