# frozen_string_literal: true

RSpec.describe Skullrax::ValkyrieCollectionCreator do
  before do
    create(:admin, email: 'admin@example.com')
  end

  it 'creates a collection' do
    generator = described_class.new
    result = generator.create

    expect(result).to be_success
    expect(generator.resource.class).to eq Hyrax.config.collection_class
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
    it 'sets properties from kwargs' do
      generator = described_class.new(title: ['Custom Title'],
                                      creator: ['Custom Creator'])
      result = generator.create

      expect(result).to be_success
      expect(generator.resource.title).to eq ['Custom Title']
      expect(generator.resource.creator).to eq ['Custom Creator']
    end

    it 'ignores unknown properties' do
      generator = described_class.new(unknown_property: 'Some Value', another_one: 123)
      result = generator.create

      expect(result).to be_success
      expect(generator.resource).to be_a Hyrax.config.collection_class
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
      stub_request(:get, 'http://www.geonames.org/getJSON?geonameId=5391811&username=')
        .with(
          headers: {
            'Accept' => 'application/json',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Faraday v2.14.0'
          }
        )
        .to_return(status: 200, body: {}.to_json, headers: {})

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
      it 'can add a collection as a member of another collection' do
        parent_generator = described_class.new(title: ['Parent Collection'])
        parent_result = parent_generator.create
        expect(parent_result).to be_success

        child_generator = described_class.new(member_of_collection_ids: [parent_generator.resource.id])
        child_result = child_generator.create
        expect(child_result).to be_success

        expect(child_generator.resource.member_of_collection_ids)
          .to include(parent_generator.resource.id)
      end

      it 'raises an error if the collection does not exist' do
        generator = described_class.new(member_of_collection_ids: ['nonexistent-collection-id'])

        expect { generator.create }.to raise_error(Skullrax::CollectionNotFoundError)
      end
    end
  end

  context 'when user passes in an id' do
    context 'when the id already exists' do
      it 'raises an IdAlreadyExistsError' do
        existing_generator = described_class.new
        existing_generator.create
        existing_id = existing_generator.resource.id
        generator = described_class.new(id: existing_id)

        expect { generator.create }.to raise_error(Skullrax::IdAlreadyExistsError)
      end
    end

    context 'when the id does not exist' do
      it 'uses the provided id for the collection' do
        generator = described_class.new(id: 'custom-collection-id-123')
        result = generator.create

        expect(result).to be_success
        expect(generator.resource.id.to_s).to eq 'custom-collection-id-123'
        expect(SolrDocument.find('custom-collection-id-123')).to be_present
      end
    end
  end
end
