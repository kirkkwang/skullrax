# frozen_string_literal: true

module Skullrax
  class CsvPresenter
    include SchemaPropertyFilterConcern

    attr_reader :resources, :rows, :delimiter, :include_files, :file_handler

    def initialize(resources:, delimiter:, export_path:, include_files: false)
      @resources = resources
      @delimiter = delimiter
      @include_files = include_files
      @rows = []
      @file_handler = Skullrax::Exporters::FileHandler.new(base_path: export_path) if include_files && export_path

      present
    end

    def headers
      @headers ||= begin
        all_keys = rows.flat_map(&:keys).uniq
        fixed_columns = %i[model id]
        vis_headers = Skullrax::VisibilityHandler.headers
        present_vis_headers = vis_headers & all_keys
        middle_columns = all_keys - fixed_columns - present_vis_headers - [:file]
        final_headers = fixed_columns + middle_columns + present_vis_headers
        final_headers << :file if include_files

        final_headers
      end
    end

    private

    def present
      resources.each { |resource| create_row_from(resource) }
    end

    def create_row_from(resource)
      row = relevant_attributes_for(resource)
      add_file_info(resource, row) if include_files && resource.file_set?
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

    def add_file_info(resource, row)
      row[:file] = file_handler&.download(resource)
    end

    # def path_to_file_for(resource)
    #   return unless resource.original_file

    #   File.join(resource.id.to_s, resource.original_file.original_filename)
    # end
  end
end
