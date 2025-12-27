# frozen_string_literal: true

module Skullrax
  module TransactionConcern
    def handle_success(result)
      assign_resource(result.value!)
      result
    end

    def handle_failure(result)
      formatter = ErrorFormatter.new(result)
      formatter.log
      @errors << formatter.format
      result
    end

    def transactions
      Hyrax::Transactions::Container
    end

    def user
      @user ||= User.find_by_email('admin@example.com')
    end
  end
end
