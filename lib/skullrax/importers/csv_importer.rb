# frozen_string_literal: true

require 'csv'

module Skullrax
  class CsvImporter
    delegate :resources, :collections, :works, :file_sets, :errors, to: :processor

    attr_reader :csv, :delimiter, :action, :found_resources

    def initialize(csv:, delimiter: ';')
      @csv = csv
      @delimiter = delimiter
    end

    def import(autofill: false, except: [])
      parse_csv
      processor.process(rows, autofill:, except:)
    end

    def update(merge: false, autofill: false, except: [])
      @action = :update
      parse_csv
      @found_resources = validate_for_update!
      override_models_in_rows!
      processor.process(rows, action:, merge:, autofill:, except:)
    end

    private

    attr_reader :rows

    def parse_csv
      validate_csv_input!
      @rows = parsed_rows
    end

    def validate_csv_input!
      raise Skullrax::ArgumentError, 'CSV input must be a String' unless csv.is_a?(String)
    end

    def override_models_in_rows!
      found_resources_by_id = found_resources.index_by { |r| r.id.to_s }

      rows.each do |row|
        next unless row[:id].present?

        existing_resource = found_resources_by_id[row[:id].to_s]
        row[:model] = existing_resource.class if existing_resource
      end
    end

    def validate_for_update!
      missing_ids = rows.select { |row| row[:id].blank? }
      return validate_all_ids_exist! unless missing_ids.any?

      raise Skullrax::ArgumentError, "Update requires ID column for all rows. #{missing_ids.count} rows missing IDs."
    end

    def validate_all_ids_exist!
      all_ids = rows.map { |row| row[:id] }
      found_resources = Hyrax.query_service.find_many_by_ids(ids: all_ids).to_a
      found_ids = found_resources.map(&:id).map(&:to_s)

      missing_ids = all_ids - found_ids

      if missing_ids.any?
        raise Skullrax::ObjectNotFoundError,
              "Cannot update: #{missing_ids.count} IDs not found: #{missing_ids.join(', ')}"
      end

      found_resources
    end

    def parsed_rows
      Skullrax::CsvParser.new(importer: self).parse
    end

    def processor
      @processor ||= Skullrax::RowProcessor.new
    end
  end
end
