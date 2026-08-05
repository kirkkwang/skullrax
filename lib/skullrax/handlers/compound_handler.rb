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

      def process(property, value)
        rows = fragment?(value) ? value.values : Array.wrap(value)
        unless rows.all?(Hash)
          raise Skullrax::ArgumentError,
                I18n.t('skullrax.errors.invalid_compound_value', property:, value: value.inspect)
        end

        rows.each_with_index.to_h { |row, index| [index.to_s, row.to_h.stringify_keys] }
      end

      def compound_names(model)
        return [] unless defined?(Hyrax::CompoundSchema) && model

        if flexible?
          names_for(model)
        else
          @compound_names ||= {}
          @compound_names[model.to_s] ||= names_for(model)
        end
      rescue StandardError
        []
      end

      private

      def flexible?
        Hyrax.config.respond_to?(:flexible?) && Hyrax.config.flexible?
      end

      def names_for(model)
        target = model.respond_to?(:new) ? model.new : model
        Hyrax::CompoundSchema.for(target).compound_names.map(&:to_s)
      end

      def fragment?(value)
        value.is_a?(Hash) && value.values.all?(Hash)
      end
    end
  end
end
