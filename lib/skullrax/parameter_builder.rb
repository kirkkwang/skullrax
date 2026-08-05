# frozen_string_literal: true

module Skullrax
  class ParameterBuilder
    include SchemaPropertyFilterConcern

    attr_reader :model, :fill_mode, :except, :skip_existence_check, :kwargs

    include Skullrax::ObjectNotFound

    def initialize(model:, fill_mode: :required, except: [], skip_existence_check: false, **kwargs)
      @model = model
      @fill_mode = fill_mode
      @except = Array.wrap(except).map(&:to_s)
      @skip_existence_check = skip_existence_check
      @kwargs = kwargs
    end

    def build
      base_params.tap do |hash|
        VisibilityHandler.add_visibility(hash, kwargs)
        add_custom_attributes(hash)
      end
    end

    def required_properties
      super(model).map(&:to_s)
    end

    def settable_properties
      splittable_properties(model).map(&:to_s)
    end

    private

    def properties
      case fill_mode
      when :none then []
      when :required then (required_properties - except - compound_properties)
      when :all then (settable_properties - except - compound_properties)
      end
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

      [resolve_test_value(property)]
    end

    def add_custom_attributes(hash) # rubocop:disable Metrics/AbcSize
      kwargs.each do |key, value|
        validate_existence(value) if relationship_key?(key) && !skip_existence_check

        if compound_handler.handles?(model, key)
          hash[compound_handler.param_key(key)] = compound_handler.process(key, value)
        else
          processed = process_attribute(key, value)
          key = based_near_handler.param_key if based_near_handler.handles?(key.to_s)
          hash[key] = processed
        end
      end
    end

    def process_attribute(key, value)
      return based_near_handler.process(value) if based_near_handler.handles?(key.to_s)

      Array.wrap(value)
    end

    def compound_properties
      compound_handler.compound_names(model)
    end

    def controlled_property?(property)
      Skullrax::ControlledVocabularyHandler.controlled_properties.include?(property)
    end

    def controlled_vocabulary_for(property)
      Skullrax::ControlledVocabularyHandler.new(property, kwargs[property.to_sym]).validate
    end

    def relationship_key?(key)
      %i[member_of_collection_ids member_ids].include?(key)
    end

    def validate_existence(ids)
      Array.wrap(ids).each do |id|
        Hyrax.query_service.find_by(id:)
      rescue *object_not_found_errors
        raise Skullrax::ObjectNotFoundError, I18n.t('skullrax.errors.object_not_found_single', id:)
      end
    end

    def resolve_test_value(property)
      callable = Skullrax.config.test_default_for(model, property) ||
                 Skullrax.config.default_test_value
      callable.call(model.to_s, property)
    end

    def based_near_handler
      Skullrax::BasedNearHandler
    end

    def compound_handler
      Skullrax::CompoundHandler
    end
  end
end
