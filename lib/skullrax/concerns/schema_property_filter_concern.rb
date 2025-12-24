# frozen_string_literal: true

module Skullrax
  module SchemaPropertyFilterConcern
    def splittable_properties(model)
      filter_schema_properties(model) { |schema_key| schema_key.meta['form'].present? }
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
  end
end
