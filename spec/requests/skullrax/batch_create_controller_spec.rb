# frozen_string_literal: true

RSpec.describe Skullrax::BatchCreateController do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin) }
  let(:importer) { instance_double(Skullrax::CsvImporter) }
  let(:csv_string) { 'title,creator\nTest,Author' }
  let(:resources) { [double, double, double] }

  before do
    sign_in admin

    allow(Skullrax::ParamsToCsvConverterService).to receive_message_chain(:new, :to_csv).and_return(csv_string)
    allow(Skullrax::CsvImporter).to receive(:new).and_return(importer)
    allow(importer).to receive(:import)
    allow(importer).to receive(:resources).and_return(resources)
  end

  describe 'POST /skullrax/batch_create' do
    subject(:post_create) do
      post skullrax.batch_create_path, params: {
        resources: { title: 'Test', creator: 'Author' },
        autofill: autofill_param
      }
    end

    let(:autofill_param) { 'true' }

    context 'when import is successful' do
      before do
        allow(importer).to receive(:errors).and_return([])
      end

      it 'redirects with translated success notice' do
        post_create

        expect(response).to redirect_to(%r{/skullrax})
        expect(flash[:notice]).to eq(I18n.t('skullrax.batch_create.create.success', count: 3))
      end

      it 'calls import with correct arguments' do
        post_create
        expect(importer).to have_received(:import).with(autofill: true, fill_required: true)
      end
    end

    context 'when import fails' do
      before do
        allow(importer).to receive(:errors).and_return(['Invalid CSV', 'Missing Title'])
      end

      it 'redirects with error flash' do
        post_create

        expect(response).to redirect_to(%r{/skullrax})
        expect(flash[:error]).to include('Invalid CSV', 'Missing Title')
      end
    end

    context 'when autofill is false' do
      let(:autofill_param) { 'false' }

      before do
        allow(importer).to receive(:errors).and_return([])
      end

      it 'passes false to the importer' do
        post_create
        expect(importer).to have_received(:import).with(autofill: false, fill_required: false)
      end
    end

    context 'when batch uploads directory cleanup' do
      let(:batch_uploads_dir) { Rails.root.join('tmp', 'skullrax_batch_uploads', 'test123') }

      before do
        allow(importer).to receive(:errors).and_return([])
        allow(FileUtils).to receive(:rm_rf)
        # Mock the batch_uploads_dir to return a known value
        allow_any_instance_of(described_class).to receive(:batch_uploads_dir).and_return(batch_uploads_dir)
        allow(File).to receive(:exist?).with(batch_uploads_dir).and_return(true)
      end

      it 'cleans up batch uploads directory after import succeeds' do
        post_create

        expect(FileUtils).to have_received(:rm_rf).with(batch_uploads_dir)
      end

      it 'cleans up batch uploads directory even when import fails' do
        allow(importer).to receive(:errors).and_return(['Some error'])

        post_create

        expect(FileUtils).to have_received(:rm_rf).with(batch_uploads_dir)
      end

      it 'does not attempt cleanup if directory does not exist' do
        allow(File).to receive(:exist?).with(batch_uploads_dir).and_return(false)

        post_create

        expect(FileUtils).not_to have_received(:rm_rf)
      end
    end
  end
end
