# frozen_string_literal: true

module Skullrax
  class ErrorFormatter
    attr_reader :result

    def initialize(result)
      @result = result
    end

    def format
      return result.failure[0].to_s unless validation_error?

      "#{result.failure[1].full_messages.to_sentence} [#{result.failure[0]}]"
    end

    def log
      Rails.logger.info("Transaction failed: #{format}\n  #{result.trace}")
    end

    private

    def validation_error?
      result.failure[1].respond_to?(:full_messages)
    end
  end
end
