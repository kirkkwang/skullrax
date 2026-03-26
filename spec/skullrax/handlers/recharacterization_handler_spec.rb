# frozen_string_literal: true

RSpec.describe Skullrax::RecharacterizationHandler do
  let(:file_set_id) { 'fs-001' }
  let(:file_metadata_id) { instance_double(Valkyrie::ID, to_s: 'fm-001') }

  let(:file_set) do
    instance_double(Hyrax::FileSet, id: instance_double(Valkyrie::ID, to_s: file_set_id))
  end

  let(:file_metadata) do
    instance_double(
      Hyrax::FileMetadata,
      id: file_metadata_id,
      original_filename: 'photo.jpg',
      mime_type: ['image/jpeg'],
      file: instance_double(Valkyrie::StorageAdapter::StreamFile)
    )
  end

  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: file_set_id).and_return(file_set)
    allow(Hyrax.custom_queries).to receive(:find_original_file).with(file_set:).and_return(file_metadata)
  end

  describe '.characterization_fields' do
    it 'includes checksum regardless of mapper state' do
      expect(described_class.characterization_fields).to include('checksum')
    end

    it 'excludes identity and file management attributes' do
      expect(described_class.characterization_fields).not_to include(
        'id', 'label', 'original_filename', 'mime_type',
        'file_set_id', 'file_identifier', 'internal_resource',
        'created_at', 'updated_at', 'pcdm_use'
      )
    end

    it 'returns only strings' do
      expect(described_class.characterization_fields).to all(be_a(String))
    end
  end

  describe '#call' do
    context 'with async: true (default)' do
      let(:handler) { described_class.new(file_set_id:) }

      before { allow(ValkyrieCharacterizationJob).to receive(:perform_later) }

      it 'enqueues ValkyrieCharacterizationJob with the file_metadata_id' do
        handler.call

        expect(ValkyrieCharacterizationJob).to have_received(:perform_later).with('fm-001')
      end

      it 'returns enqueued status' do
        result = handler.call

        expect(result[:status]).to eq('enqueued')
        expect(result[:file_set_id]).to eq(file_set_id)
        expect(result[:file_metadata_id]).to eq('fm-001')
        expect(result[:original_filename]).to eq('photo.jpg')
        expect(result[:mime_type]).to eq('image/jpeg')
      end

      it 'does not include a characterization snapshot' do
        result = handler.call

        expect(result).not_to have_key(:characterization)
      end
    end

    context 'with async: false' do
      let(:handler) { described_class.new(file_set_id:, async: false) }
      let(:characterization_service) { class_double('Hyrax::Characterization::ValkyrieCharacterizationService') }
      let(:service_instance) { instance_double('Hyrax::Characterization::ValkyrieCharacterizationService') }

      before do
        allow(Hyrax.config).to receive(:characterization_service).and_return(characterization_service)
        allow(Hyrax.config).to receive(:characterization_options).and_return({ ch12n_tool: :fits })
        allow(characterization_service).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:characterize)
        allow(Hyrax.persister).to receive(:save).with(resource: file_metadata).and_return(file_metadata)
        allow(Hyrax.index_adapter).to receive(:save).with(resource: file_set)

        # Stub all characterization fields to empty by default so the snapshot doesn't
        # blow up on unstubbed methods. The respond_to? guard in snapshot skips any
        # fields the double doesn't implement.
        Skullrax::RecharacterizationHandler.characterization_fields.each do |field|
          allow(file_metadata).to receive(field).and_return([]) if file_metadata.respond_to?(field)
          allow(file_metadata).to receive(:"#{field}=") if file_metadata.respond_to?(:"#{field}=")
        end

        allow(file_metadata).to receive(:format_label).and_return(['JPEG EXIF'])
        allow(file_metadata).to receive(:height).and_return(['1200'])
        allow(file_metadata).to receive(:width).and_return(['900'])
        allow(file_metadata).to receive(:color_space).and_return(['sRGB'])
      end

      it 'initializes the characterization service with metadata, file, and config options' do
        handler.call

        expect(characterization_service).to have_received(:new).with(
          metadata: file_metadata,
          file: file_metadata.file,
          ch12n_tool: :fits
        )
        expect(service_instance).to have_received(:characterize)
      end

      it 'does not publish the file.characterized event' do
        expect(Hyrax.publisher).not_to receive(:publish).with('file.characterized', anything)

        handler.call
      end

      it 'does not enqueue derivative jobs' do
        stub_const('Hyrax::CreateDerivativesJob', class_double('Hyrax::CreateDerivativesJob'))
        expect(Hyrax::CreateDerivativesJob).not_to receive(:perform_later)

        handler.call
      end

      it 'returns completed status' do
        result = handler.call

        expect(result[:status]).to eq('completed')
        expect(result[:file_set_id]).to eq(file_set_id)
      end

      it 'includes a characterization snapshot of populated fields' do
        result = handler.call

        expect(result[:characterization]).to include(
          'format_label' => ['JPEG EXIF'],
          'height' => ['1200'],
          'width' => ['900'],
          'color_space' => ['sRGB']
        )
      end

      it 'omits empty fields from the snapshot' do
        result = handler.call

        expect(result[:characterization]).not_to have_key('date_created')
        expect(result[:characterization]).not_to have_key('frame_rate')
      end

      it 'reindexes the FileSet after the service runs' do
        handler.call

        expect(Hyrax.index_adapter).to have_received(:save).with(resource: file_set)
      end

      it 'clears fields, runs the service, saves, then reindexes — in that order' do
        expect(file_metadata).to receive(:format_label=).with([]).ordered
        expect(service_instance).to receive(:characterize).ordered
        expect(Hyrax.persister).to receive(:save).with(resource: file_metadata).ordered
        expect(Hyrax.index_adapter).to receive(:save).with(resource: file_set).ordered

        handler.call
      end
    end

    context 'when the FileSet is not found' do
      let(:handler) { described_class.new(file_set_id:) }

      before do
        allow(Hyrax.query_service).to receive(:find_by).with(id: file_set_id)
                                                       .and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      end

      it 'returns status error' do
        result = handler.call

        expect(result[:status]).to eq('error')
        expect(result[:error]).to be_a(String)
      end
    end

    context 'when the FileSet has no original file' do
      let(:handler) { described_class.new(file_set_id:) }

      before do
        not_found = Valkyrie::Persistence::ObjectNotFoundError
        allow(Hyrax.custom_queries).to receive(:find_original_file).with(file_set:)
                                                                   .and_raise(not_found, 'missing')
      end

      it 'returns status error with a descriptive message' do
        result = handler.call

        expect(result[:status]).to eq('error')
        expect(result[:error]).to be_a(String)
      end
    end
  end
end
