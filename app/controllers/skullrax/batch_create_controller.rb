# frozen_string_literal: true

module Skullrax
  class BatchCreateController < ApplicationController
    def create
      perform_import
      resolve_request
    ensure
      cleanup_uploaded_files
    end

    private

    def perform_import
      importer.import(autofill:, fill_required:, dry_run: download_form_as_csv)
    end

    def resolve_request
      importer.errors.empty? ? handle_success : handle_failure
    end

    def handle_success
      return send_csv if download_form_as_csv

      redirect_to skullrax.root_path, notice: t('.success', count: importer.resources.count)
    end

    def handle_failure
      flash[:error] = Skullrax::ErrorFormatterService.format(errors: importer.errors)
      redirect_to skullrax.root_path
    end

    def importer
      @importer ||= Skullrax::CsvImporter.new(csv: csv_string, user: current_user)
    end

    def csv_string
      Skullrax::ParamsToCsvConverterService.new(params: params[:resources].permit!.to_h, batch_uploads_dir:).to_csv
    end

    def batch_uploads_dir
      @batch_uploads_dir ||= Rails.root.join('tmp', 'skullrax_batch_uploads', batch_id)
    end

    def batch_id
      @batch_id ||= SecureRandom.hex(8)
    end

    def cleanup_uploaded_files
      FileUtils.rm_rf(batch_uploads_dir) if batch_uploads_dir && File.exist?(batch_uploads_dir)
    end

    def send_csv
      send_data importer.csv, filename: "batch_create_form_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    end

    def autofill
      params[:autofill] == 'true'
    end

    # Realistically, if autofill is true, we would want to fill
    # required fields as well when importing through batch create
    def fill_required
      autofill
    end

    def download_form_as_csv
      params['download-form-as-csv'] == 'true'
    end
  end
end
