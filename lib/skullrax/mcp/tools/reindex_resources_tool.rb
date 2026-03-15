# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class ReindexResourcesTool < Skullrax::Mcp::Tool
        def self.tool_name
          'reindex_resources'
        end

        def self.description
          'Reindexes Solr documents for one or more Hyrax resources by ID. Use when a record ' \
            'exists in the persistence layer but its Solr document is missing or stale. ' \
            'Returns per-resource status.'
        end

        def self.input_schema # rubocop:disable Metrics/MethodLength
          {
            type: 'object',
            properties: {
              ids: {
                type: 'array',
                items: { type: 'string' },
                description: 'Array of resource IDs to reindex in Solr'
              }
            },
            required: %w[ids]
          }
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          ids = params['ids'] || []
          results = ids.map { |id| reindex(id) }
          text_response(results.to_json)
        end

        private

        def reindex(id)
          resource = Hyrax.query_service.find_by(id:)
          Hyrax.index_adapter.save(resource:)
          { id:, status: 'reindexed' }
        rescue StandardError => e
          { id:, status: 'failed', errors: [e.message] }
        end
      end
    end
  end
end
