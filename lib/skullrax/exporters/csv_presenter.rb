# frozen_string_literal: true

module Skullrax
  class CsvPresenter
    attr_reader :resources, :delimiter, :include_files, :export_path

    def initialize(resources:, delimiter:, export_path:, include_files: false)
      @resources = resources
      @delimiter = delimiter
      @include_files = include_files
      @export_path = export_path
    end

    def headers
      @headers ||= Skullrax::HeaderBuilder.new(rows:, include_files:).build
    end

    def rows
      @rows ||= resources.map { |resource| build_row(resource) }
    end

    private

    def build_row(resource)
      Skullrax::RowBuilder.new(resource:, delimiter:, file_handler:).build
    end

    def file_handler
      @file_handler ||= build_file_handler if include_files
    end

    def build_file_handler
      Skullrax::FileHandler.new(base_path: export_path) if export_path
    end
  end
end
