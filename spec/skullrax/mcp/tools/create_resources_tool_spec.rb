# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::CreateResourcesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }

  let(:work_resource) { double('resource', id: double('id', to_s: 'abc123'), title: ['My Work']) }
  let(:success_result) { double('result', success?: true, value!: work_resource) }
  let(:failure_result) { double('result', success?: false) }
  let(:generator) { instance_double(Skullrax::ValkyrieWorkGenerator, create: success_result, errors: []) }
  let(:failing_generator) do
    instance_double(Skullrax::ValkyrieWorkGenerator, create: failure_result, errors: ['Title is required'])
  end

  describe '.tool_name' do
    it 'returns create_resources' do
      expect(described_class.tool_name).to eq('create_resources')
    end
  end

  describe '.input_schema' do
    it 'requires resource_type, model, and records' do
      schema = described_class.input_schema

      expect(schema[:required]).to include('resource_type', 'records')
    end
  end

  describe '#call' do
    let(:record) { { 'title' => ['My Work'], 'creator' => ['Author'] } }

    context 'when creating works' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
      end

      it 'creates works and returns created status' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'model' => 'Monograph', 'records' => [record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('created')
        expect(data.first['id']).to eq('abc123')
      end

      it 'passes user and attrs to the generator' do
        tool.call(
          params: { 'resource_type' => 'work', 'model' => 'Monograph', 'records' => [record] },
          current_user: user
        )

        expect(Skullrax::ValkyrieWorkGenerator).to have_received(:new)
          .with(hash_including(model: 'Monograph', user:))
      end
    end

    context 'when creating collections' do
      let(:collection_resource) { double('collection', id: double('id', to_s: 'col456'), title: ['My Collection']) }
      let(:col_success) { double('result', success?: true, value!: collection_resource) }
      let(:col_generator) { instance_double(Skullrax::ValkyrieCollectionGenerator, create: col_success, errors: []) }

      before do
        allow(Skullrax::ValkyrieCollectionGenerator).to receive(:new).and_return(col_generator)
      end

      it 'dispatches to ValkyrieCollectionGenerator' do
        result = tool.call(
          params: { 'resource_type' => 'collection', 'records' => [record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(Skullrax::ValkyrieCollectionGenerator).to have_received(:new)
        expect(data.first['status']).to eq('created')
      end
    end

    context 'when creation fails' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(failing_generator)
      end

      it 'returns failed status with errors' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'model' => 'Monograph', 'records' => [record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Title is required')
      end
    end

    context 'when multiple records are provided' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
      end

      it 'creates each record and returns results for all' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'model' => 'Monograph', 'records' => [record, record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.length).to eq(2)
        expect(data.all? { |r| r['status'] == 'created' }).to be true
      end
    end
  end
end
