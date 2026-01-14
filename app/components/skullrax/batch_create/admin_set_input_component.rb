# frozen_string_literal: true

module Skullrax
  module BatchCreate
    class AdminSetInputComponent < ViewComponent::Base
      attr_reader :resource_type, :work_types

      def initialize(work_types:, resource_type:)
        @work_types = work_types
        @resource_type = resource_type
      end

      private

      def render?
        Flipflop.assign_admin_set? && work_types.include?(resource_type)
      end
    end
  end
end
