# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class ValidateResourcesTool < Skullrax::Mcp::Tool
        include Skullrax::SchemaPropertyFilterConcern

        def self.tool_name
          'validate_resources'
        end

        def self.description
          'Validates a list of work records against a Hyrax work type schema. Use when the user wants ' \
            'to check or preview records before importing. Returns valid records and invalid records ' \
            'with reasons. Does not persist anything.'
        end

        def self.input_schema # rubocop:disable Metrics/MethodLength
          {
            type: 'object',
            properties: {
              model: {
                type: 'string',
                description: "The work type model name, e.g. 'Monograph'"
              },
              records: {
                type: 'array',
                items: { type: 'object' },
                description: 'Array of work attribute hashes to validate'
              }
            },
            required: %w[model records]
          }
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument, Metrics/AbcSize, Metrics/MethodLength
          model = resolve_model(params['model'])
          records = params['records'] || []

          required = required_properties(model)
          known = schema_for(model).map { |k| k.name.to_s }

          valid = []
          invalid = []

          records.each do |record|
            reasons = validate_record(record, required, known)

            if reasons.empty?
              valid << record
            else
              invalid << { record:, reasons: }
            end
          end

          text_response({ valid:, invalid: }.to_json)
        end

        private

        def resolve_model(model_name)
          Valkyrie.config.resource_class_resolver.call(model_name)
        end

        def validate_record(record, required_fields, known_fields)
          reasons = []

          required_fields.each do |field|
            value = record[field.to_s]
            reasons << "Missing required field: #{field}" if value.blank?
          end

          record.each_key do |key|
            reasons << "Unknown field: #{key}" unless known_fields.include?(key.to_s)
          end

          reasons
        end
      end
    end
  end
end
