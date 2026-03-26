# frozen_string_literal: true

module Skullrax
  class RecharacterizationHandler
    attr_reader :file_set_id, :async

    class << self
      # Derived directly from Hyrax::FileMetadata attribute definitions
      # (app/models/hyrax/file_metadata.rb) rather than the mapper, so clear
      # is always complete regardless of mapper state.
      def characterization_fields
        @characterization_fields ||=
          Hyrax::FileMetadata.attribute_names
                             .map(&:to_s)
                             .reject { |attr| non_characterization_attributes.include?(attr) }
                             .freeze
      end

      def non_characterization_attributes
        %w[
          id internal_resource created_at updated_at new_record
          file_identifier alternate_ids file_set_id
          label original_filename mime_type pcdm_use
        ]
      end
    end

    def initialize(file_set_id:, async: true)
      @file_set_id = file_set_id
      @async = async
    end

    def call
      file_set = Hyrax.query_service.find_by(id: file_set_id)
      file_metadata = find_original_file(file_set)

      if async
        enqueue(file_metadata)
      else
        characterize(file_metadata)
      end
    rescue StandardError => e
      { status: 'error', error: e.message }
    end

    private

    def find_original_file(file_set)
      Hyrax.custom_queries.find_original_file(file_set:)
    end

    def enqueue(file_metadata)
      ValkyrieCharacterizationJob.perform_later(file_metadata.id.to_s)
      build_result(file_metadata, status: 'enqueued')
    end

    def characterize(file_metadata)
      clear_characterization_fields(file_metadata)
      Hyrax.config.characterization_service
           .new(metadata: file_metadata, file: file_metadata.file, **Hyrax.config.characterization_options)
           .characterize
      Hyrax.persister.save(resource: file_metadata)
      reindex_file_set
      build_result(file_metadata, status: 'completed', snapshot: snapshot(file_metadata))
    end

    def reindex_file_set
      file_set = Hyrax.query_service.find_by(id: file_set_id)
      Hyrax.index_adapter.save(resource: file_set)
    end

    def clear_characterization_fields(file_metadata)
      self.class.characterization_fields.each do |field|
        next unless file_metadata.respond_to?(:"#{field}=")

        value = field == 'mime_type' ? 'application/octet-stream' : []
        file_metadata.public_send(:"#{field}=", value)
      end
    end

    def build_result(file_metadata, status:, snapshot: nil)
      {
        file_set_id:,
        file_metadata_id: file_metadata.id.to_s,
        original_filename: file_metadata.original_filename,
        mime_type: Array(file_metadata.mime_type).first,
        status:
      }.tap { |r| r[:characterization] = snapshot if snapshot }
    end

    def snapshot(file_metadata)
      self.class.characterization_fields.each_with_object({}) do |field, hash|
        next unless file_metadata.respond_to?(field)

        value = Array(file_metadata.public_send(field)).reject(&:blank?)
        hash[field] = value if value.present?
      end
    end
  end
end
