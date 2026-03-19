# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::FindMembersTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User) }

  let(:work_doc) do
    { 'id' => 'work1', 'has_model_ssim' => ['Monograph'], 'title_tesim' => ['A Work'] }
  end

  let(:collection_doc) do
    { 'id' => 'col1', 'has_model_ssim' => ['Collection'], 'title_tesim' => ['A Collection'] }
  end

  let(:file_set_doc) do
    { 'id' => 'fs1', 'has_model_ssim' => ['FileSet'], 'title_tesim' => ['image.jpg'] }
  end

  describe '.tool_name' do
    it 'returns find_members' do
      expect(described_class.tool_name).to eq('find_members')
    end
  end

  describe '.input_schema' do
    it 'requires id and resource_type' do
      expect(described_class.input_schema[:required]).to contain_exactly('id', 'resource_type')
    end

    it 'includes member_type as an optional property' do
      expect(described_class.input_schema[:properties]).to have_key(:member_type)
    end

    it 'enumerates valid member_type values' do
      enum = described_class.input_schema.dig(:properties, :member_type, :enum)
      expect(enum).to contain_exactly('work', 'collection', 'file_set', 'any')
    end
  end

  describe '#call' do
    context 'when resource_type is collection' do
      before do
        allow(Hyrax::SolrService).to receive(:query)
          .with('member_of_collection_ids_ssim:"parent1"', rows: 1000)
          .and_return([work_doc, collection_doc, file_set_doc])
      end

      it 'queries Solr for member_of_collection_ids_ssim' do
        tool.call(params: { 'id' => 'parent1', 'resource_type' => 'collection' }, current_user: user)
        expect(Hyrax::SolrService).to have_received(:query)
          .with('member_of_collection_ids_ssim:"parent1"', rows: 1000)
      end

      it 'returns all members when member_type is any' do
        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'collection', 'member_type' => 'any' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.map { |d| d['id'] }).to contain_exactly('work1', 'col1', 'fs1')
      end

      it 'returns all members when member_type is omitted' do
        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'collection' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.size).to eq(3)
      end

      it 'filters to only works when member_type is work' do
        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'collection', 'member_type' => 'work' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.map { |d| d['id'] }).to eq(['work1'])
      end

      it 'does not classify AdminSet as a work' do
        admin_set_doc = { 'id' => 'as1', 'has_model_ssim' => ['AdminSet'] }
        allow(Hyrax::SolrService).to receive(:query)
          .with('member_of_collection_ids_ssim:"parent1"', rows: 1000)
          .and_return([work_doc, admin_set_doc])

        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'collection', 'member_type' => 'work' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.map { |d| d['id'] }).to eq(['work1'])
      end

      it 'filters to only collections when member_type is collection' do
        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'collection', 'member_type' => 'collection' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.map { |d| d['id'] }).to eq(['col1'])
      end

      it 'filters to only file sets when member_type is file_set' do
        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'collection', 'member_type' => 'file_set' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.map { |d| d['id'] }).to eq(['fs1'])
      end
    end

    context 'when resource_type is work' do
      let(:parent_doc) do
        { 'id' => 'parent1', 'member_ids_ssim' => %w[work1 fs1] }
      end

      before do
        allow(Hyrax::SolrService).to receive(:query)
          .with('id:parent1', rows: 1)
          .and_return([parent_doc])

        allow(Hyrax::SolrService).to receive(:query)
          .with('id:("work1" OR "fs1")', rows: 2)
          .and_return([work_doc, file_set_doc])
      end

      it 'fetches member_ids_ssim from the parent Solr doc then retrieves each member' do
        tool.call(params: { 'id' => 'parent1', 'resource_type' => 'work' }, current_user: user)
        expect(Hyrax::SolrService).to have_received(:query).with('id:parent1', rows: 1)
        expect(Hyrax::SolrService).to have_received(:query).with('id:("work1" OR "fs1")', rows: 2)
      end

      it 'returns all members when member_type is any' do
        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'work' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.map { |d| d['id'] }).to contain_exactly('work1', 'fs1')
      end

      it 'filters to only file sets when member_type is file_set' do
        result = tool.call(
          params: { 'id' => 'parent1', 'resource_type' => 'work', 'member_type' => 'file_set' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])
        expect(data.map { |d| d['id'] }).to eq(['fs1'])
      end

      context 'when the parent work has no members' do
        let(:parent_doc) { { 'id' => 'parent1' } }

        it 'returns an empty array' do
          result = tool.call(
            params: { 'id' => 'parent1', 'resource_type' => 'work' },
            current_user: user
          )
          data = JSON.parse(result[:content].first[:text])
          expect(data).to eq([])
        end
      end

      context 'when the parent work is not found in Solr' do
        before do
          allow(Hyrax::SolrService).to receive(:query)
            .with('id:parent1', rows: 1)
            .and_return([])
        end

        it 'returns an empty array' do
          result = tool.call(
            params: { 'id' => 'parent1', 'resource_type' => 'work' },
            current_user: user
          )
          data = JSON.parse(result[:content].first[:text])
          expect(data).to eq([])
        end
      end
    end
  end
end
