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
        add_visibility(hash)
        add_additional_attributes(hash)
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
        key = property == 'based_near' ? 'based_near_attributes' : property
        hash[key] = param_value_for(property)
      end
    end

    def param_value_for(property)
      return controlled_vocabulary_for(property) if controlled_property?(property)
      return based_near_default if property == 'based_near' && kwargs[property].blank?

      ["Test #{property}"]
    end

    def based_near_default
      {
        '0' => {
          'id' => 'https://sws.geonames.org/5391811/',
          '_destroy' => 'false'
        }
      }
    end

    def controlled_property?(property)
      ControlledVocabularyHandler.controlled_properties.include?(property)
    end

    def controlled_vocabulary_for(property)
      ControlledVocabularyHandler.new(property, kwargs[property.to_sym]).validate
    end

    def add_visibility(hash)
      visibility = kwargs.delete(:visibility)
      hash['visibility'] = visibility if visibility
    end

    def add_additional_attributes(hash)
      kwargs.each do |key, value|
        hash[key] = value.is_a?(Array) ? value : [value]
      end
    end
  end
end
