# frozen_string_literal: true

RSpec.describe Skullrax::CsvExporter do
  before do
    create(:admin, email: 'admin@example.com')
  end

  describe 'export' do
    it 'exports a roundtrip-able CSV file' do
      future_date = Date.today + 1.month

      initial_csv = <<~CSV
        model,title,creator,description,visibility,visibility_during_lease,lease_expiration_date,visibility_after_lease,visibility_during_embargo,embargo_release_date,visibility_after_embargo,file
        CollectionResource,,Collection Creator;Another Collection Creator,,restricted
        GenericWorkResource,,,Work description,lease,open,#{future_date},authenticated
        FileSet,,,,lease,open,#{future_date},authenticated,,,,#{Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png')}
        Monograph,Monograph Title,,,embargo,,,,restricted,#{future_date},open
      CSV

      importer = Skullrax::CsvImporter.new(csv: initial_csv)
      importer.import(autofill: true)

      collection = importer.collections.first
      generic_work = importer.works.find { |work| work.is_a?(GenericWorkResource) }
      file_set = importer.file_sets.first
      monograph = importer.works.find { |work| work.is_a?(Monograph) }

      expect(collection.creator).to eq(['Collection Creator', 'Another Collection Creator'])
      expect(collection.visibility).to eq('restricted')
      expect(generic_work.description).to eq(['Work description'])
      expect(generic_work.visibility).to eq('open')
      expect(generic_work.lease.visibility_during_lease).to eq('open')
      expect(generic_work.lease.lease_expiration_date.to_date).to eq(future_date)
      expect(generic_work.lease.visibility_after_lease).to eq('authenticated')
      expect(file_set.visibility).to eq('open')
      expect(file_set.lease.visibility_during_lease).to eq('open')
      expect(file_set.lease.lease_expiration_date.to_date).to eq(future_date)
      expect(file_set.lease.visibility_after_lease).to eq('authenticated')
      expect(monograph.visibility).to eq('restricted')
      expect(monograph.embargo.visibility_during_embargo).to eq('restricted')
      expect(monograph.embargo.embargo_release_date.to_date).to eq(future_date)
      expect(monograph.embargo.visibility_after_embargo).to eq('open')
      expect(monograph.title).to eq(['Monograph Title'])

      exporter = Skullrax::CsvExporter.new(ids: [collection.id, generic_work.id, monograph.id])
      exporter.export

      parsed = CSV.parse(exporter.csv, headers: true)

      parsed.each do |row|
        if row['model'] == 'CollectionResource'
          row['creator'] = row['creator']&.split(';')&.first
          row['visibility'] = 'open'
        end

        if row['model'] == 'GenericWorkResource'
          row['description'] = 'Updated work description'
          row['visibility'] = 'open'
          row['visibility_during_lease'] = nil
          row['lease_expiration_date'] = nil
          row['visibility_after_lease'] = nil
        end

        if row['model'] == 'Hyrax::FileSet'
          row['title'] = 'Updated FileSet Title'
          row['visibility'] = 'restricted'
          row['visibility_during_lease'] = nil
          row['lease_expiration_date'] = nil
          row['visibility_after_lease'] = nil
        end

        next unless row['model'] == 'Monograph'

        row['title'] = 'An Updated Monograph Title'
        row['visibility'] = 'open'
        row['visibility_during_embargo'] = nil
        row['embargo_release_date'] = nil
        row['visibility_after_embargo'] = nil
      end

      updated_csv = CSV.generate(headers: true) do |csv|
        csv << parsed.headers
        parsed.each { |row| csv << row }
      end

      update_importer = Skullrax::CsvImporter.new(csv: updated_csv)
      update_importer.update

      updated_collection = update_importer.collections.first
      updated_generic_work = update_importer.works.find { |work| work.is_a?(GenericWorkResource) }
      updated_file_set = update_importer.file_sets.first
      updated_monograph = update_importer.works.find { |work| work.is_a?(Monograph) }

      expect(updated_collection.creator).to eq(['Collection Creator'])
      expect(updated_collection.visibility).to eq('open')
      expect(updated_generic_work.description).to eq(['Updated work description'])
      expect(updated_generic_work.visibility).to eq('open')
      expect(updated_generic_work.lease).not_to be_active
      expect(updated_file_set.visibility).to eq('restricted')
      expect(updated_file_set.lease).not_to be_active
      expect(updated_monograph.title).to eq(['An Updated Monograph Title'])
      expect(updated_monograph.visibility).to eq('open')
      expect(updated_monograph.embargo).not_to be_active
    end

    context 'with include_files option' do
      after do
        FileUtils.rm_rf(Dir.glob(Rails.root.join('tmp', 'exports', '*')))
        storage_path = Valkyrie::StorageAdapter.storage_adapters[:disk].base_path
        FileUtils.rm_rf(Dir.glob("#{storage_path}/*"))
      end

      it 'includes file paths in the exported CSV' do
        allow(Hyrax::Characterization::ValkyrieCharacterizationService).to receive(:run)

        csv = <<~CSV
          model,title,creator,description,file
          GenericWorkResource,,,Work description,
          FileSet,,,,#{Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt')}
          FileSet,,,,#{Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png')}
        CSV

        importer = Skullrax::CsvImporter.new(csv:)

        perform_enqueued_jobs do
          importer.import(autofill: true)
        end

        work = importer.works.first

        file_set1 = importer.file_sets.first
        original_filename1 = file_set1.original_file.original_filename

        file_set2 = importer.file_sets.last
        original_filename2 = file_set2.original_file.original_filename

        exporter = Skullrax::CsvExporter.new(ids: [work.id])

        zip_data = exporter.export(include_files: true)

        expect(zip_data).to be_present
        expect(zip_data).to be_a(String)

        Dir.mktmpdir do |dir|
          temp_zip_path = File.join(dir, 'test_export.zip')
          File.binwrite(temp_zip_path, zip_data)

          Zip::File.open(temp_zip_path) do |zip|
            expect(zip.find_entry('export.csv')).to be_truthy

            expected_path1 = "#{file_set1.id}/#{original_filename1}"
            expect(zip.find_entry(expected_path1)).to be_truthy

            expected_path2 = "#{file_set2.id}/#{original_filename2}"
            expect(zip.find_entry(expected_path2)).to be_truthy
          end
        end
      end
    end
  end
end
