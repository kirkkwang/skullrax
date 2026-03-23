# frozen_string_literal: true

require 'digest'

module Skullrax
  class ChecksumHandler
    attr_reader :file_set_id

    def initialize(file_set_id:)
      @file_set_id = file_set_id
    end

    def recalculate # rubocop:disable Metrics/MethodLength
      file_set = find_file_set
      original_file = find_original_file(file_set)
      checksum = compute_checksum(original_file)

      persist_checksum(original_file, checksum)
      Hyrax.index_adapter.save(resource: file_set)
      audit_log = record_audit_log(original_file, checksum)

      {
        file_set_id:,
        file_metadata_id: original_file.id.to_s,
        filename: original_file.original_filename,
        checksum:,
        algorithm: 'MD5',
        audit_log_id: audit_log.id,
        status: 'ok'
      }
    rescue StandardError => e
      { status: 'error', error: e.message }
    end

    private

    def find_file_set
      Hyrax.query_service.find_by(id: file_set_id)
    end

    def find_original_file(file_set)
      file_set.file_ids
              .map { |id| Hyrax.query_service.find_by(id:) }
              .find { |m| Array(m.pcdm_use).any? { |u| u.to_s.include?('OriginalFile') } }
              .tap { |fm| raise "No OriginalFile found on FileSet #{file_set_id}" unless fm }
    end

    def compute_checksum(file_metadata)
      file = Hyrax.storage_adapter.find_by(id: file_metadata.file_identifier)
      file.rewind
      Digest::MD5.new.tap { |md5| md5 << file.read }.hexdigest
    end

    def persist_checksum(file_metadata, checksum)
      file_metadata.checksum = [checksum]
      Hyrax.persister.save(resource: file_metadata)
    end

    def record_audit_log(file_metadata, checksum)
      ChecksumAuditLog.create_and_prune!(
        file_set_id:,
        file_id: file_metadata.id.to_s,
        checked_uri: file_metadata.file_identifier.to_s,
        expected_result: checksum,
        passed: true
      )
    end
  end
end
