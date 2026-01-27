# frozen_string_literal: true

module Skullrax
  # rubocop:disable Metrics/ClassLength
  class VisibilityHandler
    class << self
      def add_visibility(hash, kwargs)
        visibility_params.each do |param|
          hash[param.to_s] = kwargs.delete(param).to_s if kwargs.key?(param)
        end
      end

      def extract(resource)
        attributes = { visibility: resource.visibility }
        embargo = resource.embargo
        lease = resource.lease

        set_embargo_attributes(embargo, attributes) if embargo&.active?
        set_lease_attributes(lease, attributes) if lease&.active?

        attributes
      end

      def headers
        visibility_params
      end

      def cleanup(resource:, params:)
        new_vis = params[:visibility]

        return embargo_destroyed?(resource) if new_vis != 'embargo' && resource.embargo&.active?
        return lease_destroyed?(resource) if new_vis != 'lease' && resource.lease&.active?

        false
      end

      def normalize_for_file_set(params)
        visibility = params[:visibility]

        case visibility
        when 'embargo'
          params[:visibility_during_embargo] || visibility
        when 'lease'
          params[:visibility_during_lease] || visibility
        else
          visibility
        end
      end

      def apply_to_file_set(file_set, params)
        return unless params.present?

        if params[:embargo_release_date].present?
          apply_embargo_to_file_set(file_set, params)
        elsif params[:lease_expiration_date].present?
          apply_lease_to_file_set(file_set, params)
        end
      end

      private

      def visibility_params
        %i[
          visibility
          visibility_during_embargo
          visibility_after_embargo
          embargo_release_date
          visibility_during_lease
          visibility_after_lease
          lease_expiration_date
        ]
      end

      def set_embargo_attributes(embargo, attributes)
        attributes[:visibility_during_embargo] = embargo.visibility_during_embargo
        attributes[:visibility_after_embargo] = embargo.visibility_after_embargo
        attributes[:embargo_release_date] = embargo.embargo_release_date.to_date
      end

      def set_lease_attributes(lease, attributes)
        attributes[:visibility_during_lease] = lease.visibility_during_lease
        attributes[:visibility_after_lease] = lease.visibility_after_lease
        attributes[:lease_expiration_date] = lease.lease_expiration_date.to_date
      end

      def embargo_destroyed?(resource)
        Hyrax::Actors::EmbargoActor.new(resource).destroy
        true
      end

      def lease_destroyed?(resource)
        Hyrax::Actors::LeaseActor.new(resource).destroy
        true
      end

      def apply_embargo_to_file_set(file_set, params)
        embargo = build_embargo(params)
        file_set.embargo = Hyrax.persister.save(resource: embargo)
        Hyrax::EmbargoManager.apply_embargo_for(resource: file_set)
        save_file_set_with_permissions(file_set)
      end

      def apply_lease_to_file_set(file_set, params)
        lease = build_lease(params)
        file_set.lease = Hyrax.persister.save(resource: lease)
        Hyrax::LeaseManager.apply_lease_for(resource: file_set)
        save_file_set_with_permissions(file_set)
      end

      def build_embargo(params)
        Hyrax::Embargo.new(
          embargo_release_date: Date.parse(params[:embargo_release_date].to_s),
          visibility_during_embargo: params[:visibility_during_embargo],
          visibility_after_embargo: params[:visibility_after_embargo]
        )
      end

      def build_lease(params)
        Hyrax::Lease.new(
          lease_expiration_date: Date.parse(params[:lease_expiration_date].to_s),
          visibility_during_lease: params[:visibility_during_lease],
          visibility_after_lease: params[:visibility_after_lease]
        )
      end

      def save_file_set_with_permissions(file_set)
        permission_manager = file_set.permission_manager.acl
        permission_manager.save if permission_manager.pending_changes?
        Hyrax.persister.save(resource: file_set)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
