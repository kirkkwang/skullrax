# frozen_string_literal: true

module Skullrax
  module TransactionConcern
    def handle_success(result)
      assign_resource(result.value!)
      result
    end

    def handle_failure(result)
      val = result.failure

      message = if val.is_a?(Array) && val[1].respond_to?(:full_messages)
                  "#{val[1].full_messages.to_sentence} [#{val[0]}]"
                else
                  val.to_s
                end

      Rails.logger.error("Skullrax Transaction Failed: #{message}")
      @errors << message
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
