# frozen_string_literal: true

RSpec.describe Skullrax::YmlToCsvConverterService do
  let(:yml_path) { Rails.root.join('tmp', 'test_seeds.yml') }

  before do
    FileUtils.mkdir_p(yml_path.dirname)
  end

  after do
    FileUtils.rm_f(yml_path) if File.exist?(yml_path)
  end

  describe '#to_csv' do
    context 'with a simple GenericWork' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: GenericWork
              admin_set_id: admin_set_default
              title:
                - "No Collection Work 1 Title"
              creator:
                - "No Collection Work 1 Creator"
                - "Second Creator"
              visibility: open
        YML
      end

      it 'converts to CSV format' do
        File.write(yml_path, yml_content)

        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility
          GenericWorkResource,admin_set_default,No Collection Work 1 Title,No Collection Work 1 Creator;Second Creator,open
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a simple Collection' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: CollectionResource
              title:
                - "Collection 1 Title"
              creator:
                - "Collection 1 Creator"
              visibility: open
        YML
      end

      it 'converts to CSV format' do
        File.write(yml_path, yml_content)

        expected_csv = <<~CSV
          model,title,creator,visibility
          CollectionResource,Collection 1 Title,Collection 1 Creator,open
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a Collection containing a work' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: CollectionResource
              title:
                - "Collection 1 Title"
              creator:
                - "Collection 1 Creator"
              visibility: open
              works:
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Collection 1 Work 1 Title"
                  creator:
                    - "Collection 1 Work 1 Creator"
                  visibility: open
        YML
      end

      it 'converts to CSV with collection first, then work' do
        File.write(yml_path, yml_content)

        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,
          GenericWorkResource,Collection 1 Work 1 Title,Collection 1 Work 1 Creator,open,admin_set_default
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(2)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
      end
    end

    context 'with a collection containing multiple works' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: CollectionResource
              title:
                - "Collection 1 Title"
              creator:
                - "Collection 1 Creator"
              visibility: open
              works:
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Work 1 Title"
                  creator:
                    - "Work 1 Creator"
                  visibility: open
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Work 2 Title"
                  creator:
                    - "Work 2 Creator"
                  visibility: restricted
        YML
      end

      it 'converts to CSV with collection, then both works' do
        File.write(yml_path, yml_content)

        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,
          GenericWorkResource,Work 1 Title,Work 1 Creator,open,admin_set_default
          GenericWorkResource,Work 2 Title,Work 2 Creator,restricted,admin_set_default
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(3)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
      end
    end

    context 'with a work containing remote files' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: GenericWork
              admin_set_id: admin_set_default
              title:
                - "Work with Remote Files"
              creator:
                - "Work Creator"
              visibility: open
              files:
                - "https://example.com/file1.jpg"
                - "https://example.com/file2.pdf"
        YML
      end

      it 'converts to CSV with remote files joined by semicolon' do
        File.write(yml_path, yml_content)

        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Work with Remote Files,Work Creator,open,https://example.com/file1.jpg;https://example.com/file2.pdf
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a work containing local file paths' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: GenericWork
              admin_set_id: admin_set_default
              title:
                - "Work with Local Files"
              creator:
                - "Work Creator"
              visibility: open
              files:
                - "db/seeds/files/image.png"
                - "db/seeds/files/document.pdf"
        YML
      end

      it 'converts relative paths to absolute paths' do
        File.write(yml_path, yml_content)

        expected_file1 = Rails.root.join('db/seeds/files/image.png').to_s
        expected_file2 = Rails.root.join('db/seeds/files/document.pdf').to_s

        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Work with Local Files,Work Creator,open,#{expected_file1};#{expected_file2}
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a work containing absolute file paths' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: GenericWork
              admin_set_id: admin_set_default
              title:
                - "Work with Absolute Files"
              creator:
                - "Work Creator"
              visibility: open
              files:
                - "/absolute/path/to/image.png"
        YML
      end

      it 'keeps absolute paths unchanged' do
        File.write(yml_path, yml_content)

        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Work with Absolute Files,Work Creator,open,/absolute/path/to/image.png
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a work containing mixed local and remote files' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: GenericWork
              admin_set_id: admin_set_default
              title:
                - "Work with Mixed Files"
              creator:
                - "Work Creator"
              visibility: open
              files:
                - "db/seeds/files/local.png"
                - "https://example.com/remote.jpg"
        YML
      end

      it 'converts to CSV with both local and remote files' do
        File.write(yml_path, yml_content)

        expected_local = Rails.root.join('db/seeds/files/local.png').to_s

        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Work with Mixed Files,Work Creator,open,#{expected_local};https://example.com/remote.jpg
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a collection containing a work with a fileset' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: CollectionResource
              title:
                - "Collection 1 Title"
              creator:
                - "Collection 1 Creator"
              visibility: open
              works:
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Work with FileSet"
                  creator:
                    - "Work Creator"
                  visibility: open
                  filesets:
                    - model: Hyrax::FileSet
                      title:
                        - "FileSet Title"
                      creator:
                        - "FileSet Creator"
                      visibility: open
                      file: "db/seeds/files/image.png"
        YML
      end

      it 'converts to CSV with collection, work, then fileset' do
        File.write(yml_path, yml_content)

        expected_file = Rails.root.join('db/seeds/files/image.png').to_s

        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id,file
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,,
          GenericWorkResource,Work with FileSet,Work Creator,open,admin_set_default,
          Hyrax::FileSet,FileSet Title,FileSet Creator,open,,#{expected_file}
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(3)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
      end
    end

    context 'with a collection containing a work with multiple filesets' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: CollectionResource
              title:
                - "Collection 1 Title"
              creator:
                - "Collection 1 Creator"
              visibility: open
              works:
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Work with Multiple FileSets"
                  creator:
                    - "Work Creator"
                  visibility: open
                  filesets:
                    - model: Hyrax::FileSet
                      title:
                        - "FileSet 1 Title"
                      creator:
                        - "FileSet 1 Creator"
                      visibility: open
                      file: "db/seeds/files/image.png"
                    - model: Hyrax::FileSet
                      title:
                        - "FileSet 2 Title"
                      creator:
                        - "FileSet 2 Creator"
                      visibility: restricted
                      file: "https://example.com/remote.jpg"
        YML
      end

      it 'converts to CSV with collection, work, then both filesets' do
        File.write(yml_path, yml_content)

        expected_file = Rails.root.join('db/seeds/files/image.png').to_s

        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id,file
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,,
          GenericWorkResource,Work with Multiple FileSets,Work Creator,open,admin_set_default,
          Hyrax::FileSet,FileSet 1 Title,FileSet 1 Creator,open,,#{expected_file}
          Hyrax::FileSet,FileSet 2 Title,FileSet 2 Creator,restricted,,https://example.com/remote.jpg
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(4)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
        expect(actual_rows[3].to_h).to eq(expected_rows[3].to_h)
      end
    end

    context 'with standalone work and collection (wrong order)' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: CollectionResource
              title:
                - "Collection Title"
              creator:
                - "Collection Creator"
              visibility: open
              works:
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Work in Collection"
                  creator:
                    - "Work Creator"
                  visibility: open
            - model: GenericWork
              admin_set_id: admin_set_default
              title:
                - "Standalone Work"
              creator:
                - "Standalone Creator"
              visibility: open
        YML
      end

      it 'outputs CSV with standalone work first, then collection and its works' do
        File.write(yml_path, yml_content)

        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility
          GenericWorkResource,admin_set_default,Standalone Work,Standalone Creator,open
          CollectionResource,,Collection Title,Collection Creator,open
          GenericWorkResource,admin_set_default,Work in Collection,Work Creator,open
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(3)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
      end
    end

    context 'with full complex real-world YML structure' do
      let(:yml_content) do
        <<~YML
          resources:
            - model: CollectionResource
              title:
                - "Collection 1 Title"
              creator:
                - "Collection 1 Creator 1"
                - "Collection 1 Creator 2"
              visibility: open
              works:
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Collection 1 Work 1 Title"
                  creator:
                    - "Collection 1 Work 1 Creator"
                  visibility: open
                  files:
                    - "db/seeds/files/image1.png"
                  filesets:
                    - model: Hyrax::FileSet
                      title:
                        - "Collection 1 Work FileSet Form Title"
                      creator:
                        - "Collection 1 Work FileSet Form Creator"
                      visibility: restricted
                      file: "https://example.com/image.jpg"
                - model: Monograph
                  admin_set_id: admin_set_default
                  title:
                    - "Collection 1 Work 2 Title"
                  creator:
                    - "Collection 1 Work 2 Creator"
                  record_info:
                    - "Collection 1 Work 2 Record Info"
                  visibility: restricted
            - model: GenericWork
              admin_set_id: admin_set_default
              title:
                - "No Collection Work 1 Title"
              creator:
                - "No Collection Work 1 Creator"
              visibility: embargo
              visibility_during_embargo: restricted
              embargo_release_date: "2026-01-30"
              visibility_after_embargo: authenticated
              files:
                - "https://example.com/image2.jpg"
                - "https://example.com/image3.jpg"
              filesets:
                - model: Hyrax::FileSet
                  title:
                    - "No Collection Work 1 FileSet Form Title"
                  creator:
                    - "No Collection Work 1 FileSet Form Creator"
                  visibility: open
                  file: "db/seeds/files/document.pdf"
            - model: Monograph
              admin_set_id: admin_set_default
              title:
                - "No Collection Work 2 Title"
              creator:
                - "No Collection Work 2 Creator"
              record_info:
                - "No Collection Work 2 Record Info"
              visibility: open
            - model: CollectionResource
              title:
                - "Collection 2 Title"
              creator:
                - "Collection 2 Creator"
              visibility: restricted
              works:
                - model: GenericWork
                  admin_set_id: admin_set_default
                  title:
                    - "Collection 2 Work 1 Title"
                  creator:
                    - "Collection 2 Work 1 Creator"
                  subject:
                    - "Collection 2 Work 1 Subject 1"
                    - "Collection 2 Work 1 Subject 2"
                  visibility: lease
                  visibility_during_lease: open
                  lease_expiration_date: "2026-01-30"
                  visibility_after_lease: restricted
                  files:
                    - "db/seeds/files/file1.csv"
                    - "db/seeds/files/file2.csv"
                - model: Monograph
                  admin_set_id: admin_set_default
                  title:
                    - "Collection 2 Work 2 Title"
                  creator:
                    - "Collection 2 Work 2 Creator"
                  record_info:
                    - "Collection 2 Work 2 Record info"
                  visibility: restricted
                  filesets:
                    - model: Hyrax::FileSet
                      title:
                        - "Collection 2 Work 2 FileSet Form 1 Title"
                      creator:
                        - "Collection 2 Work 2 FileSet Form 1 Creator"
                      license:
                        - "http://creativecommons.org/publicdomain/zero/1.0/"
                      visibility: open
                      file: "db/seeds/files/document.pdf"
                    - model: Hyrax::FileSet
                      title:
                        - "Collection 2 Work 2 FileSet Form 2 Title"
                      creator:
                        - "Collection 2 Work 2 FileSet Form 2 Creator"
                      visibility: authenticated
                      file: "https://example.com/image4.jpg"
        YML
      end

      it 'handles full complex nested structure with proper ordering' do
        File.write(yml_path, yml_content)

        file1 = Rails.root.join('db/seeds/files/image1.png').to_s
        file2 = Rails.root.join('db/seeds/files/document.pdf').to_s
        file3 = Rails.root.join('db/seeds/files/file1.csv').to_s
        file4 = Rails.root.join('db/seeds/files/file2.csv').to_s

        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,visibility_during_embargo,embargo_release_date,visibility_after_embargo,record_info,subject,visibility_during_lease,lease_expiration_date,visibility_after_lease,license,file
          GenericWorkResource,admin_set_default,No Collection Work 1 Title,No Collection Work 1 Creator,embargo,restricted,2026-01-30,authenticated,,,,,,,https://example.com/image2.jpg;https://example.com/image3.jpg
          Hyrax::FileSet,,No Collection Work 1 FileSet Form Title,No Collection Work 1 FileSet Form Creator,open,,,,,,,,,,#{file2}
          Monograph,admin_set_default,No Collection Work 2 Title,No Collection Work 2 Creator,open,,,,No Collection Work 2 Record Info,,,,,,
          CollectionResource,,Collection 1 Title,Collection 1 Creator 1;Collection 1 Creator 2,open,,,,,,,,,,
          GenericWorkResource,admin_set_default,Collection 1 Work 1 Title,Collection 1 Work 1 Creator,open,,,,,,,,,,#{file1}
          Hyrax::FileSet,,Collection 1 Work FileSet Form Title,Collection 1 Work FileSet Form Creator,restricted,,,,,,,,,,https://example.com/image.jpg
          Monograph,admin_set_default,Collection 1 Work 2 Title,Collection 1 Work 2 Creator,restricted,,,,Collection 1 Work 2 Record Info,,,,,,
          CollectionResource,,Collection 2 Title,Collection 2 Creator,restricted,,,,,,,,,,
          GenericWorkResource,admin_set_default,Collection 2 Work 1 Title,Collection 2 Work 1 Creator,lease,,,,,Collection 2 Work 1 Subject 1;Collection 2 Work 1 Subject 2,open,2026-01-30,restricted,,#{file3};#{file4}
          Monograph,admin_set_default,Collection 2 Work 2 Title,Collection 2 Work 2 Creator,restricted,,,,Collection 2 Work 2 Record info,,,,,,
          Hyrax::FileSet,,Collection 2 Work 2 FileSet Form 1 Title,Collection 2 Work 2 FileSet Form 1 Creator,open,,,,,,,,,http://creativecommons.org/publicdomain/zero/1.0/,#{file2}
          Hyrax::FileSet,,Collection 2 Work 2 FileSet Form 2 Title,Collection 2 Work 2 FileSet Form 2 Creator,authenticated,,,,,,,,,,https://example.com/image4.jpg
        CSV

        service = described_class.new(yml_path:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(12)
        (0..11).each do |i|
          expect(actual_rows[i].to_h).to eq(expected_rows[i].to_h)
        end
      end
    end
  end
end
