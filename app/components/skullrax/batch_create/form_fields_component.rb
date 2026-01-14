# frozen_string_literal: true

module Skullrax
  module BatchCreate
    class FormFieldsComponent < ViewComponent::Base
      def initialize(form:, form_builder:)
        @form = form
        @form_builder = form_builder
      end

      private

      attr_reader :form, :form_builder

      delegate :primary_terms, :secondary_terms, :display_additional_fields?, :model_class, to: :form
      delegate :render_edit_field_partial, to: :helpers
    end
  end
end
