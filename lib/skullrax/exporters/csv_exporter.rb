# frozen_string_literal: true

module Skullrax
  class CsvExporter
    attr_reader :ids, :delimiter, :include_files
    attr_accessor :resources, :csv

    def initialize(ids:)
      @ids = ids

      @resources = nil
      @csv = nil
    end

    def export(include_files: false, delimiter: ';')
      @include_files = include_files
      @delimiter = delimiter
      find_resources
      self.csv = export_csv
    end

    private

    def find_resources
      self.resources = Skullrax::ResourceFetcher.fetch(ids:)
    end

    def export_csv
      headers = presenter.headers
      rows = presenter.rows

      CSV.generate(headers: true) do |csv|
        csv << headers

        rows.each do |row|
          csv << headers.map { |header| row[header] }
        end
      end
    end

    def presenter
      @presenter ||= CsvPresenter.new(resources:, delimiter:)
    end
  end
end
