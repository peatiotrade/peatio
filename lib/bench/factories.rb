module Bench
  module Factories
    class << self
      def create(model, number, options = {})
        "#{self.name}/#{model}"
          .camelize
          .constantize
          .new(number, options)
          .create(number, options)
      end
    end

    class Member
      def initialize(number, options)
        @number = number
        @options = options
      end

      def create(number, options)
        Array.new(number) do
          ::Member.create(construct_member)
        end
      end

      def construct_member
        { email: unique_email,
          level: 3,
          disabled: false }
      end

      def unique_email
        Faker::Internet.unique.email
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
  end
end
