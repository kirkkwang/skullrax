# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class CreateResourcesTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'create_resources'
          end

          def description
            'Creates one or more Hyrax works or collections via Skullrax. Accepts an array of records ' \
              'with work attributes and creates each one. Returns per-record status with IDs on success ' \
              'or error messages on failure. Run validate_resources first to check records are valid. ' \
              'To attach a file (local path or remote URL), include a file_paths key in the record — ' \
              'in majority of cases, do not use import_url, which is a raw persistence field and ' \
              'will not attach the file correctly.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
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
                defaults: {
                  type: 'object',
                  description: 'Attributes merged into every record. Record-level values take precedence.'
                },
                records: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      file_paths: {
                        type: %w[string array],
                        description: 'Local file path(s) or remote URL(s) to attach to the work. ' \
                                     'Accepts a single string or an array of strings.'
                      },
                      file_set_params: {
                        type: %w[object array],
                        description: 'Metadata for each attached file set, in the same order as file_paths. ' \
                                     'Accepts a single hash (applies to the first file) or an array of hashes ' \
                                     '(one per file). Supported keys: title, description, keyword, creator, etc. ' \
                                     'Example: [{ title: "Figure 1", description: "Chart showing results" }]'
                      }
                    }
                  },
                  description: 'Array of attribute hashes for resources to create. Each hash may ' \
                               'include any work attribute plus file_paths and file_set_params for file attachment.'
                }
              },
              required: %w[resource_type records]
            }
          end
        end

        def call(params:, current_user:)
          resource_type = params['resource_type'] || 'work'
          model_name = params['model']
          records = params['records'] || []
          defaults = params['defaults'] || {}

          results = records.map do |record|
            create_resource(defaults.merge(record), resource_type, model_name, current_user)
          end
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
