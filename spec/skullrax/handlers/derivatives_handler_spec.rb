# frozen_string_literal: true

RSpec.describe Skullrax::DerivativesHandler do
  let(:file_set_id) { 'fs-001' }
  let(:manager) { described_class.new(file_set_id) }

  let(:file_set_valkyrie_id) { instance_double(Valkyrie::ID, to_s: file_set_id) }
  let(:original_id) { instance_double(Valkyrie::ID, to_s: 'original-001') }
  let(:thumbnail_id) { instance_double(Valkyrie::ID, to_s: 'thumb-001') }
  let(:original_storage_id) { instance_double(Valkyrie::ID) }
  let(:thumbnail_storage_id) { instance_double(Valkyrie::ID) }

  let(:original_file) do
    instance_double(
      Hyrax::FileMetadata,
      id: original_id,
      pcdm_use: ['http://pcdm.org/use#OriginalFile'],
      mime_type: ['image/jpeg'],
      original_filename: 'original.jpg',
      file_identifier: original_storage_id
    )
  end

  let(:thumbnail) do
    instance_double(
      Hyrax::FileMetadata,
      id: thumbnail_id,
      pcdm_use: ['http://pcdm.org/use#ThumbnailImage'],
      mime_type: ['image/jpeg'],
      original_filename: '97-thumbnail.jpeg',
      file_identifier: thumbnail_storage_id
    )
  end

  let(:file_ids) { [original_id, thumbnail_id] }

  let(:file_set) do
    instance_double(Hyrax::FileSet, id: file_set_valkyrie_id, file_ids:)
  end

  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: file_set_id).and_return(file_set)
    allow(Hyrax.custom_queries).to receive(:find_files).with(file_set:)
                                                       .and_return([original_file, thumbnail])
  end

  describe '#list' do
    before do
      allow(manager).to receive(:imagemagick_writable_formats).and_return(%w[JPEG PNG TIFF JP2])
    end

    it 'returns the file_set_id and mime type' do
      result = manager.list

      expect(result[:file_set_id]).to eq(file_set_id)
      expect(result[:mime_type]).to eq('image/jpeg')
    end

    it 'returns existing derivatives excluding the original file' do
      result = manager.list

      expect(result[:existing_derivatives].length).to eq(1)
      expect(result[:existing_derivatives].first[:file_id]).to eq('thumb-001')
      expect(result[:existing_derivatives].first[:pcdm_use]).to eq('ThumbnailImage')
      expect(result[:existing_derivatives].first[:filename]).to eq('97-thumbnail.jpeg')
    end

    it 'returns imagemagick writable formats' do
      result = manager.list

      expect(result[:imagemagick_writable_formats]).to eq(%w[JPEG PNG TIFF JP2])
    end

    it 'does not include available_menu_items in the response' do
      result = manager.list

      expect(result).not_to have_key(:available_menu_items)
    end

    context 'when the FileSet is not found' do
      before do
        allow(Hyrax.query_service).to receive(:find_by).with(id: file_set_id)
                                                       .and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      end

      it 'raises Skullrax::ArgumentError with a clear message' do
        expect { manager.list }.to raise_error(Skullrax::ArgumentError, /FileSet not found/)
      end
    end

    context 'when the FileSet has no original file' do
      before do
        allow(Hyrax.custom_queries).to receive(:find_files).with(file_set:).and_return([])
      end

      it 'raises Skullrax::ArgumentError with a clear message' do
        expect { manager.list }.to raise_error(Skullrax::ArgumentError, /No original file found/)
      end
    end
  end

  describe '#regenerate' do
    let(:derivatives_storage_adapter) { instance_double('StorageAdapter', delete: nil) }

    before do
      allow(Hyrax.config).to receive(:derivatives_storage_adapter).and_return(derivatives_storage_adapter)
      allow(Hyrax.persister).to receive(:delete)
      allow(Hyrax.persister).to receive(:save).with(resource: file_set)
      allow(Hyrax.index_adapter).to receive(:save).with(resource: file_set)
      allow(ValkyrieCreateDerivativesJob).to receive(:perform_later)
    end

    it 'deletes each non-OriginalFile FileMetadata record' do
      manager.regenerate

      expect(Hyrax.persister).to have_received(:delete).with(resource: thumbnail)
    end

    it 'removes each derivative file_id from the FileSet' do
      manager.regenerate

      expect(file_ids).not_to include(thumbnail_id)
    end

    it 'deletes each derivative from the storage adapter' do
      manager.regenerate

      expect(derivatives_storage_adapter).to have_received(:delete).with(id: thumbnail_storage_id)
    end

    it 'saves the FileSet once after all deletions' do
      manager.regenerate

      expect(Hyrax.persister).to have_received(:save).with(resource: file_set).once
    end

    it 'reindexes the FileSet after cleanup' do
      manager.regenerate

      expect(Hyrax.index_adapter).to have_received(:save).with(resource: file_set)
    end

    it 'enqueues ValkyrieCreateDerivativesJob with the FileSet and original file IDs' do
      manager.regenerate

      expect(ValkyrieCreateDerivativesJob).to have_received(:perform_later)
        .with(file_set_id, 'original-001')
    end

    it 'returns enqueued status with a cleanup count message' do
      result = manager.regenerate

      expect(result[:status]).to eq('enqueued')
      expect(result[:file_set_id]).to eq(file_set_id)
      expect(result[:message]).to match(/Cleaned up 1 derivative/)
    end

    context 'when the storage adapter raises on delete (file already missing from disk)' do
      before do
        allow(derivatives_storage_adapter).to receive(:delete).and_raise(StandardError, 'file not found')
        allow(Hyrax.logger).to receive(:warn)
      end

      it 'logs a warning and continues' do
        manager.regenerate

        expect(Hyrax.logger).to have_received(:warn).with(/Could not delete derivative file/)
      end

      it 'still deletes the FileMetadata record' do
        manager.regenerate

        expect(Hyrax.persister).to have_received(:delete).with(resource: thumbnail)
      end
    end

    context 'when there are no derivatives to clean up' do
      before do
        allow(Hyrax.custom_queries).to receive(:find_files).with(file_set:)
                                                           .and_return([original_file])
      end

      it 'does not save or reindex the FileSet' do
        manager.regenerate

        expect(Hyrax.persister).not_to have_received(:save)
        expect(Hyrax.index_adapter).not_to have_received(:save)
      end

      it 'still enqueues the job' do
        manager.regenerate

        expect(ValkyrieCreateDerivativesJob).to have_received(:perform_later)
      end

      it 'reports zero derivatives cleaned up' do
        result = manager.regenerate

        expect(result[:message]).to match(/Cleaned up 0 derivative/)
      end
    end
  end

  describe '#create' do
    before do
      allow(manager).to receive(:imagemagick_writable_formats).and_return(%w[JP2 PNG TIFF JPEG AVIF WEBP])
      allow(Skullrax::CreateSpecificDerivativeJob).to receive(:perform_later)
    end

    it 'enqueues CreateSpecificDerivativeJob with derivative_type and mime_type' do
      manager.create('png', 'image/png')

      expect(Skullrax::CreateSpecificDerivativeJob).to have_received(:perform_later)
        .with('original-001', 'png', 'image/png')
    end

    it 'returns enqueued status with derivative_type' do
      result = manager.create('png', 'image/png')

      expect(result[:status]).to eq('enqueued')
      expect(result[:derivative_type]).to eq('png')
    end

    context 'when derivative_type is not a writable ImageMagick format' do
      it 'raises Skullrax::ArgumentError' do
        expect { manager.create('hologram', 'image/hologram') }
          .to raise_error(Skullrax::ArgumentError, /Not a writable ImageMagick format/)
      end

      it 'does not enqueue a job' do
        manager.create('hologram', 'image/hologram')
      rescue Skullrax::ArgumentError
        expect(Skullrax::CreateSpecificDerivativeJob).not_to have_received(:perform_later)
      end
    end

    context 'when the source file is not an image' do
      let(:audio_original) do
        instance_double(
          Hyrax::FileMetadata,
          id: original_id,
          pcdm_use: ['http://pcdm.org/use#OriginalFile'],
          mime_type: ['audio/mp3'],
          original_filename: 'audio.mp3',
          file_identifier: original_storage_id
        )
      end

      before do
        allow(Hyrax.custom_queries).to receive(:find_files).with(file_set:)
                                                           .and_return([audio_original])
      end

      it 'raises Skullrax::ArgumentError' do
        expect { manager.create('png', 'image/png') }
          .to raise_error(Skullrax::ArgumentError, /not compatible with mime type/)
      end
    end

    context 'when derivative_type is a known alias' do
      it 'passes validation and enqueues the job with the original derivative_type' do
        manager.create('tif', 'image/tiff')

        expect(Skullrax::CreateSpecificDerivativeJob).to have_received(:perform_later)
          .with('original-001', 'tif', 'image/tiff')
      end
    end
  end

  describe '#delete' do
    let(:derivatives_storage_adapter) { instance_double('StorageAdapter', delete: nil) }
    let(:hyrax_config) { instance_double(Hyrax::Configuration, derivatives_storage_adapter:) }

    before do
      allow(Hyrax.persister).to receive(:save).with(resource: file_set)
      allow(Hyrax.config).to receive(:derivatives_storage_adapter).and_return(derivatives_storage_adapter)
      allow(Hyrax.persister).to receive(:delete).with(resource: thumbnail)
      allow(Hyrax.index_adapter).to receive(:save).with(resource: file_set)
    end

    it 'removes the file_id from the FileSet and saves' do
      manager.delete('thumb-001')

      expect(file_ids).not_to include(thumbnail_id)
      expect(Hyrax.persister).to have_received(:save).with(resource: file_set)
    end

    it 'deletes the file from the storage adapter' do
      manager.delete('thumb-001')

      expect(derivatives_storage_adapter).to have_received(:delete).with(id: thumbnail_storage_id)
    end

    it 'deletes the FileMetadata record' do
      manager.delete('thumb-001')

      expect(Hyrax.persister).to have_received(:delete).with(resource: thumbnail)
    end

    it 'reindexes the FileSet in Solr' do
      manager.delete('thumb-001')

      expect(Hyrax.index_adapter).to have_received(:save).with(resource: file_set)
    end

    it 'returns deletion confirmation with filename, pcdm_use, and mime_type' do
      result = manager.delete('thumb-001')

      expect(result[:status]).to eq('deleted')
      expect(result[:file_id]).to eq('thumb-001')
      expect(result[:filename]).to eq('97-thumbnail.jpeg')
      expect(result[:pcdm_use]).to eq('ThumbnailImage')
      expect(result[:mime_type]).to eq('image/jpeg')
    end

    context 'when the file_id is the original file' do
      it 'raises Skullrax::ArgumentError and refuses deletion' do
        expect { manager.delete('original-001') }
          .to raise_error(Skullrax::ArgumentError, /Cannot delete the original file/)
      end

      it 'does not call persister or storage adapter' do
        manager.delete('original-001')
      rescue Skullrax::ArgumentError
        expect(Hyrax.persister).not_to have_received(:save)
        expect(derivatives_storage_adapter).not_to have_received(:delete)
      end
    end

    context 'when the file_id is not found on the FileSet' do
      it 'raises Skullrax::ArgumentError with a clear message' do
        expect { manager.delete('nonexistent-id') }
          .to raise_error(Skullrax::ArgumentError, /not found on FileSet/)
      end
    end
  end

  describe '#imagemagick_writable_formats (private)' do
    # ImageMagick 7.x with Module column (e.g. Docker dev image, IM 7.1.0)
    let(:im_output_with_module) do
      "      JP2* JP2       rw+   JPEG-2000 File Format Syntax\n" \
        "      JPEG* JPEG      rw-   Joint Photographic Experts Group JFIF\n" \
        "      TIFF* TIFF      rw+   Tagged Image File Format\n" \
        "      PNG* PNG       r--   Portable Network Graphics (read-only)\n"
    end

    # ImageMagick 7.1.1+ without Module column (e.g. Hyku production, IM 7.1.1-47)
    let(:im_output_without_module) do
      "      JP2* rw+   JPEG-2000 File Format Syntax\n" \
        "      JPEG* rw-   Joint Photographic Experts Group JFIF\n" \
        "      TIFF* rw+   Tagged Image File Format\n" \
        "      PNG* r--   Portable Network Graphics (read-only)\n"
    end

    let(:success_status) { instance_double(Process::Status, success?: true) }
    let(:failure_status) { instance_double(Process::Status, success?: false) }

    it 'parses writable formats from output with a Module column' do
      allow(Open3).to receive(:capture2).and_return([im_output_with_module, success_status])
      result = manager.send(:imagemagick_writable_formats)

      expect(result).to include('JP2', 'JPEG', 'TIFF')
      expect(result).not_to include('PNG')
      expect(result).to eq(result.sort)
    end

    it 'parses writable formats from output without a Module column' do
      allow(Open3).to receive(:capture2).and_return([im_output_without_module, success_status])
      result = manager.send(:imagemagick_writable_formats)

      expect(result).to include('JP2', 'JPEG', 'TIFF')
      expect(result).not_to include('PNG')
      expect(result).to eq(result.sort)
    end

    it 'returns an empty array when the command exits non-zero' do
      allow(Open3).to receive(:capture2).and_return(['', failure_status])
      result = manager.send(:imagemagick_writable_formats)

      expect(result).to eq([])
    end

    it 'returns an empty array when the command raises an error' do
      allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT, 'magick')
      result = manager.send(:imagemagick_writable_formats)

      expect(result).to eq([])
    end
  end
end
