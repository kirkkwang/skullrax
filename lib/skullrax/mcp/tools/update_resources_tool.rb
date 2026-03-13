# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class UpdateResourcesTool < Skullrax::Mcp::Tool
        def self.tool_name
          'update_resources'
        end

        def self.description
          'Updates one or more existing Hyrax works or collections. Each record must include an id ' \
            'field identifying the resource to update, plus any attributes to change. Returns ' \
            'per-record status.'
        end

        def self.input_schema # rubocop:disable Metrics/MethodLength
          {
            type: 'object',
            properties: {
              resource_type: {
                type: 'string',
                enum: %w[work collection],
                description: "Type of resource to update: 'work' or 'collection'"
              },
              records: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    id: { type: 'string', description: 'ID of the resource to update' }
                  },
                  required: ['id']
                },
                description: 'Array of records with id and updated attributes'
              }
            },
            required: %w[resource_type records]
          }
        end

        def call(params:, current_user:)
          resource_type = params['resource_type'] || 'work'
          records = params['records'] || []

          results = records.map { |record| update_resource(record, resource_type, current_user) }
          text_response(results.to_json)
        end

        private

        def update_resource(record, resource_type, user) # rubocop:disable Metrics/MethodLength
          id = record['id']
          model_name = record['model']
          attrs = record.except('id', 'model').symbolize_keys

          generator = build_generator(resource_type, id, model_name, attrs, user)
          result = generator.update

          if result.success?
            resource = result.value!
            { id: resource.id.to_s, status: 'updated' }
          else
            { id:, status: 'failed', errors: generator.errors }
          end
        rescue StandardError => e
          { id: record['id'], status: 'failed', errors: [e.message] }
        end

        def build_generator(resource_type, id, model_name, attrs, user)
          if resource_type == 'collection'
            Skullrax::ValkyrieCollectionGenerator.new(user:, id:, **attrs)
          else
            Skullrax::ValkyrieWorkGenerator.new(model: model_name, user:, id:, **attrs)
          end
        end
      end
    end
  end
end
