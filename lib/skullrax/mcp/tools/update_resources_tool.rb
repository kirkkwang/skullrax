# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class UpdateResourcesTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'update_resources'
          end

          def description
            'Updates one or more existing Hyrax works, collections, or file sets. Each record must ' \
              'include an id field identifying the resource to update, plus any attributes to change. ' \
              'Array attributes (e.g. member_ids, keyword, creator) are replaced entirely — not merged — ' \
              'so always include the full desired array when updating them. ' \
              'To add a work or sub-collection to a collection, update the child with member_of_collection_ids. ' \
              'To add a child work or file set to a parent work, update the PARENT work with member_ids. ' \
              'Returns per-record status.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                resource_type: {
                  type: 'string',
                  enum: %w[work collection file_set],
                  description: "Type of resource to update: 'work', 'collection', or 'file_set'"
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
                      id: { type: 'string', description: 'ID of the resource to update' },
                      model: { type: 'string',
                               description: 'Work type model name, e.g. "Monograph". Optional — used when ' \
                                            'the generator needs the model to perform the update.' }
                    },
                    required: ['id']
                  },
                  description: 'Array of records with id and updated attributes. ' \
                               'Array attributes are fully replaced on update — fetch the current value ' \
                               'first if you need to append. ' \
                               'Use member_of_collection_ids on the child to nest inside a collection. ' \
                               'Use member_ids on the parent work to nest child works or file sets.'
                }
              },
              required: %w[resource_type records]
            }
          end
        end

        def call(params:, current_user:)
          resource_type = params['resource_type'] || 'work'
          records = params['records'] || []
          defaults = params['defaults'] || {}

          results = records.map { |record| update_resource(defaults.merge(record), resource_type, current_user) }
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
          case resource_type
          when 'collection'
            Skullrax::ValkyrieCollectionGenerator.new(user:, id:, **attrs)
          when 'file_set'
            Skullrax::ValkyrieFileSetGenerator.new(user:, id:, **attrs)
          else
            Skullrax::ValkyrieWorkGenerator.new(model: model_name, user:, id:, **attrs)
          end
        end
      end
    end
  end
end
