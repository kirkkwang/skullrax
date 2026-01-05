# frozen_string_literal: true

require 'zip'

module Skullrax
  class ZipPackager
    attr_reader :export_path, :csv_content

    def initialize(export_path:, csv_content:)
      @export_path = export_path
      @csv_content = csv_content
    end

    def package
      write_csv
      create_zip
      File.binread(zip_file_path)
    ensure
      cleanup
    end

    private

    def write_csv
      File.write(csv_file_path, csv_content)
    end

    def csv_file_path
      File.join(export_path, 'export.csv')
    end

    def create_zip
      Zip::File.open(zip_file_path, create: true) do |zipfile|
        add_files_to_zip(zipfile)
      end
    end

    def add_files_to_zip(zipfile)
      Dir.glob(File.join(export_path, '**', '*')).each do |file|
        add_file_to_zip(zipfile, file) unless File.directory?(file)
      end
    end

    def add_file_to_zip(zipfile, file)
      relative_path = Pathname.new(file).relative_path_from(export_path).to_s
      zipfile.add(relative_path, file)
    end

    def zip_file_path
      @zip_file_path ||= "#{export_path}.zip"
    end

    def cleanup
      FileUtils.rm_rf(export_path)
      FileUtils.rm_f(zip_file_path)
    end
  end
end
