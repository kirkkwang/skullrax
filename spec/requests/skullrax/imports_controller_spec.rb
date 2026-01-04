# frozen_string_literal: true

require 'zip'

RSpec.describe Skullrax::ImportsController do
  include Devise::Test::IntegrationHelpers

  before do
    admin = create(:admin, email: 'admin@example.com')
    sign_in admin
  end

  describe 'POST /skullrax/imports' do
    context 'with valid CSV file' do
      it 'imports successfully and redirects with notice' do
        csv_content = <<~CSV
          title,creator,visibility
          Test Title 1,Author One,open
          Test Title 2,Author Two,open
        CSV

        csv_file = Tempfile.new(['import', '.csv'])
        csv_file.write(csv_content)
        csv_file.rewind

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'import.csv')

        post skullrax.imports_path, params: { import: { file: uploaded_file } }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(%r{^http://www.example.com/skullrax/\?})
        expect(flash[:notice]).to eq('Import completed successfully.')

        csv_file.close
        csv_file.unlink
      end
    end

    context 'with valid ZIP file containing CSV and files' do
      it 'extracts and imports successfully' do
        csv_content = <<~CSV
          title,creator,visibility,file
          Test Title 1,Author One,open,files/test_file.png
          Test Title 2,Author Two,open,test_file.txt
        CSV

        zip_file = Tempfile.new(['import', '.zip'])

        Zip::File.open(zip_file.path, create: true) do |zipfile|
          zipfile.get_output_stream('import.csv') { |f| f.write(csv_content) }

          zipfile.get_output_stream('files/test_file.png') do |f|
            f.write(File.read(Skullrax.root.join('spec/fixtures/files/test_file.png')))
          end

          zipfile.get_output_stream('test_file.txt') do |f|
            f.write(File.read(Skullrax.root.join('spec/fixtures/files/test_file.txt')))
          end
        end

        uploaded_file = Rack::Test::UploadedFile.new(zip_file.path, 'application/zip', original_filename: 'import.zip')

        post skullrax.imports_path, params: { import: { file: uploaded_file } }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(%r{^http://www.example.com/skullrax/\?})
        expect(flash[:notice]).to eq('Import completed successfully.')

        zip_file.close
        zip_file.unlink
      end
    end

    context 'with ZIP file missing CSV' do
      it 'redirects with error message' do
        zip_file = Tempfile.new(['import', '.zip'])

        Zip::File.open(zip_file.path, create: true) do |zipfile|
          zipfile.get_output_stream('files/test_file.png') do |f|
            f.write(File.read(Skullrax.root.join('spec/fixtures/files/test_file.png')))
          end
        end

        uploaded_file = Rack::Test::UploadedFile.new(zip_file.path, 'application/zip', original_filename: 'import.zip')

        post skullrax.imports_path, params: { import: { file: uploaded_file } }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(%r{^http://www.example.com/skullrax/\?})
        expect(flash[:alert]).to include('No CSV file found inside the ZIP')

        zip_file.close
        zip_file.unlink
      end
    end

    context 'with invalid CSV data' do
      it 'redirects with formatted error messages' do
        csv_content = <<~CSV
          title,creator,visibility
          ,Author One,open
          Test Title 2,,open
        CSV

        csv_file = Tempfile.new(['import', '.csv'])
        csv_file.write(csv_content)
        csv_file.rewind

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'import.csv')

        post skullrax.imports_path, params: { import: { file: uploaded_file } }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(%r{^http://www.example.com/skullrax/\?})
        expect(flash[:alert]).to include('Import failed')
        expect(flash[:alert]).to match(/Row \d+:/)

        csv_file.close
        csv_file.unlink
      end
    end

    context 'with more than 5 errors' do
      it 'truncates error messages and shows count' do
        csv_content = <<~CSV
          title,creator,visibility
          ,Author One,open
          ,Author Two,open
          ,Author Three,open
          ,Author Four,open
          ,Author Five,open
          ,Author Six,open
        CSV

        csv_file = Tempfile.new(['import', '.csv'])
        csv_file.write(csv_content)
        csv_file.rewind

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'import.csv')

        post skullrax.imports_path, params: { import: { file: uploaded_file } }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(%r{^http://www.example.com/skullrax/\?})
        expect(flash[:alert]).to include('...and 1 more errors')

        csv_file.close
        csv_file.unlink
      end
    end

    context 'with no file' do
      it 'redirects with alert' do
        post skullrax.imports_path, params: { import: { file: nil } }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(%r{^http://www.example.com/skullrax/\?})
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
  end
end
