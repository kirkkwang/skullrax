# frozen_string_literal: true

RSpec.describe Skullrax::ParameterBuilder do
  # Reset config between tests to avoid cross-test pollution
  after { Skullrax.instance_variable_set(:@config, nil) }

  describe '#resolve_test_value (via param_value_for)' do
    let(:model) { double('model', to_s: 'Monograph') }
    let(:builder) { described_class.new(model:) }

    before do
      # Stub schema introspection so we can test just the value resolution path
      allow(builder).to receive(:controlled_property?).and_return(false)
      allow(builder).to receive(:based_near_handler).and_return(
        double(handles?: false, param_key: nil, default_value: nil)
      )
    end

    it 'falls back to the built-in default when no config is set' do
      result = builder.send(:param_value_for, 'title')

      expect(result).to eq(['Test title'])
    end

    it 'uses the global default_test_value when configured' do
      Skullrax.configure do |config|
        config.default_test_value = ->(model, property) { "#{model} | #{property}" }
      end

      result = builder.send(:param_value_for, 'title')

      expect(result).to eq(['Monograph | title'])
    end

    it 'uses a per-model+property callable when configured' do
      Skullrax.configure do |config|
        config.test_default_for('Monograph', :title) do |_model, property|
          "custom #{property} for Monograph"
        end
      end

      result = builder.send(:param_value_for, 'title')

      expect(result).to eq(['custom title for Monograph'])
    end

    it 'per-model+property takes precedence over global default_test_value' do
      Skullrax.configure do |config|
        config.default_test_value = ->(_model, _property) { 'global' }
        config.test_default_for('Monograph', :title) { 'specific' }
      end

      result = builder.send(:param_value_for, 'title')

      expect(result).to eq(['specific'])
    end

    it 'falls back to global default when model is registered but property is not' do
      Skullrax.configure do |config|
        config.default_test_value = ->(_model, _property) { 'global fallback' }
        config.test_default_for('Monograph', :creator) { 'creator specific' }
      end

      result = builder.send(:param_value_for, 'title')

      expect(result).to eq(['global fallback'])
    end
  end

  describe '#add_custom_attributes (compound properties)' do
    let(:model) { double('model', to_s: 'Monograph') }
    let(:compound_schema) { double('compound_schema', compound_names: [:participants]) }

    before do
      allow(Hyrax::CompoundSchema).to receive(:for).with(model).and_return(compound_schema)
    end

    it 'converts a bare compound kwarg into an _attributes fragment' do
      builder = described_class.new(model:, fill_mode: :none, participants: [{ 'name' => 'Ada', 'role' => 'Author' }])

      result = builder.build

      expect(result['participants_attributes']).to eq('0' => { 'name' => 'Ada', 'role' => 'Author' })
      expect(result).not_to have_key(:participants)
    end

    it 'normalizes an _attributes kwarg without array-wrapping it' do
      builder = described_class.new(
        model:, fill_mode: :none, participants_attributes: { '0' => { name: 'Ada', role: 'Author' } }
      )

      result = builder.build

      expect(result['participants_attributes']).to eq('0' => { 'name' => 'Ada', 'role' => 'Author' })
    end

    it 'leaves non-compound kwargs untouched' do
      builder = described_class.new(model:, fill_mode: :none, title: 'My Work')

      result = builder.build

      expect(result[:title]).to eq(['My Work'])
    end
  end
end
