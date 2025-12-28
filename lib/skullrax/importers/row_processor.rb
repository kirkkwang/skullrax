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

    def process(rows, action: :import, merge: false, autofill: false, except: [])
      @rows = rows
      @action = action
      @merge = merge
      @autofill = autofill
      @except = except

      process_each_row
      resources
    end

    def collections
      resources.select(&:collection?)
    end

    def works
      resources.select(&:work?)
    end

    def file_sets
      resources.select(&:file_set?)
    end

    private

    attr_reader :rows, :current_collection, :indices_to_skip, :merge, :autofill, :except, :action

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
      return import_collection(row, index) if row[:model]&.collection?
      return import_work_with_file_sets(row, index) if row[:model]&.work?
    end

    def import_collection(row, index)
      generator = if action == :import
                    create_collection_generator(row, index)
                  else
                    update_collection_generator(row, index)
                  end
      update_current_collection(generator.resource)
      add_to_resources(generator.resource)
    end

    def create_collection_generator(row, index)
      Skullrax::ValkyrieCollectionGenerator.new(**row.except(:model)).tap do |generator|
        generator.generate(autofill:, except:)
        add_to_errors(generator, index) if generator.errors.present?
      end
    end

    def update_collection_generator(row, index)
      Skullrax::ValkyrieCollectionGenerator.new(**row).tap do |generator|
        generator.update(merge:, autofill:, except:)
        add_to_errors(generator, index) if generator.errors.present?
      end
    end

    def update_current_collection(collection)
      @current_collection = collection
    end

    def add_to_resources(resource)
      resources << resource
    end

    def import_work_with_file_sets(work_row, current_index)
      file_set_rows = Skullrax::FileSetCollector.new(rows, indices_to_skip).collect_after(current_index)

      if action == :import
        prepared_row = Skullrax::WorkRowPreparer.new(work_row, file_set_rows, current_collection).prepare
        import_prepared_work(prepared_row, current_index)
      else
        import_prepared_work(work_row, current_index)
        update_file_sets(file_set_rows, current_index)
      end
    end

    def update_file_sets(file_set_rows, index)
      file_set_rows.each do |file_set_row|
        update_file_set_generator(file_set_row, index)
      end
    end

    def update_file_set_generator(row, index)
      Skullrax::ValkyrieFileSetGenerator.new(**row).tap do |generator|
        generator.update(merge:, autofill:, except:)
        add_to_resources(generator.resource)
        add_to_errors(generator, index) if generator.errors.present?
      end
    end

    def import_prepared_work(work_row, index)
      generator = if action == :import
                    create_work_generator(work_row, index)
                  else
                    update_work_generator(work_row, index)
                  end
      add_to_resources(generator.resource)
      add_work_file_sets(generator.resource) if action == :import
    end

    def create_work_generator(row, index)
      Skullrax::ValkyrieWorkGenerator.new(**row).tap do |generator|
        generator.generate(autofill:, except:)
        add_to_errors(generator, index) if generator.errors.present?
      end
    end

    def update_work_generator(row, index)
      Skullrax::ValkyrieWorkGenerator.new(**row).tap do |generator|
        generator.update(merge:, autofill:, except:)
        add_to_errors(generator, index) if generator.errors.present?
      end
    end

    def add_work_file_sets(work)
      work_file_sets(work).each { |file_set| add_to_resources(file_set) }
    end

    def work_file_sets(work)
      work.member_ids.map { |id| Hyrax.query_service.find_by(id:) }
    end

    def add_to_errors(generator, index)
      errors << {
        row_number: index + 2, # +2 to account for header row and 0-based index
        resource_type: generator.resource.class,
        errors: generator.errors
      }
    end
  end
end
