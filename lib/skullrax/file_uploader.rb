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
      file = path.to_s.start_with?('http') ? download_file(path) : File.open(path)

      Hyrax::UploadedFile.create(file:, user:)
    end

    def download_file(url)
      tempfile = Tempfile.new(['skullrax', File.extname(url)])
      tempfile.binmode

      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        response = http.request_get(uri.path)
        tempfile.write(response.body)
      end

      tempfile.rewind
      tempfile
    end
  end
end
