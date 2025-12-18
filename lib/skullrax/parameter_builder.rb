# frozen_string_literal: true

module Skullrax
  class ParameterBuilder
    attr_reader :model, :autofill, :except, :kwargs

    def initialize(model:, autofill: false, except: [], **kwargs)
      @model = model
      @autofill = autofill
      @except = Array.wrap(except).map(&:to_s)
      @kwargs = kwargs
    end

    def build
      base_params.tap do |hash|
        VisibilityHandler.add_visibility(hash, kwargs)
        add_custom_attributes(hash)
      end
    end

    def required_properties
      model.schema.filter_map { |key| key.name.to_s if key.meta.dig('form', 'required') }
    end

    def settable_properties
      model.schema.keys.filter_map { |key| key.name.to_s if key.meta['form'].present? }
    end

    private

    def properties
      (autofill ? settable_properties : required_properties) - except
    end

    def base_params
      properties.each_with_object({}) do |property, hash|
        hash[param_key_for(property)] = param_value_for(property)
      end
    end

    def param_key_for(property)
      based_near_handler.handles?(property) ? based_near_handler.param_key : property
    end

    def param_value_for(property)
      return controlled_vocabulary_for(property) if controlled_property?(property)
      return based_near_handler.default_value if based_near_handler.handles?(property) && kwargs[property].blank?

      ["Test #{property}"]
    end

    def controlled_property?(property)
      ControlledVocabularyHandler.controlled_properties.include?(property)
    end

    def controlled_vocabulary_for(property)
      ControlledVocabularyHandler.new(property, kwargs[property.to_sym]).validate
    end

    def add_custom_attributes(hash)
      kwargs.each do |key, value|
        validate_existence(key, value) if relationship_key?(key)
        hash[key] = process_attribute(key, value)
      end
    end

    def relationship_key?(key)
      %i[member_of_collection_ids member_ids].include?(key)
    end

    def validate_existence(key, ids)
      Array.wrap(ids).each do |id|
        Hyrax.query_service.find_by(id:)
      rescue Valkyrie::Persistence::ObjectNotFoundError
        raise error_klass_for(key), "#{id} not found.  Create it first or use a valid ID."
      end
    end

    def error_klass_for(key)
      key == :member_of_collection_ids ? Skullrax::CollectionNotFoundError : Skullrax::WorkNotFoundError
    end

    def process_attribute(key, value)
      return based_near_handler.process(value) if based_near_handler.handles?(key.to_s)

      Array.wrap(value)
    end

    def based_near_handler
      BasedNearHandler
    end
  end
end
