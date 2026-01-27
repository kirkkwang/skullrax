# frozen_string_literal: true

module Skullrax
  class FileSetParamsBuilder
    attr_reader :file_paths, :file_set_params, :user

    def initialize(file_paths:, file_set_params:, user:)
      @file_paths = Array.wrap(file_paths)
      @file_set_params = Array.wrap(file_set_params)
      @user = user
    end

    def uploaded_file_ids
      return [] if file_paths.empty?

      @uploaded_file_ids ||= file_uploader.uploaded_file_ids
    end

    def formatted_file_set_params
      return [] if file_set_params.empty?

      uploaded_ids = uploaded_file_ids
      file_set_params.each_with_index.map { |params, index| format_single_params(params, uploaded_ids[index]) }
    end

    private

    def file_uploader
      @file_uploader ||= Skullrax::FileAttachmentHandler.new(file_paths:, user:)
    end

    def format_single_params(params, uploaded_id)
      normalized = params.transform_values { |v| Array.wrap(v) }
      normalized[:visibility] = normalize_visibility(normalized) if normalized[:visibility]
      normalized[:uploaded_file_id] = uploaded_id.to_s if uploaded_id
      ActionController::Parameters.new(normalized)
    end

    def normalize_visibility(normalized)
      unwrapped = normalized.transform_values { |v| Array.wrap(v).first }
      Skullrax::VisibilityHandler.normalize_for_file_set(unwrapped)
    end
  end
end
