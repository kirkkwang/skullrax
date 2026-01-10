# frozen_string_literal: true

module Skullrax
  class ZipExtractor
    def initialize(file:)
      @file = file
      @extract_path = nil
    end

    def extract
      create_temp_directory
      extract_entries
      validate_csv_present
      build_result
    rescue Zip::Error, StandardError => e
      cleanup
      raise Skullrax::UploadedFileHandler::Error,
            I18n.t('skullrax.errors.zip_extraction_failed', message: e.message)
    end

    private

    attr_reader :file, :extract_path, :csv_content

    def create_temp_directory
      @extract_path = Dir.mktmpdir('skullrax_import_')
    end

    def extract_entries
      Zip::File.open(file.path) do |zip_file|
        zip_file.each { |entry| extract_entry(entry) }
      end
    end

    def extract_entry(entry)
      return if skip_entry?(entry)

      destination = build_destination_path(entry)
      write_entry(entry, destination)
      capture_csv_content(destination, entry.name)
    end

    def skip_entry?(entry)
      junk_file?(entry.name) || entry.directory?
    end

    def junk_file?(name)
      name =~ /__MACOSX/ || name =~ /\.DS_Store/
    end

    def build_destination_path(entry)
      clean_name = sanitize_entry_name(entry.name)
      File.join(extract_path, clean_name)
    end

    def sanitize_entry_name(name)
      name.gsub('\\', '/').sub(%r{\A/}, '')
    end

    def write_entry(entry, destination)
      FileUtils.mkdir_p(File.dirname(destination))

      entry.get_input_stream do |input_stream|
        File.open(destination, 'wb') do |output_file|
          IO.copy_stream(input_stream, output_file)
        end
      end
    end

    def capture_csv_content(destination, entry_name)
      return unless csv_file?(entry_name)

      @csv_content = File.read(destination)
    end

    def csv_file?(name)
      name.match?(/\.[cC][sS][vV]$/)
    end

    def validate_csv_present
      return if csv_content

      cleanup
      raise Skullrax::UploadedFileHandler::Error, I18n.t('skullrax.errors.no_csv_in_zip')
    end

    def build_result
      Skullrax::UploadedFileHandler::Result.new(force_utf8(csv_content), extract_path)
    end

    def cleanup
      return unless extract_path && Dir.exist?(extract_path)

      FileUtils.remove_entry(extract_path)
    end

    def force_utf8(string)
      string.force_encoding('UTF-8').gsub("\xEF\xBB\xBF", '')
    end
  end
end
