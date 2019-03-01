module Bench
  module Factories
    class << self
      def create(model, options = {})
        "#{self.name}/#{model}"
          .camelize
          .constantize
          .new(options)
          .create
      end

      def create_list(model, number, options = {})
        "#{self.name}/#{model}"
          .camelize
          .constantize
          .new(options)
          .create_list(number)
      end
    end

    class Member
      def initialize(options)
        @options = options
      end

      def create
        ::Member.create!(construct_member)
      end

      def create_list(number)
        Array.new(number) { create }
      end

      def construct_member
        { email: unique_email,
          level: 3,
          disabled: false }.merge(@options)
      end

      def unique_email
        @used_emails ||= ::Member.pluck(:email)
        loop do
          email = Faker::Internet.unique.email
          unless @used_emails.include?(email)
            @used_emails << email
            return email
          end
        end
      end
    end

    class Deposit
      DEFAULT_DEPOSIT_AMOUNT = 1_000_000_000
      def initialize(options)
        @options = options
      end

      def create
        ::Deposit.create!(construct_deposit).tap(&:charge!)
      end

      def construct_deposit
        { amount: DEFAULT_DEPOSIT_AMOUNT,
          type: 'Deposits::Fiat' }.merge(@options)
      end
    end
  end
end

# Table name: deposits
#
#  id            :integer          not null, primary key
#  member_id     :integer          not null
#  currency_id   :string(10)       not null
#  amount        :decimal(32, 16)  not null
#  fee           :decimal(32, 16)  not null
#  address       :string(64)
#  txid          :string(128)
#  txout         :integer
#  aasm_state    :string(30)       not null
#  confirmations :integer          default(0), not null
#  type          :string(30)       not null
#  tid           :string(64)       not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  completed_at  :datetime
#
