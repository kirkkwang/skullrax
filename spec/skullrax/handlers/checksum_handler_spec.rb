# frozen_string_literal: true

RSpec.describe Skullrax::ChecksumHandler do
  let(:file_set_id) { 'fs-abc123' }
  let(:handler) { described_class.new(file_set_id:) }

  let(:file_set_valkyrie_id) { instance_double(Valkyrie::ID, to_s: file_set_id) }
  let(:original_file_id) { instance_double(Valkyrie::ID, to_s: 'fm-orig-001') }
  let(:file_identifier) { instance_double(Valkyrie::ID) }

  let(:original_file) do
    instance_double(
      Hyrax::FileMetadata,
      id: original_file_id,
      pcdm_use: ['http://pcdm.org/use#OriginalFile'],
      original_filename: 'foo.jpg',
      file_identifier:,
      checksum: []
    )
  end

  let(:file_set) do
    instance_double(Hyrax::FileSet, id: file_set_valkyrie_id, file_ids: [original_file_id])
  end

  let(:readable_file) { instance_double(Valkyrie::StorageAdapter::StreamFile, rewind: nil, read: 'file contents') }
  let(:audit_log) { instance_double(ChecksumAuditLog, id: 42) }

  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: file_set_id).and_return(file_set)
    allow(Hyrax.query_service).to receive(:find_by).with(id: original_file_id).and_return(original_file)
    allow(Hyrax.storage_adapter).to receive(:find_by).with(id: file_identifier).and_return(readable_file)
    allow(ChecksumAuditLog).to receive(:create_and_prune!).and_return(audit_log)
  end

  describe '#recalculate' do
    context 'when the FileSet and OriginalFile exist and file is readable' do
      let(:md5) { instance_double(Digest::MD5, hexdigest: 'abc123def456') }

      before do
        allow(Digest::MD5).to receive(:new).and_return(md5)
        allow(md5).to receive(:<<)
        allow(original_file).to receive(:checksum=).with(['abc123def456'])
        allow(Hyrax.persister).to receive(:save).with(resource: original_file)
        allow(Hyrax.index_adapter).to receive(:save).with(resource: file_set)
      end

      it 'returns the expected result hash with status ok' do
        result = handler.recalculate

        expect(result[:status]).to eq('ok')
        expect(result[:file_set_id]).to eq(file_set_id)
        expect(result[:file_metadata_id]).to eq('fm-orig-001')
        expect(result[:filename]).to eq('foo.jpg')
        expect(result[:algorithm]).to eq('MD5')
        expect(result[:audit_log_id]).to eq(42)
      end

      it 'persists the computed checksum to FileMetadata' do
        handler.recalculate

        expect(Hyrax.persister).to have_received(:save).with(resource: original_file)
      end

      it 'reindexes the FileSet in Solr' do
        handler.recalculate

        expect(Hyrax.index_adapter).to have_received(:save).with(resource: file_set)
      end

      it 'reads the file via the storage adapter' do
        handler.recalculate

        expect(Hyrax.storage_adapter).to have_received(:find_by).with(id: file_identifier)
        expect(readable_file).to have_received(:rewind)
        expect(readable_file).to have_received(:read)
      end

      it 'writes a ChecksumAuditLog record' do
        handler.recalculate

        expect(ChecksumAuditLog).to have_received(:create_and_prune!).with(
          file_set_id:,
          file_id: 'fm-orig-001',
          checked_uri: file_identifier.to_s,
          expected_result: 'abc123def456',
          passed: true
        )
      end
    end

    context 'when the FileSet is not found' do
      before do
        allow(Hyrax.query_service).to receive(:find_by).with(id: file_set_id)
                                                       .and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      end

      it 'returns status error' do
        result = handler.recalculate

        expect(result[:status]).to eq('error')
        expect(result[:error]).to be_a(String)
      end
    end

    context 'when the FileSet has no OriginalFile' do
      let(:non_original) do
        instance_double(
          Hyrax::FileMetadata,
          id: original_file_id,
          pcdm_use: ['http://pcdm.org/use#ThumbnailImage']
        )
      end

      before do
        allow(Hyrax.query_service).to receive(:find_by).with(id: original_file_id).and_return(non_original)
      end

      it 'returns status error with a descriptive message' do
        result = handler.recalculate

        expect(result[:status]).to eq('error')
        expect(result[:error]).to match(/No OriginalFile found/)
      end
    end

    context 'when the storage adapter cannot read the file' do
      before do
        allow(Hyrax.storage_adapter).to receive(:find_by).with(id: file_identifier)
                                                         .and_raise(StandardError, 'Could not read file from storage')
      end

      it 'returns status error with a descriptive message' do
        result = handler.recalculate

        expect(result[:status]).to eq('error')
        expect(result[:error]).to match(/Could not read file from storage/)
      end
    end
  end
end
