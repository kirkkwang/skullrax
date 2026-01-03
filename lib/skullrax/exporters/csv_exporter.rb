# frozen_string_literal: true

module Skullrax
  class CsvExporter
    attr_reader :ids, :export_path, :csv

    def initialize(ids:, export_path: nil)
      @ids = ids
      @export_path = export_path || default_export_path
      @csv = nil
    end

    def export(include_files: false, delimiter: ';')
      prepare_export_directory if include_files

      @csv = generate_csv(include_files:, delimiter:)

      include_files ? package_with_files(csv) : csv
    end

    private

    def default_export_path
      Rails.root.join('tmp', 'exports', "export_#{timestamp}")
    end

    def timestamp
      Time.now.strftime('%Y%m%d%H%M%S')
    end

    def prepare_export_directory
      FileUtils.mkdir_p(export_path)
    end

    def generate_csv(include_files:, delimiter:)
      presenter = build_presenter(include_files:, delimiter:)
      Skullrax::CsvGenerator.new(presenter:).generate
    end

    def build_presenter(include_files:, delimiter:)
      resources = fetch_resources
      Skullrax::CsvPresenter.new(resources:, delimiter:, export_path:, include_files:)
    end

    def fetch_resources
      Skullrax::ResourceFetcher.fetch(ids:)
    end

    def package_with_files(csv_content)
      Skullrax::ZipPackager.new(export_path:, csv_content:).package
    end
  end
end
