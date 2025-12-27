# frozen_string_literal: true

module Skullrax
  class ValkyrieWorkGenerator
    attr_reader :model, :file_paths, :file_set_params

    include Skullrax::GeneratorConcern

    def initialize(model: nil, file_paths: [], file_set_params: [], **kwargs)
      @model = normalize_model(model)
      @file_paths = file_paths
      @file_set_params = file_set_params
      @kwargs = kwargs
      @id = kwargs.delete(:id)
      @resource = nil
      @errors = []
    end

    def resource
      @resource ||= model.new.tap do |w|
        w.id = id if id.present?
        w.depositor = user.email
        w.admin_set_id = admin_set_id
      end
    end

    def self.default_model
      Wings::ModelRegistry.reverse_lookup(Hyrax.config.curation_concerns.first)
    end

    private

    def normalize_model(model)
      model = model.to_s.safe_constantize || self.class.default_model
      Wings::ModelRegistry.reverse_lookup(model) || model
    end

    def perform_create_action
      action.validate
      result = transaction_executor.create
      result.success? ? handle_success(result) : handle_failure(result)
    end

    def perform_update_action
      result = transaction_executor.update
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
      @file_set_params_builder ||= FileSetParamsBuilder.new(file_paths, file_set_params, user)
    end

    def admin_set_id
      @admin_set_id ||= Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
    end
  end
end
