# frozen_string_literal: true

RSpec.describe Skullrax::ValkyrieWorkGenerator do
  before do
    create(:admin, email: 'admin@example.com')
  end

  it 'creates a work' do
    generator = described_class.new
    result = generator.create

    expect(result).to be_success
    expect(generator.resource.class).to eq Wings::ModelRegistry.reverse_lookup(Hyrax.config.curation_concerns.first)
  end

  it 'fills in required properties with "Test <property>"' do
    generator = described_class.new
    generator.create

    expect(generator.resource.title).to eq ['Test title']
    expect(generator.resource.creator).to eq ['Test creator']
  end

  it 'returns a failure if there are errors' do
    generator = described_class.new
    # makes generate think there aren't any required properties
    allow(generator.parameter_builder).to receive(:required_properties).and_return([])

    result = generator.create

    expect(result).to be_failure
    expect(generator.resource.id).to be_nil
    expect(generator.errors).not_to be_empty
  end

  context 'when passing kwargs' do
    it 'creates a work of that model' do
      generator = described_class.new(model: Monograph)
      result = generator.create

      expect(result).to be_success
      expect(generator.resource).to be_a Monograph
    end

    it 'sets properties from kwargs' do
      generator = described_class.new(model: Monograph,
                                      title: ['Custom Title'],
                                      creator: ['Custom Creator'])
      result = generator.create

      expect(result).to be_success
      expect(generator.resource).to be_a Monograph
      expect(generator.resource.title).to eq ['Custom Title']
      expect(generator.resource.creator).to eq ['Custom Creator']
    end

    it 'ignores unknown properties' do
      generator = described_class.new(model: Monograph, unknown_property: 'Some Value', another_one: 123)
      result = generator.create

      expect(result).to be_success
      expect(generator.resource).to be_a Monograph
      expect(generator.resource.respond_to?(:unknown_property)).to be false
      expect(generator.resource.respond_to?(:another_one)).to be false
    end

    context 'when visibility is provided' do
      it 'can set open' do
        generator = described_class.new(visibility: 'open')
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.visibility).to eq 'open'
      end

      it 'can set restricted' do
        generator = described_class.new(visibility: 'restricted')
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.visibility).to eq 'restricted'
      end

      it 'can set authenticated' do
        generator = described_class.new(visibility: 'authenticated')
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.visibility).to eq 'authenticated'
      end

      it 'can set embargo' do
        future_date = Date.today + 1.month
        generator = described_class.new(
          visibility: 'embargo',
          visibility_during_embargo: 'restricted',
          embargo_release_date: future_date,
          visibility_after_embargo: 'open'
        )
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.visibility).to eq 'restricted'
        expect(generator.resource.embargo.embargo_release_date).to eq future_date
        expect(generator.resource.embargo.visibility_during_embargo).to eq 'restricted'
        expect(generator.resource.embargo.visibility_after_embargo).to eq 'open'
      end

      it 'can set lease' do
        future_date = Date.today + 1.month
        generator = described_class.new(
          visibility: 'lease',
          visibility_during_lease: 'open',
          lease_expiration_date: future_date,
          visibility_after_lease: 'authenticated'
        )
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.visibility).to eq 'open'
        expect(generator.resource.lease.lease_expiration_date).to eq future_date
        expect(generator.resource.lease.visibility_after_lease).to eq 'authenticated'
      end
    end
  end

  context 'when properties are controlled vocabularies' do
    it 'sets properties from controlled vocabularies' do
      generator = described_class.new(license: ['https://creativecommons.org/licenses/by-nc/4.0/'])
      allow(generator.parameter_builder)
        .to(receive(:required_properties)
              .and_return(generator.parameter_builder.required_properties + ['license']))

      result = generator.create

      expect(result).to be_success
      expect(generator.resource.license).to eq ['https://creativecommons.org/licenses/by-nc/4.0/']
    end

    it 'raises an error for invalid controlled vocabulary terms' do
      generator = described_class.new(license: ['Invalid License Term'])
      allow(generator.parameter_builder)
        .to(receive(:required_properties)
              .and_return(generator.parameter_builder.required_properties + ['license']))

      expect { generator.create }.to raise_error(Skullrax::InvalidControlledVocabularyTerm)
    end

    it 'fills in required controlled vocabularies if they are not provided' do
      license_authority = Qa::Authorities::Local.subauthority_for('licenses')
      active_license_terms = license_authority.all.select { |hash| hash[:active] }.pluck(:id)
      rights_statement_authority = Qa::Authorities::Local.subauthority_for('rights_statements')
      active_rights_terms = rights_statement_authority.all.select { |hash| hash[:active] }.pluck(:id)
      resource_type_authority = Qa::Authorities::Local.subauthority_for('resource_types')
      active_resource_types = resource_type_authority.all.select { |hash| hash[:active] }.pluck(:id)

      generator = described_class.new
      extra_fields = %w[license rights_statement resource_type]
      allow(generator.parameter_builder)
        .to(receive(:required_properties)
              .and_return(generator.parameter_builder.required_properties + extra_fields))

      result = generator.create

      expect(result).to be_success
      expect(active_license_terms).to include(generator.resource.license.first)
      expect(active_rights_terms).to include(generator.resource.rights_statement.first)
      expect(active_resource_types).to include(generator.resource.resource_type.first)
    end

    context 'when the authority uses singular property names' do
      it 'attempts to adjust for unconventional naming' do
        resource_type_authority = Qa::Authorities::Local.subauthority_for('resource_types')
        active_resource_types = resource_type_authority.all.select { |hash| hash[:active] }.pluck(:id)
        allow(Qa::Authorities::Local)
          .to receive(:subauthority_for).with('resource_types').and_raise(Qa::InvalidSubAuthority)
        allow(Qa::Authorities::Local)
          .to receive(:subauthority_for).with('resource_type').and_return(resource_type_authority)

        generator = described_class.new
        allow(generator.parameter_builder)
          .to(receive(:required_properties)
                .and_return(generator.parameter_builder.required_properties + ['resource_type']))

        result = generator.create

        expect(result).to be_success
        expect(active_resource_types).to include(generator.resource.resource_type.first)
      end
    end
  end

  context 'with files' do
    let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
    let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }
    let(:remote_url) { 'https://example.com/remote_file.pdf' }

    it 'uploads local files and associates them with the work' do
      generator = described_class.new(file_paths: [file1, file2])
      result = generator.create

      expect(result).to be_success
      expect(generator.resource.member_ids.length).to eq 2
    end

    it 'can be called with a single file' do
      generator = described_class.new(file_paths: file1)
      result = generator.create

      expect(result).to be_success
      expect(generator.resource.member_ids.length).to eq 1
    end

    it 'downloads and uploads remote files from URLs' do
      stub_request(:get, remote_url)
        .to_return(
          status: 200,
          body: File.read(file1),
          headers: { 'Content-Type' => 'application/pdf' }
        )

      generator = described_class.new(file_paths: remote_url)
      result = generator.create

      expect(result).to be_success
      expect(generator.resource.member_ids.length).to eq 1
    end

    it 'handles mixed local and remote files' do
      stub_request(:get, remote_url)
        .to_return(status: 200, body: 'fake pdf content')

      generator = described_class.new(file_paths: [file1, remote_url])
      result = generator.create

      expect(result).to be_success
      expect(generator.resource.member_ids.length).to eq 2
    end

    context 'with file set metadata' do
      it 'can set properties' do
        generator = described_class.new(
          file_paths: [file1, file2],
          file_set_params: [
            { title: 'Some Image', keyword: 'example' },
            { title: 'Some Text File', language: 'english' }
          ]
        )
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.member_ids.length).to eq 2

        file_sets = generator.resource.member_ids.map { |id| Hyrax.query_service.find_by(id:) }
        expect(file_sets.first.title).to eq ['Some Image']
        expect(file_sets.first.keyword).to eq ['example']
        expect(file_sets.last.title).to eq ['Some Text File']
        expect(file_sets.last.language).to eq ['english']
      end

      it 'is very forgiving of missing metadata entries' do
        generator = described_class.new(
          file_paths: [file1, file2],
          file_set_params: { title: 'Some Image' } # No metadata for second file sets
        )
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.member_ids.length).to eq 2

        file_sets = generator.resource.member_ids.map { |id| Hyrax.query_service.find_by(id:) }
        expect(file_sets.first.title).to eq ['Some Image']
        expect(file_sets.last.title).to be_empty
      end

      it 'ignores extra metadata entries beyond the number of files' do
        generator = described_class.new(
          file_paths: [file1],
          file_set_params: [
            { title: 'Some Image' },
            { title: 'Extra Metadata' }
          ]
        )
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.member_ids.length).to eq 1

        file_set = Hyrax.query_service.find_by(id: generator.resource.member_ids.first)
        expect(file_set.title).to eq ['Some Image']
      end

      it 'ignores unknown metadata properties' do
        generator = described_class.new(
          file_paths: [file1],
          file_set_params: [
            { title: 'Some Image', unknown_property: 'Some Value' }
          ]
        )
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.member_ids.length).to eq 1

        file_set = Hyrax.query_service.find_by(id: generator.resource.member_ids.first)
        expect(file_set.title).to eq ['Some Image']
        expect(file_set.respond_to?(:unknown_property)).to be false
      end
    end
  end

  context 'with autofill true' do
    it 'automatically fills in all settable properties' do
      generator = described_class.new(autofill: true)
      result = generator.create

      expect(result).to be_success
      expect(generator.resource.title).to eq ['Test title']
      expect(generator.resource.creator).to eq ['Test creator']
      expect(generator.resource.description).to eq ['Test description']
      expect(generator.resource.based_near).to eq ['https://sws.geonames.org/5391811/']
    end

    context 'and except option' do
      it 'omits the specified properties from being set' do
        generator = described_class.new(autofill: true, except: %w[description based_near])
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.title).to eq ['Test title']
        expect(generator.resource.creator).to eq ['Test creator']
        expect(generator.resource.description).to be_empty
        expect(generator.resource.based_near).to be_empty
      end
    end
  end

  context 'with based_near property' do
    it 'looks up place names via Geonames' do
      url = 'http://api.geonames.org/searchJSON?q=san+diego&username=scientist&maxRows=1'
      stub_request(:get, url)
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Host' => 'api.geonames.org',
            'User-Agent' => 'Ruby'
          }
        )
        .to_return(status: 200, body: '', headers: {})

      generator = described_class.new(based_near: ['san diego'])
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      allow(generator.parameter_builder)
        .to(receive(:required_properties)
              .and_return(generator.parameter_builder.required_properties + ['based_near']))
      allow(response).to receive(:body).and_return('{"geonames":[{"geonameId":5391811}]}')
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      result = generator.create

      expect(result).to be_success
      expect(generator.resource.based_near).to eq ['https://sws.geonames.org/5391811/']
    end
  end

  context 'with relationships' do
    context 'when adding to a collection' do
      it 'can add the work to the specified collection(s)' do
        col_generator1 = Skullrax::ValkyrieCollectionGenerator.new
        col_generator1.create
        col_id1 = col_generator1.resource.id
        col_generator2 = Skullrax::ValkyrieCollectionGenerator.new
        col_generator2.create
        col_id2 = col_generator2.resource.id
        generator = described_class.new(member_of_collection_ids: [col_id1, col_id2])

        result = generator.create

        expect(result).to be_success
        expect(generator.resource.member_of_collection_ids).to include col_id1
        expect(generator.resource.member_of_collection_ids).to include col_id2
      end

      it 'will raise an error if the collection does not exist' do
        generator = described_class.new(member_of_collection_ids: 'nonexistent-collection-id')

        expect { generator.create }.to raise_error(Skullrax::CollectionNotFoundError)
      end
    end

    context 'when adding a child work' do
      it 'can add the child work to the parent work' do
        child_generator = described_class.new
        child_generator.create
        child_work_id = child_generator.resource.id
        parent_generator = described_class.new(member_ids: [child_work_id])

        result = parent_generator.create

        expect(result).to be_success
        expect(parent_generator.resource.member_ids).to include child_work_id
      end

      it 'will raise an error if the parent work does not exist' do
        generator = described_class.new(member_ids: 'nonexistent-parent-work-id')

        expect { generator.create }.to raise_error(Skullrax::WorkNotFoundError)
      end
    end
  end
end
