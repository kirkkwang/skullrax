# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class GetSchemaTool < Skullrax::Mcp::Tool
        include Skullrax::SchemaPropertyFilterConcern

        def self.tool_name
          'get_schema'
        end

        def self.description
          'Returns the schema for a Hyrax work type, including field names, types, required status, ' \
            'and splittable status. Use this before validating or creating works to understand what ' \
            'fields are expected and whether they accept multiple values.'
        end

        def self.input_schema
          {
            type: 'object',
            properties: {
              model: {
                type: 'string',
                description: "The work type model name, e.g. 'Monograph' or 'GenericWork'"
              }
            },
            required: ['model']
          }
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          model = resolve_model(params['model'])
          fields = build_schema_fields(model)
          text_response(fields.to_json)
        end

        private

        def resolve_model(model_name)
          Valkyrie.config.resource_class_resolver.call(model_name)
        rescue StandardError
          raise ArgumentError, "Unknown model: #{model_name}"
        end

        def build_schema_fields(model)
          required = required_properties(model)
          splittable = splittable_properties(model)

          schema_for(model).map do |schema_key|
            {
              name: schema_key.name,
              type: extract_type(schema_key),
              required: required.include?(schema_key.name),
              splittable: splittable.include?(schema_key.name)
            }
          end
        end

        def extract_type(schema_key)
          schema_key.type.name
        rescue StandardError
          schema_key.type.to_s
        end
      end
    end
  end
end
