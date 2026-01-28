# frozen_string_literal: true

module Skullrax
  module SchemaPropertyFilterConcern
    def splittable_properties(model)
      filter_schema_properties(model) { |schema_key| form_present?(schema_key) && display_form?(schema_key) }
    end

    def required_properties(model)
      filter_schema_properties(model) { |schema_key| schema_key.meta.dig('form', 'required') }
    end

    private

    def filter_schema_properties(model, &block)
      schema_for(model).filter_map { |schema_key| schema_key.name if block.call(schema_key) }
    end

    def schema_for(model)
      model.new.singleton_class&.schema || model.schema
    end

    def form_present?(schema_key)
      schema_key.meta['form'].present?
    end

    def display_form?(schema_key)
      schema_key.meta.dig('form', 'display') != false
    end
  end
end
