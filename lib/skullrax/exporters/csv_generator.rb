# frozen_string_literal: true

module Skullrax
  class CsvGenerator
    attr_reader :presenter

    def initialize(presenter:)
      @presenter = presenter
    end

    def generate
      CSV.generate(headers: true) do |csv|
        csv << presenter.headers
        presenter.rows.each { |row| csv << row_values(row) }
      end
    end

    private

    def row_values(row)
      presenter.headers.map { |header| row[header] }
    end
  end
end
