# frozen_string_literal: true

module Skullrax
  class ControlledVocabularyHandler
    attr_reader :property, :values

    def initialize(property, values = nil)
      @property = property
      @values = Array.wrap(values)
    end

    def self.controlled_properties
      @controlled_properties ||= qa_registry.filter_map do |k, v|
        k.singularize if v.klass == Qa::Authorities::Local::FileBasedAuthority
      end
    end

    def self.qa_registry
      @qa_registry ||= Qa::Authorities::Local.registry.instance_variable_get('@hash')
    end

    def validate
      return first_valid_term if values.empty?

      values.flat_map { |value| validate_term(value) }
    end

    private

    def authority
      @authority ||= Qa::Authorities::Local.subauthority_for(property.pluralize)
    rescue Qa::InvalidSubAuthority
      # Try singular if plural not found
      @authority ||= Qa::Authorities::Local.subauthority_for(property)
    end

    def first_valid_term
      term = authority.all.find { |t| t[:active] }
      term ? [term[:id]] : []
    end

    def validate_term(value)
      term = authority.find(value)
      return [term[:id]] if active_term?(term)

      raise ArgumentError, error_message(value)
    end

    def active_term?(term)
      term&.dig('active') == true
    end

    def error_message(value)
      "'#{value}' is not an active term in the controlled vocabulary for '#{property}'"
    end
  end
end
