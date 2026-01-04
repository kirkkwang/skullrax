# frozen_string_literal: true

module Skullrax
  class ImportsController < ApplicationController
    def create
      uploaded_file = import_params[:file]
      return redirect_with_alert('Please select a file.') unless uploaded_file.present?

      service = Skullrax::ImportService.new(uploaded_file:).call

      if service.success?
        redirect_with_notice('Import completed successfully.')
      else
        redirect_with_alert(service.error_message)
      end
    end

    private

    def redirect_with_notice(message)
      redirect_to skullrax.root_path, notice: message
    end

    def redirect_with_alert(message)
      redirect_to skullrax.root_path, alert: message
    end

    def import_params
      params.require(:import).permit(:file)
    end
  end
end
