# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class DeleteSolrDocumentsTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'delete_solr_documents'
          end

          def description
            'Removes Solr documents by ID without touching the underlying persisted records. ' \
              'Use when a Solr document exists for a resource that has already been deleted from ' \
              'the persistence layer (orphaned Solr docs). Returns per-ID status.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                ids: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Array of resource IDs whose Solr documents should be removed'
                }
              },
              required: %w[ids]
            }
          end
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          ids = params['ids'] || []
          results = ids.map { |id| delete_solr_document(id) }
          text_response(results.to_json)
        end

        private

        def delete_solr_document(id)
          Hyrax::SolrService.delete(id)
          { id:, status: 'deleted' }
        rescue StandardError => e
          { id:, status: 'failed', errors: [e.message] }
        end
      end
    end
  end
end
