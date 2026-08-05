# frozen_string_literal: true

RSpec.describe Skullrax::CompoundHandler do
  let(:model) { double('model', to_s: 'Monograph') }
  let(:compound_schema) { double('compound_schema', compound_names: %i[participants identifiers]) }

  before do
    allow(Hyrax::CompoundSchema).to receive(:for).with(model).and_return(compound_schema)
  end

  describe '.handles?' do
    it 'returns true for a compound property' do
      expect(described_class.handles?(model, :participants)).to be true
    end

    it 'returns true for the _attributes form of a compound property' do
      expect(described_class.handles?(model, 'participants_attributes')).to be true
    end

    it 'returns false for a scalar property' do
      expect(described_class.handles?(model, :title)).to be false
    end

    it 'returns false when the schema lookup raises' do
      allow(Hyrax::CompoundSchema).to receive(:for).and_raise(StandardError)

      expect(described_class.handles?(model, :participants)).to be false
    end

    it 'returns false when the model is nil' do
      expect(described_class.handles?(nil, :participants)).to be false
    end
  end

  describe '.param_key' do
    it 'appends _attributes to a bare property name' do
      expect(described_class.param_key(:participants)).to eq('participants_attributes')
    end

    it 'leaves an _attributes key unchanged' do
      expect(described_class.param_key('participants_attributes')).to eq('participants_attributes')
    end
  end

  describe '.process' do
    it 'converts an array of rows into an indexed fragment' do
      rows = [{ name: 'Ada', role: 'Author' }, { name: 'Grace', role: 'Editor' }]

      expect(described_class.process(rows)).to eq(
        '0' => { 'name' => 'Ada', 'role' => 'Author' },
        '1' => { 'name' => 'Grace', 'role' => 'Editor' }
      )
    end

    it 'converts a single row hash into an indexed fragment' do
      expect(described_class.process(name: 'Ada', role: 'Author')).to eq(
        '0' => { 'name' => 'Ada', 'role' => 'Author' }
      )
    end

    it 'reindexes an already-indexed fragment and stringifies row keys' do
      fragment = { '0' => { name: 'Ada' }, '1' => { name: 'Grace' } }

      expect(described_class.process(fragment)).to eq(
        '0' => { 'name' => 'Ada' },
        '1' => { 'name' => 'Grace' }
      )
    end
  end
end
