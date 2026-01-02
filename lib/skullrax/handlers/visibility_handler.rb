# frozen_string_literal: true

module Skullrax
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
    end
  end
end
