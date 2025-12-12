# frozen_string_literal: true

module Skullrax
  class FileUploader
    attr_reader :file_paths, :user

    def initialize(file_paths, user)
      @file_paths = Array.wrap(file_paths)
      @user = user
    end

    def upload
      file_paths.map { |path| create_uploaded_file(path) }
    end

    def uploaded_file_ids
      upload.map(&:id)
    end

    private

    def create_uploaded_file(path)
      Hyrax::UploadedFile.create(
        file: File.open(path),
        user:
      )
    end
  end
end
