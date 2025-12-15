# frozen_string_literal: true

module Skullrax
  class VisibilityHandler
    class << self
      def add_visibility(hash, kwargs)
        visibility_params.each do |param|
          hash[param.to_s] = kwargs.delete(param).to_s if kwargs.key?(param)
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
    end
  end
end
