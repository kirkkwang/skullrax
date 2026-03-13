# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class CreateResourcesTool < Skullrax::Mcp::Tool
        def self.tool_name
          'create_resources'
        end

        def self.description
          'Creates one or more Hyrax works or collections via Skullrax. Accepts an array of records ' \
            'with work attributes and creates each one. Returns per-record status with IDs on success ' \
            'or error messages on failure. Run validate_resources first to check records are valid.'
        end

        def self.input_schema # rubocop:disable Metrics/MethodLength
          {
            type: 'object',
            properties: {
              resource_type: {
                type: 'string',
                enum: %w[work collection],
                description: "Type of resource to create: 'work' or 'collection'"
              },
              model: {
                type: 'string',
                description: "Work type model name (required for works), e.g. 'Monograph'"
              },
              records: {
                type: 'array',
                items: { type: 'object' },
                description: 'Array of attribute hashes for resources to create'
              }
            },
            required: %w[resource_type records]
          }
        end

        def call(params:, current_user:)
          resource_type = params['resource_type'] || 'work'
          model_name = params['model']
          records = params['records'] || []

          results = records.map { |record| create_resource(record, resource_type, model_name, current_user) }
          text_response(results.to_json)
        end

        private

        def create_resource(record, resource_type, model_name, user)
          generator = build_generator(resource_type, model_name, record, user)
          result = generator.create

          if result.success?
            resource = result.value!
            { id: resource.id.to_s, title: Array(resource.title).first, status: 'created' }
          else
            { status: 'failed', errors: generator.errors }
          end
        rescue StandardError => e
          { status: 'failed', errors: [e.message] }
        end

        def build_generator(resource_type, model_name, record, user)
          attrs = record.symbolize_keys

          if resource_type == 'collection'
            Skullrax::ValkyrieCollectionGenerator.new(user:, **attrs)
          else
            Skullrax::ValkyrieWorkGenerator.new(model: model_name, user:, **attrs)
          end
        end
      end
    end
  end
end
