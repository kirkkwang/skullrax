# frozen_string_literal: true

module Skullrax
  class ValkyrieFileSetGenerator
    include Skullrax::GeneratorConcern

    attr_reader :file_path

    alias assign_resource resource=

    def initialize(id: nil, file_path: nil, **kwargs)
      @id = id
      @file_path = file_path
      @kwargs = kwargs
      @errors = []
      @resource = model.new unless id
    end

    def resource
      @resource ||= Hyrax.query_service.find_by(id:)
    rescue *object_not_found_errors
      nil
    end

    private

    def validate_form
      form_valid = super
      file_valid = validate_file_presence

      form_valid && file_valid
    end

    def validate_file_presence
      return true if metadata_only_update?
      return false if creation_file_missing?

      validate_attachments(file_path)
    end

    def metadata_only_update?
      resource.persisted? && file_path.blank?
    end

    def creation_file_missing?
      return false if file_path.present?

      @errors << 'File is required for creation'
      true
    end

    def perform_create_action
      raise NotImplementedError, 'Direct FileSet creation is not yet implemented. Please attach files via the Work.'
    end

    def perform_update_action
      form.validate(merged_kwargs)

      result =
        transactions['change_set.update_file_set']
        .with_step_args('file_set.save_acl' => { permissions_params: form.input_params['permissions'] })
        .call(form)

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def perform_destroy_action
      result = transactions['file_set.destroy']
               .with_step_args('file_set.remove_from_work' => { user: },
                               'file_set.delete' => { user: })
               .call(resource)

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def model
      Hyrax.config.file_set_class
    end
  end
end
