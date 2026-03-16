# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class FindMembersTool < Skullrax::Mcp::Tool
        COLLECTION_MODELS = %w[Collection Hyrax::PcdmCollection].freeze
        FILE_SET_MODELS = %w[FileSet Hyrax::FileSet].freeze
        WORK_MODELS = -> { Hyrax.config.curation_concerns.map(&:to_s) }
        SOLR_ROWS = 1_000

        def self.tool_name
          'find_members'
        end

        def self.description
          'Finds the members of a Hyrax collection or work. For a collection, queries Solr for ' \
            'resources whose member_of_collection_ids_ssim matches the given ID. For a work, ' \
            "reads member_ids_ssim from the parent work's Solr document and fetches those members. " \
            'Optionally filter by member_type (collection, work, file_set, or any). ' \
            'Returns up to 1000 members. For larger collections, use find_resources with a Solr query directly.'
        end

        def self.input_schema # rubocop:disable Metrics/MethodLength
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
              }
            },
            required: %w[id resource_type]
          }
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          id = params['id']
          member_type = params['member_type'] || 'any'

          docs = case params['resource_type']
                 when 'collection' then find_collection_members(id)
                 when 'work'       then find_work_members(id)
                 end

          text_response(filter_by_member_type(docs, member_type).to_json)
        end

        private

        def find_collection_members(id)
          Hyrax::SolrService.query("member_of_collection_ids_ssim:\"#{id}\"", rows: SOLR_ROWS)
                            .map { |doc| doc.to_h.compact }
        end

        def find_work_members(id)
          parent_doc = Hyrax::SolrService.query("id:#{id}", rows: 1).first
          return [] unless parent_doc

          member_ids = parent_doc['member_ids_ssim'] || []
          return [] if member_ids.empty?

          fetch_docs_by_ids(member_ids)
        end

        def fetch_docs_by_ids(ids)
          quoted = ids.map { |id| "\"#{id}\"" }.join(' OR ')
          Hyrax::SolrService.query("id:(#{quoted})", rows: ids.size)
                            .map { |doc| doc.to_h.compact }
        end

        def filter_by_member_type(docs, member_type)
          return docs if member_type == 'any'

          docs.select { |doc| matches_member_type?(doc, member_type) }
        end

        def matches_member_type?(doc, member_type) # rubocop:disable Metrics/MethodLength
          models = Array(doc['has_model_ssim'])

          case member_type
          when 'collection'
            models.any? { |m| COLLECTION_MODELS.include?(m) }
          when 'file_set'
            models.any? { |m| FILE_SET_MODELS.include?(m) }
          when 'work'
            models.any? { |m| WORK_MODELS.call.include?(m) }
          else
            true
          end
        end
      end
    end
  end
end
