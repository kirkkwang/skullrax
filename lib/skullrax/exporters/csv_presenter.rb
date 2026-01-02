# frozen_string_literal: true

module Skullrax
  class CsvPresenter
    include SchemaPropertyFilterConcern

    attr_reader :resources, :rows, :delimiter

    def initialize(resources:, delimiter:)
      @resources = resources
      @delimiter = delimiter
      @rows = []
      present
    end

    def headers
      all_keys = rows.flat_map(&:keys).uniq
      fixed_columns = %i[model id]
      vis_headers = Skullrax::VisibilityHandler.headers
      present_vis_headers = vis_headers & all_keys
      middle_columns = all_keys - fixed_columns - present_vis_headers
      fixed_columns + middle_columns + present_vis_headers
    end

    private

    def present
      resources.each { |resource| create_row_from(resource) }
    end

    def create_row_from(resource)
      row = relevant_attributes_for(resource)
      @rows << conform_row(resource, row)
    end

    def relevant_attributes_for(resource)
      attrs = resource.attributes.select do |key, value|
        splittable_properties(resource.class).include?(key) && value.present?
      end

      attrs.merge(Skullrax::VisibilityHandler.extract(resource))
    end

    def conform_row(resource, row)
      row.tap do |hash|
        hash[:model] = resource.class
        hash[:id] = resource.id
        join_values(hash)
      end
    end

    def join_values(hash)
      hash.transform_values! { |value| Array.wrap(value).join(delimiter) }
    end
  end
end
