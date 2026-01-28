# frozen_string_literal: true

module Skullrax
  class FileAttachmentHandler
    attr_reader :file_paths, :user

    def initialize(file_paths:, user:)
      @file_paths = Array.wrap(file_paths).flat_map { |path| path.to_s.split(';') }
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
        I18n.t('skullrax.errors.file_not_found', path:)
      end
    end

    def validate_remote_url(url)
      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 2) do |http|
        http.head(uri.request_uri)
      end

      return nil if response.is_a?(Net::HTTPSuccess)

      I18n.t('skullrax.errors.remote_file_unreachable', code: response.code, url:)
    rescue URI::InvalidURIError
      I18n.t('skullrax.errors.invalid_url_format', url:)
    rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout => e
      I18n.t('skullrax.errors.remote_connection_failed', message: e.message)
    end

    def create_uploaded_file(path)
      file = path.to_s.start_with?('http') ? download_file(path) : File.open(path)

      Hyrax::UploadedFile.create(file:, user:)
    end

    def download_file(url)
      uri = URI.parse(url)
      tempfile = Tempfile.new('skullrax')
      tempfile.binmode

      response = fetch_remote_file(uri, tempfile)
      tempfile.rewind

      wrap_with_filename(tempfile, uri, response)
    end

    def fetch_remote_file(uri, tempfile)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        response = http.request_get(uri.path)
        tempfile.write(response.body)
        response
      end
    end

    def wrap_with_filename(tempfile, uri, response)
      filename = extract_filename(uri, response)
      content_type = response['content-type'] || 'application/octet-stream'

      ActionDispatch::Http::UploadedFile.new(
        tempfile:,
        filename:,
        type: content_type
      )
    end

    def extract_filename(uri, response)
      filename = filename_from_header(response) || File.basename(uri.path)
      add_extension_if_missing(filename, response['content-type'])
    end

    def filename_from_header(response)
      response['content-disposition']&.match(/filename="?([^"]+)"?/)&.captures&.first
    end

    def add_extension_if_missing(filename, content_type)
      return filename if File.extname(filename).present?
      return filename unless content_type

      extension = Mime::Type.lookup(content_type)&.symbol
      extension ? "#{filename}.#{extension}" : filename
    end
  end
end
