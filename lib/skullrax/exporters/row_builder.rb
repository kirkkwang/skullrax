# frozen_string_literal: true

module Skullrax
  class RowBuilder
    include SchemaPropertyFilterConcern

    attr_reader :resource, :delimiter, :file_handler

    def initialize(resource:, delimiter:, file_handler: nil)
      @resource = resource
      @delimiter = delimiter
      @file_handler = file_handler
    end

    def build
      base_row
        .merge(visibility_attributes)
        .merge(file_attributes)
        .then { |row| conform_row(row) }
    end

    private

    def base_row
      resource.attributes.select do |key, value|
        splittable_properties(resource.class).include?(key) && value.present?
      end
    end

    def visibility_attributes
      Skullrax::VisibilityHandler.extract(resource)
    end

    def file_attributes
      return {} unless file_handler && resource.file_set?

      { file: file_handler.download(resource) }
    end

    def conform_row(row)
      {
        model: resource.class,
        id: resource.id
      }.merge(joined_values(row))
    end

    def joined_values(row)
      row.transform_values { |value| Array.wrap(value).join(delimiter) }
    end
  end
end
