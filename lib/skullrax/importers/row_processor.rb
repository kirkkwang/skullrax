# frozen_string_literal: true

module Skullrax
  class RowProcessor
    attr_reader :resources
    attr_accessor :errors

    def initialize
      @resources = []
      @current_collection = nil
      @indices_to_skip = Set.new
      @errors = []
    end

    def process(rows, action: :create, merge: false, autofill: false, except: [])
      @rows = rows
      @action = action
      @merge = merge
      @autofill = autofill
      @except = except

      process_each_row
      resources
    end

    def collections = resources.select(&:collection?)

    def works = resources.select(&:work?)

    def file_sets = resources.select(&:file_set?)

    private

    attr_reader :current_collection, :indices_to_skip, :merge, :autofill, :except, :action
    attr_accessor :rows

    def process_each_row
      queue = destroy? ? rows_ordered_for_destruction : rows
      queue.each { |row| process_row_at_index(row) }
    end

    def process_row_at_index(row)
      return if indices_to_skip.include?(row.index)
      return destroy_row(row) if destroy?

      import_row(row)
    end

    def import_row(row)
      import_collection(row) if row.collection?
      import_work_with_file_sets(row) if row.work?
    end

    def import_collection(row)
      generator = resource_processor.generate_resource(row:)
      @current_collection = generator.resource
      resources << generator.resource
    end

    def import_work_with_file_sets(work_row)
      file_set_rows = collect_file_set_rows(work_row.index)
      return import_work_and_file_sets(work_row, file_set_rows) if create?

      update_work_and_file_sets(work_row, file_set_rows)
    end

    def collect_file_set_rows(work_index)
      FileSetCollector.new(rows, indices_to_skip).collect_after(work_index)
    end

    def import_work_and_file_sets(work_row, file_set_rows)
      prepared_row = prepare_work_row(work_row, file_set_rows)
      process_work(prepared_row)
    end

    def update_work_and_file_sets(work_row, file_set_rows)
      process_work(work_row)
      process_file_sets(file_set_rows)
    end

    def prepare_work_row(work_row, file_set_rows)
      WorkRowPreparer.new(work_row, file_set_rows, current_collection).prepare
    end

    def process_work(work_row)
      generator = resource_processor.generate_resource(row: work_row)
      resources << generator.resource
      add_work_file_sets(generator.resource) if create?
    end

    def add_work_file_sets(work)
      work_file_sets(work).each { |file_set| resources << file_set }
    end

    def work_file_sets(work)
      work.member_ids.map { |id| Hyrax.query_service.find_by(id:) }
    end

    def process_file_sets(file_set_rows)
      file_set_rows.each { |row| process_file_set(row) }
    end

    def process_file_set(row)
      generator = resource_processor.generate_resource(row:)
      resources << generator.resource
    end

    def destroy_row(row)
      resource_processor.generate_resource(row:)
    end

    def rows_ordered_for_destruction
      # Ensure file sets are processed before their parent works
      file_sets, works_and_collections = rows.partition(&:file_set?)
      file_sets + works_and_collections
    end

    def resource_processor
      @resource_processor ||=
        ResourceProcessor.new(action:, errors:, merge:, autofill:, except:)
    end

    def create? = action == :create

    def destroy? = action == :destroy
  end
end
