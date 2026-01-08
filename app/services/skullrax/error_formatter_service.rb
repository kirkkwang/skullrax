# frozen_string_literal: true

module Skullrax
  class ErrorFormatterService
    MAX_DISPLAYED_ERRORS = 5

    def self.format(errors:)
      new(errors:).format
    end

    def initialize(errors:)
      @errors = errors
    end

    def format
      return nil if errors.empty?

      "Import failed: #{formatted_messages}"
    end

    private

    attr_reader :errors

    def formatted_messages
      if too_many_errors?
        "#{displayed_messages} ...and #{remaining_count} more errors."
      else
        all_messages
      end
    end

    def displayed_messages
      error_messages.first(MAX_DISPLAYED_ERRORS).join(' | ')
    end

    def all_messages
      error_messages.join(' | ')
    end

    def error_messages
      @error_messages ||= errors.map { |error| format_error(error) }
    end

    def format_error(error)
      return error if error.is_a?(String)

      error_messages = Array.wrap(error[:errors]).map(&:to_s)
      "Row #{error[:row_number]}: #{error_messages.join(', ')}"
    end

    def too_many_errors?
      errors.size > MAX_DISPLAYED_ERRORS
    end

    def remaining_count
      errors.size - MAX_DISPLAYED_ERRORS
    end
  end
end
