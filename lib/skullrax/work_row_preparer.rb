# frozen_string_literal: true

module Skullrax
  class WorkRowPreparer
    def initialize(work_row, file_set_rows, current_collection)
      @work_row = work_row
      @file_set_rows = file_set_rows
      @current_collection = current_collection
    end

    def prepare
      assign_collection
      return work_row if file_set_rows.empty?

      work_row.merge(file_set_data)
    end

    private

    attr_reader :work_row, :file_set_rows, :current_collection

    def assign_collection
      work_row[:member_of_collection_ids] ||= current_collection_id
    end

    def current_collection_id
      current_collection&.id&.to_s
    end

    def file_set_data
      {
        file_paths: extract_file_paths,
        file_set_params: extract_file_set_params
      }
    end

    def extract_file_paths
      file_set_rows.map { |row| row[:file_paths] }.compact
    end

    def extract_file_set_params
      file_set_rows.map { |row| file_set_metadata(row) }
    end

    def file_set_metadata(file_set_row)
      file_set_row.except(:model, :file_paths)
    end
  end
end
