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
          render_field_input(term:, hint: I18n.t('skullrax.dashboard.batch_create.hints.based_near'))
        # Remove required terms for file sets
        elsif term == :id
          render_field_input(term:, multi: false, required: false, hint: id_hint, label: 'ID', pattern: id_pattern)
        elsif required_file_set_term?(term)
          render_field_input(term:, required: false)
        else
          render_edit_field_partial(term, f: form_builder, curation_concern: form.model_class)
        end
      end

      def primary_terms
        form.primary_terms + [:id]
      end

      private

      attr_reader :form, :form_builder

      delegate :secondary_terms, :display_additional_fields?, :model_class, to: :form
      delegate :render_edit_field_partial, to: :helpers

      def required_file_set_term?(term)
        form.model_class == Hyrax.config.file_set_class && form.required?(term)
      end

      def render_field_input( # rubocop:disable Metrics/ParameterLists
        term:,
        multi: form.multiple?(term),
        required: form.required?(term),
        hint: I18n.t("simple_form.hints.defaults.#{term}"),
        label: nil,
        pattern: nil
      )
        form_builder.input term,
                           as: multi ? :multi_value : :string,
                           input_html: { class: 'form-control' },
                           hint:,
                           required:,
                           label:,
                           pattern:
      end

      def id_hint = I18n.t('skullrax.dashboard.batch_create.hints.id')

      def id_pattern = '^[a-zA-Z0-9_\-.]+$'
    end
  end
end
