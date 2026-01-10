# frozen_string_literal: true

require 'zip'

RSpec.describe Skullrax::ImportsController do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin, email: 'admin@example.com') }

  before { sign_in admin }

  describe 'POST /skullrax/imports' do
    subject(:post_import) do
      post skullrax.imports_path, params: { import: { file: uploaded_file, action: import_action } }
    end

    context 'when creating new resources' do
      let(:import_action) { 'create' }

      let(:csv_content) do
        <<~CSV
          title,creator,visibility
          Test Title 1,Author One,open
          Test Title 2,Author Two,open
        CSV
      end

      context 'with valid CSV file' do
        let(:uploaded_file) { upload_csv(csv_content) }

        it 'redirects with success notice' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:notice]).to eq('Import completed successfully.')
        end
      end

      context 'with valid ZIP file containing CSV and files' do
        let(:csv_content) do
          <<~CSV
            title,creator,visibility,file
            Test Title 1,Author One,open,files/test_file.png
            Test Title 2,Author Two,open,test_file.txt
          CSV
        end

        let(:uploaded_file) do
          upload_zip do |zipfile|
            zipfile.get_output_stream('import.csv') { |f| f.write(csv_content) }
            zipfile.get_output_stream('files/test_file.png') do |f|
              f.write(File.read(fixture_file('test_file.png')))
            end
            zipfile.get_output_stream('test_file.txt') do |f|
              f.write(File.read(fixture_file('test_file.txt')))
            end
          end
        end

        it 'redirects with success notice' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:notice]).to eq('Import completed successfully.')
        end
      end

      context 'with ZIP file missing CSV' do
        let(:uploaded_file) do
          upload_zip do |zipfile|
            zipfile.get_output_stream('files/test_file.png') do |f|
              f.write(File.read(fixture_file('test_file.png')))
            end
          end
        end

        it 'redirects with error alert' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('No CSV file found inside the ZIP')
        end
      end

      context 'with a malformed CSV file' do
        let(:csv_content) do
          <<~CSV
            title,creator,description
            malformed work,Some Author,12'-6" clearance
          CSV
        end

        let(:uploaded_file) { upload_csv(csv_content) }

        it 'raises an error during import' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('Import failed')
          expect(flash[:alert]).to match(/Malformed CSV:/)
        end
      end

      context 'with invalid CSV data' do
        let(:csv_content) do
          <<~CSV
            title,creator,visibility
            ,Author One,open
            Test Title 2,,open
          CSV
        end

        let(:uploaded_file) { upload_csv(csv_content) }

        it 'redirects with formatted error messages' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('Import failed')
          expect(flash[:alert]).to match(/Row \d+:/)
        end
      end

      context 'with no file' do
        let(:uploaded_file) { nil }

        it 'redirects with error alert' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to eq('Please select a file.')
        end
      end

      context 'with missing file parameter' do
        it 'raises parameter missing error' do
          expect do
            post skullrax.imports_path, params: {}
          end.to raise_error(ActionController::ParameterMissing)
        end
      end

      context 'with a different admin user' do
        let(:other_admin) { create(:admin, email: 'other_admin@example.com') }
        let(:csv_content) do
          <<~CSV
            id,title,creator
            test-work-1,Test Title 1,Author One
          CSV
        end
        let(:uploaded_file) { upload_csv(csv_content) }

        before { sign_in other_admin }

        it 'imports the work with that user as depositor' do
          post_import

          expect(response).to redirect_to(/skullrax/)

          work = Hyrax.query_service.find_by(id: 'test-work-1')
          expect(work.depositor).to eq('other_admin@example.com')
        end
      end
    end

    context 'when updating existing resources' do
      let(:import_action) { 'update' }

      let!(:existing_work) do
        generator = Skullrax::ValkyrieWorkGenerator.new(id: 'existing-work-1', title: 'Old Title',
                                                        creator: 'Old Author')
        generator.generate
        generator.resource
      end

      let(:csv_content) do
        <<~CSV
          id,title,creator
          existing-work-1,New Title,New Author
        CSV
      end

      let(:uploaded_file) { upload_csv(csv_content) }

      it 'updates the existing work' do
        expect(existing_work.id).to eq('existing-work-1')
        expect(existing_work.title).to eq(['Old Title'])
        expect(existing_work.creator).to eq(['Old Author'])

        post_import

        expect(response).to redirect_to(/skullrax/)
        expect(flash[:notice]).to eq('Import completed successfully.')

        updated_work = Hyrax.query_service.find_by(id: 'existing-work-1')
        expect(updated_work.title).to eq(['New Title'])
        expect(updated_work.creator).to eq(['New Author'])
      end

      context 'with a malformed CSV file' do
        let(:csv_content) do
          <<~CSV
            title,creator,description
            malformed work,Some Author,12'-6" clearance
          CSV
        end

        let(:uploaded_file) { upload_csv(csv_content) }

        it 'raises an error during import' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('Import failed')
          expect(flash[:alert]).to match(/Malformed CSV:/)
        end
      end

      context 'when reporting errors on file set rows' do
        it 'reports the correct row number for file set errors' do
          csv_content = <<~CSV
            model,title,creator,file
            GenericWork,Test Work 1,Work Creator 1
            FileSet,,,fake1.jpg
            FileSet,,,fake2.jpg
            GenericWork,Test Work 2,Work Creator 2
            FileSet,,,fake3.jpg
            FileSet,,,fake4.jpg
          CSV

          uploaded_file = upload_csv(csv_content)

          post skullrax.imports_path, params: { import: { file: uploaded_file, action: 'create' } }

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('Import failed')
          expect(flash[:alert]).not_to match(/Row 2:/)
          expect(flash[:alert]).to match(/Row 3: File not found: fake1.jpg/)
          expect(flash[:alert]).to match(/Row 4: File not found: fake2.jpg/)
          expect(flash[:alert]).not_to match(/Row 5:/)
          expect(flash[:alert]).to match(/Row 6: File not found: fake3.jpg/)
          expect(flash[:alert]).to match(/Row 7: File not found: fake4.jpg/)
        end
      end

      context 'when updating non-existent resources' do
        let(:csv_content) do
          <<~CSV
            id,title,creator
            non-existent-work,Title,Author
          CSV
        end

        let(:uploaded_file) { upload_csv(csv_content) }

        it 'raises an object not found error during import' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('Import failed')
          expect(flash[:alert]).to match(/Cannot action: 1 ID not found: non-existent-work/)
        end
      end
    end

    context 'when destroying existing resources' do
      let(:import_action) { 'destroy' }

      let!(:existing_work) do
        generator = Skullrax::ValkyrieWorkGenerator.new(id: 'existing-work-1', title: 'To Be Deleted',
                                                        creator: 'Author')
        generator.generate
        generator.resource
      end

      let(:csv_content) do
        <<~CSV
          id
          existing-work-1
        CSV
      end

      let(:uploaded_file) { upload_csv(csv_content) }

      it 'deletes the existing work' do
        expect(Hyrax.query_service.find_by(id: 'existing-work-1')).not_to be_nil

        post_import

        expect(response).to redirect_to(/skullrax/)
        expect(flash[:notice]).to eq('Import completed successfully.')
        expect do
          Hyrax.query_service.find_by(id: 'existing-work-1')
        end.to raise_error(Valkyrie::Persistence::ObjectNotFoundError)
      end

      context 'with a malformed CSV file' do
        let(:csv_content) do
          <<~CSV
            title,creator,description
            malformed work,Some Author,12'-6" clearance
          CSV
        end

        let(:uploaded_file) { upload_csv(csv_content) }

        it 'raises an error during import' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('Import failed')
          expect(flash[:alert]).to match(/Malformed CSV:/)
        end
      end

      context 'when destroying non-existent resources' do
        let(:csv_content) do
          <<~CSV
            id
            non-existent-work
            another-non-existent-work
          CSV
        end

        let(:uploaded_file) { upload_csv(csv_content) }

        it 'raises an object not found error during import' do
          post_import

          expect(response).to redirect_to(/skullrax/)
          expect(flash[:alert]).to include('Import failed')
          expect(flash[:alert]).to match(/Cannot action: 2 IDs not found: non-existent-work, another-non-existent-work/)
        end
      end
    end
  end
end
