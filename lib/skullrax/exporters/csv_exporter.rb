# frozen_string_literal: true

require 'zip'

module Skullrax
  class CsvExporter
    attr_reader :ids, :delimiter, :include_files, :export_path
    attr_accessor :resources, :csv

    delegate :headers, :rows, to: :presenter

    def initialize(ids:, export_path: nil)
      @ids = ids
      @export_path = export_path || Rails.root.join('tmp', 'exports', "export_#{Time.now.strftime('%Y%m%d%H%M%S')}")
      @resources = nil
      @csv = nil
    end

    def export(include_files: false, delimiter: ';')
      @include_files = include_files
      @delimiter = delimiter

      FileUtils.mkdir_p(export_path) if include_files

      find_resources
      self.csv = generate_csv

      return csv unless include_files

      package_zip
    ensure
      FileUtils.rm_rf(export_path) if include_files
    end

    private

    def find_resources
      self.resources = Skullrax::ResourceFetcher.fetch(ids:)
    end

    def generate_csv
      CSV.generate(headers: true) do |csv|
        csv << headers
        rows.each { |row| csv << headers.map { |header| row[header] } }
      end
    end

    def package_zip
      File.write(File.join(export_path, 'export.csv'), csv)

      zip_file_path = "#{export_path}.zip"

      Zip::File.open(zip_file_path, create: true) do |zipfile|
        Dir.glob(File.join(export_path, '**', '*')).each do |file|
          next if File.directory?(file)

          relative_path = Pathname.new(file).relative_path_from(export_path).to_s
          zipfile.add(relative_path, file)
        end
      end

      zip_file_path
    end

    def presenter
      @presenter ||= Skullrax::CsvPresenter.new(resources:, delimiter:, include_files:, export_path:)
    end
  end
end
