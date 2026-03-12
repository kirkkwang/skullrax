# frozen_string_literal: true

RSpec.describe Skullrax::Configuration do
  subject(:config) { described_class.new }

  describe '#default_test_value' do
    it 'defaults to a lambda returning "Test {property}"' do
      result = config.default_test_value.call('Monograph', 'title')

      expect(result).to eq('Test title')
    end

    it 'can be replaced with a custom callable' do
      config.default_test_value = ->(model, property) { "#{model}/#{property}" }

      expect(config.default_test_value.call('Monograph', 'title')).to eq('Monograph/title')
    end
  end

  describe '#test_default_for' do
    context 'when registering with a string model name' do
      it 'stores and retrieves a per-model+property callable' do
        config.test_default_for('Monograph', :title) { |model, property| "#{model} #{property} custom" }

        callable = config.test_default_for('Monograph', :title)
        expect(callable.call('Monograph', 'title')).to eq('Monograph title custom')
      end
    end

    context 'when registering with a constant' do
      it 'calls .to_s on the constant to derive the model key' do
        stub_const('FakeModel', Class.new)

        config.test_default_for(FakeModel, :description) { |model, property| "#{model}:#{property}" }

        callable = config.test_default_for(FakeModel, :description)
        expect(callable.call('FakeModel', 'description')).to eq('FakeModel:description')
      end
    end

    context 'when registering a model-level default (no property)' do
      it 'returns the model default when no property-specific callable exists' do
        config.test_default_for('Monograph') { |_model, property| "model default #{property}" }

        callable = config.test_default_for('Monograph', :title)
        expect(callable.call('Monograph', 'title')).to eq('model default title')
      end

      it 'is superseded by a property-specific callable' do
        config.test_default_for('Monograph') { 'model default' }
        config.test_default_for('Monograph', :title) { 'property specific' }

        callable = config.test_default_for('Monograph', :title)
        expect(callable.call('Monograph', 'title')).to eq('property specific')
      end
    end

    context 'when no callable is registered' do
      it 'returns nil for an unregistered model' do
        expect(config.test_default_for('Unknown', :title)).to be_nil
      end

      it 'returns nil for an unregistered property on a registered model' do
        config.test_default_for('Monograph', :title) { 'something' }

        expect(config.test_default_for('Monograph', :creator)).to be_nil
      end
    end
  end
end
