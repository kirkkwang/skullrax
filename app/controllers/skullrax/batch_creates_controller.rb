# frozen_string_literal: true

module Skullrax
  class BatchCreatesController < ApplicationController
    def create
      redirect_to skullrax.root_path, notice: 'Batch create coming soon!'
    end

    private

    def batch_create_params
      params.permit(
        :resource_type,
        collection: %i[title description],
        works: [
          :title,
          :creator,
          :description,
          { files: [] }
        ]
      )
    end
  end
end
