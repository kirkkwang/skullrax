# frozen_string_literal: true

module Skullrax
  module BatchCreate
    class TemplatesComponent < Skullrax::BatchCreate::CardComponent
      def all_resource_types
        [collection_value] + work_types + [file_set_value]
      end

      def form_for_resource_type(resource_type)
        klass = resolve_resource_class(resource_type)
        resource = klass.new
        Hyrax::Forms::ResourceForm.for(resource:)
      end

      def form_builder(form)
        SimpleForm::FormBuilder.new(form.model_name.param_key, form, self, {})
      end

      private

      def resolve_resource_class(resource_type)
        return resource_type.constantize unless defined?(Wings)

        Wings::ModelRegistry.reverse_lookup(resource_type.constantize) ||
          resource_type.constantize
      end
    end
  end
end
