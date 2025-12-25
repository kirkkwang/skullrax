# frozen_string_literal: true

RSpec.describe Skullrax::CsvImporter do
  before do
    create(:admin, email: 'admin@example.com')
  end

  it 'can import content from a CSV' do
    csv = <<~CSV
      title,creator,visibility
      Test Title 1,Author One,open
      Test Title 2,Author Two,open
    CSV

    importer = Skullrax::CsvImporter.new(csv:)
    importer.import

    expect(importer.resources).to be_an(Array)
    expect(importer.resources.size).to eq(2)
    expect(importer.resources).to all(be_a(GenericWorkResource))
    expect(importer.resources.map(&:title)).to contain_exactly(['Test Title 1'], ['Test Title 2'])
    expect(importer.resources.map(&:creator)).to contain_exactly(['Author One'], ['Author Two'])
    expect(importer.resources.map(&:visibility)).to contain_exactly('open', 'open')
  end

  context 'when not all required fields are provided' do
    it 'accumulate errors' do
      csv = <<~CSV
        model,title
        CollectionResource,Collection Title 1
        GenericWorkResource,Test Title 1
      CSV

      importer = Skullrax::CsvImporter.new(csv:)
      importer.import(autofill: true, except: :creator)
      errors = importer.errors

      expect(errors.size).to eq(2)
      expect(errors.first[:row_number]).to eq(2)
      expect(errors.first[:resource_type]).to eq(CollectionResource)
      expect(errors.first[:errors].first).to include("Creator can't be blank")
      expect(errors.second[:row_number]).to eq(3)
      expect(errors.second[:resource_type]).to eq(GenericWorkResource)
      expect(errors.second[:errors].first).to include("Creator can't be blank")
    end
  end

  it 'can import other work types from a CSV' do
    csv = <<~CSV
      model,title,creator,record_info,visibility
      Monograph,Monograph Title 1,Author One,Some Record Info,open
    CSV

    importer = Skullrax::CsvImporter.new(csv:)
    importer.import
    resource = importer.resources.first

    expect(resource).to be_a(Monograph)
    expect(resource.title).to eq(['Monograph Title 1'])
    expect(resource.creator).to eq(['Author One'])
    expect(resource.record_info).to eq('Some Record Info')
    expect(resource.visibility).to eq('open')
  end

  it 'can import collections from a CSV' do
    csv = <<~CSV
      model,title,creator,visibility
      Collection,Collection Title,Collection Creator,open
    CSV

    importer = Skullrax::CsvImporter.new(csv:)
    importer.import
    resource = importer.resources.first

    expect(resource).to be_a(Hyrax.config.collection_class)
    expect(resource.title).to eq(['Collection Title'])
    expect(resource.creator).to eq(['Collection Creator'])
    expect(resource.visibility).to eq('open')
  end

  it 'can set the id of imported works and collections' do
    csv = <<~CSV
      model,id,title,creator,visibility
      Collection,col-123,Collection Title,Collection Creator,open
      GenericWorkResource,work-456,Work Title,Work Creator,open
    CSV

    importer = Skullrax::CsvImporter.new(csv:)
    importer.import
    collection = importer.collections.first
    work = importer.works.first

    expect(collection.id.to_s).to eq('col-123')
    expect(work.id.to_s).to eq('work-456')
  end

  it 'raises an error for invalid CSV input' do
    invalid_csv = nil
    importer = Skullrax::CsvImporter.new(csv: invalid_csv)

    expect { importer.import }.to raise_error(Skullrax::ArgumentError)
  end

  it 'supports unmigrated model name' do
    csv = <<~CSV
      model,title,creator,visibility
      GenericWork,Work Title,Work Creator,open
    CSV

    importer = Skullrax::CsvImporter.new(csv:)
    importer.import

    expect(importer.works.first.class).to eq(GenericWorkResource)
  end

  context 'with relationships' do
    it 'can create a relationship between a work and a collection' do
      csv = <<~CSV
        model,id,title,creator,member_of_collection_ids,visibility
        Collection,col-789,Related Collection,Collection Creator,,open
        GenericWork,,Work in Collection,Work Creator,col-789,open
      CSV

      importer = Skullrax::CsvImporter.new(csv:)
      importer.import
      work = importer.works.first

      expect(work.member_of_collection_ids).to include(importer.collections.first.id)
    end

    context 'when no collection id is provided for a work' do
      it 'assumes the collection that the works are under is the parent collection of the works' do
        csv = <<~CSV
          model,title,creator,record_info
          Collection,Parent Collection,Collection Creator
          GenericWork,Child Work,Work Creator
          Monograph,Another Child Work,Another Work Creator,Some Record Info
        CSV

        importer = Skullrax::CsvImporter.new(csv:)
        importer.import

        expect(importer.works.map(&:member_of_collection_ids)).to all(include(importer.collections.first.id))
      end

      it 'supports multiple collections and their works' do
        csv = <<~CSV
          model,title,creator,record_info
          Collection,Collection One,Collection Creator One
          GenericWork,Work One,Work Creator One
          Collection,Collection Two,Collection Creator Two
          Monograph,Work Two,Work Creator Two,Some Record Info
        CSV

        importer = Skullrax::CsvImporter.new(csv:)
        importer.import

        collection_one = importer.collections[0]
        collection_two = importer.collections[1]
        work_one = importer.works[0]
        work_two = importer.works[1]

        expect(work_one.member_of_collection_ids).to include(collection_one.id)
        expect(work_two.member_of_collection_ids).to include(collection_two.id)
      end

      it 'will handle standalone works without collections' do
        csv = <<~CSV
          model,title,creator
          GenericWork,Standalone Work,Work Creator
          GenericWork,Another Standalone Work,Another Work Creator
          Collection,Some Collection,Collection Creator
          GenericWork,Work in Collection,Work Creator
        CSV

        importer = Skullrax::CsvImporter.new(csv:)
        importer.import

        expect(importer.works.first.member_of_collection_ids).to be_empty
        expect(importer.works.second.member_of_collection_ids).to be_empty
        expect(importer.works.last.member_of_collection_ids).to include(importer.collections.first.id)
      end
    end

    context 'with file_sets' do
      it 'can import a file set on the work row' do
        csv = <<~CSV
          model,title,creator,visibility,file
          GenericWork,Work with FileSet,Work Creator,open,spec/fixtures/files/test_file.png
        CSV

        importer = Skullrax::CsvImporter.new(csv:)
        importer.import

        work = importer.works.first
        expect(work.member_ids.size).to eq(1)
      end

      it 'can import file sets on separate rows under its works' do
        csv = <<~CSV
          model,title,creator,visibility,file
          GenericWork,Work with FileSet,Work Creator,open
          FileSet,FileSet Title,FileSet Creator,open,spec/fixtures/files/test_file.png
          GenericWork,Another Work,Another Creator,open
          FileSet,Another FileSet,Another FileSet Creator,open,spec/fixtures/files/test_file.txt
        CSV

        importer = Skullrax::CsvImporter.new(csv:)
        importer.import

        work_with_file_set = importer.works.find { |work| work.title.include?('Work with FileSet') }
        expect(work_with_file_set.member_ids.size).to eq(1)

        file_set1 = importer.file_sets.find { |fs| fs.title.include?('FileSet Title') }
        expect(file_set1.title).to eq(['FileSet Title'])
        expect(file_set1.creator).to eq(['FileSet Creator'])

        another_work_with_file_set = importer.works.find { |work| work.title.include?('Another Work') }
        expect(another_work_with_file_set.member_ids.size).to eq(1)

        file_set2 = importer.file_sets.find { |fs| fs.title.include?('Another FileSet') }
        expect(file_set2.title).to eq(['Another FileSet'])
        expect(file_set2.creator).to eq(['Another FileSet Creator'])
      end
    end
  end

  context 'with multi-valued fields' do
    it 'can split values by a delimiter' do
      csv = <<~CSV
        model,title,creator,keyword,visibility
        GenericWork,Work title ; Second Title,Some Author; Some Other Author,keyword1;keyword2;keyword3,open
      CSV

      importer = Skullrax::CsvImporter.new(csv:)
      importer.import

      expect(importer.works.first.title).to contain_exactly('Work title', 'Second Title')
      expect(importer.works.first.creator).to contain_exactly('Some Author', 'Some Other Author')
      expect(importer.works.first.keyword).to contain_exactly('keyword1', 'keyword2', 'keyword3')
    end

    it 'can split by a different delimiter' do
      csv = <<~CSV
        model,title,creator,keyword,visibility
        GenericWork,Work title | Second Title,Some Author| Some Other Author,keyword1|keyword2|keyword3,open
      CSV

      importer = Skullrax::CsvImporter.new(csv:, delimiter: '|')
      importer.import

      expect(importer.works.first.title).to contain_exactly('Work title', 'Second Title')
      expect(importer.works.first.creator).to contain_exactly('Some Author', 'Some Other Author')
      expect(importer.works.first.keyword).to contain_exactly('keyword1', 'keyword2', 'keyword3')
    end
  end
end
