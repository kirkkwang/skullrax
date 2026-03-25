# frozen_string_literal: true

require 'open3'

module Skullrax
  class DerivativesHandler # rubocop:disable Metrics/ClassLength
    attr_reader :file_set_id

    def initialize(file_set_id)
      @file_set_id = file_set_id
    end

    def list
      file_set = find_file_set
      original = find_original_file(file_set)
      mime_type = Array(original.mime_type).first
      existing_derivatives = existing_derivatives(file_set)

      {
        file_set_id:,
        mime_type:,
        existing_derivatives:,
        imagemagick_writable_formats:
      }
    end

    def regenerate
      file_set = find_file_set
      original = find_original_file(file_set)
      derivatives = Hyrax.custom_queries.find_files(file_set:).reject { |f| original_file?(f) }

      delete_derivatives(derivatives, file_set)

      ValkyrieCreateDerivativesJob.perform_later(file_set.id.to_s, original.id.to_s)

      {
        file_set_id:,
        status: 'enqueued',
        message: "Cleaned up #{derivatives.size} derivative(s). Regeneration job enqueued."
      }
    end

    def create(derivative_type, mime_type) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      file_set = find_file_set
      original = find_original_file(file_set)
      source_mime = Array(original.mime_type).first

      unless source_mime.to_s.start_with?('image/')
        raise Skullrax::ArgumentError,
              "Derivative type '#{derivative_type}' is not compatible with mime type '#{source_mime}'"
      end

      normalized = format_aliases.fetch(derivative_type.downcase, derivative_type.upcase)
      unless imagemagick_writable_formats.include?(normalized)
        raise Skullrax::ArgumentError,
              "Unsupported format: '#{derivative_type}'. Not a writable ImageMagick format."
      end

      Skullrax::CreateSpecificDerivativeJob.perform_later(original.id.to_s, derivative_type, mime_type)

      {
        file_set_id:,
        derivative_type:,
        status: 'enqueued'
      }
    end

    def delete(file_id) # rubocop:disable Metrics/MethodLength
      file_set = find_file_set
      derivative = find_derivative(file_set, file_id)
      guard_original_file!(derivative)

      delete_derivatives([derivative], file_set)

      {
        file_set_id:,
        file_id:,
        status: 'deleted',
        filename: derivative.original_filename,
        pcdm_use: pcdm_use_label(derivative),
        mime_type: Array(derivative.mime_type).first
      }
    end

    private

    def find_file_set
      Hyrax.query_service.find_by(id: file_set_id)
    rescue Valkyrie::Persistence::ObjectNotFoundError
      raise Skullrax::ArgumentError, "FileSet not found: #{file_set_id}"
    end

    def find_original_file(file_set)
      files = Hyrax.custom_queries.find_files(file_set:)
      original = files.find { |f| original_file?(f) }
      raise Skullrax::ArgumentError, "No original file found on FileSet #{file_set_id}" unless original

      original
    end

    def find_derivative(file_set, file_id)
      Hyrax.custom_queries.find_files(file_set:)
           .find { |f| f.id.to_s == file_id.to_s }
           .tap { |d| raise Skullrax::ArgumentError, "File ID #{file_id} not found on FileSet #{file_set_id}" unless d }
    end

    def guard_original_file!(file_metadata)
      raise Skullrax::ArgumentError, 'Cannot delete the original file' if original_file?(file_metadata)
    end

    def original_file?(file_metadata)
      Array(file_metadata.pcdm_use).any? { |u| u.to_s.end_with?('OriginalFile') }
    end

    def pcdm_use_label(file_metadata)
      Array(file_metadata.pcdm_use).first&.to_s&.split('#')&.last
    end

    def existing_derivatives(file_set)
      Hyrax.custom_queries.find_files(file_set:).filter_map do |f|
        next if original_file?(f)

        {
          file_id: f.id.to_s,
          pcdm_use: pcdm_use_label(f),
          mime_type: Array(f.mime_type).first,
          filename: f.original_filename
        }
      end
    end

    # This is really a best effort approach to help get the list of formats
    # output may be different for different versions of ImageMagick
    def imagemagick_writable_formats
      output, status = Open3.capture2('magick', 'identify', '-list', 'format')
      return [] unless status.success?

      output.lines.filter_map do |line|
        match = line.match(/^\s*([^\s*]+)\*?\s+(?:\S+\s+)?([r\-][w\-][+\-])/)
        match[1] if match && match[2][1] == 'w'
      end.uniq.sort
    rescue StandardError
      []
    end

    def delete_derivatives(derivatives, file_set) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      derivatives.each do |derivative|
        file_set.file_ids.delete(derivative.id)
        begin
          Hyrax.config.derivatives_storage_adapter.delete(id: derivative.file_identifier)
        rescue StandardError => e
          Hyrax.logger.warn("Could not delete derivative file: #{e.message}")
        end
        Hyrax.persister.delete(resource: derivative)
      end

      Hyrax.persister.save(resource: file_set) if derivatives.any?
      Hyrax.index_adapter.save(resource: file_set) if derivatives.any?
    end

    # ImageMagick registers 'TIFF' but not 'TIF' as a writable format name
    def format_aliases
      {
        'tif' => 'TIFF'
      }
    end
  end
end
