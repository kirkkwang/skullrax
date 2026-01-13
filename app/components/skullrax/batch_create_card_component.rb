# frozen_string_literal: true

module Skullrax
  class BatchCreateCardComponent < ViewComponent::Base
    def batch_create_path
      helpers.skullrax.batch_create_path
    end

    def work_options
      safe_join(
        work_types.map do |work_type|
          content_tag(:option, work_type.split('::').last.titleize, value: work_type)
        end
      )
    end

    def all_resource_types
      [collection_value] + work_types + [file_set_value]
    end

    def form_for_resource_type(resource_type)
      klass = Wings::ModelRegistry.reverse_lookup(resource_type.constantize) || resource_type.constantize
      resource = klass.new
      Hyrax::Forms::ResourceForm.for(resource:)
    end

    private

    def work_types
      Hyrax.config.registered_curation_concern_types
    end

    def collection_value
      Hyrax.config.collection_class.to_s
    end

    def file_set_value
      Hyrax.config.file_set_class.to_s
    end
  end
end
