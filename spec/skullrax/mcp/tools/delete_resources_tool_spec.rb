# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::DeleteResourcesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }

  let(:success_result) { double('result', success?: true) }
  let(:failure_result) { double('result', success?: false) }
  let(:generator) { instance_double(Skullrax::ValkyrieWorkGenerator, destroy: success_result, errors: []) }
  let(:failing_generator) do
    instance_double(Skullrax::ValkyrieWorkGenerator, destroy: failure_result, errors: ['Not found'])
  end

  describe '.tool_name' do
    it 'returns delete_resources' do
      expect(described_class.tool_name).to eq('delete_resources')
    end
  end

  describe '.input_schema' do
    it 'requires resource_type and ids' do
      schema = described_class.input_schema

      expect(schema[:required]).to include('resource_type', 'ids')
    end
  end

  describe '#call' do
    context 'when deleting works' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
      end

      it 'deletes the work and returns deleted status' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('deleted')
        expect(data.first['id']).to eq('abc123')
      end

      it 'passes id and user to the generator' do
        tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'] },
          current_user: user
        )

        expect(Skullrax::ValkyrieWorkGenerator).to have_received(:new)
          .with(hash_including(id: 'abc123', user:))
      end
    end

    context 'when deleting collections' do
      let(:col_generator) do
        instance_double(Skullrax::ValkyrieCollectionGenerator, destroy: success_result, errors: [])
      end

      before do
        allow(Skullrax::ValkyrieCollectionGenerator).to receive(:new).and_return(col_generator)
      end

      it 'dispatches to ValkyrieCollectionGenerator' do
        result = tool.call(
          params: { 'resource_type' => 'collection', 'ids' => ['col456'] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(Skullrax::ValkyrieCollectionGenerator).to have_received(:new)
        expect(data.first['status']).to eq('deleted')
      end
    end

    context 'when delete fails' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(failing_generator)
      end

      it 'returns failed status with errors' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Not found')
      end
    end

    context 'when deleting multiple IDs' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
      end

      it 'deletes each resource and returns results for all' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => %w[abc123 def456] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.length).to eq(2)
        expect(data.all? { |r| r['status'] == 'deleted' }).to be true
      end
    end
  end
end
