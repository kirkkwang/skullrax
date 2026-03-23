# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class FindMembersTool < Skullrax::Mcp::Tool
        class << self
          def tool_name
            'find_members'
          end

          def description
            'Finds the members of a Hyrax collection or work. For a collection, queries Solr for ' \
              'resources whose member_of_collection_ids_ssim matches the given ID. For a work, ' \
              "reads member_ids_ssim from the parent work's Solr document and fetches those members. " \
              'Optionally filter by member_type (collection, work, file_set, or any). ' \
              'Returns up to 1000 members. For larger collections, use find_resources with a Solr query directly.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                id: {
                  type: 'string',
                  description: 'ID of the parent collection or work'
                },
                resource_type: {
                  type: 'string',
                  enum: %w[collection work],
                  description: "Type of the parent resource. Use 'collection' to find resources " \
                               "whose member_of_collection_ids_ssim matches id. Use 'work' to read " \
                               "member_ids_ssim from the parent work's Solr document."
                },
                member_type: {
                  type: 'string',
                  enum: %w[work collection file_set any],
                  description: "Filter the type of members to return. Defaults to 'any'.",
                  default: 'any'
                },
                fields: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Solr fields to return for each member, e.g. ["id", "title_tesim"]. ' \
                              'Defaults to all fields. Use to reduce response size for large collections.'
                }
              },
              required: %w[id resource_type]
            }
          end
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          id = params['id']
          member_type = params['member_type'] || 'any'
          fields = params['fields'] || []

          docs = case params['resource_type']
                 when 'collection' then find_collection_members(id, fields)
                 when 'work'       then find_work_members(id, fields)
                 end

          text_response(filter_by_member_type(docs, member_type).to_json)
        end

        private

        def find_collection_members(id, fields)
          opts = { rows: solr_rows }
          opts[:fl] = fields.join(',') if fields.any?
          Hyrax::SolrService.query("member_of_collection_ids_ssim:\"#{id}\"", **opts)
                            .map { |doc| doc.to_h.compact }
        end

        def find_work_members(id, fields)
          parent_doc = Hyrax::SolrService.query("id:#{id}", rows: 1).first
          return [] unless parent_doc

          member_ids = parent_doc['member_ids_ssim'] || []
          return [] if member_ids.empty?

          fetch_docs_by_ids(member_ids, fields)
        end

        def fetch_docs_by_ids(ids, fields)
          quoted = ids.map { |id| "\"#{id}\"" }.join(' OR ')
          opts = { rows: ids.size }
          opts[:fl] = fields.join(',') if fields.any?
          Hyrax::SolrService.query("id:(#{quoted})", **opts)
                            .map { |doc| doc.to_h.compact }
        end

        def filter_by_member_type(docs, member_type)
          return docs if member_type == 'any'

          docs.select { |doc| matches_member_type?(doc, member_type) }
        end

        def matches_member_type?(doc, member_type)
          model = doc['has_model_ssim']&.first
          return false unless model

          case member_type
          when 'collection' then collection_models.include?(model)
          when 'file_set'   then file_set_models.include?(model)
          when 'work'       then work_models.include?(model)
          else true
          end
        end

        def collection_models
          [Hyrax.config.collection_class.to_rdf_representation]
        end

        def file_set_models
          [Hyrax.config.file_set_class.to_rdf_representation]
        end

        def work_models
          Hyrax.config.curation_concerns.map(&:to_rdf_representation)
        end
      end
    end
  end
end
