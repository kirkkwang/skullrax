# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class DeleteResourcesTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'delete_resources'
          end

          def description
            'Deletes one or more Hyrax works, collections, or file sets by ID. ' \
            'IMPORTANT: Always ask the user to confirm before calling this tool. ' \
            'Only pass confirm: true if the user has explicitly agreed. ' \
            'Respects Hyrax CanCan permissions — the authenticated user must have delete access. ' \
            'Returns per-resource status.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                resource_type: {
                  type: 'string',
                  enum: %w[work collection file_set],
                  description: "Type of resource to delete: 'work', 'collection', or 'file_set'"
                },
                ids: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Array of resource IDs to delete'
                },
                confirm: {
                  type: 'boolean',
                  description: 'Must be true to proceed. IMPORTANT: Never set this to true on your own. ' \
                               'You must first show the user the IDs to be deleted and ask ' \
                               'for explicit confirmation. ' \
                               'Only pass confirm: true after the user has affirmatively agreed in the conversation.'
                }
              },
              required: %w[resource_type ids confirm]
            }
          end
        end

        def call(params:, current_user:)
          return text_response({ error: 'Deletion not confirmed. Set confirm: true to proceed.' }.to_json) \
            unless params['confirm'] == true

          resource_type = params['resource_type'] || 'work'
          ids = params['ids'] || []

          results = ids.map { |id| delete_resource(id, resource_type, current_user) }
          text_response(results.to_json)
        end

        private

        def delete_resource(id, resource_type, user)
          generator = build_generator(resource_type, id, user)
          result = generator.destroy

          if result.success?
            { id:, status: 'deleted' }
          else
            { id:, status: 'failed', errors: generator.errors }
          end
        rescue StandardError => e
          { id:, status: 'failed', errors: [e.message] }
        end

        def build_generator(resource_type, id, user)
          case resource_type
          when 'collection'
            Skullrax::ValkyrieCollectionGenerator.new(user:, id:)
          when 'file_set'
            Skullrax::ValkyrieFileSetGenerator.new(user:, id:)
          else
            Skullrax::ValkyrieWorkGenerator.new(user:, id:)
          end
        end
      end
    end
  end
end
