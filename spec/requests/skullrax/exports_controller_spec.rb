# frozen_string_literal: true

RSpec.describe Skullrax::ExportsController do
  include Devise::Test::IntegrationHelpers

  before do
    admin = create(:admin, email: 'admin@example.com')
    sign_in admin
  end

  describe 'GET /skullrax/exports' do
    let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
    let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }

    let!(:work_id1) do
      Skullrax::ValkyrieWorkGenerator.new(file_paths: [file1]).generate(autofill: true).value!.id.to_s
    end
    let!(:work_id2) do
      Skullrax::ValkyrieWorkGenerator.new(file_paths: [file2]).generate(autofill: true).value!.id.to_s
    end

    context 'with valid work IDs' do
      it 'exports successfully and returns CSV' do
        get skullrax.exports_path, params: { ids: "#{work_id1}\r\n#{work_id2}" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include('.csv')
      end
    end

    context 'with include_files checkbox checked' do
      it 'exports successfully and returns a ZIP file' do
        get skullrax.exports_path, params: { ids: "#{work_id1}\r\n#{work_id2}", include_files: '1' }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/zip')
        expect(response.headers['Content-Disposition']).to include('.zip')
      end
    end

    context 'with no IDs' do
      it 'returns an error' do
        get skullrax.exports_path, params: { ids: '' }

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end

    context 'with missing ids parameter' do
      it 'returns an error' do
        get skullrax.exports_path, params: {}

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
