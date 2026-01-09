# frozen_string_literal: true

module Skullrax
  class FileAttachmentHandler
    attr_reader :file_paths, :user

    def initialize(file_paths:, user:)
      @file_paths = Array.wrap(file_paths)
      @user = user
    end

    def validate
      errors = []
      file_paths.each do |path|
        error = validate_path(path)
        errors << error unless error.nil?
      end
      errors
    end

    def upload
      file_paths.map { |path| create_uploaded_file(path) }
    end

    def uploaded_file_ids
      upload.map(&:id)
    end

    private

    def validate_path(path)
      return nil if path.blank?

      if path.to_s.start_with?('http')
        validate_remote_url(path)
      elsif File.exist?(path)
        nil
      else
        "File not found: #{path}"
      end
    end

    def validate_remote_url(url)
      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 2) do |http|
        http.head(uri.request_uri)
      end

      return nil if response.is_a?(Net::HTTPSuccess)

      "Remote file unreachable (#{response.code}): #{url}"
    rescue URI::InvalidURIError
      "Invalid URL format: #{url}"
    rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout => e
      "Remote file connection failed: #{e.message}"
    end

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
