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
        expect(importer).to have_received(:import).with(autofill: true, fill_required: true, dry_run: false)
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
        expect(importer).to have_received(:import).with(autofill: false, fill_required: false, dry_run: false)
      end
    end

    context 'with autofill true' do
      context 'when downloading form as CSV' do
        let(:params) do
          {
            resources: {
              'resource-0' => {
                'type' => 'CollectionResource',
                'title' => ['Test Title'],
                'creator' => ['Test Creator'],
                'visibility' => 'restricted'
              }
            },
            autofill: 'true',
            'download-form-as-csv' => 'true'
          }
        end

        before do
          # Remove the importer stubs from the outer before block for this context
          allow(Skullrax::CsvImporter).to receive(:new).and_call_original
          allow(Skullrax::ParamsToCsvConverterService).to receive(:new).and_call_original
        end

        it 'sends the generated CSV data with expected content' do
          expected_csv = <<~CSV
            model,id,title,abstract,access_right,alternative_title,arkivo_checksum,based_near,bibliographic_citation,contributor,creator,date_created,description,identifier,keyword,publisher,label,language,license,related_url,resource_type,rights_notes,rights_statement,source,subject,target_audience,department,course,visibility,file
            CollectionResource,,Test Title,Test abstract,Test access_right,Test alternative_title,Test arkivo_checksum,https://sws.geonames.org/5391811/,Test bibliographic_citation,Test contributor,Test Creator,Test date_created,Test description,Test identifier,Test keyword,Test publisher,Test label,Test language,https://creativecommons.org/licenses/by/4.0/,Test related_url,Article,Test rights_notes,http://rightsstatements.org/vocab/InC/1.0/,Test source,Test subject,Test target_audience,Test department,Test course,restricted,
          CSV

          post skullrax.batch_create_path, params: params

          expect(response.headers['Content-Disposition']).to include('attachment; filename="batch_create_form_')

          actual_rows = CSV.parse(response.body, headers: true)
          expected_rows = CSV.parse(expected_csv, headers: true)

          expect(actual_rows.length).to eq(1)
          expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
          expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        end
      end
    end

    context 'when batch uploads directory cleanup' do
      let(:batch_uploads_dir) { Rails.root.join('tmp', 'skullrax_batch_uploads', 'test123') }

      before do
        allow(importer).to receive(:errors).and_return([])
        allow(FileUtils).to receive(:rm_rf)
        # Mock the batch_uploads_dir to return a known value
        allow_any_instance_of(described_class).to receive(:batch_uploads_dir).and_return(batch_uploads_dir)
        allow(File).to receive(:exist?).and_call_original
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
