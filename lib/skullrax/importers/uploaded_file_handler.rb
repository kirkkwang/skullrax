# frozen_string_literal: true

require 'zip'
require 'tmpdir'

module Skullrax
  class UploadedFileHandler
    class Error < StandardError; end

    Result = Struct.new(:csv_content, :files_path)

    def self.call(file)
      new(file).process
    end

    def initialize(file)
      @file = file
    end

    def process
      return nil unless @file.present?

      zip_file? ? extract_zip : extract_csv
    end

    private

    attr_reader :file

    def zip_file?
      filename = file.original_filename.downcase
      filename.end_with?('.zip') || file.content_type == 'application/zip'
    end

    def extract_csv
      Result.new(force_utf8(file.read), nil)
    end

    def extract_zip
      Skullrax::ZipExtractor.new(file:).extract
    end

    def force_utf8(string)
      string.force_encoding('UTF-8').gsub("\xEF\xBB\xBF", '')
    end
  end
end
