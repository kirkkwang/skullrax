# frozen_string_literal: true

module Skullrax
  # rubocop:disable Metrics/ClassLength
  class ValkyrieWorkGenerator
    attr_writer :work
    attr_accessor :errors
    attr_reader :model, :autofill, :kwargs

    def initialize(model: nil, file_paths: [], autofill: false, except: [], **kwargs)
      @model = model || default_model
      @file_paths = Array.wrap(file_paths)
      @autofill = autofill
      @except = Array.wrap(except).map(&:to_s)
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

    def properties
      (autofill ? settable_properties : required_properties) - @except
    end

    def required_properties
      model.schema.filter_map { |key| key.name.to_s if key.meta.dig('form', 'required') }
    end

    def settable_properties
      model.schema.keys.filter_map { |schema_key| schema_key.name.to_s if schema_key.meta['form'].present? }
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

    attr_reader :file_paths

    def params
      base = { param_key => param_hash }
      base[:uploaded_files] = file_uploader.uploaded_file_ids if file_paths.any?
      base
    end

    def file_uploader
      @file_uploader ||= FileUploader.new(file_paths, user)
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
