# frozen_string_literal: true

namespace :bench do
  desc 'Mathing'
  task matching: :environment do
    Bench::Matching.new.run!
  end
end
