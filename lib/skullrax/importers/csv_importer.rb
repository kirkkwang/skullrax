# frozen_string_literal: true

require 'csv'

module Skullrax
  class CsvImporter
    delegate :resources, :collections, :works, :file_sets, :errors, to: :processor

    attr_reader :csv, :delimiter, :action, :found_resources, :files_path, :user

    def initialize(csv:, files_path: nil, delimiter: ';', user: nil)
      @csv = csv
      @files_path = files_path
      @delimiter = delimiter
      @user = user
    end

    def import(dry_run: false, autofill: false, fill_required: false, except: [])
      validate_csv_input!
      @action = :create

      processor.process(parser.parse, dry_run:, autofill:, fill_required:, except:)
    rescue Skullrax::CsvParsingError => e
      errors << e.message
    end

    def update(dry_run: false, merge: false, autofill: false, except: [])
      validate_csv_input!
      @action = :update

      parser.validate_ids_present!
      parser.found_resources = ResourceFetcher.fetch(ids: parser.raw_ids)

      processor.process(parser.parse, action:, dry_run:, merge:, autofill:, except:)
    rescue Skullrax::CsvParsingError, Skullrax::ObjectNotFoundError => e
      errors << e.message
    end

    def destroy(dry_run: false)
      validate_csv_input!
      @action = :destroy

      parser.validate_ids_present!
      parser.found_resources = ResourceFetcher.fetch(ids: parser.raw_ids)

      processor.process(parser.parse, action:, dry_run:)
    rescue Skullrax::CsvParsingError, Skullrax::ObjectNotFoundError => e
      errors << e.message
    end

    private

    def validate_csv_input!
      raise Skullrax::ArgumentError, I18n.t('skullrax.errors.csv_must_be_string') unless csv.is_a?(String)
    end

    def parser
      @parser ||= Skullrax::CsvParser.new(csv:, delimiter:, action:)
    end

    def processor
      @processor ||= Skullrax::RowProcessor.new(files_path:, user:)
    end
  end
end
