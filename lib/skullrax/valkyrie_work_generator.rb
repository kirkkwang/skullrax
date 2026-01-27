# frozen_string_literal: true

module Skullrax
  class ValkyrieWorkGenerator
    attr_reader :model, :file_paths, :file_set_params

    include Skullrax::GeneratorConcern

    def initialize(model: nil, file_paths: [], file_set_params: [], user: nil, **kwargs)
      @model = normalize_model(model)
      @file_paths = file_paths
      @file_set_params = file_set_params
      @user = user
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
      Valkyrie.config.resource_class_resolver.call(Hyrax.config.registered_curation_concern_types.first)
    end

    private

    def normalize_model(model)
      model = model.to_s.safe_constantize || self.class.default_model
      Valkyrie.config.resource_class_resolver.call(model.to_s)
    end

    def validate_form
      form_valid = super
      files_valid = validate_file_presence
      form_valid && files_valid
    end

    def validate_file_presence
      validate_attachments(file_paths)
    end

    def perform_create_action
      action.validate
      result = transaction_executor.create

      if result.success?
        apply_file_set_embargoes_and_leases(result.value!)
        handle_success(result)
      else
        handle_failure(result)
      end
    end

    def perform_update_action
      cleanup_visibility!

      form.validate(merged_kwargs)

      result = transaction_executor.update
      result.success? ? handle_success(result) : handle_failure(result)
    end

    def perform_destroy_action
      result = transactions['work_resource.destroy']
               .with_step_args('work_resource.delete' => { user: },
                               'work_resource.delete_all_file_sets' => { user: })
               .call(resource)

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def action
      @action ||=
        Hyrax::Action::CreateValkyrieWork.new(form:, transactions:, user:, params:, work_attributes_key: attributes_key)
    end

    def transaction_executor
      @transaction_executor ||=
        Skullrax::WorkTransactionExecutor.new(action:, params:, user:, form:, file_set_params_builder:)
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
      @file_set_params_builder ||= Skullrax::FileSetParamsBuilder.new(file_paths:, file_set_params:, user:)
    end

    def admin_set_id
      @admin_set_id ||= Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
    end

    def cleanup_visibility!
      return unless Skullrax::VisibilityHandler.cleanup(resource:, params: merged_kwargs)

      @resource = Hyrax.query_service.find_by(id: resource.id)
      @form = nil
    end

    def apply_file_set_embargoes_and_leases(work)
      return if file_set_params.empty?

      file_sets = Hyrax.custom_queries.find_child_file_sets(resource: work)

      file_sets.each_with_index do |file_set, index|
        params = file_set_params[index]
        next unless params

        Skullrax::VisibilityHandler.apply_to_file_set(file_set, params)
      end
    end
  end
end
