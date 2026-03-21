# frozen_string_literal: true

module Skullrax
  class CreateSpecificDerivativeJob < Hyrax::ApplicationJob
    queue_as Hyrax.config.ingest_queue_name

    def perform(file_id, derivative_type, mime_type) # rubocop:disable Metrics/MethodLength
      file_metadata = Hyrax.custom_queries.find_file_metadata_by(id: file_id)
      file = Hyrax.storage_adapter.find_by(id: file_metadata.file_identifier)
      service = Hyrax::FileSetDerivativesService.new(file_metadata)

      output = {
        label: derivative_type.to_sym,
        format: derivative_type.downcase,
        container: 'service_file',
        mime_type:,
        url: service.derivative_url(derivative_type)
      }

      # FileMetadata persistence, FileSet attachment, and Solr indexing are handled
      # automatically by Hydra::Derivatives' output_file_service.
      Hydra::Derivatives::ImageDerivatives.create(file.disk_path.to_s, outputs: [output])
    end
  end
end
