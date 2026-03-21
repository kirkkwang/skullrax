# frozen_string_literal: true

RSpec.describe Skullrax::CreateSpecificDerivativeJob do
  let(:file_set_id) { 'fs-001' }
  let(:file_id) { 'file-001' }
  let(:storage_id) { instance_double(Valkyrie::ID) }
  let(:disk_path) { Pathname.new('/derivatives/original.jpg') }

  let(:file_metadata) do
    instance_double(Hyrax::FileMetadata, file_identifier: storage_id)
  end

  let(:file) do
    instance_double('Valkyrie::StorageAdapter::File', disk_path:)
  end

  let(:derivative_service) do
    instance_double(Hyrax::FileSetDerivativesService, derivative_url: 'file:///derivatives/thumb.jpg')
  end

  before do
    allow(Hyrax.custom_queries).to receive(:find_file_metadata_by).with(id: file_id).and_return(file_metadata)
    allow(Hyrax.storage_adapter).to receive(:find_by).with(id: storage_id).and_return(file)
    allow(Hyrax::FileSetDerivativesService).to receive(:new).with(file_metadata).and_return(derivative_service)
  end

  describe '#perform' do
    before do
      allow(Hydra::Derivatives::ImageDerivatives).to receive(:create)
      allow(derivative_service).to receive(:derivative_url).with('png').and_return('file:///png.png')
    end

    it 'uses the provided mime_type in the output hash' do
      described_class.new.perform(file_id, 'png', 'image/png')

      expect(Hydra::Derivatives::ImageDerivatives).to have_received(:create)
        .with('/derivatives/original.jpg',
              outputs: [hash_including(label: :png, format: 'png', container: 'service_file',
                                       mime_type: 'image/png')])
    end

    it 'merges the derivative URL into the output hash' do
      described_class.new.perform(file_id, 'png', 'image/png')

      expect(Hydra::Derivatives::ImageDerivatives).to have_received(:create)
        .with(anything, outputs: [hash_including(url: 'file:///png.png')])
    end
  end
end
