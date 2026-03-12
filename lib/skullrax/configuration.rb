# frozen_string_literal: true

module Skullrax
  # @example configuring Skullrax in a host app
  #
  #   Skullrax.configure do |config|
  #     config.default_test_value = ->(model, property) { "#{model} #{property}" }
  #
  #     config.test_default_for('GenericWorkResource', :video_embed) do |_model, _property|
  #       "https://www.youtube.com/embed/Znf73dsFdC8"
  #     end
  #
  #     config.test_default_for('GenericWorkResource') do |model, property|
  #       "Test #{property} for #{model}"
  #     end
  #   end
  class Configuration
    attr_writer :default_test_value

    # Lambda called to generate a fallback test value for any model/property pair
    # not covered by a more specific +test_default_for+ registration.
    def default_test_value
      @default_test_value ||= ->(_model, property) { "Test #{property}" }
    end

    # Register or retrieve a per-model (or per-model+property) test value callable.
    #
    # When called with a block, registers the callable:
    #   config.test_default_for('Monograph', :title) { |model, property| "..." }
    #   config.test_default_for('Monograph') { |model, property| "..." }  # model-level default
    #
    # When called without a block, retrieves the best matching callable:
    #   config.test_default_for(Monograph, :title)  # => callable or nil
    #
    # Lookup priority: per-model+property > per-model default > nil
    def test_default_for(model, property = nil, &block)
      model_key = model.to_s
      return resolve_test_default(model_key, property&.to_s) unless block

      register_test_default(model_key, property, block)
    end

    private

    def test_defaults
      @test_defaults ||= {}
    end

    def register_test_default(model_key, property, block)
      test_defaults[model_key] ||= {}
      key = property ? property.to_s : :_model_default
      test_defaults[model_key][key] = block
    end

    def resolve_test_default(model_key, property_key)
      model_defaults = test_defaults[model_key]
      return nil unless model_defaults

      model_defaults[property_key] || model_defaults[:_model_default]
    end
  end
end
