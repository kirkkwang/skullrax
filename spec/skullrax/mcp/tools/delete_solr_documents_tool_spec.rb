# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::DeleteSolrDocumentsTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }

  describe '.tool_name' do
    it 'returns delete_solr_documents' do
      expect(described_class.tool_name).to eq('delete_solr_documents')
    end
  end

  describe '.input_schema' do
    it 'requires ids' do
      expect(described_class.input_schema[:required]).to include('ids')
    end
  end

  describe '#call' do
    before do
      allow(Hyrax::SolrService).to receive(:delete)
    end

    it 'deletes the Solr document for each ID and returns success status' do
      result = tool.call(params: { 'ids' => ['abc123'] }, current_user: user)
      data = JSON.parse(result[:content].first[:text])

      expect(data.first['id']).to eq('abc123')
      expect(data.first['status']).to eq('deleted')
    end

    it 'calls SolrService.delete for each ID' do
      tool.call(params: { 'ids' => %w[abc123 def456] }, current_user: user)

      expect(Hyrax::SolrService).to have_received(:delete).with('abc123')
      expect(Hyrax::SolrService).to have_received(:delete).with('def456')
    end

    it 'deletes multiple documents and returns one result per ID' do
      result = tool.call(params: { 'ids' => %w[abc123 def456] }, current_user: user)
      data = JSON.parse(result[:content].first[:text])

      expect(data.length).to eq(2)
      expect(data.all? { |r| r['status'] == 'deleted' }).to be true
    end

    context 'when Solr raises an error' do
      before do
        allow(Hyrax::SolrService).to receive(:delete)
          .with('bad-id')
          .and_raise(StandardError, 'Solr connection failed')
      end

      it 'returns failed status with the error message' do
        result = tool.call(params: { 'ids' => ['bad-id'] }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Solr connection failed')
      end
    end
  end
end
