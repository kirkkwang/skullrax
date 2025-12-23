# frozen_string_literal: true

module Skullrax
  class RowProcessor
    def initialize(resources)
      @resources = resources
      @current_collection = nil
      @indices_to_skip = Set.new
    end

    def process(rows)
      @rows = rows
      process_each_row
    end

    private

    attr_reader :rows, :resources, :current_collection, :indices_to_skip

    def process_each_row
      rows.each_with_index { |row, index| process_row_at_index(row, index) }
    end

    def process_row_at_index(row, index)
      return if skip_index?(index)

      import_row(row, index)
    end

    def skip_index?(index)
      indices_to_skip.include?(index)
    end

    def import_row(row, index)
      return import_collection(row) if collection?(row)
      return import_work_with_file_sets(row, index) if work?(row)
    end

    def import_collection(row)
      generator = create_collection_generator(row)
      update_current_collection(generator.resource)
      add_to_resources(generator.resource)
    end

    def create_collection_generator(row)
      Skullrax::ValkyrieCollectionGenerator.new(**row.except(:model)).tap(&:create)
    end

    def update_current_collection(collection)
      @current_collection = collection
    end

    def add_to_resources(resource)
      resources << resource
    end

    def import_work_with_file_sets(work_row, current_index)
      file_set_rows = Skullrax::FileSetCollector.new(rows, indices_to_skip).collect_after(current_index)
      prepared_row = Skullrax::WorkRowPreparer.new(work_row, file_set_rows, current_collection).prepare
      import_prepared_work(prepared_row)
    end

    def import_prepared_work(work_row)
      generator = create_work_generator(work_row)
      add_to_resources(generator.resource)
      add_work_file_sets(generator.resource)
    end

    def create_work_generator(row)
      Skullrax::ValkyrieWorkGenerator.new(**row).tap(&:create)
    end

    def add_work_file_sets(work)
      work_file_sets(work).each { |file_set| add_to_resources(file_set) }
    end

    def work_file_sets(work)
      work.member_ids.map { |id| Hyrax.query_service.find_by(id:) }
    end

    def collection?(row)
      row[:model]&.collection?
    end

    def work?(row)
      !collection?(row) && !file_set?(row)
    end

    def file_set?(row)
      row[:model] == Hyrax::FileSet
    end
  end
end
