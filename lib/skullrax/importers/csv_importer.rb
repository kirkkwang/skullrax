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
      validate_csv_input!
      @action = :create

      processor.process(parser.parse, autofill:, except:)
    end

    def update(merge: false, autofill: false, except: [])
      validate_csv_input!
      @action = :update

      parser.validate_ids_present!
      parser.found_resources = ResourceFetcher.fetch(ids: parser.raw_ids)

      processor.process(parser.parse, action:, merge:, autofill:, except:)
    end

    def destroy
      validate_csv_input!
      @action = :destroy

      parser.validate_ids_present!
      parser.found_resources = ResourceFetcher.fetch(ids: parser.raw_ids)

      processor.process(parser.parse, action:)
    end

    private

    def validate_csv_input!
      raise Skullrax::ArgumentError, 'CSV input must be a String' unless csv.is_a?(String)
    end

    def parser
      @parser ||= Skullrax::CsvParser.new(csv:, delimiter:, action:)
    end

    def processor
      @processor ||= Skullrax::RowProcessor.new
    end
  end
end
