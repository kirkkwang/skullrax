# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::FindResourcesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User) }

  let(:resource) do
    double('resource',
           class: double('model_class', name: 'Monograph'),
           attributes: {
             id: 'abc123',
             title: ['My Work'],
             creator: ['Author'],
             visibility: 'open'
           })
  end

  let(:solr_doc) do
    {
      'id' => 'abc123',
      'has_model_ssim' => ['Monograph'],
      'title_tesim' => ['My Work'],
      'creator_tesim' => ['Author'],
      'visibility_ssi' => 'open'
    }
  end

  describe '.tool_name' do
    it 'returns find_resources' do
      expect(described_class.tool_name).to eq('find_resources')
    end
  end

  describe '.input_schema' do
    it 'documents ids and query as mutually exclusive inputs' do
      schema = described_class.input_schema

      expect(schema[:properties]).to have_key(:ids)
      expect(schema[:properties]).to have_key(:query)
    end
  end

  describe '#call' do
    context 'when ids are provided' do
      before do
        allow(Hyrax.query_service).to receive(:find_many_by_ids)
          .with(ids: ['abc123'])
          .and_return([resource])
      end

      it 'uses Valkyrie query service to find resources by ID' do
        result = tool.call(params: { 'ids' => ['abc123'] }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['id']).to eq('abc123')
        expect(data.first['title']).to eq(['My Work'])
      end

      it 'ids take precedence when both ids and query are provided' do
        allow(Hyrax::SolrService).to receive(:query)

        tool.call(params: { 'ids' => ['abc123'], 'query' => 'something' }, current_user: user)

        expect(Hyrax.query_service).to have_received(:find_many_by_ids)
        expect(Hyrax::SolrService).not_to have_received(:query)
      end
    end

    context 'when resource has Valkyrie::ID and DateTime attributes' do
      let(:resource_with_special_types) do
        double('resource',
               class: double('model_class', name: 'Monograph'),
               attributes: {
                 id: Valkyrie::ID.new('abc123'),
                 created_at: DateTime.new(2024, 1, 1, 12, 0, 0)
               })
      end

      before do
        allow(Hyrax.query_service).to receive(:find_many_by_ids)
          .with(ids: ['abc123'])
          .and_return([resource_with_special_types])
      end

      it 'coerces Valkyrie::ID to string and DateTime to ISO8601' do
        result = tool.call(params: { 'ids' => ['abc123'] }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['id']).to eq('abc123')
        expect(data.first['created_at']).to match(/\d{4}-\d{2}-\d{2}/)
      end
    end

    context 'when a query string is provided' do
      before do
        allow(Hyrax::SolrService).to receive(:query)
          .with('title:test', rows: 25)
          .and_return([solr_doc])
      end

      it 'uses Solr to search by query string' do
        result = tool.call(params: { 'query' => 'title:test' }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['id']).to eq('abc123')
        expect(data.first['title_tesim']).to eq(['My Work'])
      end
    end

    context 'when neither ids nor query is provided' do
      it 'returns an error message' do
        result = tool.call(params: {}, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to be_present
      end
    end
  end
end
