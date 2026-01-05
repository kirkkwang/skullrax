# frozen_string_literal: true

module Skullrax
  class ExportsController < ApplicationController
    def create
      ids = fetch_ids
      return redirect_to skullrax.root_path, alert: 'Please enter at least one ID.' if ids.empty?

      generate_and_send(ids, include_files?)
    end

    private

    def fetch_ids
      export_params[:ids]&.split("\n")&.map(&:strip)&.reject(&:empty?) || []
    end

    def generate_and_send(ids, include_files)
      exporter = Skullrax::CsvExporter.new(ids:)
      data = exporter.export(include_files:)

      send_data(
        data,
        filename: "export-#{Date.today}.#{extension(include_files)}",
        type: mime_type(include_files),
        disposition: 'attachment'
      )
    end

    def include_files?
      export_params[:include_files] == '1'
    end

    def mime_type(zip_mode)
      zip_mode ? 'application/zip' : 'text/csv'
    end

    def extension(zip_mode)
      zip_mode ? 'zip' : 'csv'
    end

    def export_params
      params.permit(:ids, :include_files)
    end
  end
end
