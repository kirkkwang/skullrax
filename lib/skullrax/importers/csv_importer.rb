# frozen_string_literal: true

require 'csv'

module Skullrax
  class CsvImporter
    delegate :resources, :collections, :works, :file_sets, :errors, to: :processor

    attr_reader :csv, :delimiter

    def initialize(csv:, delimiter: ';')
      @csv = csv
      @delimiter = delimiter
    end

    def import(autofill: false, except: [])
      parse_csv
      processor.process(rows, autofill:, except:)
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

    def parsed_rows
      Skullrax::CsvParser.new(importer: self).parse
    end

    def processor
      @processor ||= Skullrax::RowProcessor.new
    end
  end
end
