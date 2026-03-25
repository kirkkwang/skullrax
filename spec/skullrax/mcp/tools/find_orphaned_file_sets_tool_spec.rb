# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::FindOrphanedFileSetsTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }

  let(:solr_response) do
    {
      'response' => {
        'docs' => [
          { 'id' => 'fs-001', 'title_tesim' => ['Orphaned File 1'] },
          { 'id' => 'fs-002', 'title_tesim' => ['Orphaned File 2'] }
        ]
      }
    }
  end

  before do
    allow(Hyrax::SolrService).to receive(:get).and_return(solr_response)
  end

  describe '.tool_name' do
    it 'returns find_orphaned_file_sets' do
      expect(described_class.tool_name).to eq('find_orphaned_file_sets')
    end
  end

  describe '.input_schema' do
    it 'does not require any fields' do
      expect(described_class.input_schema[:required]).to be_empty
    end
  end

  describe '#call' do
    it 'queries Solr for FileSets not belonging to any parent work' do
      tool.call(params: {}, current_user: user)

      expect(Hyrax::SolrService).to have_received(:get).with(
        include('has_model_ssim:FileSet'),
        anything
      )
    end

    it 'returns orphaned FileSets with default fields' do
      result = tool.call(params: {}, current_user: user)
      data = JSON.parse(result[:content].first[:text])

      expect(data.length).to eq(2)
      expect(data.first['id']).to eq('fs-001')
      expect(data.first['title_tesim']).to eq(['Orphaned File 1'])
    end

    it 'passes custom fields to Solr' do
      tool.call(params: { 'fields' => %w[id creator_tesim] }, current_user: user)

      expect(Hyrax::SolrService).to have_received(:get).with(
        anything,
        hash_including(fl: 'id,creator_tesim')
      )
    end

    it 'slices only the requested fields from each doc' do
      extra_doc_response = {
        'response' => {
          'docs' => [{ 'id' => 'fs-001', 'title_tesim' => ['Title'], 'extra_field' => 'ignored' }]
        }
      }
      allow(Hyrax::SolrService).to receive(:get).and_return(extra_doc_response)

      result = tool.call(params: { 'fields' => %w[id title_tesim] }, current_user: user)
      data = JSON.parse(result[:content].first[:text])

      expect(data.first.keys).to match_array(%w[id title_tesim])
    end

    context 'when Solr returns no results' do
      before do
        allow(Hyrax::SolrService).to receive(:get).and_return({ 'response' => { 'docs' => [] } })
      end

      it 'returns an empty array' do
        result = tool.call(params: {}, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data).to eq([])
      end
    end

    context 'when Solr raises an error' do
      before do
        allow(Hyrax::SolrService).to receive(:get).and_raise(StandardError, 'Solr connection failed')
      end

      it 'returns an error response' do
        result = tool.call(params: {}, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to eq('Solr connection failed')
      end
    end
  end
end
