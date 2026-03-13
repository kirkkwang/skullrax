# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::ValidateResourcesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User) }
  let(:fake_type) { double('dry_type', name: 'String') }

  let(:title_key) do
    double('schema_key',
           name: :title,
           meta: { 'form' => { 'required' => true, 'display' => true } },
           type: fake_type)
  end

  let(:creator_key) do
    double('schema_key',
           name: :creator,
           meta: { 'form' => { 'required' => false, 'display' => true } },
           type: fake_type)
  end

  let(:model_class) { double('model_class') }

  before do
    allow(Valkyrie.config.resource_class_resolver).to receive(:call).with('Monograph').and_return(model_class)
    instance = double('instance', singleton_class: double('sc', schema: nil))
    allow(model_class).to receive(:new).and_return(instance)
    allow(model_class).to receive(:schema).and_return([title_key, creator_key])
  end

  describe '.tool_name' do
    it 'returns validate_resources' do
      expect(described_class.tool_name).to eq('validate_resources')
    end
  end

  describe '.input_schema' do
    it 'requires model and records' do
      schema = described_class.input_schema

      expect(schema[:required]).to include('model', 'records')
    end
  end

  describe '#call' do
    let(:valid_record) { { 'title' => ['My Work'], 'creator' => ['Author'] } }
    let(:missing_required) { { 'creator' => ['Author'] } }
    let(:unknown_field) { { 'title' => ['My Work'], 'bogus_field' => ['X'] } }

    def call_tool(records)
      tool.call(params: { 'model' => 'Monograph', 'records' => records }, current_user: user)
    end

    it 'marks valid records correctly' do
      result = call_tool([valid_record])
      data = JSON.parse(result[:content].first[:text])

      expect(data['valid'].length).to eq(1)
      expect(data['invalid']).to be_empty
    end

    it 'flags records missing required fields' do
      result = call_tool([missing_required])
      data = JSON.parse(result[:content].first[:text])

      expect(data['invalid'].length).to eq(1)
      expect(data['invalid'].first['reasons']).to include(match(/Missing required field: title/))
    end

    it 'flags records with unknown fields' do
      result = call_tool([unknown_field])
      data = JSON.parse(result[:content].first[:text])

      expect(data['invalid'].length).to eq(1)
      expect(data['invalid'].first['reasons']).to include(match(/Unknown field: bogus_field/))
    end

    it 'handles mixed valid and invalid records' do
      result = call_tool([valid_record, missing_required])
      data = JSON.parse(result[:content].first[:text])

      expect(data['valid'].length).to eq(1)
      expect(data['invalid'].length).to eq(1)
    end

    it 'handles empty records array' do
      result = call_tool([])
      data = JSON.parse(result[:content].first[:text])

      expect(data['valid']).to be_empty
      expect(data['invalid']).to be_empty
    end
  end
end
