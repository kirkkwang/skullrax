# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class DeleteResourcesTool < Skullrax::Mcp::Tool
        def self.tool_name
          'delete_resources'
        end

        def self.description
          'Deletes one or more Hyrax works or collections by ID. Respects Hyrax CanCan permissions — ' \
            'the authenticated user must have delete access. Returns per-resource status.'
        end

        def self.input_schema # rubocop:disable Metrics/MethodLength
          {
            type: 'object',
            properties: {
              resource_type: {
                type: 'string',
                enum: %w[work collection],
                description: "Type of resource to delete: 'work' or 'collection'"
              },
              ids: {
                type: 'array',
                items: { type: 'string' },
                description: 'Array of resource IDs to delete'
              }
            },
            required: %w[resource_type ids]
          }
        end

        def call(params:, current_user:)
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
          if resource_type == 'collection'
            Skullrax::ValkyrieCollectionGenerator.new(user:, id:)
          else
            Skullrax::ValkyrieWorkGenerator.new(user:, id:)
          end
        end
      end
    end
  end
end
