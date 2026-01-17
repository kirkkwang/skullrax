# frozen_string_literal: true

module Skullrax
  class BatchCreateController < ApplicationController
    def create
      perform_import
      resolve_request
    end

    private

    def perform_import
      importer.import(autofill:, fill_required:)
    end

    def resolve_request
      importer.errors.empty? ? handle_success : handle_failure
    end

    def handle_success
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
      Skullrax::ParamsToCsvConverterService.new(params: params[:resources].permit!.to_h).to_csv
    end

    def autofill
      params[:autofill] == 'true'
    end

    # Realistically, if autofill is true, we would want to fill
    # required fields as well when importing through batch create
    def fill_required
      autofill
    end
  end
end
