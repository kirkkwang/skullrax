# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class RecharacterizeFileSetsTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'recharacterize_file_sets'
          end

          def description
            'Re-runs FITS characterization on the OriginalFile of a FileSet and updates ' \
              'FileMetadata fields (mime_type, format_label, height, width, checksum, etc.). ' \
              'Use when characterization failed silently during ingest, produced incomplete ' \
              'metadata, or needs to be refreshed after a FITS configuration change. ' \
              'Use async: false when recharacterizing a single FileSet and the result is ' \
              'needed immediately — the characterization snapshot is returned in the response. ' \
              'Use async: true (default) when recharacterizing multiple FileSets — call this ' \
              'tool once per FileSet and let the jobs run in the background rather than ' \
              'blocking the server.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                file_set_id: {
                  type: 'string',
                  description: 'The Valkyrie ID of the FileSet'
                },
                async: {
                  type: 'boolean',
                  description: 'When true (default) enqueues a background job — use for ' \
                               'multiple FileSets to avoid blocking the server. ' \
                               'When false runs characterization inline and returns the ' \
                               'updated metadata snapshot — use for a single FileSet ' \
                               'when the result is needed immediately.'
                }
              },
              required: ['file_set_id']
            }
          end
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          file_set_id = params['file_set_id']
          return text_response({ error: 'file_set_id is required' }.to_json) unless file_set_id

          async = params.fetch('async', true)
          result = Skullrax::RecharacterizationHandler.new(file_set_id:, async:).call
          text_response(result.to_json)
        end
      end
    end
  end
end
