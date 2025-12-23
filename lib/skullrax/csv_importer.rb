# frozen_string_literal: true

require 'csv'

module Skullrax
  class CsvImporter
    attr_reader :csv, :resources, :delimiter

    def initialize(csv:, delimiter: ';')
      @csv = csv
      @resources = []
      @processor = Skullrax::RowProcessor.new(resources)
      @delimiter = delimiter
    end

    def import
      parse_csv
      process_rows

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

    attr_reader :rows, :processor

    def parse_csv
      validate_csv_input!
      @rows = parsed_rows
    end

    def validate_csv_input!
      raise Skullrax::ArgumentError, 'CSV input must be a String' unless csv.is_a?(String)
    end

    def parsed_rows
      Skullrax::CsvParser.new(importer: self).parse
    end

    def process_rows
      processor.process(rows)
    end
  end
end
