# frozen_string_literal: true

module Skullrax
  class ImportService
    def initialize(uploaded_file:)
      @uploaded_file = uploaded_file
      @result = nil
      @error_message = nil
    end

    def call
      process_import
      self
    ensure
      cleanup_files
    end

    def success?
      @error_message.nil?
    end

    attr_reader :error_message

    private

    attr_reader :uploaded_file, :result

    def process_import
      @result = Skullrax::UploadedFileHandler.call(uploaded_file)
      run_importer
    rescue Skullrax::UploadedFileHandler::Error => e
      @error_message = "File Error: #{e.message}"
    end

    def run_importer
      importer = build_importer
      importer.import

      @error_message = Skullrax::ErrorFormatterService.format(errors: importer.errors) unless importer.errors.empty?
    end

    def build_importer
      Skullrax::CsvImporter.new(
        csv: result.csv_content,
        files_path: result.files_path
      )
    end

    def cleanup_files
      return unless result&.files_path
      return unless Dir.exist?(result.files_path)

      FileUtils.remove_entry(result.files_path)
    end
  end
end
