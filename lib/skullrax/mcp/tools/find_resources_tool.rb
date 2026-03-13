# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class FindResourcesTool < Skullrax::Mcp::Tool
        SOLR_ROWS = 25

        def self.tool_name
          'find_resources'
        end

        def self.description
          'Finds Hyrax works or collections by ID or by Solr query string. Provide either ids ' \
            '(array of resource IDs, uses Valkyrie query service for full attributes) or query ' \
            '(Solr query string for catalog search, returns indexed fields). If both are given, ' \
            'ids take precedence.'
        end

        def self.input_schema # rubocop:disable Metrics/MethodLength
          {
            type: 'object',
            properties: {
              ids: {
                type: 'array',
                items: { type: 'string' },
                description: 'Array of resource IDs to fetch via Valkyrie query service'
              },
              query: {
                type: 'string',
                description: 'Solr query string to search the catalog, e.g. "title:My Work"'
              }
            }
          }
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          if params['ids'].present?
            find_by_ids(params['ids'])
          elsif params['query'].present?
            find_by_query(params['query'])
          else
            text_response({ error: "Either 'ids' or 'query' must be provided" }.to_json)
          end
        end

        private

        def find_by_ids(ids)
          resources = Hyrax.query_service.find_many_by_ids(ids: ids.map(&:to_s))
          serialized = resources.map { |r| serialize_resource(r) }
          text_response(serialized.to_json)
        end

        def find_by_query(query)
          docs = Hyrax::SolrService.query(query, rows: SOLR_ROWS)
          serialized = docs.map { |doc| serialize_solr_doc(doc) }
          text_response(serialized.to_json)
        end

        def serialize_resource(resource)
          {
            id: resource.id.to_s,
            type: resource.class.name,
            title: Array(resource.try(:title)).first,
            creator: Array(resource.try(:creator)),
            visibility: resource.try(:visibility)
          }.compact
        end

        def serialize_solr_doc(doc)
          {
            id: doc['id'],
            type: Array(doc['has_model_ssim']).first,
            title: Array(doc['title_tesim']).first,
            creator: Array(doc['creator_tesim']),
            visibility: doc['visibility_ssi']
          }.compact
        end
      end
    end
  end
end
