# frozen_string_literal: true

module Skullrax
  class ValkyrieWorkGenerator
    attr_writer :resource
    attr_reader :model

    include Skullrax::GeneratorConcern

    def initialize(model: nil, file_paths: [], file_set_params: [], autofill: false, except: [], **kwargs) # rubocop:disable Metrics/ParameterLists
      @model = model || default_model
      @file_paths = file_paths
      @file_set_params = file_set_params
      @autofill = autofill
      @except = Array.wrap(except).map(&:to_s)
      @kwargs = kwargs
      @resource = nil
      @errors = []
    end

    def create
      validate_form
      perform_action
    end

    def resource
      @resource ||= model.new.tap do |w|
        w.depositor = user.email
        w.admin_set_id = admin_set_id
      end
    end

    private

    def perform_action
      action.validate
      result = transaction_executor.execute
      result.success? ? handle_success(result) : handle_failure(result)
    end

    def action
      @action ||=
        Hyrax::Action::CreateValkyrieWork.new(form:, transactions:, user:, params:, work_attributes_key: attributes_key)
    end

    def transaction_executor
      @transaction_executor ||= WorkTransactionExecutor.new(action:, params:, user:, form:, file_set_params_builder:)
    end

    def form
      @form ||= form_class.new(resource:)
    end

    def form_class
      Hyrax::WorkFormService.form_class(resource)
    end

    def params
      builder = file_set_params_builder

      result = { attributes_key => params_hash }
      result[attributes_key][:file_set] = builder.formatted_file_set_params if builder.formatted_file_set_params.any?
      result[:uploaded_files] = builder.uploaded_file_ids if builder.uploaded_file_ids.any?
      result
    end

    def file_set_params_builder
      @file_set_params_builder ||= FileSetParamsBuilder.new(@file_paths, @file_set_params, user)
    end

    def default_model
      Wings::ModelRegistry.reverse_lookup(Hyrax.config.curation_concerns.first)
    end

    def admin_set_id
      @admin_set_id ||= Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
    end
  end
end
