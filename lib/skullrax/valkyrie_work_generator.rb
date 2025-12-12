# frozen_string_literal: true

module Skullrax
  # rubocop:disable Metrics/ClassLength
  class ValkyrieWorkGenerator
    attr_writer :work
    attr_accessor :errors
    attr_reader :model, :kwargs

    def initialize(model: nil, **kwargs)
      @model = model || default_model
      @kwargs = kwargs
      @work = nil
      @errors = []
    end

    def create
      validate_form
      perform_action
    end

    def work
      @work ||= model.new.tap do |w|
        w.depositor = user.email
        w.admin_set_id = admin_set_id
      end
    end

    private

    def default_model
      Wings::ModelRegistry.reverse_lookup(Hyrax.config.curation_concerns.first)
    end

    def user
      @user ||= User.find_by_email('admin@example.com')
    end

    def admin_set_id
      @admin_set_id ||= Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
    end

    def form
      @form ||= form_class.new(resource: work)
    end

    def form_class
      Hyrax::WorkFormService.form_class(work)
    end

    def param_key
      model.model_name.param_key
    end

    def required_properties
      model.schema.filter_map { |key| key.name.to_s if key.meta.dig('form', 'required') }
    end

    def param_hash
      @param_hash ||= build_param_hash
    end

    def build_param_hash
      base_params.tap do |hash|
        add_visibility(hash)
        add_additional_attributes(hash)
      end
    end

    def base_params
      required_properties.each_with_object({}) do |property, hash|
        hash[property] = param_value_for(property)
      end
    end

    def param_value_for(property)
      return controlled_vocabulary_for(property) if controlled_property?(property)

      ["Test #{property}"]
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

    def params
      { param_key => param_hash }
    end

    def validate_form
      form.validate(params[param_key])
    end

    def action
      @action ||= Hyrax::Action::CreateValkyrieWork.new(
        form:,
        transactions: Hyrax::Transactions::Container,
        user:,
        params:,
        work_attributes_key: param_key
      )
    end

    def perform_action
      action.validate
      result = action.perform

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def handle_success(result)
      self.work = result.value!
      result
    end

    def handle_failure(result)
      formatter = ErrorFormatter.new(result)
      formatter.log
      @errors << formatter.format
      result
    end
  end
  # rubocop:enable Metrics/ClassLength
end
