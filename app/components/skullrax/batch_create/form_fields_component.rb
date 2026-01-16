# frozen_string_literal: true

module Skullrax
  module BatchCreate
    class FormFieldsComponent < ViewComponent::Base
      def initialize(form:, form_builder:)
        @form = form
        @form_builder = form_builder
      end

      def render_field(term)
        # Override based_near to use simple input (no autocomplete widget)
        if term == :based_near
          render_simple_based_near(multi: form.multiple?(term))
        else
          render_edit_field_partial(term, f: form_builder, curation_concern: model_class)
        end
      end

      private

      attr_reader :form, :form_builder

      delegate :primary_terms, :secondary_terms, :display_additional_fields?, :model_class, to: :form
      delegate :render_edit_field_partial, to: :helpers

      def render_simple_based_near(multi: true)
        form_builder.input :based_near,
                           as: multi ? :multi_value : :string,
                           input_html: {
                             class: 'form-control'
                           },
                           hint: I18n.t('skullrax.dashboard.batch_create.hints.based_near'),
                           required: form.required?(:based_near)
      end
    end
  end
end
