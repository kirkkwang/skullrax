# frozen_string_literal: true

module Skullrax
  class FileSetParamsBuilder
    attr_reader :file_paths, :file_set_params, :user

    def initialize(file_paths, file_set_params, user)
      @file_paths = Array.wrap(file_paths)
      @file_set_params = Array.wrap(file_set_params)
      @user = user
    end

    def uploaded_file_ids
      return [] if file_paths.empty?

      file_uploader.uploaded_file_ids
    end

    def formatted_file_set_params
      return [] if file_set_params.empty?

      file_set_params.map do |params|
        normalized = params.transform_values { |v| Array.wrap(v) }
        ActionController::Parameters.new(normalized)
      end
    end

    private

    def file_uploader
      @file_uploader ||= FileUploader.new(file_paths, user)
    end
  end
end
