# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class FindOrphanedFileSetsTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'find_orphaned_file_sets'
          end

          def description
            'Finds FileSets that are not members of any parent work by querying Solr. ' \
              'Returns Solr document fields for each orphaned FileSet. ' \
              'Use when auditing for FileSets left behind after a failed or partial ingest, ' \
              'or after parent works were deleted without cleaning up their FileSets.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                fields: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Solr fields to return for each orphaned FileSet. ' \
                               'Defaults to ["id", "title_tesim"] if omitted.'
                }
              },
              required: []
            }
          end
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          fields = params['fields'] || %w[id title_tesim]
          results = find_orphaned_file_sets(fields:)
          text_response(results.to_json)
        rescue StandardError => e
          text_response({ error: e.message }.to_json)
        end

        private

        def find_orphaned_file_sets(fields:)
          query = 'has_model_ssim:FileSet AND -{!join from=member_ids_ssim to=id}*:*'
          response = Hyrax::SolrService.get(query, rows: solr_rows, fl: fields.join(','))
          docs = response.dig('response', 'docs') || []
          docs.map { |doc| doc.slice(*fields) }
        end
      end
    end
  end
end
