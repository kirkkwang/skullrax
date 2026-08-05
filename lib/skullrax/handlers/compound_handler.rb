# frozen_string_literal: true

module Skullrax
  class CompoundHandler
    class << self
      def handles?(model, property)
        compound_names(model).include?(property.to_s.delete_suffix('_attributes'))
      end

      def param_key(property)
        "#{property.to_s.delete_suffix('_attributes')}_attributes"
      end

      def process(value)
        rows = fragment?(value) ? value.values : Array.wrap(value)
        rows.each_with_index.to_h { |row, index| [index.to_s, row.to_h.stringify_keys] }
      end

      def compound_names(model)
        return [] unless defined?(Hyrax::CompoundSchema) && model

        Hyrax::CompoundSchema.for(model).compound_names.map(&:to_s)
      rescue StandardError
        []
      end

      private

      def fragment?(value)
        value.is_a?(Hash) && value.values.all?(Hash)
      end
    end
  end
end
