# frozen_string_literal: true

module Skullrax
  module ResourceManagementConcern
    def retrieve_existing_resource
      raise Skullrax::ArgumentError, I18n.t('skullrax.errors.id_required') unless id.present?

      existing_resource = Hyrax.query_service.find_by(id:)
      assign_resource(existing_resource)
    rescue *object_not_found_errors
      raise Skullrax::ObjectNotFoundError, I18n.t('skullrax.errors.no_resource_found', id:)
    end

    def check_id
      return unless id.present?

      begin
        Hyrax.query_service.find_by(id:)
        raise Skullrax::IdAlreadyExistsError, I18n.t('skullrax.errors.id_already_exists', id:)
      rescue *object_not_found_errors
        true
      end
    end

    def assign_resource(resource)
      self.resource = resource
    end
  end
end
