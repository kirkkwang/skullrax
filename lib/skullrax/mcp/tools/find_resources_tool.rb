# frozen_string_literal: true

module Skullrax
  module Mcp
    module Tools
      class FindResourcesTool < Skullrax::Mcp::Tool # rubocop:disable Metrics/ClassLength
        class << self
          def tool_name
            'find_resources'
          end

          def description
            'Finds Hyrax works or collections by ID, terms, or Solr query string. Provide ids ' \
              '(array of resource IDs, uses Valkyrie query service for full attributes), terms ' \
              '(array of related search terms matched across all descriptive text fields with ' \
              'automatic field discovery), or query (Solr query string for catalog search, returns ' \
              'indexed fields). Priority order: ids → terms → query.'
          end

          def input_schema # rubocop:disable Metrics/MethodLength
            {
              type: 'object',
              properties: {
                ids: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Array of resource IDs to fetch via Valkyrie query service'
                },
                terms: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Array of semantically related search terms to match across all ' \
                    'descriptive text fields on indexed work and collection types. Before calling ' \
                    'this tool with a natural language concept, expand it to related terms — e.g. ' \
                    'for "france" pass ["france", "french", "paris", "parisian"]. The tool will ' \
                    'OR these terms across all relevant indexed fields automatically.'
                },
                query: {
                  type: 'string',
                  description: 'Solr query string to search the catalog, e.g. "title:My Work"'
                },
                fields: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Solr fields to return for each result, e.g. ["id", "title_tesim"]. ' \
                              'Defaults to all fields. Use to reduce response size for large result sets. ' \
                              'Does not apply when using ids, which fetches full attributes via Valkyrie.'
                }
              }
            }
          end
        end

        def call(params:, current_user:) # rubocop:disable Lint/UnusedMethodArgument
          fields = params['fields'] || []

          if params['ids'].present?
            find_by_ids(params['ids'])
          elsif params['terms'].present?
            find_by_terms(params['terms'], fields)
          elsif params['query'].present?
            find_by_query(params['query'], fields)
          else
            text_response({ error: "One of 'ids', 'terms', or 'query' must be provided" }.to_json)
          end
        end

        private

        def find_by_ids(ids)
          resources = Hyrax.query_service.find_many_by_ids(ids: ids.map(&:to_s))
          serialized = resources.map { |r| serialize_resource(r) }
          text_response(serialized.to_json)
        end

        def find_by_query(query, fields = [])
          opts = { rows: solr_rows }
          opts[:fl] = fields.join(',') if fields.any?
          docs = Hyrax::SolrService.query(query, **opts)
          serialized = docs.map { |doc| serialize_solr_doc(doc) }
          text_response(serialized.to_json)
        end

        def find_by_terms(terms, fields = []) # rubocop:disable Metrics/AbcSize
          solr_fields = descriptive_tesim_fields
          return text_response({ error: 'No searchable fields found' }.to_json) if solr_fields.empty?

          terms_query = terms.join(' OR ')
          fields_query = solr_fields.map { |field| "#{field}:(#{terms_query})" }.join(' OR ')
          query = "(#{model_filter}) AND (#{fields_query})"
          opts = { rows: solr_rows, qt: 'search' }
          opts[:fl] = fields.join(',') if fields.any?
          docs = Hyrax::SolrService.query(query, **opts)
          serialized = docs.map { |doc| serialize_solr_doc(doc) }
          text_response(serialized.to_json)
        end

        def descriptive_tesim_fields
          fields_from_schema & fields_from_luke
        end

        def fields_from_schema
          resource_types.flat_map do |type|
            model = Valkyrie.config.resource_class_resolver.call(type)
            model.schema.filter_map do |schema_key|
              "#{schema_key.name}_tesim" if schema_key.type.to_s.include?('Array')
            end
          end.uniq
        end

        def resource_types
          work_types + [Hyrax.config.collection_class.to_s]
        end

        def work_types
          if defined?(Hyku)
            ::Site.instance.available_works
          else
            Hyrax.config.curation_concerns.map(&:to_s)
          end
        end

        def model_filter
          resource_types.map { |t| "has_model_ssim:#{t}" }.join(' OR ')
        end

        def fields_from_luke
          luke_result = Hyrax::SolrService.get(path: 'admin/luke', numTerms: 0)
          luke_result['fields'].keys.select { |k| k.end_with?('_tesim') }
        end

        def serialize_resource(resource)
          resource.attributes
                  .transform_values { |v| coerce_value(v) }
                  .merge(type: resource.class.name)
                  .compact
        end

        def serialize_solr_doc(doc)
          doc.to_h.compact
        end

        def coerce_value(value)
          case value
          when Array
            value.map { |v| coerce_value(v) }
          when Valkyrie::ID, RDF::URI, RDF::Literal
            value.to_s
          when DateTime, Date, Time
            value.iso8601
          else
            value
          end
        end
      end
    end
  end
end
