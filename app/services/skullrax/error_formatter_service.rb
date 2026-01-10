# frozen_string_literal: true

module Skullrax
  class ErrorFormatterService
    delegate :content_tag, :safe_join, to: :controller_helpers

    def self.format(errors:)
      new(errors:).format
    end

    def initialize(errors:)
      @errors = errors
    end

    def format
      return nil if errors.empty?

      build_html_message
    end

    private

    attr_reader :errors

    def build_html_message
      content_tag(:div, class: 'import-errors') do
        content_tag(:strong, I18n.t('skullrax.import_failed')) +
          content_tag(:ul, class: 'error-list') do
            safe_join(error_list_items)
          end
      end
    end

    def error_list_items
      error_messages.map do |error|
        content_tag(:li, error)
      end
    end

    def error_messages
      @error_messages ||= errors.map { |error| format_error(error) }
    end

    def format_error(error)
      return error if error.is_a?(String)

      error_messages = Array.wrap(error[:errors]).map(&:to_s)
      I18n.t('skullrax.errors.row_error', row_number: error[:row_number], errors: error_messages.join(', '))
    end

    def controller_helpers
      @controller_helpers ||= ActionController::Base.helpers
    end
  end
end
