# frozen_string_literal: true

module Skullrax
  module BatchCreate
    class CardComponent < ViewComponent::Base
      def batch_create_path
        helpers.skullrax.batch_create_path
      end

      def work_options
        safe_join(
          work_types.map do |work_type|
            content_tag(:option, work_type.split('::').last.titleize, value: work_type)
          end
        )
      end

      private

      def work_types
        if defined?(::Hyku)
          ::Site.instance.available_works
        else
          Hyrax.config.registered_curation_concern_types
        end
      end

      def collection_value
        Hyrax.config.collection_class.to_s
      end

      def file_set_value
        Hyrax.config.file_set_class.to_s
      end
    end
  end
end
