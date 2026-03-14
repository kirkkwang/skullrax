# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::GetSchemaTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User) }
  let(:fake_type) { double('dry_type', name: 'String') }

  let(:required_key) do
    double('schema_key',
           name: :title,
           meta: { 'form' => { 'required' => true, 'display' => true } },
           type: fake_type)
  end

  let(:optional_key) do
    double('schema_key',
           name: :creator,
           meta: { 'form' => { 'required' => false, 'display' => true } },
           type: fake_type)
  end

  let(:non_form_key) do
    double('schema_key',
           name: :internal_id,
           meta: {},
           type: fake_type)
  end

  let(:model_class) { double('model_class') }

  before do
    allow(Valkyrie.config.resource_class_resolver).to receive(:call).with('Monograph').and_return(model_class)
    allow(model_class).to receive(:new).and_return(double('instance', singleton_class: nil))
    allow(model_class).to receive(:schema).and_return([required_key, optional_key, non_form_key])
    allow(model_class).to receive(:new).and_return(double('instance', singleton_class: double('sc', schema: nil)))
  end

  describe '.tool_name' do
    it 'returns get_schema' do
      expect(described_class.tool_name).to eq('get_schema')
    end
  end

  describe '.description' do
    it 'includes key phrases about schema and validation' do
      expect(described_class.description).to include('schema')
      expect(described_class.description).to include('work type')
    end
  end

  describe '.input_schema' do
    it 'requires model parameter' do
      schema = described_class.input_schema

      expect(schema[:type]).to eq('object')
      expect(schema[:required]).to include('model')
      expect(schema.dig(:properties, :model, :type)).to eq('string')
    end
  end

  describe '#call' do
    context 'when model cannot be resolved' do
      it 'raises Skullrax::ArgumentError' do
        allow(Valkyrie.config.resource_class_resolver).to receive(:call).with('Unknown').and_raise(NameError)

        expect { tool.call(params: { 'model' => 'Unknown' }, current_user: user) }
          .to raise_error(Skullrax::ArgumentError, /Unknown model/)
      end
    end

    context 'when a schema key type does not respond to name' do
      let(:nameless_type) { double('type') }
      let(:nameless_key) do
        double('schema_key', name: :odd_field, meta: {}, type: nameless_type)
      end

      before do
        allow(nameless_type).to receive(:name).and_raise(NoMethodError)
        allow(nameless_type).to receive(:to_s).and_return('SomeType')
        allow(model_class).to receive(:schema).and_return([nameless_key])
      end

      it 'falls back to type.to_s' do
        result = tool.call(params: { 'model' => 'Monograph' }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['type']).to be_a(String)
      end
    end

    subject(:result) { tool.call(params: { 'model' => 'Monograph' }, current_user: user) }

    let(:parsed_fields) { JSON.parse(result[:content].first[:text]) }

    before do
      # Allow schema_for to work via SchemaPropertyFilterConcern
      allow(model_class).to receive(:schema).and_return([required_key, optional_key, non_form_key])
      instance = double('instance')
      sc = double('singleton_class', schema: nil)
      allow(instance).to receive(:singleton_class).and_return(sc)
      allow(model_class).to receive(:new).and_return(instance)
    end

    it 'returns MCP text content' do
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first[:type]).to eq('text')
    end

    it 'includes field names' do
      field_names = parsed_fields.map { |f| f['name'] }
      expect(field_names).to include('title', 'creator', 'internal_id')
    end

    it 'marks required fields correctly' do
      title_field = parsed_fields.find { |f| f['name'] == 'title' }
      creator_field = parsed_fields.find { |f| f['name'] == 'creator' }

      expect(title_field['required']).to be true
      expect(creator_field['required']).to be false
    end

    it 'includes type information' do
      title_field = parsed_fields.find { |f| f['name'] == 'title' }
      expect(title_field['type']).to be_a(String)
    end
  end
end
