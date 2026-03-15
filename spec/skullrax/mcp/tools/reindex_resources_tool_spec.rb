# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::ReindexResourcesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }
  let(:resource) { instance_double(GenericWorkResource, id: 'abc123') }

  describe '.tool_name' do
    it 'returns reindex_resources' do
      expect(described_class.tool_name).to eq('reindex_resources')
    end
  end

  describe '.input_schema' do
    it 'requires ids' do
      expect(described_class.input_schema[:required]).to include('ids')
    end
  end

  describe '#call' do
    before do
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'abc123').and_return(resource)
      allow(Hyrax.index_adapter).to receive(:save).with(resource:)
    end

    it 'reindexes each resource and returns success status' do
      result = tool.call(params: { 'ids' => ['abc123'] }, current_user: user)
      data = JSON.parse(result[:content].first[:text])

      expect(data.first['id']).to eq('abc123')
      expect(data.first['status']).to eq('reindexed')
    end

    it 'calls index_adapter.save for each resource' do
      tool.call(params: { 'ids' => ['abc123'] }, current_user: user)

      expect(Hyrax.index_adapter).to have_received(:save).with(resource:)
    end

    it 'reindexes multiple resources' do
      resource2 = instance_double(GenericWorkResource, id: 'def456')
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'def456').and_return(resource2)
      allow(Hyrax.index_adapter).to receive(:save).with(resource: resource2)

      result = tool.call(params: { 'ids' => %w[abc123 def456] }, current_user: user)
      data = JSON.parse(result[:content].first[:text])

      expect(data.length).to eq(2)
      expect(data.all? { |r| r['status'] == 'reindexed' }).to be true
    end

    context 'when the resource is not found' do
      before do
        allow(Hyrax.query_service).to receive(:find_by)
          .with(id: 'missing')
          .and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      end

      it 'returns failed status with an error message' do
        result = tool.call(params: { 'ids' => ['missing'] }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to be_present
      end
    end

    context 'when indexing raises an error' do
      before do
        allow(Hyrax.index_adapter).to receive(:save).and_raise(StandardError, 'Solr connection failed')
      end

      it 'returns failed status with the error message' do
        result = tool.call(params: { 'ids' => ['abc123'] }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Solr connection failed')
      end
    end
  end
end
