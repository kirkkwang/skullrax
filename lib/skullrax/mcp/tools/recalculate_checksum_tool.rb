# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class RecalculateChecksumTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'recalculate_checksum'
          end

          def description
            'Recomputes the MD5 checksum for the OriginalFile of a FileSet and persists it to ' \
              'FileMetadata#checksum. Use when checksums are missing (never computed during ingest) ' \
              'or need to be refreshed after a file update.'
          end

          def input_schema
            {
              type: 'object',
              properties: {
                file_set_id: {
                  type: 'string',
                  description: 'The Valkyrie ID of the FileSet'
                }
              },
              required: ['file_set_id']
            }
          end
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          file_set_id = params['file_set_id']
          return text_response({ error: 'file_set_id is required' }.to_json) unless file_set_id

          result = Skullrax::ChecksumHandler.new(file_set_id:).recalculate
          text_response(result.to_json)
        end
      end
    end
  end
end
