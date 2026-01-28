# frozen_string_literal: true

RSpec.describe Skullrax::FileAttachmentHandler do
  let(:user) { create(:user) }

  describe '#upload with remote files' do
    context 'when URL has a filename with extension' do
      it 'preserves the original filename' do
        url = 'https://example.com/images/test_file.png'

        stub_request(:get, url)
          .to_return(
            status: 200,
            body: File.read(Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png')),
            headers: { 'Content-Type' => 'image/png' }
          )

        handler = described_class.new(file_paths: [url], user:)
        uploaded_files = handler.upload

        expect(uploaded_files.first.uploader.filename).to eq('test_file.png')
      end
    end

    context 'when URL has no extension' do
      it 'adds extension based on content-type' do
        url = 'https://example.com/images/test_file'

        stub_request(:get, url)
          .to_return(
            status: 200,
            body: File.read(Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png')),
            headers: { 'Content-Type' => 'image/png' }
          )

        handler = described_class.new(file_paths: [url], user:)
        uploaded_files = handler.upload

        expect(uploaded_files.first.uploader.filename).to eq('test_file.png')
      end
    end

    context 'when Content-Disposition header is present' do
      it 'uses filename from header' do
        url = 'https://example.com/download/12345'

        stub_request(:get, url)
          .to_return(
            status: 200,
            body: File.read(Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png')),
            headers: {
              'Content-Type' => 'image/png',
              'Content-Disposition' => 'attachment; filename="test_file.png"'
            }
          )

        handler = described_class.new(file_paths: [url], user:)
        uploaded_files = handler.upload

        expect(uploaded_files.first.uploader.filename).to eq('test_file.png')
      end
    end
  end
end
