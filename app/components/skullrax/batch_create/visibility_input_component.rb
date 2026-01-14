# frozen_string_literal: true

module Skullrax
  module BatchCreate
    class VisibilityInputComponent < ViewComponent::Base
      def initialize(resource_type:)
        @resource_type = resource_type
      end

      private

      attr_reader :resource_type

      delegate :visibility_badge, :institution_name, to: :helpers
    end
  end
end
