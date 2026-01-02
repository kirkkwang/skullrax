# frozen_string_literal: true

module Skullrax
  class ResourceFetcher
    class << self
      def fetch(ids:)
        found_resources = Hyrax.query_service.find_many_by_ids(ids:)
        validate_all_found!(ids.map(&:to_s), found_resources)

        found_resources.flat_map do |resource|
          file_sets = Hyrax.custom_queries.find_child_file_sets(resource:)
          [resource] + file_sets
        end
      end

      private

      def validate_all_found!(requested_ids, found_resources)
        found_ids = found_resources.map(&:id).map(&:to_s)
        missing_ids = requested_ids - found_ids
        return if missing_ids.empty?

        raise Skullrax::ObjectNotFoundError,
              "Cannot update: #{missing_ids.count} IDs not found: #{missing_ids.join(', ')}"
      end
    end
  end
end
