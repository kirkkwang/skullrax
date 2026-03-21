# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class ManageDerivativesTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'manage_derivatives'
          end

          def description
            'Manages derivatives for a Hyrax FileSet. Supports four modes: ' \
              "'list' (synchronous) — returns existing derivatives, available types for the " \
              "FileSet's mime type, and ImageMagick writable formats; " \
              "'regenerate' (async) — runs cleanup synchronously then enqueues the full derivative " \
              'pipeline via ValkyrieCreateDerivativesJob; ' \
              "'create' (async) — enqueues creation of a single derivative type by ImageMagick-writable format name; " \
              "'delete' (synchronous) — removes a specific derivative from disk, Postgres FileMetadata, " \
              "FileSet file_ids, and Solr. Call 'list' first to discover derivative file_ids and " \
              "available types before calling 'create' or 'delete'."
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                file_set_id: {
                  type: 'string',
                  description: 'The Valkyrie ID of the FileSet'
                },
                mode: {
                  type: 'string',
                  enum: %w[list regenerate create delete],
                  description: 'list = show available derivative types for this FileSet. ' \
                               'regenerate = enqueue cleanup + re-run full pipeline. ' \
                               'create = enqueue creation of a specific derivative. ' \
                               'delete = remove a specific derivative.'
                },
                derivative_type: {
                  type: 'string',
                  description: "Only used when mode is 'create'. Any ImageMagick-writable format name " \
                               '(e.g. png, jp2, avif, webp, tif). ' \
                               "Use 'list' mode to see writable formats available for this FileSet."
                },
                mime_type: {
                  type: 'string',
                  description: "Only used when mode is 'create'. The MIME type for the derivative " \
                               "(e.g. 'image/png', 'image/jp2', 'image/avif'). If unsure, ask the user. " \
                               "Defaults to 'application/octet-stream' if not provided."
                },
                file_id: {
                  type: 'string',
                  description: "Only used when mode is 'delete'. The Valkyrie ID of the specific " \
                               "FileMetadata record to delete. Use 'list' mode first to find the ID."
                }
              },
              required: %w[file_set_id mode]
            }
          end
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          file_set_id = params['file_set_id']
          mode = params['mode']

          return text_response({ error: 'file_set_id is required' }.to_json) unless file_set_id
          return text_response({ error: 'mode is required' }.to_json) unless mode

          manager = Skullrax::DerivativesHandler.new(file_set_id)
          result = dispatch(manager, mode, params)
          text_response(result.to_json)
        rescue ArgumentError => e
          text_response({ error: e.message }.to_json)
        end

        private

        def dispatch(manager, mode, params)
          case mode
          when 'list' then manager.list
          when 'regenerate' then manager.regenerate
          when 'create' then handle_create(manager, params)
          when 'delete' then handle_delete(manager, params)
          else { error: "Unknown mode: #{mode}" }
          end
        end

        def handle_create(manager, params)
          derivative_type = params['derivative_type']
          return { error: "derivative_type is required when mode is 'create'" } unless derivative_type

          mime_type = params['mime_type']
          return { error: "mime_type is required when mode is 'create'" } unless mime_type

          manager.create(derivative_type, mime_type)
        end

        def handle_delete(manager, params)
          file_id = params['file_id']
          return { error: "file_id is required when mode is 'delete'" } unless file_id

          manager.delete(file_id)
        end
      end
    end
  end
end
