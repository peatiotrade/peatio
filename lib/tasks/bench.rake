# TODO: Should work without require_relative.
require_relative '../bench/matching'

namespace :bench do
  desc 'Mathing'
  task :matching do
    Bench::Matching.new()
  end
end
