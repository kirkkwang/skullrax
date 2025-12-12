# frozen_string_literal: true

RSpec.describe Skullrax::ValkyrieWorkGenerator do
  before do
    create(:admin, email: 'admin@example.com')
  end

  it 'creates a work' do
    generator = described_class.new
    result = generator.create

    expect(result).to be_success
    expect(generator.work.class).to eq Wings::ModelRegistry.reverse_lookup(Hyrax.config.curation_concerns.first)
  end

  it 'fills in required properties with "Test <property>"' do
    generator = described_class.new
    generator.create

    expect(generator.work.title).to eq ['Test title']
    expect(generator.work.creator).to eq ['Test creator']
  end

  it 'returns a failure if there are errors' do
    generator = described_class.new
    # makes generate think there aren't any required properties
    allow(generator).to receive(:required_properties).and_return([])

    result = generator.create

    expect(result).to be_failure
    expect(generator.work.id).to be_nil
    expect(generator.errors).not_to be_empty
  end

  context 'when passing kwargs' do
    it 'creates a work of that model' do
      generator = described_class.new(model: Monograph)
      result = generator.create

      expect(result).to be_success
      expect(generator.work).to be_a Monograph
    end

    it 'sets properties from kwargs' do
      generator = described_class.new(model: Monograph,
                                      title: ['Custom Title'],
                                      creator: ['Custom Creator'],
                                      visibility: 'open')
      result = generator.create

      expect(result).to be_success
      expect(generator.work).to be_a Monograph
      expect(generator.work.title).to eq ['Custom Title']
      expect(generator.work.creator).to eq ['Custom Creator']
      expect(generator.work.visibility).to eq 'open'
    end

    it 'ignores unknown properties' do
      generator = described_class.new(model: Monograph, unknown_property: 'Some Value', another_one: 123)
      result = generator.create

      expect(result).to be_success
      expect(generator.work).to be_a Monograph
      expect(generator.work.respond_to?(:unknown_property)).to be false
      expect(generator.work.respond_to?(:another_one)).to be false
    end
  end

  context 'when properties are controlled vocabularies' do
    it 'sets properties from controlled vocabularies' do
      generator = described_class.new(license: ['https://creativecommons.org/licenses/by-nc/4.0/'])
      allow(generator).to receive(:required_properties).and_return(generator.send(:required_properties) << 'license')

      result = generator.create

      expect(result).to be_success
      expect(generator.work.license).to eq ['https://creativecommons.org/licenses/by-nc/4.0/']
    end

    it 'raises an error for invalid controlled vocabulary terms' do
      generator = described_class.new(license: ['Invalid License Term'])
      allow(generator).to receive(:required_properties).and_return(['license'])

      expect do
        generator.create
      end.to raise_error(
        ArgumentError, /'Invalid License Term' is not an active term in the controlled vocabulary for 'license'/
      )
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
      allow(generator).to receive(:required_properties).and_return(generator.send(:required_properties) + extra_fields)

      result = generator.create

      expect(result).to be_success
      expect(active_license_terms).to include(generator.work.license.first)
      expect(active_rights_terms).to include(generator.work.rights_statement.first)
      expect(active_resource_types).to include(generator.work.resource_type.first)
    end
  end

  context 'with files' do
    file1 = Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png')
    file2 = Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt')

    it 'uploads files and associates them with the work' do
      generator = described_class.new(file_paths: [file1, file2])
      result = generator.create

      expect(result).to be_success
      expect(generator.work.member_ids.length).to eq 2
    end

    it 'can be called with a single file' do
      generator = described_class.new(file_paths: file1)
      result = generator.create

      expect(result).to be_success
      expect(generator.work.member_ids.length).to eq 1
    end
  end
end
