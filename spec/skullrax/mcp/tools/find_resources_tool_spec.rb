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

    it 'includes terms as an array property' do
      schema = described_class.input_schema

      expect(schema[:properties]).to have_key(:terms)
      expect(schema[:properties][:terms][:type]).to eq('array')
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
          .with('title:test', rows: 1_000)
          .and_return([solr_doc])
      end

      it 'uses Solr to search by query string' do
        result = tool.call(params: { 'query' => 'title:test' }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['id']).to eq('abc123')
        expect(data.first['title_tesim']).to eq(['My Work'])
      end
    end

    context 'when terms are provided' do
      let(:schema_key_title) do
        double('schema_key_title',
               name: :title,
               type: double('array_type', to_s: 'Dry::Types::Array'))
      end

      let(:schema_key_description) do
        double('schema_key_description',
               name: :description,
               type: double('array_type2', to_s: 'Dry::Types::Array'))
      end

      let(:schema_key_date) do
        double('schema_key_date',
               name: :date_created,
               type: double('string_type', to_s: 'String'))
      end

      let(:model_class) do
        double('model_class', schema: [schema_key_title, schema_key_description, schema_key_date])
      end

      let(:collection_class) { double('collection_class', to_s: 'Collection') }

      # Luke has title_tesim but not description_tesim — lets us test the intersection
      let(:luke_response) do
        { 'fields' => { 'title_tesim' => {}, 'visibility_ssi' => {} } }
      end

      before do
        stub_const('Hyku', Module.new)
        default_site = double('default_site', available_works: [double(to_s: 'Monograph')])
        stub_const('Site', double('Site', instance: default_site))
        allow(Hyrax.config).to receive(:curation_concerns).and_return([double(to_s: 'Monograph')])
        allow(Hyrax.config).to receive(:collection_class).and_return(collection_class)
        allow(Valkyrie.config).to receive(:resource_class_resolver)
          .and_return(->(_type) { model_class })
        allow(Hyrax::SolrService).to receive(:get)
          .with(path: 'admin/luke', numTerms: 0)
          .and_return(luke_response)
        allow(Hyrax::SolrService).to receive(:query).and_return([solr_doc])
      end

      it 'routes to find_by_terms and not find_by_ids or find_by_query' do
        allow(Hyrax.query_service).to receive(:find_many_by_ids)

        tool.call(params: { 'terms' => ['france'] }, current_user: user)

        expect(Hyrax::SolrService).to have_received(:query)
        expect(Hyrax.query_service).not_to have_received(:find_many_by_ids)
      end

      it 'ids take precedence over terms when both are provided' do
        allow(Hyrax.query_service).to receive(:find_many_by_ids).and_return([resource])

        tool.call(params: { 'ids' => ['abc123'], 'terms' => ['france'] }, current_user: user)

        expect(Hyrax.query_service).to have_received(:find_many_by_ids)
        expect(Hyrax::SolrService).not_to have_received(:query)
      end

      it 'terms take precedence over query when both are provided' do
        tool.call(params: { 'terms' => ['france'], 'query' => 'title:test' }, current_user: user)

        expect(Hyrax::SolrService).not_to have_received(:query).with('title:test', anything)
        expect(Hyrax::SolrService).to have_received(:query).with(include('title_tesim'), hash_including(qt: 'search'))
      end

      it 'builds a Solr query that ORs all terms across all descriptive fields' do
        tool.call(params: { 'terms' => %w[france french] }, current_user: user)

        # model_filter scopes to registered types; fields_query ORs terms across descriptive fields
        expected = '(has_model_ssim:Monograph OR has_model_ssim:Collection) AND (title_tesim:(france OR french))'
        expect(Hyrax::SolrService).to have_received(:query).with(expected, rows: 1_000, qt: 'search')
      end

      it 'scopes the query to registered work and collection types' do
        tool.call(params: { 'terms' => ['france'] }, current_user: user)

        expect(Hyrax::SolrService).to have_received(:query)
          .with(start_with('(has_model_ssim:'), rows: 1_000, qt: 'search')
      end

      it 'includes the collection class in the model filter' do
        tool.call(params: { 'terms' => ['france'] }, current_user: user)

        expect(Hyrax::SolrService).to have_received(:query)
          .with(include('has_model_ssim:Collection'), anything)
      end

      it 'excludes file sets by omitting them from the model filter' do
        tool.call(params: { 'terms' => ['france'] }, current_user: user)

        expect(Hyrax::SolrService).not_to have_received(:query)
          .with(include('FileSet'), anything)
      end

      it 'uses the eDisMax request handler for relevancy scoring' do
        tool.call(params: { 'terms' => ['france'] }, current_user: user)

        expect(Hyrax::SolrService).to have_received(:query)
          .with(anything, hash_including(qt: 'search'))
      end

      it 'serializes results the same way as find_by_query' do
        result = tool.call(params: { 'terms' => ['france'] }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['id']).to eq('abc123')
        expect(data.first['title_tesim']).to eq(['My Work'])
      end

      it 'only includes Array-typed schema fields' do
        tool.call(params: { 'terms' => ['france'] }, current_user: user)

        # date_created is String-typed so date_created_tesim must not appear in the query
        expect(Hyrax::SolrService).not_to have_received(:query)
          .with(include('date_created_tesim'), anything)
      end

      it 'only includes fields present in the Luke response (intersection)' do
        tool.call(params: { 'terms' => ['france'] }, current_user: user)

        # description is Array-typed but absent from Luke, so it must not appear in the query
        expect(Hyrax::SolrService).not_to have_received(:query)
          .with(include('description_tesim'), anything)
      end

      context 'when Hyku is defined' do
        let(:site_instance) { double('site', available_works: [double(to_s: 'Monograph')]) }

        before do
          # Hyku already stubbed in parent; override Site with the spy instance
          stub_const('Site', double('Site', instance: site_instance))
        end

        it 'uses Site.instance.available_works for work types' do
          tool.call(params: { 'terms' => ['test'] }, current_user: user)

          expect(site_instance).to have_received(:available_works).at_least(:once)
        end
      end

      context 'when Hyku is not defined' do
        before { hide_const('Hyku') }

        it 'uses Hyrax.config.curation_concerns for work types' do
          tool.call(params: { 'terms' => ['test'] }, current_user: user)

          expect(Hyrax.config).to have_received(:curation_concerns).at_least(:once)
        end
      end

      context 'when Luke returns no _tesim fields' do
        before do
          allow(Hyrax::SolrService).to receive(:get)
            .with(path: 'admin/luke', numTerms: 0)
            .and_return({ 'fields' => { 'visibility_ssi' => {} } })
        end

        it 'returns a graceful error response' do
          result = tool.call(params: { 'terms' => ['france'] }, current_user: user)
          data = JSON.parse(result[:content].first[:text])

          expect(data['error']).to be_present
        end
      end
    end

    context 'when neither ids, terms, nor query is provided' do
      it 'returns an error message' do
        result = tool.call(params: {}, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to be_present
      end
    end
  end
end
